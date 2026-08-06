import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/unit_model.dart';
import '../../../core/models/unit_status.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/section_title.dart';
import '../../unit/widgets/unit_sheet.dart';

/// Дашборд (FR-10). Денежные показатели отсутствуют (FR-10.6).
/// Администратор видит показатели по компании, продавец — только свои.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final unitsAsync = ref.watch(unitsProvider);
    final allUnits = unitsAsync.value ?? const <UnitModel>[];

    // Продавец видит весь фонд (FR-09.4), но «свои» показатели — по себе.
    final mine = user == null
        ? const <UnitModel>[]
        : allUnits.where((u) => u.heldBy(user.id)).toList(growable: false);
    // Фонд по статусам — по всей компании (FR-10.1). Показатели работы —
    // администратору по компании, продавцу по себе (FR-10.4).
    final scope = isAdmin ? allUnits : mine;
    final stats = UnitStats.of(allUnits);

    final clients = ref.watch(visibleClientsProvider);
    final deals = ref.watch(visibleDealsProvider).where((d) => d.isActive);
    final bookings = scope
        .where((u) => u.status == UnitStatus.hold)
        .toList()
      ..sort((a, b) => (a.heldUntil ?? DateTime(2100))
          .compareTo(b.heldUntil ?? DateTime(2100)));
    final expiring = bookings
        .where(
          (u) =>
              u.heldUntil != null &&
              u.heldUntil!.difference(DateTime.now()).inHours < 24,
        )
        .toList();
    final overdueClients =
        clients.where((c) => c.actionOverdue).toList(growable: false);

    return Column(
      children: [
        AppHeader(
          title: 'Дашборд',
          subtitle: user == null
              ? 'Отдел продаж'
              : '${user.name} · ${user.role.label}',
          bottom: const LiveIndicator(
            text: 'Онлайн · показатели фонда обновляются в реальном времени',
          ),
        ),
        Expanded(
          child: unitsAsync.isLoading && allUnits.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    const SectionTitle('Работа сейчас'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          _MetricCard(
                            value: '${clients.length}',
                            label: isAdmin ? 'клиентов' : 'моих клиентов',
                            icon: Icons.people_outline,
                            color: AppColors.brand,
                          ),
                          const SizedBox(width: 10),
                          _MetricCard(
                            value: '${deals.length}',
                            label: 'сделок',
                            icon: Icons.handshake_outlined,
                            color: AppColors.work,
                          ),
                          const SizedBox(width: 10),
                          _MetricCard(
                            value: '${scope.where((u) => u.status == UnitStatus.hold).length}',
                            label: 'броней',
                            icon: Icons.event_available,
                            color: AppColors.hold,
                          ),
                        ],
                      ),
                    ),
                    if (expiring.isNotEmpty) ...[
                      const SectionTitle('Брони истекают'),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            for (final unit in expiring.take(4))
                              _AlertRow(
                                unit: unit,
                                onTap: () => _openUnit(context, unit.id),
                              ),
                          ],
                        ),
                      ),
                    ],
                    if (overdueClients.isNotEmpty) ...[
                      const SectionTitle('Просроченные действия'),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.holdBg,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSmall),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final c in overdueClients.take(4))
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Text(
                                    '• ${c.name} — ${c.stage.label.toLowerCase()}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.holdInk,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  void _openUnit(BuildContext context, String unitId) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => UnitSheet(unitId: unitId),
      );
}

class _StatusGrid extends StatelessWidget {
  const _StatusGrid({required this.stats});
  final UnitStats stats;

  @override
  Widget build(BuildContext context) {
    final items = [
      (AppColors.free, 'Свободно', stats.free),
      (AppColors.work, 'В работе', stats.work),
      (AppColors.hold, 'Бронь', stats.hold),
      (AppColors.design, 'Оформление', stats.design),
      (AppColors.sold, 'Продано', stats.sold),
      (AppColors.offMarket, 'Не в продаже', stats.offMarket),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.35,
      children: [
        for (final (color, label, value) in items)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: AppTheme.shadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$value',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(label, style: AppTextStyles.caption),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    ),
  );
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.unit, required this.onTap});
  final UnitModel unit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final left = unit.heldUntil?.difference(DateTime.now());
    final hours = left == null ? 0 : left.inHours;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.holdBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.timer_outlined, size: 18, color: AppColors.hold),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${unit.complexName} · бл. ${unit.block} · №${unit.number}',
                style: AppTextStyles.bodyStrong,
              ),
            ),
            Text(
              hours <= 0 ? 'истекла' : 'через $hours ч',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.holdInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
