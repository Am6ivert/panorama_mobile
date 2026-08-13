import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/unit_model.dart';
import '../../../core/models/unit_status.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../core/utils/api_action.dart';

/// Табличный редактор квартир блока (FR-04): выделение и групповое изменение.
/// Квартиры с активной бронью/сделкой исключаются из массовых операций.
class TableEditorScreen extends ConsumerStatefulWidget {
  const TableEditorScreen({super.key, required this.args});

  final EditorArgs args;

  @override
  ConsumerState<TableEditorScreen> createState() => _TableEditorScreenState();
}

class _TableEditorScreenState extends ConsumerState<TableEditorScreen> {
  final _selected = <String>{};

  bool _locked(UnitModel u) => u.status.isTaken; // бронь/работа/оформление

  @override
  Widget build(BuildContext context) {
    final units = ref.watch(
      blockUnitsProvider((
        complexId: widget.args.complexId,
        block: widget.args.block,
      )),
    );

    final floors = <int, List<UnitModel>>{};
    for (final u in units) {
      floors.putIfAbsent(u.floor, () => []).add(u);
    }
    for (final l in floors.values) {
      l.sort((a, b) => a.position.compareTo(b.position));
    }
    final positions = floors.values
        .map((e) => e.length)
        .fold(0, (a, b) => a > b ? a : b);

    return Scaffold(
      // Панель действий — в слоте bottomNavigationBar, а не как условный
      // ребёнок Column с Expanded: так на web не возникает кадр, где кнопки
      // ещё без размера (иначе mouse_tracker сыплет «hit test ... no size»).
      bottomNavigationBar: _selected.isEmpty
          ? null
          : _ApplyBar(
              count: _selected.length,
              onRooms: () => _applyRooms(context),
              onStatus: () => _applyStatus(context),
            ),
      body: Column(
        children: [
          AppHeader(
            title: 'Блок ${widget.args.block}',
            subtitle: 'Табличный редактор · ${units.length} квартир',
            gradient: false,
            onBack: () => Navigator.of(context).pop(),
          ),
          _Toolbar(
            positions: positions,
            selectedCount: _selected.length,
            onSelectStack: (pos) => _selectStack(units, pos),
            onClear: () => setState(_selected.clear),
          ),
          Expanded(
            child: units.isEmpty
                ? const Center(child: Text('В блоке нет квартир'))
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    child: Column(
                      children: [
                        for (final floor
                            in floors.keys.toList()..sort((a, b) => b - a))
                          _FloorRow(
                            floor: floor,
                            units: floors[floor]!,
                            selected: _selected,
                            locked: _locked,
                            onToggleUnit: _toggle,
                            onToggleFloor: () => _selectFloor(floors[floor]!),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _toggle(UnitModel u) {
    if (_locked(u)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Квартира с бронью или сделкой исключена из операций'),
        ),
      );
      return;
    }
    setState(() {
      _selected.contains(u.id) ? _selected.remove(u.id) : _selected.add(u.id);
    });
  }

  void _selectFloor(List<UnitModel> floorUnits) => setState(() {
    for (final u in floorUnits) {
      if (!_locked(u)) _selected.add(u.id);
    }
  });

  void _selectStack(List<UnitModel> units, int position) => setState(() {
    for (final u in units.where((u) => u.position == position && !_locked(u))) {
      _selected.add(u.id);
    }
  });

  Future<void> _applyRooms(BuildContext context) async {
    final rooms = await _pick<int>(
      context,
      'Комнатность для ${_selected.length} квартир',
      const [
        ('Студия', 0),
        ('1-комнатная', 1),
        ('2-комнатная', 2),
        ('3-комнатная', 3),
        ('4-комнатная', 4),
      ],
    );
    if (rooms == null) return;
    await _bulkUpdate((u) => u.copyWith(rooms: rooms));
  }

  Future<void> _applyStatus(BuildContext context) async {
    final status = await _pick<UnitStatus>(
      context,
      'Статус для ${_selected.length} квартир',
      const [
        ('Свободна', UnitStatus.free),
        ('Не для продажи', UnitStatus.offMarket),
      ],
    );
    if (status == null) return;
    await _bulkUpdate((u) => u.copyWith(status: status, clearHold: true));
  }

  Future<void> _bulkUpdate(UnitModel Function(UnitModel) transform) async {
    final by = ref.read(currentUserProvider);
    if (by == null) return;
    final repo = ref.read(panoramaRepositoryProvider);
    final all = ref.read(unitsProvider).value ?? const <UnitModel>[];
    final targets = all.where((u) => _selected.contains(u.id)).toList();
    // Если сервер отклонит одну из правок, цикл прерывался молча: снекбар не
    // показывался, выделение оставалось, причина была не видна.
    final done = await runApi(context, () async {
      for (final u in targets) {
        await repo.updateUnit(transform(u), by: by);
      }
      return targets.length;
    });
    if (!mounted || done == null) return;
    setState(_selected.clear);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Обновлено $done квартир')),
    );
  }

  Future<T?> _pick<T>(
    BuildContext context,
    String title,
    List<(String, T)> options,
  ) => showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.h2),
            const SizedBox(height: 12),
            for (final (label, value) in options)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(label),
                onTap: () => Navigator.of(context).pop(value),
              ),
          ],
        ),
      ),
    ),
  );
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.positions,
    required this.selectedCount,
    required this.onSelectStack,
    required this.onClear,
  });

  final int positions;
  final int selectedCount;
  final ValueChanged<int> onSelectStack;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(bottom: BorderSide(color: AppColors.line)),
    ),
    child: Row(
      children: [
        const Text('Стояк:', style: AppTextStyles.caption),
        const SizedBox(width: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var p = 1; p <= positions; p++)
                  GestureDetector(
                    onTap: () => onSelectStack(p),
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Text(
                        '$p',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (selectedCount > 0)
          TextButton(onPressed: onClear, child: const Text('Сброс')),
      ],
    ),
  );
}

