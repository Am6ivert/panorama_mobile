import 'notification_service_io.dart'
    if (dart.library.js_interop) 'notification_service_web.dart';

/// Показ системных (мобилка) / браузерных (web) уведомлений о событиях фонда.
///
/// Это доставка событий на уровень ОС, пока приложение открыто. Для доставки
/// при закрытом приложении нужен FCM/APNs (см. backend/PUSH.md).
abstract class NotificationService {
  /// Инициализация и запрос разрешения.
  Future<void> init();

  /// Показать уведомление.
  Future<void> show({required String title, required String body});
}

/// Реализация под текущую платформу.
NotificationService createNotificationService() => makeNotificationService();
