import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/client_model.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/initials_avatar.dart';
import '../../clients/widgets/add_client_sheet.dart';

/// Результат выбора клиента: `null` из [pickClient] — отмена, а [ClientPick]
/// с пустым [client] — «без клиента» (данные внесём позже).
class ClientPick {
  const ClientPick(this.client);
  final ClientModel? client;
}

/// Выбор клиента для показа/брони. Клиента можно выбрать, завести нового или
/// продолжить без него — данные клиента опциональны.
Future<ClientPick?> pickClient(BuildContext context) =>
    showModalBottomSheet<ClientPick>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ClientPickSheet(),
    );

class _ClientPickSheet extends ConsumerWidget {
  const _ClientPickSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Свои клиенты — привязать квартиру можно только к своему клиенту.
    final clients = ref.watch(visibleClientsProvider);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('С каким клиентом?', style: AppTextStyles.h1),
              const SizedBox(height: 4),
              const Text(
                'Выберите клиента, заведите нового или продолжите без клиента — '
                'данные можно внести позже.',
                style: AppTextStyles.secondary,
              ),
              const SizedBox(height: 14),
              if (clients.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'У вас пока нет клиентов — заведите нового или продолжите '
                    'без клиента.',
                    style: AppTextStyles.secondary,
                  ),
                )
              else
                for (final client in clients)
                  _ClientTile(
                    client: client,
                    onTap: () =>
                        Navigator.of(context).pop(ClientPick(client)),
                  ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () => _addAndPick(context, ref),
                icon: const Icon(Icons.add, size: 18),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  side: const BorderSide(color: AppColors.brand),
                  foregroundColor: AppColors.brand,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                label: const Text(
                  'Новый клиент',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 9),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(const ClientPick(null)),
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: AppColors.ink2,
                ),
                child: const Text(
                  'Продолжить без клиента',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addAndPick(BuildContext context, WidgetRef ref) async {
    final client = await addClient(context);
    if (client == null || !context.mounted) return;
    Navigator.of(context).pop(ClientPick(client));
  }
}

class _ClientTile extends StatelessWidget {
  const _ClientTile({required this.client, required this.onTap});

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
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall + 2),
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
                  '${client.phone}',
                  style: const TextStyle(fontSize: 12, color: AppColors.ink2),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
