abstract final class AppConfig {
  /// Пока данные берутся из [MockPanoramaRepository].
  /// Когда Panorama отдаст свой API — поставить false и заполнить [apiBaseUrl].
  static const useMockData = true;

  static const apiBaseUrl = 'https://api.panorama.kg/v1';

  /// Часовой пояс отображения (ТЗ 5.4). Метки в БД — UTC.
  static const displayTimeZone = 'Asia/Bishkek';

  /// Сколько держится статус «в работе», пока менеджер показывает квартиру.
  static const workHoldDuration = Duration(hours: 2);

  /// Срок брони по умолчанию (FR-07.6) — 3 дня. Максимум настраивает админ.
  static const bookingDuration = Duration(days: 3);

  /// Лимит активных броней на менеджера (FR-07.9).
  static const bookingLimitPerManager = 5;

  /// За сколько до истечения брони считаем её «истекающей» (FR-09.9, FR-11.2).
  static const bookingExpiryWarning = Duration(hours: 24);

  /// Демо-пароль для входа, пока не подключён backend с SMS-паролями.
  static const demoPassword = '0000';
}
