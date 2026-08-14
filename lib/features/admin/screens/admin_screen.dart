import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/complex_model.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/section_title.dart';
import '../widgets/create_complex_sheet.dart';

/// Админ-панель (ТЗ 3): объекты, блоки, квартиры, мастер создания,
/// пользователи, журнал. Продавцу пункт недоступен на уровне маршрутизации.
class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Админ-панель')),
        body: const Center(child: Text('Доступ только для администратора')),
      );
    }

    final complexes = ref.watch(complexesProvider).value ?? const [];
    final units = ref.watch(unitsProvider).value ?? const [];

    return Scaffold(
      body: Column(
        children: [
          AppHeader(
            title: 'Админ-панель',
            subtitle: 'Управление фондом и доступом',
            gradient: false,
            onBack: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                const SectionTitle('Управление'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _ActionCard(
                        icon: Icons.add_business_outlined,
                        title: 'Создать объект (ЖК)',
                        subtitle: 'Новый жилой комплекс (FR-02.1)',
                        color: AppColors.free,
                        onTap: () => _createComplex(context, ref),
                      ),
                      _ActionCard(
                        icon: Icons.auto_awesome_motion,
                        title: 'Мастер массового создания',
                        subtitle: 'Блок целиком за минуты (FR-03)',
                        color: AppColors.brand,
                        onTap: () =>
                            Navigator.of(context).pushNamed(AppRoutes.bulkWizard),
                      ),
                      _ActionCard(
                        icon: Icons.people_alt_outlined,
                        title: 'Пользователи',
                        subtitle: 'Учётные записи, роли, блокировка',
                        color: AppColors.work,
                        onTap: () =>
                            Navigator.of(context).pushNamed(AppRoutes.users),
                      ),
                      _ActionCard(
                        icon: Icons.receipt_long_outlined,
                        title: 'Журнал аудита',
                        subtitle: 'Действия пользователей (FR-12)',
                        color: AppColors.design,
                        onTap: () =>
                            Navigator.of(context).pushNamed(AppRoutes.audit),
                      ),
                    ],
                  ),
                ),
                const SectionTitle('Объекты и блоки'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      for (final complex in complexes)
                        _ComplexAdminCard(
                          complex: complex,
                          unitCount: units
                              .where((u) => u.complexId == complex.id)
                              .length,
                          onEditBlock: (block) => Navigator.of(context).pushNamed(
                            AppRoutes.tableEditor,
                            arguments: EditorArgs(
                              complexId: complex.id,
                              block: block,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createComplex(BuildContext context, WidgetRef ref) async {
    final complex = await createComplexSheet(context);
    if (complex == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Объект «${complex.name}» создан. Добавьте блоки мастером создания.',
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.shadow,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 21, color: color),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyStrong),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.ink3),
        ],
      ),
    ),
  );
}

class _ComplexAdminCard extends StatelessWidget {
  const _ComplexAdminCard({
    required this.complex,
    required this.unitCount,
    required this.onEditBlock,
  });

  final ComplexModel complex;
  final int unitCount;
  final ValueChanged<String> onEditBlock;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      boxShadow: AppTheme.shadow,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(complex.name, style: AppTextStyles.title),
        const SizedBox(height: 2),
        Text(
          '${complex.address} · $unitCount квартир',
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final block in complex.blocks)
              GestureDetector(
                onTap: () => onEditBlock(block.name),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Блок ${block.name}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(Icons.edit_outlined, size: 14, color: AppColors.ink3),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}
