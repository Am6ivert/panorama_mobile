import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Активная вкладка нижней навигации.
///
/// Живёт в провайдере, чтобы с карточки квартиры можно было отправить
/// менеджера в подбор похожих вариантов.
final shellTabProvider = StateProvider<int>((ref) => 0);

abstract final class ShellTab {
  static const complexes = 0;
  static const search = 1;
  static const deals = 2;
  static const clients = 3;
}
