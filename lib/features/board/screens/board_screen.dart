import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/complex_model.dart';
import '../../../core/models/unit_model.dart';
import '../../../core/models/unit_status.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/utils/time_format.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/choice_chip_bar.dart';
import '../../../shared/widgets/section_title.dart';
import '../../unit/widgets/unit_sheet.dart';
import '../widgets/unit_cell.dart';

/// Шахматка одного ЖК: этажи по вертикали, квартиры этажа по горизонтали.
class BoardScreen extends ConsumerStatefulWidget {
  const BoardScreen({super.key, required this.complexId});

  final String complexId;

  @override
  ConsumerState<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends ConsumerState<BoardScreen> {
  String? _block;
  final _rooms = <int>{};
  bool _onlyFree = false;
  DateTime _updatedAt = DateTime.now();

  static const _floorColumnWidth = 34.0;
  static const _gap = 6.0;
  static const _minCellWidth = 46.0;
  static const _scrollCellWidth = 60.0;

  bool get _filterActive => _rooms.isNotEmpty || _onlyFree;

  bool _matches(UnitModel unit) =>
      (_rooms.isEmpty || _rooms.contains(unit.rooms)) &&
      (!_onlyFree || unit.status == UnitStatus.free);

  @override
  Widget build(BuildContext context) {
    ref.listen(unitsProvider, (_, _) {
      if (mounted) setState(() => _updatedAt = DateTime.now());
    });

    final complexes = ref.watch(complexesProvider);

    return Scaffold(
      body: complexes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка загрузки: $e')),
        data: (list) {
          final complex = list.firstWhere(
            (c) => c.id == widget.complexId,
            orElse: () => list.first,
          );
          final block = _block ?? complex.blocks.first.name;
          final units = ref.watch(
            blockUnitsProvider((complexId: complex.id, block: block)),
          );
          final stats = UnitStats.of(units);

          return Column(
            children: [
              AppHeader(
                title: complex.name,
                subtitle: '${complex.address} · ${complex.deadline}',
                gradient: false,
                onBack: () => Navigator.of(context).pop(),
                bottom: LiveIndicator(
                  text:
                      'Данные актуальны · обновлено в '
                      '${TimeFormat.hhmm(_updatedAt)}',
                ),
              ),
              _FilterPanel(
                complex: complex,
                block: block,
                rooms: _rooms,
                onlyFree: _onlyFree,
                stats: stats,
                onBlock: (value) => setState(() => _block = value),
                onRoom: (value) => setState(
                  () => _rooms.contains(value)
                      ? _rooms.remove(value)
                      : _rooms.add(value),
                ),
                onOnlyFree: () => setState(() => _onlyFree = !_onlyFree),
              ),
              Expanded(child: _Grid(units: units, screen: this)),
            ],
          );
        },
      ),
    );
  }

  void _openUnit(UnitModel unit) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => UnitSheet(unitId: unit.id),
  );
}

class _Grid extends StatelessWidget {
  const _Grid({required this.units, required this.screen});

  final List<UnitModel> units;
  final _BoardScreenState screen;

  @override
  Widget build(BuildContext context) {
    if (units.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Text(
            'В этом блоке пока нет квартир',
            style: TextStyle(color: AppColors.ink3),
          ),
        ),
      );
    }

    // Этажи сверху вниз, как в бумажной шахматке.
    final floors = <int, List<UnitModel>>{};
    for (final unit in units) {
      floors.putIfAbsent(unit.floor, () => []).add(unit);
    }
    final maxPerFloor = floors.values
        .map((e) => e.length)
        .reduce((a, b) => a > b ? a : b);

    return LayoutBuilder(
      builder: (context, constraints) {
        final available =
            constraints.maxWidth -
            32 -
            _BoardScreenState._floorColumnWidth -
            _BoardScreenState._gap * maxPerFloor;
        final fitted = available / maxPerFloor;
        final scrolls = fitted < _BoardScreenState._minCellWidth;
        final cellWidth = scrolls
            ? _BoardScreenState._scrollCellWidth
            : fitted;

        final rows = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final entry in floors.entries)
              Padding(
                padding: const EdgeInsets.only(
                  bottom: _BoardScreenState._gap,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: _BoardScreenState._floorColumnWidth,
                      height: 56,
                      child: Center(
                        child: Text(
                          '${entry.key}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink3,
                          ),
                        ),
                      ),
                    ),
                    for (final unit in entry.value) ...[
                      const SizedBox(width: _BoardScreenState._gap),
                      UnitCell(
                        unit: unit,
                        width: cellWidth,
                        dimmed:
                            screen._filterActive && !screen._matches(unit),
                        highlighted:
                            screen._filterActive && screen._matches(unit),
                        onTap: () => screen._openUnit(unit),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        );

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          children: [
            if (scrolls)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: rows,
              )
            else
              rows,
            const SizedBox(height: 8),
            const Text(
              'Нажмите на квартиру, чтобы открыть карточку, взять в работу '
              'или забронировать.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.5,
                color: AppColors.ink3,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.complex,
    required this.block,
    required this.rooms,
    required this.onlyFree,
    required this.stats,
    required this.onBlock,
    required this.onRoom,
    required this.onOnlyFree,
  });

  final ComplexModel complex;
  final String block;
  final Set<int> rooms;
  final bool onlyFree;
  final UnitStats stats;
  final ValueChanged<String> onBlock;
  final ValueChanged<int> onRoom;
  final VoidCallback onOnlyFree;

  static const _roomLabels = ['Студия', '1к', '2к', '3к', '4к'];

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.only(top: 10, bottom: 10),
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(bottom: BorderSide(color: AppColors.line)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChoiceChipBar<String>(
          options: [
            for (final b in complex.blocks)
              ChipOption(value: b.name, label: 'Блок ${b.name}'),
          ],
          isSelected: (value) => value == block,
          onTap: onBlock,
        ),
        const SizedBox(height: 8),
        ChoiceChipBar<int>(
          options: [
            for (var i = 0; i < _roomLabels.length; i++)
              ChipOption(value: i, label: _roomLabels[i]),
          ],
          isSelected: rooms.contains,
          onTap: onRoom,
          trailing: AppChip(
            label: 'Только свободные',
            selected: onlyFree,
            dashed: true,
            onTap: onOnlyFree,
          ),
        ),
        const SizedBox(height: 11),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              StatusCount(
                color: AppColors.free,
                label: 'Свободно',
                count: stats.free,
              ),
              StatusCount(
                color: AppColors.work,
                label: 'В работе',
                count: stats.work,
              ),
              StatusCount(
                color: AppColors.hold,
                label: 'Бронь',
                count: stats.hold,
              ),
              StatusCount(
                color: AppColors.sold,
                label: 'Продано',
                count: stats.sold,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
