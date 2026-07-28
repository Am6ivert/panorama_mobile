import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/unit_model.dart';
import '../../../core/models/unit_status.dart';
import '../../../core/providers/data_providers.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/choice_chip_bar.dart';
import '../../../shared/widgets/labeled_slider.dart';
import '../../../shared/widgets/section_title.dart';
import '../../../shared/widgets/unit_tile.dart';
import '../../unit/widgets/unit_sheet.dart';
import '../providers/search_filter_provider.dart';

/// Подбор свободных квартир по всем объектам — только по характеристикам
/// (ТЗ 1.3): комнатность, площадь, объект. Открывается из карточки квартиры
/// и из карточки клиента.
class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key});

  static const _roomLabels = ['Студия', '1к', '2к', '3к', '4к'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(searchFilterProvider);
    final notifier = ref.read(searchFilterProvider.notifier);
    final complexes = ref.watch(complexesProvider).value ?? const [];
    final results = _search(ref, filter);

    return Scaffold(
      body: Column(
        children: [
          AppHeader(
            title: 'Похожие варианты',
            subtitle: 'Свободные квартиры по всем объектам',
            gradient: false,
            onBack: () => Navigator.of(context).pop(),
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
                const SectionTitle('Объект'),
                ChoiceChipBar<String?>(
                  options: [
                    const ChipOption<String?>(value: null, label: 'Все'),
                    for (final c in complexes)
                      ChipOption<String?>(value: c.id, label: c.name),
                  ],
                  isSelected: (value) => value == filter.complexId,
                  onTap: notifier.setComplex,
                ),
                const SectionTitle('Площадь от'),
                LabeledSlider(
                  leading: 'минимум',
                  trailing: '${filter.minArea.round()} м²',
                  value: filter.minArea,
                  min: 25,
                  max: 130,
                  divisions: 105,
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
                              'Снизьте требования к площади или комнатности.',
                        )
                      : Column(
                          children: [
                            for (final unit in results)
                              UnitTile(
                                unit: unit,
                                title:
                                    '${unit.layoutName} · ${unit.area} м²',
                                subtitle:
                                    '${unit.complexName} · бл. ${unit.block} · '
                                    '${unit.floor} этаж · №${unit.number}',
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
      ),
    );
  }

  List<UnitModel> _search(WidgetRef ref, SearchFilter filter) {
    final units = ref.watch(unitsProvider).value ?? const <UnitModel>[];
    final results =
        units
            .where(
              (u) =>
                  u.status == UnitStatus.free &&
                  u.area >= filter.minArea &&
                  (filter.complexId == null ||
                      u.complexId == filter.complexId) &&
                  (filter.rooms.isEmpty || filter.rooms.contains(u.rooms)),
            )
            .toList()
          ..sort((a, b) => a.area.compareTo(b.area));
    return results.take(40).toList(growable: false);
  }
}
