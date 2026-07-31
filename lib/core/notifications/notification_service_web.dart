import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'notification_service.dart';

NotificationService makeNotificationService() => _WebNotificationService();

/// Web-реализация на браузерном Notification API.
class _WebNotificationService implements NotificationService {
  @override
  Future<void> init() async {
    try {
      if (web.Notification.permission == 'default') {
        await web.Notification.requestPermission().toDart;
      }
    } catch (_) {}
  }

  @override
  Future<void> show({required String title, required String body}) async {
    try {
      if (web.Notification.permission != 'granted') return;
      web.Notification(title, web.NotificationOptions(body: body));
    } catch (_) {}
  }
}
