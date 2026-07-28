import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/audit_log.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/utils/time_format.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/unit_tile.dart';

/// Журнал аудита (FR-12). Записи неизменяемы; администратор видит весь журнал.
class AuditScreen extends ConsumerWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(auditProvider);

    return Scaffold(
      body: Column(
        children: [
          AppHeader(
            title: 'Журнал аудита',
            subtitle: 'Кто, что и когда — неизменяемая история',
            gradient: false,
            onBack: () => Navigator.of(context).pop(),
            trailing: GestureDetector(
              onTap: () => ref.invalidate(auditProvider),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.refresh, size: 18, color: Colors.white),
              ),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Ошибка: $e')),
              data: (logs) => logs.isEmpty
                  ? const EmptyState(
                      icon: Icons.history,
                      text: 'Записей журнала пока нет.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      itemCount: logs.length,
                      itemBuilder: (_, i) => _AuditRow(log: logs[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.log});
  final AuditLog log;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                log.action,
                style: AppTextStyles.bodyStrong,
              ),
            ),
            Text(TimeFormat.dayTime(log.at), style: AppTextStyles.caption),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          log.entity,
          style: const TextStyle(fontSize: 12.5, color: AppColors.ink2),
        ),
        if (log.details.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(log.details, style: AppTextStyles.caption),
        ],
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.person_outline, size: 13, color: AppColors.ink3),
            const SizedBox(width: 4),
            Text(log.userName, style: AppTextStyles.caption),
          ],
        ),
      ],
    ),
  );
}
