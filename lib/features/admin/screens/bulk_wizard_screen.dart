import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/data/panorama_repository.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/choice_chip_bar.dart';
import '../../../shared/widgets/section_title.dart';
import '../widgets/create_complex_sheet.dart';
import '../../../core/utils/api_action.dart';

/// Черновик одной группы этажей в UI.
class _GroupDraft {
  _GroupDraft({required this.floorFrom, required this.floorTo, required this.template});
  int floorFrom;
  int floorTo;

  /// Комнатность по позициям, например [1, 2, 2, 3].
  List<int> template;
}

/// Мастер массового создания блока (FR-03). Одной транзакцией с предпросмотром.
class BulkWizardScreen extends ConsumerStatefulWidget {
  const BulkWizardScreen({super.key});

  @override
  ConsumerState<BulkWizardScreen> createState() => _BulkWizardScreenState();
}

class _BulkWizardScreenState extends ConsumerState<BulkWizardScreen> {
  String? _complexId;
  final _blockName = TextEditingController(text: 'Г');
  int _startNumber = 1;
  final _technical = TextEditingController();
  final _skip = TextEditingController();
  bool _saving = false;

  final List<_GroupDraft> _groups = [
    _GroupDraft(floorFrom: 1, floorTo: 12, template: [1, 2, 2, 3]),
  ];

  @override
  void dispose() {
    _blockName.dispose();
    _technical.dispose();
    _skip.dispose();
    super.dispose();
  }

  Set<int> get _technicalFloors => _parseSet(_technical.text);
  Set<int> get _skipNumbers => _parseSet(_skip.text);

  int get _maxFloor =>
      _groups.map((g) => g.floorTo).fold(0, (a, b) => a > b ? a : b);

  /// Сколько квартир будет создано (учёт техэтажей).
  int get _previewCount {
    var count = 0;
    for (var floor = 1; floor <= _maxFloor; floor++) {
      if (_technicalFloors.contains(floor)) continue;
      final group = _groupFor(floor);
      if (group != null) count += group.template.length;
    }
    return count;
  }

