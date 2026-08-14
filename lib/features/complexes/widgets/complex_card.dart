import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/complex_model.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/theme/app_theme.dart';

class ComplexCard extends StatelessWidget {
  const ComplexCard({
    super.key,
    required this.complex,
    required this.stats,
    required this.onTap,
  });

  final ComplexModel complex;
  final UnitStats stats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        boxShadow: AppTheme.shadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Cover(complex: complex),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(complex.name, style: AppTextStyles.title),
                const SizedBox(height: 3),
                Text(
                  '${complex.address} · ${stats.sellable} квартир',
                  style: AppTextStyles.secondary,
                ),
                const SizedBox(height: 11),
                const Divider(height: 1, color: AppColors.line),
                const SizedBox(height: 11),
                Row(
                  children: [
                    _Stat(
                      color: AppColors.free,
                      value: stats.free,
                      label: 'свободно',
                    ),
                    _Stat(
                      color: AppColors.work,
                      value: stats.work + stats.hold,
                      label: 'в работе',
                    ),
                    _Stat(
                      color: AppColors.design,
                      value: stats.design,
                      label: 'оформление',
                    ),
                    _Stat(
                      color: AppColors.sold,
                      value: stats.sold,
                      label: 'продано',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Cover extends StatelessWidget {
  const _Cover({required this.complex});

  final ComplexModel complex;

  @override
  Widget build(BuildContext context) => Container(
    height: 118,
    width: double.infinity,
    decoration: BoxDecoration(gradient: complex.cover),
    child: Stack(
      children: [
        Positioned(
          left: 12,
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.93),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${complex.segment} · ${complex.deadline}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.color, required this.value, required this.label});

  final Color color;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: const TextStyle(fontSize: 10.5, color: AppColors.ink3),
        ),
      ],
    ),
  );
}
