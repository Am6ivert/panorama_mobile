import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

abstract final class AppTheme {
  static const radius = 16.0;
  static const radiusSmall = 12.0;

  static final shadow = <BoxShadow>[
    const BoxShadow(
      color: Color(0x0D101828),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
    const BoxShadow(
      color: Color(0x0F101828),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      surface: AppColors.surface,
    ),
    dividerColor: AppColors.line,
    textTheme: const TextTheme(
      titleLarge: AppTextStyles.h1,
      titleMedium: AppTextStyles.title,
      bodyMedium: AppTextStyles.body,
      bodySmall: AppTextStyles.secondary,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.brand,
        minimumSize: const Size.fromHeight(50),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
        ),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.brandDark,
      contentTextStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
      ),
    ),
  );
}
