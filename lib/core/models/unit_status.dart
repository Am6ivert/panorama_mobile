import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Статус квартиры в шахматке.
///
/// [work] — ключевой для компании: менеджер помечает квартиру перед выездом,
/// и остальные сразу видят, что её показывают, и не продают повторно.
enum UnitStatus {
  free('free', 'Свободна'),
  work('work', 'В работе'),
  hold('hold', 'Бронь'),
  sold('sold', 'Продана');

  const UnitStatus(this.wire, this.label);

  /// Значение, в котором статус ездит по API.
  final String wire;
  final String label;

  static UnitStatus fromWire(String? value) => UnitStatus.values.firstWhere(
    (s) => s.wire == value,
    orElse: () => UnitStatus.free,
  );

  Color get color => switch (this) {
    UnitStatus.free => AppColors.free,
    UnitStatus.work => AppColors.work,
    UnitStatus.hold => AppColors.hold,
    UnitStatus.sold => AppColors.sold,
  };

  Color get background => switch (this) {
    UnitStatus.free => AppColors.freeBg,
    UnitStatus.work => AppColors.workBg,
    UnitStatus.hold => AppColors.holdBg,
    UnitStatus.sold => AppColors.soldBg,
  };

  Color get border => switch (this) {
    UnitStatus.free => AppColors.freeBorder,
    UnitStatus.work => AppColors.workBorder,
    UnitStatus.hold => AppColors.holdBorder,
    UnitStatus.sold => AppColors.soldBorder,
  };

  Color get foreground => switch (this) {
    UnitStatus.free => AppColors.freeInk,
    UnitStatus.work => AppColors.workInk,
    UnitStatus.hold => AppColors.holdInk,
    UnitStatus.sold => AppColors.soldInk,
  };

  /// Можно ли начать работу с квартирой.
  bool get isAvailable => this == UnitStatus.free;

  /// Занята кем-то — в шахматке показываем инициалы менеджера.
  bool get isTaken => this == UnitStatus.work || this == UnitStatus.hold;
}
