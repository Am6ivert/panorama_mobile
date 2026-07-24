import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppTextStyles {
  static const h1 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: AppColors.ink,
  );

  static const h2 = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    color: AppColors.ink,
  );

  static const title = TextStyle(
    fontSize: 16.5,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    color: AppColors.ink,
  );

  static const body = TextStyle(fontSize: 14, color: AppColors.ink);

  static const bodyStrong = TextStyle(
    fontSize: 14.5,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );

  static const secondary = TextStyle(fontSize: 13, color: AppColors.ink2);

  static const caption = TextStyle(fontSize: 11.5, color: AppColors.ink3);

  /// Заголовок секции: «МОИ ОБЪЕКТЫ»
  static const section = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
    color: AppColors.ink2,
  );

  static const price = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.8,
    color: AppColors.ink,
  );

  static const onDarkTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: Colors.white,
  );

  static const onDarkSub = TextStyle(
    fontSize: 12.5,
    color: AppColors.onDarkSub,
  );
}
