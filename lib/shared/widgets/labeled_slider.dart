import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/theme/app_theme.dart';

/// Слайдер в карточке с подписями по краям: слева пояснение,
/// справа текущее значение. Используется в подборе и в форме клиента.
class LabeledSlider extends StatelessWidget {
  const LabeledSlider({
    super.key,
    required this.leading,
    required this.trailing,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
  });

  final String leading;
  final String trailing;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) => Container(
    margin: margin,
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      boxShadow: AppTheme.shadow,
    ),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              leading,
              style: AppTextStyles.secondary.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              trailing,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          activeColor: AppColors.brand,
          onChanged: onChanged,
        ),
      ],
    ),
  );
}
