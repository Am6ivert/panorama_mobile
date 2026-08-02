abstract final class AppConfig {
  /// Источник данных. По умолчанию — реальный backend (PostgreSQL через REST).
  /// Для автономного запуска без сервера:
  ///   flutter run --dart-define=USE_MOCK=true
  static const useMockData = bool.fromEnvironment('USE_MOCK');

  /// Адрес backend'а (по умолчанию — локальный сервер из backend/).
  /// Android-эмулятор: --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080/api/v1',
  );

  /// Часовой пояс отображения (ТЗ 5.4). Метки в БД — UTC.
  static const displayTimeZone = 'Asia/Bishkek';

  /// Сколько держится статус «в работе», пока менеджер показывает квартиру.
  static const workHoldDuration = Duration(hours: 2);

  /// Срок брони по умолчанию (FR-07.6) — 3 дня. Максимум настраивает админ.
  static const bookingDuration = Duration(days: 3);

  /// Лимит активных броней на менеджера (FR-07.9).
  static const bookingLimitPerManager = 5;

  /// Лимит квартир «в работе» (на показе) на менеджера одновременно.
  static const workLimitPerManager = 5;

  /// За сколько до истечения брони считаем её «истекающей» (FR-09.9, FR-11.2).
  static const bookingExpiryWarning = Duration(hours: 24);

  /// Пароль учётных записей для входа. При подключении backend проверка
  /// уходит на сервер (хеш Argon2id/bcrypt), это значение перестаёт
  /// использоваться.
  static const defaultPassword = '0000';

  /// VAPID key для web-push (Firebase → Cloud Messaging → Web Push certificates).
  /// Нужен только для получения FCM-токена в браузере. Можно передать через
  /// --dart-define=FCM_VAPID_KEY=... Заполняется владельцем проекта.
  static const fcmVapidKey = String.fromEnvironment('FCM_VAPID_KEY');
}
