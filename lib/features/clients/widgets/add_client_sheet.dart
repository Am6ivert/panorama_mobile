import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/client_model.dart';
import '../../../core/providers/data_providers.dart';
import '../../../shared/widgets/choice_chip_bar.dart';

/// Форма нового клиента (FR-07.1, FR-08.1). Возвращает заведённую карточку или
/// `null`, если менеджер закрыл окно. Денежных полей нет (ТЗ 1.3).
Future<ClientModel?> addClient(BuildContext context) =>
    showModalBottomSheet<ClientModel>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const AddClientSheet(),
    );

class AddClientSheet extends ConsumerStatefulWidget {
  const AddClientSheet({super.key});

  @override
  ConsumerState<AddClientSheet> createState() => _AddClientSheetState();
}

class _AddClientSheetState extends ConsumerState<AddClientSheet> {
  static const _roomLabels = ['Студия', '1к', '2к', '3к', '4к'];
  static const _sources = [
    'Реклама Instagram',
    'Рекомендация',
    'Сайт',
    'Реклама 2ГИС',
    'Звонок',
  ];

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _request = TextEditingController();
  final _customRooms = TextEditingController();

  Set<int> _selectedRooms = {2};
  String? _source;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _request.dispose();
    _customRooms.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
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
              const Text('Новый клиент', style: AppTextStyles.h1),
              const SizedBox(height: 4),
              const Text(
                'Запрос сохранится, подбор сразу покажет, что ему подходит',
                style: AppTextStyles.secondary,
              ),
              const SizedBox(height: 18),
              _Field(
                controller: _name,
                label: 'Имя и фамилия',
                hint: 'Айбек Сыдыков',
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Без имени карточку не найти'
                    : null,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _phone,
                label: 'Телефон',
                hint: '0555 41-20-08',
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-() ]')),
                ],
                validator: _validatePhone,
              ),
              const SizedBox(height: 18),
              const Text('ЧТО ИЩЕТ (можно выбрать несколько)', style: AppTextStyles.section),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < _roomLabels.length; i++)
                    FilterChip(
                      label: Text(_roomLabels[i]),
                      selected: _selectedRooms.contains(i),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedRooms.add(i);
                          } else {
                            _selectedRooms.remove(i);
                          }
                        });
                      },
                      selectedColor: AppColors.brand.withValues(alpha: 0.2),
                      checkmarkColor: AppColors.brand,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              _Field(
                controller: _customRooms,
                label: 'Или укажите свой вариант',
                hint: 'Например: пентхаус, таунхаус',
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 18),
              const Text('ИСТОЧНИК (необязательно)', style: AppTextStyles.section),
              const SizedBox(height: 10),
              ChoiceChipBar<String?>(
                padding: EdgeInsets.zero,
                options: [
                  ChipOption(value: null, label: 'Не указано'),
                  for (final s in _sources) ChipOption(value: s, label: s),
                ],
                isSelected: (value) => value == _source,
                onTap: (value) => setState(() => _source = value),
              ),
              const SizedBox(height: 18),
              _Field(
                controller: _request,
                label: 'Запрос клиента (необязательно)',
                hint: 'Важен вид на горы, не выше 8 этажа',
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
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
                    : const Text('Сохранить клиента'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  String? _validatePhone(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 'Укажите телефон — по нему ищут клиента';
    if (digits.length < 9) return 'Похоже, номер неполный';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final seller = ref.read(currentUserProvider);
    if (seller == null) return;
    setState(() => _saving = true);

    try {
      // Формируем строку запроса: выбранные комнаты + кастомный текст
      final roomsText = _selectedRooms.isEmpty
          ? ''
          : _selectedRooms.map((i) => _roomLabels[i]).join(', ');
      final custom = _customRooms.text.trim();
      final requestText = [
        if (roomsText.isNotEmpty) roomsText,
        if (custom.isNotEmpty) custom,
        if (_request.text.trim().isNotEmpty) _request.text.trim(),
      ].join(' · ');

      final client = await ref
          .read(panoramaRepositoryProvider)
          .addClient(
            name: _name.text.trim(),
            phone: _phone.text.trim(),
            seller: seller,
            rooms: _selectedRooms.isEmpty ? 0 : _selectedRooms.first,
            source: _source ?? '',
            request: requestText,
          );
      ref.invalidate(clientsProvider);
      if (mounted) Navigator.of(context).pop(client);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Не удалось сохранить: $e')));
    }
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    validator: validator,
    keyboardType: keyboardType,
    inputFormatters: inputFormatters,
    maxLines: maxLines,
    textCapitalization: textCapitalization,
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
      focusedErrorBorder: _border(AppColors.error),
    ),
  );

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(13),
    borderSide: BorderSide(color: color),
  );
}
