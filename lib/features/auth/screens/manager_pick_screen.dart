import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/manager_model.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/initials_avatar.dart';

/// Вход в приложение до появления авторизации: менеджер выбирает себя.
class ManagerPickScreen extends ConsumerWidget {
  const ManagerPickScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final managers = ref.watch(managersProvider);

    return Scaffold(
      backgroundColor: AppColors.brandDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Text('Panorama', style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                color: Colors.white,
              )),
              const SizedBox(height: 6),
              const Text(
                'Шахматка квартир для отдела продаж',
                style: TextStyle(fontSize: 14, color: AppColors.onDarkSub),
              ),
              const SizedBox(height: 36),
              const Text(
                'КТО РАБОТАЕТ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.onDarkSub,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: managers.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  error: (e, _) => Text(
                    'Не удалось загрузить список: $e',
                    style: const TextStyle(color: Colors.white),
                  ),
                  data: (list) => ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _ManagerTile(
                      manager: list[i],
                      onTap: () => _enter(context, ref, list[i]),
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 16, top: 8),
                child: Text(
                  'Авторизацию по логину добавим, когда определимся с учётными '
                  'записями менеджеров.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.ink2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _enter(BuildContext context, WidgetRef ref, ManagerModel manager) {
    ref.read(currentManagerProvider.notifier).state = manager;
    Navigator.of(context).pushReplacementNamed(AppRoutes.home);
  }
}

class _ManagerTile extends StatelessWidget {
  const _ManagerTile({required this.manager, required this.onTap});

  final ManagerModel manager;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Row(
        children: [
          InitialsAvatar(
            initials: manager.initials,
            color: manager.color,
            size: 44,
            fontSize: 15,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  manager.name,
                  style: AppTextStyles.bodyStrong.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  manager.phone,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.onDarkSub,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: AppColors.onDarkSub,
          ),
        ],
      ),
    ),
  );
}
