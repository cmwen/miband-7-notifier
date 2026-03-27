import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miband_7_notifier/main.dart';
import 'package:miband_7_notifier/services/notification_service.dart';
import 'package:miband_7_notifier/services/storage_service.dart';

void main() {
  testWidgets('sends a composed notification', (WidgetTester tester) async {
    final storage = FakeStorageService();
    final notifications = FakeNotificationService();

    await tester.pumpWidget(
      MiBandNotifierApp(
        storageService: storage,
        notificationService: notifications,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mi Band 7 Notifier'), findsOneWidget);
    expect(find.text('Compose notification'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Notification title'),
      'Tea is ready',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Notification body'),
      'Meet in the kitchen in 2 minutes.',
    );

    final sendButton = find.text('Send to phone');
    await tester.ensureVisible(sendButton);
    await tester.tap(sendButton);
    await tester.pumpAndSettle();

    expect(notifications.lastTitle, 'Tea is ready');
    expect(notifications.lastBody, 'Meet in the kitchen in 2 minutes.');
    expect(find.text('Tea is ready'), findsWidgets);
  });

  testWidgets('reuses a recent notification from history', (
    WidgetTester tester,
  ) async {
    final storage = FakeStorageService()
      ..seedStringList('notification_history', [
        '{"title":"Sprint review","body":"Join the meeting room now.","sentAt":"2026-03-27T02:00:00.000Z"}',
      ]);
    final notifications = FakeNotificationService();

    await tester.pumpWidget(
      MiBandNotifierApp(
        storageService: storage,
        notificationService: notifications,
      ),
    );
    await tester.pumpAndSettle();

    final historyItem = find.text('Sprint review').last;
    await tester.ensureVisible(historyItem);
    await tester.tap(historyItem);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(
            find.widgetWithText(TextField, 'Notification title'),
          )
          .controller
          ?.text,
      'Sprint review',
    );
    expect(
      tester
          .widget<TextField>(
            find.widgetWithText(TextField, 'Notification body'),
          )
          .controller
          ?.text,
      'Join the meeting room now.',
    );
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
  String? lastTitle;
  String? lastBody;

  @override
  Future<void> init() async {}

  @override
  Future<bool> areNotificationsEnabled() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    lastTitle = title;
    lastBody = body;
  }
}
