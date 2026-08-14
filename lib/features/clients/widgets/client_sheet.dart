import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/client_model.dart';
import '../../../core/models/unit_model.dart';
import '../../../core/models/unit_status.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/initials_avatar.dart';
import '../../../shared/widgets/unit_tile.dart';
import '../../search/providers/search_filter_provider.dart';
import '../../unit/widgets/unit_sheet.dart';

/// Карточка клиента (FR-08). Все связанные квартиры, подбор под запрос, звонок.
class ClientSheet extends ConsumerWidget {
  const ClientSheet({super.key, required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = _find(ref.watch(clientsProvider).value);
    if (client == null) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final units = ref.watch(unitsProvider).value ?? const <UnitModel>[];
    final matches =
        units
            .where((u) => u.status == UnitStatus.free && u.rooms == client.rooms)
            .toList()
          ..sort((a, b) => a.area.compareTo(b.area));
    final active = units
        .where((u) => u.clientId == client.id)
        .toList(growable: false);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InitialsAvatar(
                    initials: client.initials,
                    color: client.color,
                    size: 48,
                    fontSize: 16,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          client.name,
                          style: AppTextStyles.h1.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(client.phone, style: AppTextStyles.secondary),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: client.stage.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      client.stage.label,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: client.stage.color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _InfoBlock(client: client),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _call(client.phone),
                      child: const Text('Позвонить'),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _whatsapp(client.phone),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFEEF2F9),
                        foregroundColor: AppColors.ink,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: const Text('WhatsApp'),
                    ),
                  ),
                ],
              ),
              if (active.isNotEmpty) ...[
                const SizedBox(height: 18),
                const Text('В РАБОТЕ ПО КЛИЕНТУ', style: AppTextStyles.section),
                const SizedBox(height: 10),
                for (final unit in active)
                  UnitTile(
                    unit: unit,
                    title: 'Кв. №${unit.number} · ${unit.area} м²',
                    subtitle:
                        '${unit.complexName} · бл. ${unit.block} · '
                        '${unit.status.label.toLowerCase()}',
                    onTap: () => _openUnit(context, unit),
                  ),
              ],
              const SizedBox(height: 18),
              Text(
                'ПОДХОДИТ СЕЙЧАС (${matches.length})',
                style: AppTextStyles.section,
              ),
              const SizedBox(height: 10),
              if (matches.isEmpty)
                const Text(
                  'Свободных вариантов под запрос сейчас нет.',
                  style: AppTextStyles.secondary,
                )
              else
                for (final unit in matches.take(3))
                  UnitTile(
                    unit: unit,
                    title: '${unit.layoutName} · ${unit.area} м²',
                    subtitle:
                        '${unit.complexName} · бл. ${unit.block} · '
                        '${unit.floor} этаж',
                    onTap: () => _openUnit(context, unit),
                  ),
              const SizedBox(height: 4),
              OutlinedButton(
                onPressed: () => _openSearch(context, ref, client),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  side: const BorderSide(color: AppColors.line),
                  foregroundColor: AppColors.ink2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: Text(
                  'Открыть подбор: ${client.rooms == 0 ? 'студия' : '${client.rooms}к'}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ClientModel? _find(List<ClientModel>? clients) {
    for (final client in clients ?? const <ClientModel>[]) {
      if (client.id == clientId) return client;
    }
    return null;
  }

  void _openUnit(BuildContext context, UnitModel unit) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => UnitSheet(unitId: unit.id),
      );

  void _openSearch(BuildContext context, WidgetRef ref, ClientModel client) {
    ref.read(searchFilterProvider.notifier).seedFromClient(client);
    Navigator.of(context).pop();
    Navigator.of(context).pushNamed(AppRoutes.similar);
  }

  Future<void> _call(String phone) =>
      launchUrl(Uri.parse('tel:${_digits(phone)}'));

  Future<void> _whatsapp(String phone) => launchUrl(
    Uri.parse('https://wa.me/${_digits(phone)}'),
    mode: LaunchMode.externalApplication,
  );

  String _digits(String phone) => phone.replaceAll(RegExp(r'[^0-9+]'), '');
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.client});
  final ClientModel client;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Ответственный', client.sellerName.isEmpty ? '—' : client.sellerName),
      if (client.source.isNotEmpty) ('Источник', client.source),
      ('Ищет', client.rooms == 0 ? 'Студия' : '${client.rooms}-комн.'),
      if (client.request.isNotEmpty) ('Запрос', client.request),
      if (client.note.isNotEmpty) ('Комментарий', client.note),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  child: Text(rows[i].$1, style: AppTextStyles.caption),
                ),
                Expanded(
                  child: Text(
                    rows[i].$2,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
