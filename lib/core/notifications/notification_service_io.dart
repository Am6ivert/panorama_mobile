import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_service.dart';

NotificationService makeNotificationService() => _IoNotificationService();

/// Мобильная реализация на flutter_local_notifications (Android/iOS).
class _IoNotificationService implements NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  var _ready = false;

  @override
  Future<void> init() async {
    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _plugin.initialize(settings);

      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      _ready = true;
    } catch (_) {
      // Нет платформенного канала (тесты/неподдерживаемая среда) — тихо выходим.
    }
  }

  @override
  Future<void> show({required String title, required String body}) async {
    if (!_ready) return;
    try {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'panorama_fund',
          'Движение фонда',
          channelDescription: 'Брони, освобождения и сообщения по квартирам',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );
      await _plugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        details,
      );
    } catch (_) {}
  }
}
