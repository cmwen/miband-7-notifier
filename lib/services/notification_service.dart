import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
      _nextNotificationId = DateTime.now().millisecondsSinceEpoch.remainder(
        _maxNotificationId,
      );

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'miband_7_mirror',
    'Mi Band 7 mirror notifications',
    description:
        'Notifications created by the app so Mi Band 7 can mirror them.',
    importance: Importance.high,
  );

  static const int _maxNotificationId = 0x7fffffff;

  final FlutterLocalNotificationsPlugin _plugin;
  int _nextNotificationId;

  Future<void> init() async {
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(initializationSettings);

    final androidImplementation = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImplementation?.createNotificationChannel(_channel);
  }

  Future<bool> areNotificationsEnabled() async {
    final androidImplementation = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final enabled = await androidImplementation?.areNotificationsEnabled();
    return enabled ?? true;
  }

  Future<bool> requestPermission() async {
    final androidImplementation = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final granted = await androidImplementation
        ?.requestNotificationsPermission();
    return granted ?? true;
  }

  Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(body),
        ticker: title,
      ),
    );

    await _plugin.show(_takeNotificationId(), title, body, details);
  }

  int _takeNotificationId() {
    final id = _nextNotificationId;
    _nextNotificationId = (_nextNotificationId % (_maxNotificationId - 1)) + 1;
    return id;
  }
}
