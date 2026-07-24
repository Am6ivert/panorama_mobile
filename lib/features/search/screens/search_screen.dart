import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/unit_model.dart';
import '../../../core/models/unit_status.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/choice_chip_bar.dart';
import '../../../shared/widgets/labeled_slider.dart';
import '../../../shared/widgets/section_title.dart';
import '../../../shared/widgets/unit_tile.dart';
import '../../unit/widgets/unit_sheet.dart';
import '../providers/search_filter_provider.dart';

/// Ответ на вопрос клиента «а есть другие квартиры?» —
/// поиск сразу по всем объектам компании.
class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key});

  static const _roomLabels = ['Студия', '1к', '2к', '3к', '4к'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(searchFilterProvider);
    final notifier = ref.read(searchFilterProvider.notifier);
    final results = _search(ref, filter);

    return Column(
      children: [
        const AppHeader(
          title: 'Подбор для клиента',
          subtitle: 'По всем объектам компании, в реальном времени',
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const SectionTitle('Комнатность'),
              ChoiceChipBar<int>(
                options: [
                  for (var i = 0; i < _roomLabels.length; i++)
                    ChipOption(value: i, label: _roomLabels[i]),
                ],
                isSelected: filter.rooms.contains,
                onTap: notifier.toggleRoom,
              ),
              const SectionTitle('Бюджет до'),
              LabeledSlider(
                leading: Money.kgsApprox(filter.budget),
                trailing: Money.usd(filter.budget),
                value: filter.budget.toDouble(),
                min: SearchFilterNotifier.minBudget.toDouble(),
                max: SearchFilterNotifier.maxBudget.toDouble(),
                divisions: 44,
                onChanged: (v) => notifier.setBudget(v.round()),
              ),
              const SectionTitle('Площадь от'),
              LabeledSlider(
                leading: 'минимум',
                trailing: '${filter.minArea.round()} м²',
                value: filter.minArea,
                min: 25,
                max: 110,
                divisions: 85,
                onChanged: notifier.setMinArea,
              ),
              SectionTitle(
                results.isEmpty
                    ? 'Ничего не найдено'
                    : 'Свободно сейчас: ${results.length}',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: results.isEmpty
                    ? const EmptyState(
                        icon: Icons.search_off,
                        text: 'Под эти условия свободных квартир нет.\n'
                            'Увеличьте бюджет или снизьте требования к площади.',
                      )
                    : Column(
                        children: [
                          for (final unit in results)
                            UnitTile(
                              unit: unit,
                              title: '${unit.area} м² · ${unit.floor} этаж',
                              subtitle:
                                  '${unit.complexName} · бл. ${unit.block} · '
                                  '№${unit.number}',
                              onTap: () => showModalBottomSheet<void>(
                                context: context,
                                isScrollControlled: true,
                                showDragHandle: true,
                                builder: (_) => UnitSheet(unitId: unit.id),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<UnitModel> _search(WidgetRef ref, SearchFilter filter) {
    final units = ref.watch(unitsProvider).value ?? const <UnitModel>[];
    final results =
        units
            .where(
              (u) =>
                  u.status == UnitStatus.free &&
                  u.price <= filter.budget &&
                  u.area >= filter.minArea &&
                  (filter.rooms.isEmpty || filter.rooms.contains(u.rooms)),
            )
            .toList()
          ..sort((a, b) => a.price.compareTo(b.price));
    return results.take(40).toList(growable: false);
  }
}
