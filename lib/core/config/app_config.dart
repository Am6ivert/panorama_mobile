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

  /// Лимит квартир «в работе» (на показе) на менеджера одновременно.
  static const workLimitPerManager = 5;

  /// За сколько до истечения брони считаем её «истекающей» (FR-09.9, FR-11.2).
  static const bookingExpiryWarning = Duration(hours: 24);

  /// Пароль учётных записей для входа. При подключении backend проверка
  /// уходит на сервер (хеш Argon2id/bcrypt), это значение перестаёт
  /// использоваться.
  static const defaultPassword = '0000';
}
