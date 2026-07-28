import 'package:flutter/material.dart';

import '../../features/admin/screens/admin_screen.dart';
import '../../features/admin/screens/audit_screen.dart';
import '../../features/admin/screens/bulk_wizard_screen.dart';
import '../../features/admin/screens/table_editor_screen.dart';
import '../../features/admin/screens/users_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/board/screens/board_screen.dart';
import '../../features/search/screens/search_screen.dart';
import '../../features/shell/screens/home_shell.dart';

abstract final class AppRoutes {
  static const login = '/';
  static const home = '/home';
  static const board = '/board';
  static const similar = '/similar';
  static const admin = '/admin';
  static const bulkWizard = '/admin/bulk';
  static const tableEditor = '/admin/editor';
  static const users = '/admin/users';
  static const audit = '/admin/audit';
}

/// Аргумент для табличного редактора.
class EditorArgs {
  const EditorArgs({required this.complexId, required this.block});
  final String complexId;
  final String block;
}

abstract final class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    return switch (settings.name) {
      AppRoutes.login => _fade(const LoginScreen()),
      AppRoutes.home => _fade(const HomeShell()),
      AppRoutes.board => _slide(
        BoardScreen(complexId: settings.arguments as String? ?? ''),
      ),
      AppRoutes.similar => _slide(const SearchScreen()),
      AppRoutes.admin => _slide(const AdminScreen()),
      AppRoutes.bulkWizard => _slide(const BulkWizardScreen()),
      AppRoutes.users => _slide(const UsersScreen()),
      AppRoutes.audit => _slide(const AuditScreen()),
      AppRoutes.tableEditor => _slide(
        TableEditorScreen(args: settings.arguments as EditorArgs),
      ),
      _ => _fade(const LoginScreen()),
    };
  }

  static PageRouteBuilder<void> _fade(Widget page) => PageRouteBuilder(
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, anim, _, child) =>
        FadeTransition(opacity: anim, child: child),
    transitionDuration: const Duration(milliseconds: 300),
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
    transitionDuration: const Duration(milliseconds: 280),
  );
}
