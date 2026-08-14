import 'package:flutter/material.dart';

import '../../features/admin/screens/admin_screen.dart';
import '../../features/admin/screens/audit_screen.dart';
import '../../features/admin/screens/bulk_wizard_screen.dart';
import '../../features/admin/screens/table_editor_screen.dart';
import '../../features/admin/screens/users_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/superadmin/screens/superadmin_screen.dart';
import '../../features/board/screens/board_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/search/screens/search_screen.dart';
import '../../features/shell/screens/home_shell.dart';
import 'route_guard.dart';

abstract final class AppRoutes {
  /// Стартовый экран: пробует восстановить сессию сохранённым токеном.
  static const splash = '/';
  static const login = '/login';
  static const home = '/home';
  static const board = '/board';
  static const similar = '/similar';
  static const admin = '/admin';
  static const bulkWizard = '/admin/bulk';
  static const tableEditor = '/admin/editor';
  static const users = '/admin/users';
  static const audit = '/admin/audit';
  static const profile = '/profile';

  /// Регистрация застройщика: компания и её первый администратор.
  static const register = '/register';

  /// Панель суперадминистратора: компании и подписки. Отдельный экран, а не
  /// вкладка — у него нет ни объектов, ни фонда, ни клиентов.
  static const superadmin = '/superadmin';
}

/// Аргумент для табличного редактора.
class EditorArgs {
  const EditorArgs({required this.complexId, required this.block});
  final String complexId;
  final String block;
}

abstract final class AppRouter {
  /// Нужен, чтобы увести пользователя на экран входа из кода вне дерева
  /// виджетов — например когда сервер ответил 401 (сессия истекла).
  static final navigatorKey = GlobalKey<NavigatorState>();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    // Аргументы приходят из кода приложения, но в веб-версии по адресу можно
    // попасть и без них - поэтому проверяем тип, а не приводим вслепую.
    final args = settings.arguments;

    return switch (settings.name) {
      AppRoutes.splash => _fade(const SplashScreen()),
      AppRoutes.login => _fade(const LoginScreen()),
      AppRoutes.register => _slide(const RegisterScreen()),

      // Всё остальное - только для вошедших, а часть ещё и по роли.
      AppRoutes.home => _fade(_guard(Access.signedIn, const HomeShell())),
      AppRoutes.board => _slide(
        _guard(Access.signedIn,
            BoardScreen(complexId: args is String ? args : '')),
      ),
      AppRoutes.similar =>
        _slide(_guard(Access.signedIn, const SearchScreen())),
      AppRoutes.profile =>
        _slide(_guard(Access.signedIn, const ProfileScreen())),

      AppRoutes.admin => _slide(_guard(Access.admin, const AdminScreen())),
      AppRoutes.bulkWizard =>
        _slide(_guard(Access.admin, const BulkWizardScreen())),
      AppRoutes.users => _slide(_guard(Access.admin, const UsersScreen())),
      AppRoutes.audit => _slide(_guard(Access.admin, const AuditScreen())),

      // Без аргументов редактор открывать нечем: раньше приведение типа
      // роняло приложение, теперь возвращаем в админку.
      AppRoutes.tableEditor => _slide(
          args is EditorArgs
              ? _guard(Access.admin, TableEditorScreen(args: args))
              : _guard(Access.admin, const AdminScreen()),
        ),

      AppRoutes.superadmin =>
        _fade(_guard(Access.superadmin, const SuperadminScreen())),

      // Неизвестный адрес - на вход, а не белый экран.
      _ => _fade(const LoginScreen()),
    };
  }

  static Widget _guard(Access access, Widget page) =>
      Guard(access: access, child: page);

  static PageRouteBuilder<void> _fade(Widget page) => PageRouteBuilder(
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, anim, _, child) =>
        FadeTransition(opacity: anim, child: child),
    transitionDuration: const Duration(milliseconds: 150),
  );

  static PageRouteBuilder<void> _slide(Widget page) => PageRouteBuilder(
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, anim, _, child) => SlideTransition(
      position: Tween(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: child,
    ),
    transitionDuration: const Duration(milliseconds: 180),
  );
}
