import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Стадии сделки (FR-08.3): Показ → Переговоры → Бронь → Оформление →
/// Завершена / Отказ.
enum DealStage {
  show('show', 'Показ'),
  negotiation('negotiation', 'Переговоры'),
  booking('booking', 'Бронь'),
  design('design', 'Оформление'),
  done('done', 'Завершена'),
  rejected('rejected', 'Отказ');

  const DealStage(this.wire, this.label);

  final String wire;
  final String label;

  /// Сделка ещё в работе (не завершена и не отклонена).
  bool get isActive => this != DealStage.done && this != DealStage.rejected;

  static DealStage fromWire(String? value) => DealStage.values.firstWhere(
    (s) => s.wire == value,
    orElse: () => DealStage.show,
  );

  Color get color => switch (this) {
    DealStage.show => AppColors.work,
    DealStage.negotiation => AppColors.brand,
    DealStage.booking => AppColors.hold,
    DealStage.design => AppColors.design,
    DealStage.done => AppColors.free,
    DealStage.rejected => AppColors.offMarket,
  };
}
