import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Активная вкладка нижней навигации (ТЗ 3. Структура навигации).
final shellTabProvider = StateProvider<int>((ref) => ShellTab.dashboard);

abstract final class ShellTab {
  static const dashboard = 0;
  static const board = 1;
  static const registry = 2;
  static const clients = 3;
  static const notifications = 4;
}
