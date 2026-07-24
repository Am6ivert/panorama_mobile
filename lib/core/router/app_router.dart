import 'package:flutter/material.dart';

import '../../features/auth/screens/manager_pick_screen.dart';
import '../../features/board/screens/board_screen.dart';
import '../../features/shell/screens/home_shell.dart';

abstract final class AppRoutes {
  static const managerPick = '/';
  static const home = '/home';
  static const board = '/board';
}

abstract final class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    return switch (settings.name) {
      AppRoutes.managerPick => _fade(const ManagerPickScreen()),
      AppRoutes.home => _fade(const HomeShell()),
      AppRoutes.board => _slide(
        BoardScreen(complexId: settings.arguments as String? ?? ''),
      ),
      _ => _fade(const ManagerPickScreen()),
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
