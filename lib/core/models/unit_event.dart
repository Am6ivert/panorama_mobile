import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum UnitEventKind {
  taken('taken'),
  released('released'),
  booked('booked'),
  extended('extended'),
  design('design'),
  sold('sold'),
  offMarket('off_market'),
  edited('edited'),
  shared('shared');

  const UnitEventKind(this.wire);
  final String wire;

  static UnitEventKind fromWire(String? value) => UnitEventKind.values
      .firstWhere((k) => k.wire == value, orElse: () => UnitEventKind.taken);

  Color get color => switch (this) {
    UnitEventKind.taken => AppColors.work,
    UnitEventKind.released => AppColors.free,
    UnitEventKind.booked => AppColors.hold,
    UnitEventKind.extended => AppColors.hold,
    UnitEventKind.design => AppColors.design,
    UnitEventKind.sold => AppColors.sold,
    UnitEventKind.offMarket => AppColors.offMarket,
    UnitEventKind.edited => AppColors.ink3,
    UnitEventKind.shared => AppColors.brand,
  };
}

/// Запись в истории квартиры: кто, когда и что с ней делал (FR-06.3).
class UnitEvent {
  const UnitEvent({
    required this.kind,
    required this.title,
    required this.authorName,
    required this.at,
    this.clientName,
  });

  final UnitEventKind kind;
  final String title;
  final String authorName;
  final DateTime at;
  final String? clientName;

  factory UnitEvent.fromJson(Map<String, dynamic> json) => UnitEvent(
    kind: UnitEventKind.fromWire(json['kind'] as String?),
    title: json['title'] as String? ?? '',
    authorName: json['author_name'] as String? ?? '',
    at: DateTime.parse(json['at'] as String),
    clientName: json['client_name'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'kind': kind.wire,
    'title': title,
    'author_name': authorName,
    'at': at.toIso8601String(),
    'client_name': clientName,
  };
}
