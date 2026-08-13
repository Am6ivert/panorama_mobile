import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/org_summary.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/api_action.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/confirm_dialog.dart';

/// Панель суперадминистратора.
///
/// Отдельный экран, а не вкладка в приложении продавцов: у суперадминистратора
/// нет ни объектов, ни фонда, ни клиентов — ему нужны только компании,
/// их администраторы и подписки.
class SuperadminScreen extends ConsumerWidget {
  const SuperadminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgsAsync = ref.watch(orgsProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          AppHeader(
            title: 'Компании',
            subtitle: user == null
                ? 'Суперадминистратор'
                : '${user.name} · ${user.role.label}',
            trailing: const _LogoutButton(),
          ),
          Expanded(
            child: orgsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorState(
                message: '$e',
                onRetry: () => ref.invalidate(orgsProvider),
              ),
              data: (orgs) => orgs.isEmpty
                  ? const _EmptyState()
                  : RefreshIndicator(
                      onRefresh: () async => ref.invalidate(orgsProvider),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: orgs.length,
                        itemBuilder: (_, i) => _OrgCard(org: orgs[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoutButton extends ConsumerWidget {
  const _LogoutButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
        icon: const Icon(Icons.logout, color: Colors.white),
        tooltip: 'Выйти',
        onPressed: () {
          unawaited(ref.read(panoramaRepositoryProvider).logout());
          resetCompanyData(ref.invalidate);
          ref.read(currentUserProvider.notifier).state = null;
          Navigator.of(context)
              .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
        },
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Компаний пока нет.\nНовая заводится скриптом db\\new_org.ps1.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.ink2, height: 1.5),
          ),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 40, color: AppColors.ink3),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.ink2, height: 1.4),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Повторить')),
            ],
          ),
        ),
      );
}

/// Карточка компании: подписка, администраторы, размер и действия.
class _OrgCard extends ConsumerWidget {
  const _OrgCard({required this.org});

  final OrgSummary org;

  (Color, Color, String) get _badge => switch (org.access) {
        OrgAccess.full => org.isTrial
            ? (AppColors.holdBg, AppColors.holdInk, 'Пробный период')
            : (AppColors.freeBg, AppColors.freeInk, 'Подписка активна'),
        OrgAccess.readOnly => (
            AppColors.designBg,
            AppColors.designInk,
            'Только чтение'
          ),
        OrgAccess.blocked => (
            const Color(0xFFFDE7E7),
            AppColors.error,
            'Приостановлена'
          ),
      };

  String get _planText {
    final until = org.planUntil;
    if (until == null) return 'Подписки не было';
    final date = '${until.day.toString().padLeft(2, '0')}.'
        '${until.month.toString().padLeft(2, '0')}.${until.year}';
    final left = org.daysLeft ?? 0;
    if (left > 0) return 'до $date · осталось $left дн.';
    if (left == 0) return 'до $date · истекает сегодня';
    return 'до $date · истекла ${-left} дн. назад';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (bg, ink, label) = _badge;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(org.name, style: AppTextStyles.h2),
                    const SizedBox(height: 2),
                    Text(org.code, style: AppTextStyles.caption),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(_planText,
              style: const TextStyle(fontSize: 13, color: AppColors.ink2)),
          const SizedBox(height: 12),

          Row(
            children: [
              _Stat(value: '${org.managers}', label: 'менеджеров'),
              const SizedBox(width: 20),
              _Stat(value: '${org.admins.length}', label: 'админов'),
              const SizedBox(width: 20),
              _Stat(value: '${org.apartments}', label: 'квартир'),
            ],
          ),

          if (org.admins.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('АДМИНИСТРАТОРЫ', style: AppTextStyles.section),
            const SizedBox(height: 6),
            for (final admin in org.admins) _AdminRow(admin: admin),
          ],

          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => _extend(context, ref),
                  child: const Text('Продлить'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _toggleBlock(context, ref),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        org.isBlocked ? AppColors.free : AppColors.error,
                  ),
                  child: Text(org.isBlocked ? 'Возобновить' : 'Приостановить'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _extend(BuildContext context, WidgetRef ref) async {
    final months = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (_) => _MonthsSheet(orgName: org.name),
    );
    if (months == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final done = await runApi(context, () async {
      await ref
          .read(panoramaRepositoryProvider)
          .subscribeOrg(orgId: org.id, months: months);
      return true;
    });
    if (done == null) return;
    ref.invalidate(orgsProvider);
    messenger.showSnackBar(
      SnackBar(content: Text('«${org.name}»: подписка продлена на $months мес.')),
    );
  }

  Future<void> _toggleBlock(BuildContext context, WidgetRef ref) async {
    final blocking = !org.isBlocked;
    if (blocking) {
      final ok = await confirmDialog(
        context,
        title: 'Приостановить компанию',
        message: '«${org.name}» перейдёт в режим только чтения. '
            'Сотрудники увидят данные, но не смогут ничего менять.',
        confirmLabel: 'Приостановить',
        danger: true,
      );
      if (!ok || !context.mounted) return;
    }

    final done = await runApi(context, () async {
      await ref
          .read(panoramaRepositoryProvider)
          .setOrgBlocked(orgId: org.id, blocked: blocking);
      return true;
    });
    if (done == null) return;
    ref.invalidate(orgsProvider);
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          Text(label, style: AppTextStyles.caption),
        ],
      );
}

/// Строка администратора: ФИО, логин и телефон с возможностью позвонить.
class _AdminRow extends StatelessWidget {
  const _AdminRow({required this.admin});

  final OrgAdmin admin;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    admin.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: admin.blocked ? AppColors.ink3 : AppColors.ink,
                      decoration: admin.blocked
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                  Text('${admin.login} · ${admin.phone}',
                      style: AppTextStyles.caption),
                ],
              ),
            ),
            if (admin.phone.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.call_outlined,
                    size: 20, color: AppColors.brand),
                tooltip: 'Позвонить',
                onPressed: () => launchUrl(
                  Uri.parse('tel:${admin.phone.replaceAll(RegExp(r'[^+0-9]'), '')}'),
                ),
              ),
          ],
        ),
      );
}

/// Выбор срока продления.
class _MonthsSheet extends StatelessWidget {
  const _MonthsSheet({required this.orgName});

  final String orgName;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Продлить «$orgName»', style: AppTextStyles.h1),
              const SizedBox(height: 6),
              const Text(
                'Если подписка ещё действует, срок добавится к её концу.',
                style: TextStyle(fontSize: 13, color: AppColors.ink2),
              ),
              const SizedBox(height: 16),
              for (final months in const [1, 3, 6, 12])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(months),
                      child: Text(_label(months)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );

  static String _label(int months) => switch (months) {
        1 => '1 месяц',
        3 => '3 месяца',
        6 => '6 месяцев',
        _ => '12 месяцев',
      };
}
