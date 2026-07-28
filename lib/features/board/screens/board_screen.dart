import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/manager_model.dart';
import '../../../core/models/unit_model.dart';
import '../../../core/models/unit_status.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/utils/time_format.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/choice_chip_bar.dart';
import '../../../shared/widgets/section_title.dart';
import '../../../shared/widgets/unit_tile.dart';
import '../../unit/widgets/unit_sheet.dart';
import '../widgets/unit_cell.dart';

/// Шахматка одного ЖК: этажи по вертикали, позиции этажа по горизонтали (FR-05).
class BoardScreen extends ConsumerStatefulWidget {
  const BoardScreen({super.key, required this.complexId});

  final String complexId;

  @override
  ConsumerState<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends ConsumerState<BoardScreen> {
  String? _block;
  final _rooms = <int>{};
  final _statuses = <UnitStatus>{};
  String? _managerId;
  bool _listView = false;
  DateTime _updatedAt = DateTime.now();

  static const _floorColumnWidth = 34.0;
  static const _gap = 6.0;
  static const _minCellWidth = 46.0;
  static const _scrollCellWidth = 60.0;

  bool get _filterActive =>
      _rooms.isNotEmpty || _statuses.isNotEmpty || _managerId != null;

  bool _matches(UnitModel unit) =>
      (_rooms.isEmpty || _rooms.contains(unit.rooms)) &&
      (_statuses.isEmpty || _statuses.contains(unit.status)) &&
      (_managerId == null || unit.heldById == _managerId);

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
          // Блоки берём из живого фонда, чтобы созданные мастером блоки тоже
          // появлялись, а не только из статичного справочника.
          final complexUnits = ref.watch(complexUnitsProvider(complex.id));
          final blockNames =
              <String>{
                ...complex.blocks.map((b) => b.name),
                ...complexUnits.map((u) => u.block),
              }.toList()..sort();
          final block = _block ?? (blockNames.isNotEmpty ? blockNames.first : '');
          final units = ref.watch(
            blockUnitsProvider((complexId: complex.id, block: block)),
          );
          final stats = UnitStats.of(units);
          final managers = ref.watch(managersProvider);

          return Column(
            children: [
              AppHeader(
                title: complex.name,
                subtitle: '${complex.address} · ${complex.deadline}',
                gradient: false,
                onBack: () => Navigator.of(context).pop(),
                trailing: _ViewToggle(
                  listView: _listView,
                  onChanged: (v) => setState(() => _listView = v),
                ),
                bottom: LiveIndicator(
                  text: 'Обновлено в ${TimeFormat.hhmm(_updatedAt)}',
                ),
              ),
              _FilterPanel(
                blockNames: blockNames,
                block: block,
                rooms: _rooms,
                statuses: _statuses,
                managers: managers,
                managerId: _managerId,
                stats: stats,
                onBlock: (value) => setState(() => _block = value),
                onRoom: (value) => setState(
                  () => _rooms.contains(value)
                      ? _rooms.remove(value)
                      : _rooms.add(value),
                ),
                onStatus: (value) => setState(
                  () => _statuses.contains(value)
                      ? _statuses.remove(value)
                      : _statuses.add(value),
                ),
                onManager: (value) => setState(() => _managerId = value),
              ),
              Expanded(
                child: _listView
                    ? _ListMode(
                        units: units
                            .where((u) => !_filterActive || _matches(u))
                            .toList(growable: false),
                        onOpen: _openUnit,
                      )
                    : _Grid(units: units, screen: this),
              ),
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

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.listView, required this.onChanged});
  final bool listView;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(11),
    ),
    padding: const EdgeInsets.all(3),
    child: Row(
      children: [
        _seg(Icons.grid_view, !listView, () => onChanged(false)),
        _seg(Icons.view_list, listView, () => onChanged(true)),
      ],
    ),
  );

  Widget _seg(IconData icon, bool active, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        size: 17,
        color: active ? AppColors.brandDark : Colors.white,
      ),
    ),
  );
}

class _ListMode extends StatelessWidget {
  const _ListMode({required this.units, required this.onOpen});
  final List<UnitModel> units;
  final void Function(UnitModel) onOpen;

