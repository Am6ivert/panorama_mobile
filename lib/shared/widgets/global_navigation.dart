import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/data_providers.dart';
import '../../core/router/app_router.dart';
import 'initials_avatar.dart';

/// Глобальные кнопки навигации: админка, профиль, выход
class GlobalNavigation extends ConsumerWidget {
  const GlobalNavigation({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isAdmin = ref.watch(isAdminProvider);

    if (user == null) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isAdmin)
          _HeaderIcon(
            icon: Icons.admin_panel_settings_outlined,
            onTap: () => _navigateTo(context, AppRoutes.admin),
          ),
        _HeaderIcon(
          icon: Icons.person_outline,
          onTap: () => _navigateTo(context, AppRoutes.profile),
        ),
        _HeaderIcon(
          icon: Icons.logout,
          onTap: () => _logout(context, ref),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => _navigateTo(context, AppRoutes.profile),
          child: InitialsAvatar(
            initials: user.initials,
            color: user.color,
            size: 36,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  void _navigateTo(BuildContext context, String route) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (currentRoute == route) return; // уже на этом экране
    Navigator.of(context).pushNamed(route);
  }

  void _logout(BuildContext context, WidgetRef ref) {
    // Отзываем токен на сервере, ответ не ждём — экран входа открываем сразу.
    unawaited(ref.read(panoramaRepositoryProvider).logout());
    ref.read(currentUserProvider.notifier).state = null;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (_) => false,
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36,
      height: 36,
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, size: 18, color: Colors.white),
    ),
  );
}
