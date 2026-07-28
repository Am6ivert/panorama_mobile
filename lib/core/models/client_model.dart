import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'deal_stage.dart';

/// Клиент менеджера (FR-08.1). Показы и брони привязываются к нему,
/// чтобы история не терялась при передаче клиента другому продавцу.
///
/// Денежные поля (бюджет) исключены намеренно (ТЗ 1.3) — запрос клиента
/// описывается только характеристиками.
class ClientModel {
  const ClientModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.sellerId,
    this.sellerName = '',
    this.rooms = 0,
    this.source = '',
    this.request = '',
    this.stage = DealStage.show,
    this.note = '',
    this.nextActionAt,
  });

  final String id;
  final String name;
  final String phone;

  /// Ответственный менеджер (FR-08.1). Данные клиента видны только ему и
  /// администратору (FR-07.3, 5.2).
  final String sellerId;
  final String sellerName;

  /// Сколько комнат ищет: 0 — студия.
  final int rooms;

  /// Источник обращения (реклама, рекомендация, сайт).
  final String source;

  /// Текстовый запрос клиента.
  final String request;

  /// Текущая стадия работы с клиентом.
  final DealStage stage;

  final String note;

  /// Дата следующего действия / напоминания (FR-08.7).
  final DateTime? nextActionAt;

  bool ownedBy(String userId) => sellerId == userId;

  /// Просрочено ли следующее действие.
  bool get actionOverdue =>
      nextActionAt != null && nextActionAt!.isBefore(DateTime.now());

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts[0].characters.first + parts[1].characters.first)
        .toUpperCase();
  }

  Color get color => AppColors.fromSeed(id);

  ClientModel copyWith({
    String? name,
    String? phone,
    String? sellerId,
    String? sellerName,
    int? rooms,
    String? source,
    String? request,
    DealStage? stage,
    String? note,
    DateTime? nextActionAt,
    bool clearNextAction = false,
  }) => ClientModel(
    id: id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    sellerId: sellerId ?? this.sellerId,
    sellerName: sellerName ?? this.sellerName,
    rooms: rooms ?? this.rooms,
    source: source ?? this.source,
    request: request ?? this.request,
    stage: stage ?? this.stage,
    note: note ?? this.note,
    nextActionAt: clearNextAction ? null : (nextActionAt ?? this.nextActionAt),
  );

  factory ClientModel.fromJson(Map<String, dynamic> json) => ClientModel(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    sellerId: json['seller_id'] as String? ?? '',
    sellerName: json['seller_name'] as String? ?? '',
    rooms: (json['rooms'] as num?)?.toInt() ?? 0,
    source: json['source'] as String? ?? '',
    request: json['request'] as String? ?? '',
    stage: DealStage.fromWire(json['stage'] as String?),
    note: json['note'] as String? ?? '',
    nextActionAt: json['next_action_at'] == null
        ? null
        : DateTime.parse(json['next_action_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'seller_id': sellerId,
    'seller_name': sellerName,
    'rooms': rooms,
    'source': source,
    'request': request,
    'stage': stage.wire,
    'note': note,
    'next_action_at': nextActionAt?.toIso8601String(),
  };
}