  @override
  Widget build(BuildContext context) {
    if (units.isEmpty) {
      return const EmptyState(
        icon: Icons.filter_alt_off_outlined,
        text: 'Под фильтр ничего не подходит.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        for (final unit in units)
          UnitTile(
            unit: unit,
            title: 'Кв. №${unit.number} · ${unit.layoutName}',
            subtitle:
                '${unit.floor} этаж · поз. ${unit.position}'
                '${unit.heldByName == null ? '' : ' · ${unit.heldByName}'}',
            onTap: () => onOpen(unit),
          ),
      ],
    );
  }
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

    final floors = <int, List<UnitModel>>{};
    for (final unit in units) {
      floors.putIfAbsent(unit.floor, () => []).add(unit);
    }
    for (final list in floors.values) {
      list.sort((a, b) => a.position.compareTo(b.position));
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
                padding: const EdgeInsets.only(bottom: _BoardScreenState._gap),
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
                        dimmed: screen._filterActive && !screen._matches(unit),
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
              style: TextStyle(fontSize: 11.5, height: 1.5, color: AppColors.ink3),
            ),
          ],
        );
      },
    );
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.blockNames,
    required this.block,
    required this.rooms,
    required this.statuses,
    required this.managers,
    required this.managerId,
    required this.stats,
    required this.onBlock,
    required this.onRoom,
    required this.onStatus,
    required this.onManager,
  });

  final List<String> blockNames;
  final String block;
  final Set<int> rooms;
  final Set<UnitStatus> statuses;
  final List<ManagerModel> managers;
  final String? managerId;
  final UnitStats stats;
  final ValueChanged<String> onBlock;
  final ValueChanged<int> onRoom;
  final ValueChanged<UnitStatus> onStatus;
  final ValueChanged<String?> onManager;

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
            for (final name in blockNames)
              ChipOption(value: name, label: 'Блок $name'),
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
        ),
        const SizedBox(height: 8),
        ChoiceChipBar<UnitStatus>(
          options: const [
            ChipOption(value: UnitStatus.free, label: 'Свободна'),
            ChipOption(value: UnitStatus.work, label: 'В работе'),
            ChipOption(value: UnitStatus.hold, label: 'Бронь'),
            ChipOption(value: UnitStatus.design, label: 'Оформление'),
          ],
          isSelected: statuses.contains,
          onTap: onStatus,
          trailing: managers.isEmpty
              ? null
              : _ManagerFilter(
                  managers: managers,
                  managerId: managerId,
                  onManager: onManager,
                ),
        ),
        const SizedBox(height: 11),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              StatusCount(color: AppColors.free, label: 'Свободно', count: stats.free),
              StatusCount(color: AppColors.work, label: 'В работе', count: stats.work),
              StatusCount(color: AppColors.hold, label: 'Бронь', count: stats.hold),
              StatusCount(color: AppColors.design, label: 'Оформл.', count: stats.design),
              StatusCount(color: AppColors.sold, label: 'Продано', count: stats.sold),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ManagerFilter extends StatelessWidget {
  const _ManagerFilter({
    required this.managers,
    required this.managerId,
    required this.onManager,
  });

  final List<ManagerModel> managers;
  final String? managerId;
  final ValueChanged<String?> onManager;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String?>(
    onSelected: (v) => onManager(v == '' ? null : v),
    itemBuilder: (_) => [
      const PopupMenuItem(value: '', child: Text('Все менеджеры')),
      for (final m in managers)
        PopupMenuItem(value: m.id, child: Text(m.shortName)),
    ],
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: managerId != null ? AppColors.brand : AppColors.surface,
        border: Border.all(
          color: managerId != null ? AppColors.brand : AppColors.line,
        ),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_outline,
            size: 15,
            color: managerId != null ? Colors.white : AppColors.ink2,
          ),
          const SizedBox(width: 5),
          Text(
            managerId == null
                ? 'Менеджер'
                : managers.firstWhere((m) => m.id == managerId).shortName,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: managerId != null ? Colors.white : AppColors.ink2,
            ),
          ),
        ],
      ),
    ),
  );
}
