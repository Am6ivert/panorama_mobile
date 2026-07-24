import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/unit_model.dart';
import '../../../core/models/unit_status.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/utils/time_format.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/section_title.dart';
import '../../../shared/widgets/unit_tile.dart';
import '../../unit/widgets/unit_sheet.dart';

class DealsScreen extends ConsumerWidget {
  const DealsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deals = ref.watch(myDealsProvider);
    final inWork = deals
        .where((u) => u.status == UnitStatus.work)
        .toList(growable: false);
    final booked = deals
        .where((u) => u.status == UnitStatus.hold)
        .toList(growable: false);

    return Column(
      children: [
        const AppHeader(
          title: 'Мои сделки',
          subtitle: 'Взятые в работу и брони',
        ),
        Expanded(
          child: deals.isEmpty
              ? const SingleChildScrollView(
                  child: EmptyState(
                    icon: Icons.handshake_outlined,
                    text: 'Пока нет активных сделок.\nОткройте шахматку и '
                        'возьмите квартиру в работу перед показом.',
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    if (inWork.isNotEmpty) ...[
                      const SectionTitle('В работе (показ)'),
                      _Group(units: inWork),
                    ],
                    if (booked.isNotEmpty) ...[
                      const SectionTitle('Брони'),
                      _Group(units: booked),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.units});

  final List<UnitModel> units;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      children: [
        for (final unit in units)
          UnitTile(
            unit: unit,
            title: 'Кв. №${unit.number} · ${unit.area} м²',
            subtitle: [
              unit.complexName,
              'бл. ${unit.block}',
              if (unit.heldUntil != null) TimeFormat.until(unit.heldUntil!),
              if (unit.clientName != null) unit.clientName!,
            ].join(' · '),
            onTap: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (_) => UnitSheet(unitId: unit.id),
            ),
          ),
      ],
    ),
  );
}
