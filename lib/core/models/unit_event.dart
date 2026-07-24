import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum UnitEventKind {
  taken('taken'),
  released('released'),
  booked('booked'),
  sold('sold'),
  shared('shared');

  const UnitEventKind(this.wire);
  final String wire;

  static UnitEventKind fromWire(String? value) => UnitEventKind.values
      .firstWhere((k) => k.wire == value, orElse: () => UnitEventKind.taken);

  Color get color => switch (this) {
    UnitEventKind.taken => AppColors.work,
    UnitEventKind.released => AppColors.free,
    UnitEventKind.booked => AppColors.hold,
    UnitEventKind.sold => AppColors.sold,
    UnitEventKind.shared => AppColors.brand,
  };
}

/// Запись в истории квартиры: кто, когда и что с ней делал.
class UnitEvent {
  const UnitEvent({
    required this.kind,
    required this.title,
    required this.authorName,
    required this.at,
  });

  final UnitEventKind kind;
  final String title;
  final String authorName;
  final DateTime at;

  factory UnitEvent.fromJson(Map<String, dynamic> json) => UnitEvent(
    kind: UnitEventKind.fromWire(json['kind'] as String?),
    title: json['title'] as String? ?? '',
    authorName: json['author_name'] as String? ?? '',
    at: DateTime.parse(json['at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'kind': kind.wire,
    'title': title,
    'author_name': authorName,
    'at': at.toIso8601String(),
  };
}