  _GroupDraft? _groupFor(int floor) {
    for (final g in _groups) {
      if (floor >= g.floorFrom && floor <= g.floorTo) return g;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final complexes = ref.watch(complexesProvider).value ?? const [];
    _complexId ??= complexes.isNotEmpty ? complexes.first.id : null;

    return Scaffold(
      body: Column(
        children: [
          AppHeader(
            title: 'Массовое создание',
            subtitle: 'Блок целиком за минуты (FR-03)',
            gradient: false,
            onBack: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                const SectionTitle('Объект'),
                ChoiceChipBar<String>(
                  options: [
                    for (final c in complexes)
                      ChipOption(value: c.id, label: c.name),
                  ],
                  isSelected: (id) => id == _complexId,
                  onTap: (id) => setState(() => _complexId = id),
                  trailing: OutlinedButton.icon(
                    onPressed: _createComplex,
                    icon: const Icon(Icons.add, size: 16),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      side: const BorderSide(color: AppColors.brand),
                      foregroundColor: AppColors.brand,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    label: const Text('Новый объект'),
                  ),
                ),
                const SectionTitle('Параметры блока'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _MiniField(
                          controller: _blockName,
                          label: 'Название блока',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _NumberStepper(
                          label: 'Старт. номер',
                          value: _startNumber,
                          min: 1,
                          onChanged: (v) => setState(() => _startNumber = v),
                        ),
                      ),
                    ],
                  ),
                ),
                const SectionTitle('Группы этажей'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      for (var i = 0; i < _groups.length; i++)
                        _GroupEditor(
                          index: i,
                          group: _groups[i],
                          canRemove: _groups.length > 1,
                          onChanged: () => setState(() {}),
                          onRemove: () => setState(() => _groups.removeAt(i)),
                        ),
                      const SizedBox(height: 4),
                      OutlinedButton.icon(
                        onPressed: () => setState(
                          () => _groups.add(
                            _GroupDraft(
                              floorFrom: _maxFloor + 1,
                              floorTo: _maxFloor + 4,
                              template: [1, 2, 2],
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.add, size: 18),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                          side: const BorderSide(color: AppColors.line),
                          foregroundColor: AppColors.ink2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        label: const Text('Добавить группу этажей'),
                      ),
                    ],
                  ),
                ),
                const SectionTitle('Исключения'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _MiniField(
                        controller: _technical,
                        label: 'Технические этажи (через запятую)',
                        hint: 'напр. 1, 14',
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 10),
                      _MiniField(
                        controller: _skip,
                        label: 'Пропустить номера',
                        hint: 'напр. 13',
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
                const SectionTitle('Предпросмотр'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _Preview(
                    count: _previewCount,
                    maxFloor: _maxFloor,
                    technicalFloors: _technicalFloors,
                    groupFor: _groupFor,
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: FilledButton(
                    onPressed: _saving || _previewCount == 0 ? null : _create,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text('Создать $_previewCount квартир'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createComplex() async {
    final complex = await createComplexSheet(context);
    if (complex == null || !mounted) return;
    setState(() => _complexId = complex.id);
  }

  /// Ключ повторной отправки: живёт до успешного создания, поэтому повтор
  /// после ошибки не создаёт блок второй раз (FR-03.7).
  String? _idempotencyKey;

  Future<void> _create() async {
    final admin = ref.read(currentUserProvider);
    if (admin == null || _complexId == null || _saving) return;
    setState(() => _saving = true);
    _idempotencyKey ??=
        '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}';

    final spec = BulkBlockSpec(
      complexId: _complexId!,
      blockName: _blockName.text.trim(),
      startNumber: _startNumber,
      technicalFloors: _technicalFloors,
      skipNumbers: _skipNumbers,
      idempotencyKey: _idempotencyKey,
      groups: [
        for (final g in _groups)
          FloorGroupSpec(
            floorFrom: g.floorFrom,
            floorTo: g.floorTo,
            roomsPerPosition: g.template,
          ),
      ],
    );

    final created = await runApi(
      context,
      () => ref.read(panoramaRepositoryProvider).bulkCreateBlock(spec, by: admin),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (created == null) return; // ошибку пользователь уже увидел
    _idempotencyKey = null; // успех: следующая отправка будет новой операцией
    ref.invalidate(complexesProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Создано $created квартир в блоке ${spec.blockName}')),
    );
    Navigator.of(context).pop();
  }

  Set<int> _parseSet(String raw) => raw
      .split(RegExp(r'[,\s]+'))
      .map((s) => int.tryParse(s.trim()))
      .whereType<int>()
      .toSet();
}

class _GroupEditor extends StatelessWidget {
  const _GroupEditor({
    required this.index,
    required this.group,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final _GroupDraft group;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  void _showRoomsPicker(BuildContext context, ValueChanged<int> onPick) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Выберите комнатность',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 16),
              for (final (rooms, label) in [
                (0, 'Студия'),
                (1, '1-комнатная'),
                (2, '2-комнатная'),
                (3, '3-комнатная'),
                (4, '4-комнатная'),
              ])
                ListTile(
                  title: Text(label),
                  onTap: () {
                    Navigator.of(context).pop();
                    onPick(rooms);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      boxShadow: AppTheme.shadow,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Группа ${index + 1}', style: AppTextStyles.bodyStrong),
            const Spacer(),
            if (canRemove)
              GestureDetector(
                onTap: onRemove,
                child: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: AppColors.error,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _NumberStepper(
                label: 'Этаж с',
                value: group.floorFrom,
                min: 1,
                onChanged: (v) {
                  group.floorFrom = v;
                  onChanged();
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _NumberStepper(
                label: 'Этаж по',
                value: group.floorTo,
                min: group.floorFrom,
                onChanged: (v) {
                  group.floorTo = v;
                  onChanged();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text('КВАРТИРЫ НА ЭТАЖЕ (по позициям)', style: AppTextStyles.section),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var pos = 0; pos < group.template.length; pos++)
              _PositionChip(
                position: pos + 1,
                rooms: group.template[pos],
                onCycle: () {
                  group.template[pos] = (group.template[pos] + 1) % 5;
                  onChanged();
                },
                onRemove: group.template.length > 1
                    ? () {
                        group.template.removeAt(pos);
                        onChanged();
                      }
                    : null,
              ),
            GestureDetector(
              onTap: () => _showRoomsPicker(context, (rooms) {
                group.template.add(rooms);
                onChanged();
              }),
              child: Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: AppColors.line),
                ),
                child: const Icon(Icons.add, size: 18, color: AppColors.ink2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Нажмите на позицию, чтобы сменить комнатность (Ст → 1 → 2 → 3 → 4).',
          style: TextStyle(fontSize: 11, color: AppColors.ink3),
        ),
      ],
    ),
  );
}

class _PositionChip extends StatelessWidget {
  const _PositionChip({
    required this.position,
    required this.rooms,
    required this.onCycle,
    this.onRemove,
  });

  final int position;
  final int rooms;
  final VoidCallback onCycle;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onCycle,
    onLongPress: onRemove,
    child: Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            rooms == 0 ? 'Ст' : '$roomsк',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.brand,
            ),
          ),
          Text(
            '#$position',
            style: const TextStyle(fontSize: 9, color: AppColors.ink3),
          ),
        ],
      ),
    ),
  );
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.count,
    required this.maxFloor,
    required this.technicalFloors,
    required this.groupFor,
  });

  final int count;
  final int maxFloor;
  final Set<int> technicalFloors;
  final _GroupDraft? Function(int floor) groupFor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      boxShadow: AppTheme.shadow,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'квартир будет создано\nодной транзакцией',
              style: TextStyle(fontSize: 12, height: 1.3, color: AppColors.ink2),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (var floor = maxFloor; floor >= 1; floor--)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 26,
                  child: Text(
                    '$floor',
                    style: const TextStyle(fontSize: 11, color: AppColors.ink3),
                  ),
                ),
                if (technicalFloors.contains(floor))
                  const Text(
                    'технический этаж',
                    style: TextStyle(fontSize: 11, color: AppColors.ink3),
                  )
                else
                  Expanded(
                    child: Wrap(
                      spacing: 4,
                      children: [
                        for (final rooms
                            in groupFor(floor)?.template ?? const <int>[])
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.freeBg,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              rooms == 0 ? 'Ст' : '$roomsк',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.freeInk,
                              ),
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

class _NumberStepper extends StatelessWidget {
  const _NumberStepper({
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
  });

  final String label;
  final int value;
  final int min;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppTextStyles.caption),
      const SizedBox(height: 6),
      Container(
        height: 46,
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            _btn(Icons.remove, () => onChanged((value - 1).clamp(min, 999))),
            Expanded(
              child: Center(
                child: Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),
            _btn(Icons.add, () => onChanged(value + 1)),
          ],
        ),
      ),
    ],
  );

  Widget _btn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: SizedBox(
      width: 40,
      height: 46,
      child: Icon(icon, size: 17, color: AppColors.ink2),
    ),
  );
}

class _MiniField extends StatelessWidget {
  const _MiniField({
    required this.controller,
    required this.label,
    this.hint,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppTextStyles.caption),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        onChanged: onChanged,
        inputFormatters: [
          FilteringTextInputFormatter.deny(RegExp(r'\n')),
        ],
        style: const TextStyle(fontSize: 15, color: AppColors.ink),
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 13.5, color: AppColors.ink3),
          filled: true,
          fillColor: AppColors.bg,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
