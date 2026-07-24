import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/client_model.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/initials_avatar.dart';
import '../../clients/widgets/add_client_sheet.dart';

/// Результат выбора: `null` из [pickClient] означает отмену,
/// а [ClientPick] с пустым [client] — «показ без привязки к клиенту».
class ClientPick {
  const ClientPick(this.client);

  final ClientModel? client;
}

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
    final clients = ref.watch(clientsProvider);

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
                'Показ и бронь привяжутся к карточке клиента',
                style: AppTextStyles.secondary,
              ),
              const SizedBox(height: 14),
              clients.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, _) => Text('Не удалось загрузить клиентов: $e'),
                data: (list) => Column(
                  children: [
                    for (final client in list)
                      _ClientTile(
                        client: client,
                        onTap: () => Navigator.of(
                          context,
                        ).pop(ClientPick(client)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              // Клиента часто заводят прямо на объекте, во время показа.
              OutlinedButton.icon(
                onPressed: () => _addAndPick(context),
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
              OutlinedButton(
                onPressed: () =>
                    Navigator.of(context).pop(const ClientPick(null)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  side: const BorderSide(color: AppColors.line),
                  foregroundColor: AppColors.ink2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: const Text(
                  'Без клиента',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Завести клиента не выходя из показа и сразу привязать к нему квартиру.
  Future<void> _addAndPick(BuildContext context) async {
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
                  'до ${Money.usd(client.budget)}',
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
