import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/client_model.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/initials_avatar.dart';
import '../../../shared/widgets/section_title.dart';
import '../../../shared/widgets/unit_tile.dart';
import '../widgets/add_client_sheet.dart';
import '../widgets/client_sheet.dart';

class ClientsScreen extends ConsumerWidget {
  const ClientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clients = ref.watch(clientsProvider);

    return Column(
      children: [
        AppHeader(
          title: 'Клиенты',
          subtitle: 'Запросы, подбор и история показов',
          trailing: _AddButton(onTap: () => _add(context, ref)),
        ),
        Expanded(
          child: clients.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Ошибка загрузки: $e')),
            data: (list) => ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                SectionTitle('Активные клиенты (${list.length})'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: list.isEmpty
                      ? const EmptyState(
                          icon: Icons.person_add_alt,
                          text:
                              'Клиентов пока нет.\n'
                              'Заведите первого — подбор сразу покажет, '
                              'что ему подходит.',
                        )
                      : Column(
                          children: [
                            for (final client in list)
                              _ClientCard(
                                client: client,
                                onTap: () => _openCard(context, client.id),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _openCard(BuildContext context, String clientId) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => ClientSheet(clientId: clientId),
      );

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final client = await addClient(context);
    if (client == null || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${client.name} добавлен в клиенты')),
    );
    // Сразу открываем карточку: там уже видно, что подходит под его запрос.
    _openCard(context, client.id);
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(11),
      ),
      child: const Row(
        children: [
          Icon(Icons.add, size: 17, color: Colors.white),
          SizedBox(width: 5),
          Text(
            'Клиент',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ClientCard extends StatelessWidget {
  const _ClientCard({required this.client, required this.onTap});

  final ClientModel client;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.shadow,
      ),
      child: Row(
        children: [
          InitialsAvatar(initials: client.initials, color: client.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(client.name, style: AppTextStyles.bodyStrong),
                const SizedBox(height: 2),
                Text(
                  '${client.rooms == 0 ? 'Студия' : '${client.rooms}к'} · '
                  'до ${Money.usd(client.budget)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.ink2),
                ),
              ],
            ),
          ),
          Text(
            client.phone,
            style: const TextStyle(fontSize: 11, color: AppColors.ink3),
          ),
        ],
      ),
    ),
  );
}
