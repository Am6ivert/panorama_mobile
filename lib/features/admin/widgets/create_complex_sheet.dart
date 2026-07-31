import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/complex_model.dart';
import '../../../core/providers/data_providers.dart';
import '../../../shared/widgets/choice_chip_bar.dart';

/// Форма нового объекта (ЖК) — FR-02.1. Возвращает созданный объект или null.
Future<ComplexModel?> createComplexSheet(BuildContext context) =>
    showModalBottomSheet<ComplexModel>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _CreateComplexSheet(),
    );

class _CreateComplexSheet extends ConsumerStatefulWidget {
  const _CreateComplexSheet();

  @override
  ConsumerState<_CreateComplexSheet> createState() =>
      _CreateComplexSheetState();
}

class _CreateComplexSheetState extends ConsumerState<_CreateComplexSheet> {
  static const _segments = ['бизнес', 'комфорт', 'премиум'];

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _deadline = TextEditingController(text: 'сдача 4 кв. 2027');
  String _segment = 'комфорт';
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _deadline.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        18,
        6,
        18,
        18 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Новый объект', style: AppTextStyles.h1),
            const SizedBox(height: 4),
            const Text(
              'Создайте ЖК, затем добавьте в него блоки мастером создания',
              style: AppTextStyles.secondary,
            ),
            const SizedBox(height: 18),
            _field(_name, 'Название', 'Панорама Гарден',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Укажите название' : null),
            const SizedBox(height: 12),
            _field(_address, 'Адрес', 'ул. Ибраимова, 42'),
            const SizedBox(height: 12),
            _field(_deadline, 'Срок сдачи', 'сдача 4 кв. 2027'),
            const SizedBox(height: 18),
            const Text('СЕГМЕНТ', style: AppTextStyles.section),
            const SizedBox(height: 10),
            ChoiceChipBar<String>(
              padding: EdgeInsets.zero,
              options: [for (final s in _segments) ChipOption(value: s, label: s)],
              isSelected: (v) => v == _segment,
              onTap: (v) => setState(() => _segment = v),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Создать объект'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _field(
    TextEditingController c,
    String label,
    String hint, {
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: c,
    validator: validator,
    textCapitalization: TextCapitalization.sentences,
    style: AppTextStyles.body,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: AppTextStyles.secondary,
      hintStyle: const TextStyle(fontSize: 14, color: AppColors.ink3),
      filled: true,
      fillColor: AppColors.bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: _border(AppColors.line),
      enabledBorder: _border(AppColors.line),
      focusedBorder: _border(AppColors.brand),
      errorBorder: _border(AppColors.error),
    ),
  );

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(13),
    borderSide: BorderSide(color: color),
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final by = ref.read(currentUserProvider);
    if (by == null) return;
    setState(() => _saving = true);
    final complex = await ref.read(panoramaRepositoryProvider).createComplex(
          name: _name.text.trim(),
          address: _address.text.trim(),
          deadline: _deadline.text.trim(),
          segment: _segment,
          by: by,
        );
    ref.invalidate(complexesProvider);
    if (mounted) Navigator.of(context).pop(complex);
  }
}
