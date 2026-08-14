import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/subscription.dart';
import '../../core/providers/data_providers.dart';

/// Плашка о подписке над содержимым приложения.
///
/// Появляется только когда есть о чём предупредить: срок кончается в
/// ближайшие 3 дня, уже кончился или компанию приостановили. В остальное
/// время не занимает места.
class SubscriptionBanner extends ConsumerWidget {
  const SubscriptionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = ref.watch(subscriptionProvider).value;
    if (sub == null || !sub.needsAttention) return const SizedBox.shrink();

    final (bg, ink, text) = _content(sub);

    return Material(
      color: bg,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        child: Row(
          children: [
            Icon(
              sub.isActive ? Icons.timer_outlined : Icons.lock_clock,
              size: 18,
              color: ink,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(fontSize: 12.5, height: 1.35, color: ink),
              ),
            ),
            if (sub.supportEmail.isNotEmpty || sub.supportUrl.isNotEmpty)
              TextButton(
                onPressed: () => _contact(context, sub),
                style: TextButton.styleFrom(
                  foregroundColor: ink,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 32),
                ),
                child: const Text('Связаться'),
              ),
          ],
        ),
      ),
    );
  }

  (Color, Color, String) _content(Subscription sub) {
    if (sub.access == OrgAccess.blocked) {
      return (
        const Color(0xFFFDE7E7),
        AppColors.error,
        'Доступ приостановлен. Данные сохранены — свяжитесь с нами, '
            'чтобы возобновить работу.',
      );
    }
    if (!sub.isActive) {
      return (
        const Color(0xFFFDE7E7),
        AppColors.error,
        sub.isTrial
            ? 'Пробный период закончился. Сейчас доступен только просмотр — '
                'свяжитесь с нами, чтобы продолжить работу.'
            : 'Подписка истекла. Сейчас доступен только просмотр — '
                'свяжитесь с нами, чтобы продлить.',
      );
    }

    final left = sub.daysLeft ?? 0;
    final days = switch (left) {
      <= 0 => 'сегодня',
      1 => 'завтра',
      _ => 'через $left дн.',
    };
    return (
      AppColors.holdBg,
      AppColors.holdInk,
      sub.isTrial
          ? 'Пробный период заканчивается $days. Свяжитесь с нами, '
              'чтобы оформить подписку.'
          : 'Подписка заканчивается $days. Свяжитесь с нами, чтобы продлить.',
    );
  }

  Future<void> _contact(BuildContext context, Subscription sub) async {
    // Если способ один — открываем сразу, выбор из одного пункта раздражает.
    if (sub.supportUrl.isEmpty) {
      await launchUrl(Uri.parse('mailto:${sub.supportEmail}'));
      return;
    }
    if (sub.supportEmail.isEmpty) {
      await launchUrl(Uri.parse(sub.supportUrl),
          mode: LaunchMode.externalApplication);
      return;
    }

    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.mail_outline, color: AppColors.brand),
              title: const Text('Написать на почту'),
              subtitle: Text(sub.supportEmail),
              onTap: () {
                Navigator.of(sheetContext).pop();
                launchUrl(Uri.parse('mailto:${sub.supportEmail}'));
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_outlined, color: AppColors.free),
              title: const Text('Написать в мессенджер'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                launchUrl(Uri.parse(sub.supportUrl),
                    mode: LaunchMode.externalApplication);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