class _FloorRow extends StatelessWidget {
  const _FloorRow({
    required this.floor,
    required this.units,
    required this.selected,
    required this.locked,
    required this.onToggleUnit,
    required this.onToggleFloor,
  });

  final int floor;
  final List<UnitModel> units;
  final Set<String> selected;
  final bool Function(UnitModel) locked;
  final void Function(UnitModel) onToggleUnit;
  final VoidCallback onToggleFloor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        GestureDetector(
          onTap: onToggleFloor,
          child: SizedBox(
            width: 30,
            child: Text(
              '$floor',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.brand,
              ),
            ),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final u in units)
                _EditCell(
                  unit: u,
                  selected: selected.contains(u.id),
                  locked: locked(u),
                  onTap: () => onToggleUnit(u),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _EditCell extends StatelessWidget {
  const _EditCell({
    required this.unit,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final UnitModel unit;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    onLongPress: locked ? null : () => _editUnit(context, unit),
    child: Opacity(
      opacity: locked ? 0.5 : 1,
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.brand : unit.status.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.brand : unit.status.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '№${unit.number}',
              style: TextStyle(
                fontSize: 8,
                color: selected
                    ? Colors.white70
                    : unit.status.foreground.withValues(alpha: 0.6),
              ),
            ),
            Text(
              unit.shortLayout,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : unit.status.foreground,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _editUnit(BuildContext context, UnitModel unit) async {
    final updated = await showModalBottomSheet<UnitModel>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _UnitEditSheet(unit: unit),
    );

    if (updated == null || !context.mounted) return;

    final by = context.findAncestorStateOfType<_TableEditorScreenState>()
        ?.ref.read(currentUserProvider);
    if (by == null) return;

    final repo = context.findAncestorStateOfType<_TableEditorScreenState>()
        ?.ref.read(panoramaRepositoryProvider);
    if (repo == null) return;

    await repo.updateUnit(updated, by: by);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Квартира №${unit.number} обновлена')),
      );
    }
  }
}

class _ApplyBar extends StatelessWidget {
  const _ApplyBar({
    required this.count,
    required this.onRooms,
    required this.onStatus,
  });

  final int count;
  final VoidCallback onRooms;
  final VoidCallback onStatus;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
      16,
      12,
      16,
      12 + MediaQuery.paddingOf(context).bottom,
    ),
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(top: BorderSide(color: AppColors.line)),
    ),
    child: Row(
      children: [
        Text(
          'Выбрано: $count',
          style: AppTextStyles.bodyStrong,
        ),
        const Spacer(),
        OutlinedButton(
          onPressed: onRooms,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.line),
            foregroundColor: AppColors.ink,
          ),
          child: const Text('Комнаты'),
        ),
        const SizedBox(width: 8),
        FilledButton(onPressed: onStatus, child: const Text('Статус')),
      ],
    ),
  );
}

class _UnitEditSheet extends StatefulWidget {
  const _UnitEditSheet({required this.unit});

  final UnitModel unit;

  @override
  State<_UnitEditSheet> createState() => _UnitEditSheetState();
}

class _UnitEditSheetState extends State<_UnitEditSheet> {
  late final TextEditingController _area;
  late final TextEditingController _kitchen;
  late final TextEditingController _view;
  late final TextEditingController _finish;
  late int _bathrooms;

  @override
  void initState() {
    super.initState();
    _area = TextEditingController(text: widget.unit.area.toString());
    _kitchen = TextEditingController(text: widget.unit.kitchen);
    _view = TextEditingController(text: widget.unit.view);
    _finish = TextEditingController(text: widget.unit.finish);
    _bathrooms = widget.unit.bathrooms;
  }

  @override
  void dispose() {
    _area.dispose();
    _kitchen.dispose();
    _view.dispose();
    _finish.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      18,
      4,
      18,
      18 + MediaQuery.of(context).viewInsets.bottom,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Редактировать №${widget.unit.number}',
            style: AppTextStyles.h2,
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.unit.layoutName} · ${widget.unit.floor} этаж',
            style: AppTextStyles.secondary,
          ),
          const SizedBox(height: 18),
          _Field(
            controller: _area,
            label: 'Площадь (м²)',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          _Field(controller: _kitchen, label: 'Кухня'),
          const SizedBox(height: 12),
          _Field(controller: _view, label: 'Вид из окон'),
          const SizedBox(height: 12),
          _Field(controller: _finish, label: 'Отделка'),
          const SizedBox(height: 12),
          Text('Санузлов', style: AppTextStyles.caption),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 1; i <= 3; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('$i'),
                    selected: _bathrooms == i,
                    onSelected: (selected) {
                      if (selected) setState(() => _bathrooms = i);
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _save,
              child: const Text('Сохранить'),
            ),
          ),
        ],
      ),
    ),
  );

  void _save() {
    final area = double.tryParse(_area.text.trim());
    if (area == null || area <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите корректную площадь')),
      );
      return;
    }

    final updated = widget.unit.copyWith(
      area: area,
      kitchen: _kitchen.text.trim(),
      view: _view.text.trim(),
      finish: _finish.text.trim(),
      bathrooms: _bathrooms,
    );

    Navigator.of(context).pop(updated);
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppTextStyles.caption),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 15, color: AppColors.ink),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: AppColors.bg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.brand),
          ),
        ),
      ),
    ],
  );
}
