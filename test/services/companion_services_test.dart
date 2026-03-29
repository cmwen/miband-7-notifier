import 'package:flutter_test/flutter_test.dart';
import 'package:miband_7_notifier/models/companion_models.dart';
import 'package:miband_7_notifier/services/auth_key_extractor_service.dart';
import 'package:miband_7_notifier/services/companion_repository.dart';
import 'package:miband_7_notifier/services/storage_service.dart';

void main() {
  group('AuthKeyExtractorService', () {
    test('extracts named keys that already include a 0x prefix', () {
      const service = AuthKeyExtractorService();

      final candidates = service.extractCandidates(
        'authKey=0x11223344556677889900AABBCCDDEEFF',
      );

      expect(candidates, hasLength(1));
      expect(
        candidates.single.normalizedKey,
        '0x11223344556677889900aabbccddeeff',
      );
      expect(candidates.single.source, AuthKeySource.rootedDatabase);
    });
  });

  group('CompanionRepository', () {
    test('falls back to defaults when stored config is invalid', () async {
      final storage = _FakeStorageService()
        ..seedString('companion_config', 'not-json-at-all');
      final repository = CompanionRepository(storageService: storage);

      final config = await repository.loadConfig();

      expect(config.vendorApp, VendorAppKind.zeppLife);
      expect(config.hasAuthKey, isFalse);
      expect(config.deviceId, isEmpty);
    });

    test('ignores malformed journal entries', () async {
      final storage = _FakeStorageService()
        ..seedStringList('companion_journal', <String>[
          'not-json',
          '{"message":"Recovered auth key","level":"success","createdAt":"2025-01-01T10:00:00.000Z"}',
          '[]',
        ]);
      final repository = CompanionRepository(storageService: storage);

      final journal = await repository.loadJournal();

      expect(journal, hasLength(1));
      expect(journal.single.message, 'Recovered auth key');
      expect(journal.single.level, CompanionLogLevel.success);
    });
  });
}

class _FakeStorageService extends StorageService {
  final Map<String, Object> _values = <String, Object>{};

  void seedString(String key, String value) {
    _values[key] = value;
  }

  void seedStringList(String key, List<String> value) {
    _values[key] = value;
  }

  @override
  Future<void> init() async {}

  @override
  String? getString(String key) => _values[key] as String?;

  @override
  List<String>? getStringList(String key) => _values[key] as List<String>?;
}
