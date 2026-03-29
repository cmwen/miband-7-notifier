import 'dart:convert';

import '../models/companion_models.dart';

class AuthKeyExtractorService {
  const AuthKeyExtractorService();

  static final RegExp _namedKeyExpression = RegExp(
    r'(encryptKey|token|authKey|huamiAuthKey|auth_key|AUTHKEY)[^0-9a-fA-F]*(?:0x)?([0-9a-fA-F]{32})',
    caseSensitive: false,
  );
  static final RegExp _bareKeyExpression = RegExp(
    r'(?:0x)?([0-9a-fA-F]{32})',
    caseSensitive: false,
  );

  List<AuthKeyCandidate> extractCandidates(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const [];
    }

    final candidatesByKey = <String, AuthKeyCandidate>{};

    void addCandidate(
      String? rawKey, {
      required AuthKeySource source,
      required String sourceLabel,
    }) {
      final normalizedKey = normalize(rawKey ?? '');
      if (normalizedKey == null) {
        return;
      }

      candidatesByKey.putIfAbsent(
        normalizedKey,
        () => AuthKeyCandidate(
          normalizedKey: normalizedKey,
          source: source,
          sourceLabel: sourceLabel,
        ),
      );
    }

    for (final match in _namedKeyExpression.allMatches(trimmed)) {
      final fieldName = (match.group(1) ?? '').toLowerCase();
      addCandidate(
        match.group(2),
        source: _sourceForField(fieldName),
        sourceLabel: _sourceLabelForField(fieldName),
      );
    }

    final decoded = _tryDecodeJson(trimmed);
    if (decoded != null) {
      _collectJsonCandidates(decoded, addCandidate);
    }

    for (final match in _bareKeyExpression.allMatches(trimmed)) {
      final fallbackSource = _inferFallbackSource(trimmed);
      addCandidate(
        match.group(1),
        source: fallbackSource,
        sourceLabel: fallbackSource.label,
      );
    }

    final candidates = candidatesByKey.values.toList(growable: false);
    candidates.sort(
      (left, right) => left.source.index.compareTo(right.source.index),
    );
    return candidates;
  }

  String? normalize(String raw) {
    final match = _bareKeyExpression.firstMatch(raw.trim());
    if (match == null) {
      return null;
    }

    return '0x${match.group(1)!.toLowerCase()}';
  }

  dynamic _tryDecodeJson(String raw) {
    if (!raw.startsWith('{') && !raw.startsWith('[')) {
      return null;
    }

    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  void _collectJsonCandidates(
    dynamic value,
    void Function(
      String? rawKey, {
      required AuthKeySource source,
      required String sourceLabel,
    })
    addCandidate,
  ) {
    if (value is Map<String, dynamic>) {
      value.forEach((key, nestedValue) {
        final fieldName = key.toLowerCase();
        if (_isKnownAuthField(fieldName)) {
          addCandidate(
            nestedValue?.toString(),
            source: _sourceForField(fieldName),
            sourceLabel: _sourceLabelForField(fieldName),
          );
        }
        _collectJsonCandidates(nestedValue, addCandidate);
      });
      return;
    }

    if (value is List<dynamic>) {
      for (final nestedValue in value) {
        _collectJsonCandidates(nestedValue, addCandidate);
      }
    }
  }

  bool _isKnownAuthField(String fieldName) {
    return switch (fieldName) {
      'encryptkey' ||
      'token' ||
      'authkey' ||
      'huamiauthkey' ||
      'auth_key' => true,
      _ => false,
    };
  }

  AuthKeySource _sourceForField(String fieldName) {
    return switch (fieldName) {
      'authkey' || 'auth_key' => AuthKeySource.rootedDatabase,
      'token' => AuthKeySource.externalTool,
      _ => AuthKeySource.pastedLog,
    };
  }

  String _sourceLabelForField(String fieldName) {
    return switch (_sourceForField(fieldName)) {
      AuthKeySource.rootedDatabase => 'Vendor database / rooted extraction',
      AuthKeySource.pastedLog => 'Mi Fitness / Zepp log field',
      AuthKeySource.externalTool => 'huami-token / huafetcher output',
      AuthKeySource.manual => 'Manual key',
    };
  }

  AuthKeySource _inferFallbackSource(String raw) {
    final normalized = raw.toLowerCase();
    if (normalized.contains('sqlite') || normalized.contains('origin_db')) {
      return AuthKeySource.rootedDatabase;
    }
    if (normalized.contains('huami-token') ||
        normalized.contains('huafetcher') ||
        normalized.contains('token=')) {
      return AuthKeySource.externalTool;
    }
    if (normalized.contains('xiaomifit') ||
        normalized.contains('encryptkey') ||
        normalized.contains('huamiauthkey')) {
      return AuthKeySource.pastedLog;
    }
    return AuthKeySource.manual;
  }
}
