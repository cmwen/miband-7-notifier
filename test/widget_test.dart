import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miband_7_notifier/main.dart';
import 'package:miband_7_notifier/models/companion_models.dart';
import 'package:miband_7_notifier/services/auth_key_extractor_service.dart';
import 'package:miband_7_notifier/services/ble_companion_service.dart';
import 'package:miband_7_notifier/services/ble_permission_service.dart';
import 'package:miband_7_notifier/services/companion_repository.dart';
import 'package:miband_7_notifier/services/notification_service.dart';
import 'package:miband_7_notifier/services/storage_service.dart';

void main() {
  testWidgets('imports an auth key from pasted output', (
    WidgetTester tester,
  ) async {
    final storage = FakeStorageService();
    final notifications = FakeNotificationService();
    final repository = CompanionRepository(storageService: storage);

    await tester.pumpWidget(
      MiBandNotifierApp(
        notificationService: notifications,
        companionRepository: repository,
        authKeyExtractorService: const AuthKeyExtractorService(),
        blePermissionService: const FakeBlePermissionService(),
        bleCompanionService: const FakeBleCompanionService(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mi Band 7 Companion'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Auth key workshop'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Paste raw auth output'),
      'XiaomiFit.device.log authKey = 11223344556677889900AABBCCDDEEFF',
    );
    await tester.tap(find.text('Extract auth key candidates'));
    await tester.pumpAndSettle();

    expect(find.text('0x11223344556677889900aabbccddeeff'), findsOneWidget);

    await tester.tap(find.text('Use this key'));
    await tester.pumpAndSettle();

    expect(
      find.text('Current auth key: 0x11223344556677889900aabbccddeeff'),
      findsOneWidget,
    );
  });

  testWidgets('sends a relay smoke test notification', (
    WidgetTester tester,
  ) async {
    final storage = FakeStorageService();
    final notifications = FakeNotificationService();
    final repository = CompanionRepository(storageService: storage);

    await tester.pumpWidget(
      MiBandNotifierApp(
        notificationService: notifications,
        companionRepository: repository,
        authKeyExtractorService: const AuthKeyExtractorService(),
        blePermissionService: const FakeBlePermissionService(),
        bleCompanionService: const FakeBleCompanionService(),
      ),
    );
    await tester.pumpAndSettle();

    final button = find.text('Send relay smoke test');
    await tester.fling(find.byType(ListView), const Offset(0, -1600), 1000);
    await tester.pumpAndSettle();
    await tester.tap(button, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(notifications.lastTitle, 'Mi Band 7 Companion');
    expect(
      notifications.lastBody,
      'Relay smoke test. If your official app still mirrors notifications, the band should vibrate now.',
    );
    expect(
      find.textContaining('relay smoke-test notification'),
      findsOneWidget,
    );
  });

  testWidgets('blocks the relay smoke test when notifications stay disabled', (
    WidgetTester tester,
  ) async {
    final storage = FakeStorageService();
    final notifications = FakeNotificationService(
      notificationsEnabled: false,
      grantOnRequest: false,
    );
    final repository = CompanionRepository(storageService: storage);

    await tester.pumpWidget(
      MiBandNotifierApp(
        notificationService: notifications,
        companionRepository: repository,
        authKeyExtractorService: const AuthKeyExtractorService(),
        blePermissionService: const FakeBlePermissionService(),
        bleCompanionService: const FakeBleCompanionService(),
      ),
    );
    await tester.pumpAndSettle();

    final button = find.text('Send relay smoke test');
    await tester.fling(find.byType(ListView), const Offset(0, -1600), 1000);
    await tester.pumpAndSettle();
    await tester.tap(button, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(notifications.lastTitle, isNull);
    expect(find.textContaining('notifications are disabled'), findsOneWidget);
  });
}

class FakeStorageService extends StorageService {
  final Map<String, Object> _values = {};

  void seedStringList(String key, List<String> value) {
    _values[key] = value;
  }

  @override
  Future<void> init() async {}

  @override
  String? getString(String key) => _values[key] as String?;

  @override
  List<String>? getStringList(String key) => _values[key] as List<String>?;

  @override
  Future<bool> setString(String key, String value) async {
    _values[key] = value;
    return true;
  }

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    _values[key] = value;
    return true;
  }
}

class FakeNotificationService extends NotificationService {
  FakeNotificationService({
    this.notificationsEnabled = true,
    this.grantOnRequest = true,
  });

  bool notificationsEnabled;
  final bool grantOnRequest;
  String? lastTitle;
  String? lastBody;

  @override
  Future<void> init() async {}

  @override
  Future<bool> areNotificationsEnabled() async => notificationsEnabled;

  @override
  Future<bool> requestPermission() async {
    notificationsEnabled = grantOnRequest;
    return notificationsEnabled;
  }

  @override
  Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    lastTitle = title;
    lastBody = body;
  }
}

class FakeBlePermissionService implements BlePermissionService {
  const FakeBlePermissionService();

  @override
  Future<BlePermissionSnapshot> getSnapshot() async {
    return const BlePermissionSnapshot(
      bluetoothScanGranted: true,
      bluetoothConnectGranted: true,
      locationGranted: true,
      notificationGranted: true,
    );
  }

  @override
  Future<BlePermissionSnapshot> requestRequiredPermissions() => getSnapshot();
}

class FakeBleCompanionService implements BleCompanionService {
  const FakeBleCompanionService();

  @override
  Future<List<ScannedBand>> scanForBands({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    return const [
      ScannedBand(
        name: 'Mi Band 7',
        id: 'AA:BB:CC:DD:EE:FF',
        rssi: -42,
        connectable: true,
      ),
    ];
  }
}
