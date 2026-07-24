import 'package:flutter/material.dart';

/// Палитра приложения. Светлая тема — менеджеры работают на объекте,
/// часто при ярком дневном свете.
abstract final class AppColors {
  static const brand = Color(0xFF1B63E3);
  static const brandDark = Color(0xFF0F172A);
  static const brandGradientTop = Color(0xFF153A8A);

  static const bg = Color(0xFFF4F6FA);
  static const surface = Color(0xFFFFFFFF);
  static const line = Color(0xFFE6EAF2);

  static const ink = Color(0xFF0F172A);
  static const ink2 = Color(0xFF5B6778);
  static const ink3 = Color(0xFF98A2B3);
  static const onDarkSub = Color(0xFF9FB2D8);

  static const error = Color(0xFFEF4444);

  // Статусы квартир
  static const free = Color(0xFF10B981);
  static const freeBg = Color(0xFFE7F8F1);
  static const freeBorder = Color(0xFFBFEBDB);
  static const freeInk = Color(0xFF065F46);

  static const work = Color(0xFF7C3AED);
  static const workBg = Color(0xFFF1EBFE);
  static const workBorder = Color(0xFFDBCDFB);
  static const workInk = Color(0xFF5B21B6);

  static const hold = Color(0xFFF59E0B);
  static const holdBg = Color(0xFFFEF4E2);
  static const holdBorder = Color(0xFFF6DFB4);
  static const holdInk = Color(0xFF92400E);

  static const sold = Color(0xFFA3AEC0);
  static const soldBg = Color(0xFFEFF1F5);
  static const soldBorder = Color(0xFFE1E5EC);
  static const soldInk = Color(0xFF7A879B);

  /// Цвета аватарок менеджеров и клиентов.
  static const palette = <Color>[
    Color(0xFF1B63E3),
    Color(0xFFEC4899),
    Color(0xFF0891B2),
    Color(0xFF65A30D),
    Color(0xFF7C3AED),
    Color(0xFFF97316),
  ];

  static Color fromSeed(String seed) {
    var hash = 0;
    for (final code in seed.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return palette[hash % palette.length];
  }
}
