abstract final class TimeFormat {
  /// `17:46`
  static String hhmm(DateTime time) =>
      '${time.hour}:${time.minute.toString().padLeft(2, '0')}';

  /// `сегодня 17:46`, `вчера 15:20`, `18.07.2026 11:05`
  static String dayTime(DateTime time) {
    final now = DateTime.now();
    final date = DateTime(time.year, time.month, time.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(date).inDays;

    return switch (diff) {
      0 => 'сегодня ${hhmm(time)}',
      1 => 'вчера ${hhmm(time)}',
      _ =>
        '${time.day.toString().padLeft(2, '0')}.'
            '${time.month.toString().padLeft(2, '0')}.'
            '${time.year} ${hhmm(time)}',
    };
  }

  /// Насколько ещё держится статус: `до 17:46`, `до завтра 09:00` или
  /// `до 21.08` для дальних дат.
  static String until(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(time.year, time.month, time.day);
    final diff = date.difference(today).inDays;
    return switch (diff) {
      0 => 'до ${hhmm(time)}',
      1 => 'до завтра ${hhmm(time)}',
      _ => 'до ${dayMonth(time)}',
    };
  }

  /// `21.08`
  static String dayMonth(DateTime time) =>
      '${time.day.toString().padLeft(2, '0')}.'
      '${time.month.toString().padLeft(2, '0')}';

  /// `21.08.2026`
  static String date(DateTime time) =>
      '${dayMonth(time)}.${time.year}';

  /// Период брони: `с 21.08 по 24.08`.
  static String range(DateTime from, DateTime to) =>
      'с ${dayMonth(from)} по ${dayMonth(to)}';
}
