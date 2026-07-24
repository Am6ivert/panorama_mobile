abstract final class AppConfig {
  /// Пока данные берутся из [MockPanoramaRepository].
  /// Когда Panorama отдаст свой API — поставить false и заполнить [apiBaseUrl].
  static const useMockData = true;

  static const apiBaseUrl = 'https://api.panorama.kg/v1';

  /// Курс доллара для показа цены в сомах. Позже придёт с сервера.
  static const usdToKgs = 89.5;

  /// Сколько держится статус «в работе», пока менеджер показывает квартиру.
  static const workHoldDuration = Duration(hours: 2);

  /// Сколько держится бронь.
  static const bookingDuration = Duration(hours: 24);
}
