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

  /// Насколько ещё держится статус: `до 17:46` или `до завтра 09:00`.
  static String until(DateTime time) {
    final now = DateTime.now();
    final sameDay =
        time.year == now.year && time.month == now.month && time.day == now.day;
    return sameDay ? 'до ${hhmm(time)}' : 'до завтра ${hhmm(time)}';
  }
}
