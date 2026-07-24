import 'package:intl/intl.dart';
import '../config/app_config.dart';

/// Менеджеры называют цену в долларах, а клиенты часто просят
/// пересчитать в сомы — поэтому показываем оба варианта.
abstract final class Money {
  static final _usd = NumberFormat('#,##0', 'ru_RU');

  /// `$68 700`
  static String usd(int value) => '\$${_usd.format(value)}';

  /// `6,15 млн с`
  static String kgs(int usdValue) {
    final millions = usdValue * AppConfig.usdToKgs / 1000000;
    return '${millions.toStringAsFixed(2).replaceAll('.', ',')} млн с';
  }

  /// `≈ 6,15 млн с`
  static String kgsApprox(int usdValue) => '≈ ${kgs(usdValue)}';

  /// Цена за квадратный метр.
  static String perSquare(int price, double area) =>
      '${usd((price / area).round())} за м²';

  /// Ежемесячный платёж по рассрочке: 30% взнос, остаток на [months].
  static int monthlyInstalment(int price, {int months = 24}) =>
      (price * 0.7 / months / 50).round() * 50;
}
