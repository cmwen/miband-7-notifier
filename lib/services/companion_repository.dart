import 'dart:convert';

import '../models/companion_models.dart';
import 'storage_service.dart';

class CompanionRepository {
  CompanionRepository({required StorageService storageService})
    : _storageService = storageService;

  static const _configKey = 'companion_config';
  static const _journalKey = 'companion_journal';
  static const _maxJournalEntries = 25;

  final StorageService _storageService;

  Future<CompanionConfig> loadConfig() async {
    final raw = _storageService.getString(_configKey);
    if (raw == null || raw.isEmpty) {
      return CompanionConfig.initial();
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return CompanionConfig.initial();
      }

      return CompanionConfig.fromJson(decoded);
    } on FormatException {
      return CompanionConfig.initial();
    }
  }

  Future<void> saveConfig(CompanionConfig config) async {
    await _storageService.setString(_configKey, jsonEncode(config.toJson()));
  }

  Future<List<CompanionJournalEntry>> loadJournal() async {
    final rawEntries = _storageService.getStringList(_journalKey) ?? const [];
    final entries = <CompanionJournalEntry>[];

    for (final entry in rawEntries) {
      try {
        final decoded = jsonDecode(entry);
        if (decoded is! Map<String, dynamic>) {
          continue;
        }
        entries.add(CompanionJournalEntry.fromJson(decoded));
      } on FormatException {
        continue;
      }
    }

    return entries;
  }

  Future<List<CompanionJournalEntry>> appendJournalEntry({
    required String message,
    required CompanionLogLevel level,
  }) async {
    final current = await loadJournal();
    final updated = [
      CompanionJournalEntry(
        message: message,
        level: level,
        createdAt: DateTime.now(),
      ),
      ...current,
    ].take(_maxJournalEntries).toList(growable: false);

    await _storageService.setStringList(
      _journalKey,
      updated
          .map((entry) => jsonEncode(entry.toJson()))
          .toList(growable: false),
    );

    return updated;
  }
}
