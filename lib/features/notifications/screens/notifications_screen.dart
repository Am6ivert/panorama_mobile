import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/app_notification.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/utils/time_format.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/unit_tile.dart';
import '../../unit/widgets/unit_sheet.dart';

/// Центр уведомлений (FR-11.9): счётчик непрочитанных, deep link на карточку.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final async = ref.watch(notificationsProvider);
    final list = async.value ?? const <AppNotification>[];
    final unread = list.where((n) => !n.read).length;

    return Column(
      children: [
        AppHeader(
          title: 'Уведомления',
          subtitle: unread == 0 ? 'Все прочитаны' : '$unread непрочитанных',
          trailing: unread == 0 || user == null
              ? null
              : _MarkAllButton(
                  // Пометка «прочитано» ничего не меняет для пользователя,
                  // если не удалась, — но необработанная ошибка «брошенного»
                  // запроса роняет зону, поэтому гасим её явно.
                  onTap: () => unawaited(ref
                      .read(panoramaRepositoryProvider)
                      .markAllNotificationsRead(user.id)
                      .catchError((_) {})),
                ),
        ),
        Expanded(
          child: list.isEmpty
              ? const EmptyState(
                  icon: Icons.notifications_none,
                  text: 'Уведомлений пока нет.\n'
                      'Здесь появятся брони, истечения сроков и сообщения.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _NotificationTile(
                    item: list[i],
                    onTap: () => _open(context, ref, list[i]),
                  ),
                ),
        ),
      ],
    );
  }

  void _open(BuildContext context, WidgetRef ref, AppNotification item) {
    if (!item.read) {
      unawaited(ref
          .read(panoramaRepositoryProvider)
          .markNotificationRead(item.id)
          .catchError((_) {}));
    }
    if (item.unitId != null) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => UnitSheet(unitId: item.unitId!),
      );
    }
  }
}

class _MarkAllButton extends StatelessWidget {
  const _MarkAllButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(11),
      ),
      child: const Text(
        'Прочитать всё',
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    ),
  );
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});

  final AppNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: item.read ? AppColors.surface : const Color(0xFFF3F7FF),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: item.read ? AppColors.line : const Color(0xFFCEDDFB),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: item.kind.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.kind.icon, size: 19, color: item.kind.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(item.title, style: AppTextStyles.bodyStrong),
                    ),
                    if (!item.read)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.brand,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  item.body,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.ink2,
                  ),
                ),
                const SizedBox(height: 5),
                Text(TimeFormat.dayTime(item.at), style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
