import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/providers/data_providers.dart';
import 'global_navigation.dart';

/// Тёмная шапка экрана. Градиент — на верхнеуровневых вкладках,
/// плоский цвет — на внутренних экранах с кнопкой «назад».
class AppHeader extends ConsumerWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.gradient = true,
    this.onBack,
    this.trailing,
    this.bottom,
    this.showNavigation = true,
  });

  final String title;
  final String? subtitle;
  final bool gradient;
  final VoidCallback? onBack;
  final Widget? trailing;
  final Widget? bottom;
  final bool showNavigation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titleStyle = onBack == null
        ? AppTextStyles.onDarkTitle
        : AppTextStyles.onDarkTitle.copyWith(fontSize: 17);

    final user = ref.watch(currentUserProvider);
    final effectiveTrailing = trailing ??
        (showNavigation && user != null ? const GlobalNavigation() : null);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 14,
        16,
        16,
      ),
      decoration: BoxDecoration(
        color: gradient ? null : AppColors.brandDark,
        gradient: gradient
            ? const LinearGradient(
                colors: [AppColors.brandGradientTop, AppColors.brandDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (onBack != null) ...[
                _BackButton(onTap: onBack!),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: titleStyle),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(subtitle!, style: AppTextStyles.onDarkSub),
                    ],
                  ],
                ),
              ),
              ?effectiveTrailing,
            ],
          ),
          if (bottom != null) ...[const SizedBox(height: 13), bottom!],
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(11),
      ),
      child: const Icon(Icons.arrow_back_ios_new, size: 15, color: Colors.white),
    ),
  );
}

/// Индикатор живых данных под заголовком.
class LiveIndicator extends StatelessWidget {
  const LiveIndicator({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: AppColors.free,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 7),
      Text(
        text,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF8FE3C4),
        ),
      ),
    ],
  );
}
