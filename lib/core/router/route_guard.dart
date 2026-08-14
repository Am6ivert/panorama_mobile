import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../providers/data_providers.dart';
import 'app_router.dart';

/// Кто может открыть экран.
enum Access {
  /// Любой вошедший сотрудник.
  signedIn,

  /// Администратор компании.
  admin,

  /// Суперадминистратор сервиса.
  superadmin,
}

/// Проверяет право открыть экран — до того, как экран построится.
///
/// Раньше маршруты не проверяли ничего: в веб-версии достаточно было набрать
/// адрес `#/admin/users` или `#/superadmin`, чтобы экран открылся. Данные
/// сервер бы не отдал (он проверяет роль сам), но человек видел чужой
/// интерфейс и непонятные ошибки вместо внятного отказа.
///
/// Это второй рубеж, а не единственный: решает всё равно сервер.
class Guard extends ConsumerWidget {
  const Guard({super.key, required this.access, required this.child});

  final Access access;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    // Не вошли — отправляем на вход. Переход делаем после кадра: менять
    // навигацию во время построения дерева нельзя.
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        Navigator.of(context)
            .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
      });
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final allowed = switch (access) {
      Access.signedIn => true,
      Access.admin => user.role.isAdmin,
      Access.superadmin => user.role.isSuperadmin,
    };
    if (allowed) return child;

    return _NoAccess(
      message: access == Access.superadmin
          ? 'Этот раздел доступен только суперадминистратору сервиса.'
          : 'Этот раздел доступен только администратору компании.',
    );
  }
}

class _NoAccess extends StatelessWidget {
  const _NoAccess({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 40, color: AppColors.ink3),
                const SizedBox(height: 14),
                const Text('Нет доступа', style: AppTextStyles.h2),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: AppColors.ink2,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.of(context)
                      .pushNamedAndRemoveUntil(AppRoutes.home, (_) => false),
                  child: const Text('На главную'),
                ),
              ],
            ),
          ),
        ),
      );
}
