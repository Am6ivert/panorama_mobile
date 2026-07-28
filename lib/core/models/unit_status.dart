import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Статус квартиры в шахматке (FR-06).
///
/// [work] — ключевой для компании: менеджер помечает квартиру перед выездом,
/// и остальные сразу видят, что её показывают, и не продают повторно.
enum UnitStatus {
  free('free', 'Свободна'),
  work('work', 'В работе'),
  hold('hold', 'Бронь'),
  design('design', 'Оформление'),
  sold('sold', 'Продана'),
  offMarket('off_market', 'Не для продажи');

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
    UnitStatus.design => AppColors.design,
    UnitStatus.sold => AppColors.sold,
    UnitStatus.offMarket => AppColors.offMarket,
  };

  Color get background => switch (this) {
    UnitStatus.free => AppColors.freeBg,
    UnitStatus.work => AppColors.workBg,
    UnitStatus.hold => AppColors.holdBg,
    UnitStatus.design => AppColors.designBg,
    UnitStatus.sold => AppColors.soldBg,
    UnitStatus.offMarket => AppColors.offMarketBg,
  };

  Color get border => switch (this) {
    UnitStatus.free => AppColors.freeBorder,
    UnitStatus.work => AppColors.workBorder,
    UnitStatus.hold => AppColors.holdBorder,
    UnitStatus.design => AppColors.designBorder,
    UnitStatus.sold => AppColors.soldBorder,
    UnitStatus.offMarket => AppColors.offMarketBorder,
  };

  Color get foreground => switch (this) {
    UnitStatus.free => AppColors.freeInk,
    UnitStatus.work => AppColors.workInk,
    UnitStatus.hold => AppColors.holdInk,
    UnitStatus.design => AppColors.designInk,
    UnitStatus.sold => AppColors.soldInk,
    UnitStatus.offMarket => AppColors.offMarketInk,
  };

  /// Можно ли начать работу с квартирой.
  bool get isAvailable => this == UnitStatus.free;

  /// Занята кем-то — в шахматке показываем инициалы менеджера.
  bool get isTaken =>
      this == UnitStatus.work ||
      this == UnitStatus.hold ||
      this == UnitStatus.design;

  /// Техпомещение / снята с продажи — рисуем штриховкой.
  bool get isOffMarket => this == UnitStatus.offMarket;
}
