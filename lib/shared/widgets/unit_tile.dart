import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/models/unit_model.dart';
import '../../core/theme/app_theme.dart';

/// Строка со квартирой — используется в подборе, сделках и карточке клиента.
class UnitTile extends StatelessWidget {
  const UnitTile({
    super.key,
    required this.unit,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final UnitModel unit;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.shadow,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: unit.status.background,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              unit.shortLayout,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: unit.status.foreground,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyStrong),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.ink2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(unit.priceUsd, style: AppTextStyles.bodyStrong),
              const SizedBox(height: 1),
              Text(
                unit.priceKgs,
                style: const TextStyle(fontSize: 10.5, color: AppColors.ink3),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 46),
    child: Column(
      children: [
        Icon(icon, size: 36, color: AppColors.ink3),
        const SizedBox(height: 10),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: AppColors.ink3,
          ),
        ),
      ],
    ),
  );
}
