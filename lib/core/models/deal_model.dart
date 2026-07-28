import 'deal_stage.dart';

/// Сделка связывает клиента, квартиру и менеджера (FR-08.3).
/// Не более одной активной сделки на квартиру (FR-08.4).
class DealModel {
  const DealModel({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.unitId,
    required this.unitLabel,
    required this.sellerId,
    required this.sellerName,
    required this.stage,
    required this.createdAt,
    this.nextActionAt,
  });

  final String id;
  final String clientId;
  final String clientName;
  final String unitId;

  /// «Панорама Сити · А · №14» — для списков без загрузки квартиры.
  final String unitLabel;
  final String sellerId;
  final String sellerName;
  final DealStage stage;
  final DateTime createdAt;
  final DateTime? nextActionAt;

  bool get isActive => stage.isActive;

  bool get actionOverdue =>
      nextActionAt != null && nextActionAt!.isBefore(DateTime.now());

  DealModel copyWith({DealStage? stage, DateTime? nextActionAt}) => DealModel(
    id: id,
    clientId: clientId,
    clientName: clientName,
    unitId: unitId,
    unitLabel: unitLabel,
    sellerId: sellerId,
    sellerName: sellerName,
    stage: stage ?? this.stage,
    createdAt: createdAt,
    nextActionAt: nextActionAt ?? this.nextActionAt,
  );
}
