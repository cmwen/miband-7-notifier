enum VendorAppKind { zeppLife, zepp, miFitness }

extension VendorAppKindLabel on VendorAppKind {
  String get label => switch (this) {
    VendorAppKind.zeppLife => 'Zepp Life',
    VendorAppKind.zepp => 'Zepp',
    VendorAppKind.miFitness => 'Mi Fitness',
  };

  String get packageName => switch (this) {
    VendorAppKind.zeppLife => 'com.xiaomi.hm.health',
    VendorAppKind.zepp => 'com.huami.watch.hmwatchmanager',
    VendorAppKind.miFitness => 'com.xiaomi.wearable',
  };
}

VendorAppKind vendorAppKindFromName(String? value) {
  return VendorAppKind.values.firstWhere(
    (item) => item.name == value,
    orElse: () => VendorAppKind.zeppLife,
  );
}

enum AuthKeySource { manual, rootedDatabase, pastedLog, externalTool }

extension AuthKeySourceLabel on AuthKeySource {
  String get label => switch (this) {
    AuthKeySource.manual => 'Manual key',
    AuthKeySource.rootedDatabase => 'Rooted vendor database',
    AuthKeySource.pastedLog => 'Pasted log / JSON',
    AuthKeySource.externalTool => 'External token tool',
  };
}

AuthKeySource authKeySourceFromName(String? value) {
  return AuthKeySource.values.firstWhere(
    (item) => item.name == value,
    orElse: () => AuthKeySource.manual,
  );
}

enum CompanionLogLevel { info, success, warning }

extension CompanionLogLevelLabel on CompanionLogLevel {
  String get label => switch (this) {
    CompanionLogLevel.info => 'Info',
    CompanionLogLevel.success => 'Success',
    CompanionLogLevel.warning => 'Warning',
  };
}

CompanionLogLevel companionLogLevelFromName(String? value) {
  return CompanionLogLevel.values.firstWhere(
    (item) => item.name == value,
    orElse: () => CompanionLogLevel.info,
  );
}

class CompanionConfig {
  const CompanionConfig({
    required this.vendorApp,
    required this.officialPairingCompleted,
    required this.authKey,
    required this.authKeySource,
    required this.deviceName,
    required this.deviceId,
    required this.updatedAt,
  });

  factory CompanionConfig.initial() {
    return CompanionConfig(
      vendorApp: VendorAppKind.zeppLife,
      officialPairingCompleted: false,
      authKey: null,
      authKeySource: AuthKeySource.manual,
      deviceName: '',
      deviceId: '',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  factory CompanionConfig.fromJson(Map<String, dynamic> json) {
    return CompanionConfig(
      vendorApp: vendorAppKindFromName(json['vendorApp'] as String?),
      officialPairingCompleted:
          json['officialPairingCompleted'] as bool? ?? false,
      authKey: json['authKey'] as String?,
      authKeySource: authKeySourceFromName(json['authKeySource'] as String?),
      deviceName: json['deviceName'] as String? ?? '',
      deviceId: json['deviceId'] as String? ?? '',
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final VendorAppKind vendorApp;
  final bool officialPairingCompleted;
  final String? authKey;
  final AuthKeySource authKeySource;
  final String deviceName;
  final String deviceId;
  final DateTime updatedAt;

  bool get hasAuthKey => authKey != null && authKey!.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'vendorApp': vendorApp.name,
    'officialPairingCompleted': officialPairingCompleted,
    'authKey': authKey,
    'authKeySource': authKeySource.name,
    'deviceName': deviceName,
    'deviceId': deviceId,
    'updatedAt': updatedAt.toIso8601String(),
  };

  CompanionConfig copyWith({
    VendorAppKind? vendorApp,
    bool? officialPairingCompleted,
    String? authKey,
    bool clearAuthKey = false,
    AuthKeySource? authKeySource,
    String? deviceName,
    String? deviceId,
    DateTime? updatedAt,
  }) {
    return CompanionConfig(
      vendorApp: vendorApp ?? this.vendorApp,
      officialPairingCompleted:
          officialPairingCompleted ?? this.officialPairingCompleted,
      authKey: clearAuthKey ? null : (authKey ?? this.authKey),
      authKeySource: authKeySource ?? this.authKeySource,
      deviceName: deviceName ?? this.deviceName,
      deviceId: deviceId ?? this.deviceId,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class CompanionJournalEntry {
  const CompanionJournalEntry({
    required this.message,
    required this.level,
    required this.createdAt,
  });

  factory CompanionJournalEntry.fromJson(Map<String, dynamic> json) {
    return CompanionJournalEntry(
      message: json['message'] as String? ?? '',
      level: companionLogLevelFromName(json['level'] as String?),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String message;
  final CompanionLogLevel level;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'message': message,
    'level': level.name,
    'createdAt': createdAt.toIso8601String(),
  };

  String get createdAtLabel {
    final local = createdAt.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }
}

class AuthKeyCandidate {
  const AuthKeyCandidate({
    required this.normalizedKey,
    required this.source,
    required this.sourceLabel,
  });

  final String normalizedKey;
  final AuthKeySource source;
  final String sourceLabel;
}

class ScannedBand {
  const ScannedBand({
    required this.name,
    required this.id,
    required this.rssi,
    required this.connectable,
  });

  final String name;
  final String id;
  final int rssi;
  final bool connectable;

  String get displayName => name.isEmpty ? 'Unnamed BLE device' : name;
}
