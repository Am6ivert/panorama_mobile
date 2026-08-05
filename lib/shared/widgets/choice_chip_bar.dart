import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class ChipOption<T> {
  const ChipOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// Горизонтальная лента чипов-фильтров.
class ChoiceChipBar<T> extends StatelessWidget {
  const ChoiceChipBar({
    super.key,
    required this.options,
    required this.isSelected,
    required this.onTap,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final List<ChipOption<T>> options;
  final bool Function(T value) isSelected;
  final void Function(T value) onTap;

  /// Дополнительный чип в конце ленты — например «Только свободные».
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: padding,
    child: Row(
      children: [
        for (final option in options) ...[
          AppChip(
            label: option.label,
            selected: isSelected(option.value),
            onTap: () => onTap(option.value),
          ),
          const SizedBox(width: 8),
        ],
        ?trailing,
      ],
    ),
  );
}

class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.dashed = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool dashed;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.brand
            : (dashed ? Colors.transparent : AppColors.surface),
        border: Border.all(
          color: selected ? AppColors.brand : AppColors.line,
        ),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: selected ? Colors.white : AppColors.ink2,
        ),
      ),
    ),
  );
}
