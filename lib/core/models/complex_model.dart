import 'package:flutter/material.dart';

/// Блок (подъезд) внутри жилого комплекса (FR-02.2).
class BlockModel {
  const BlockModel({
    required this.name,
    required this.floors,
    required this.unitsPerFloor,
  });

  final String name;
  final int floors;

  /// Сколько квартир на этаже — определяет число колонок в шахматке.
  final int unitsPerFloor;

  factory BlockModel.fromJson(Map<String, dynamic> json) => BlockModel(
    name: json['name'] as String? ?? '',
    floors: (json['floors'] as num?)?.toInt() ?? 0,
    unitsPerFloor: (json['units_per_floor'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'floors': floors,
    'units_per_floor': unitsPerFloor,
  };
}

/// Жилой комплекс (FR-02.1). Денежные поля исключены (ТЗ 1.3).
class ComplexModel {
  const ComplexModel({
    required this.id,
    required this.name,
    required this.address,
    required this.deadline,
    required this.segment,
    required this.blocks,
    this.coverStart = 0xFF1E3A8A,
    this.coverEnd = 0xFF3B82F6,
  });

  final String id;
  final String name;
  final String address;

  /// «сдача 2 кв. 2027» или «сдан».
  final String deadline;

  /// «бизнес», «комфорт», «премиум».
  final String segment;

  final List<BlockModel> blocks;

  /// Пока обложка — градиент. Заменится на фото, когда Panorama даст снимки.
  final int coverStart;
  final int coverEnd;

  Gradient get cover => LinearGradient(
    colors: [Color(coverStart), Color(coverEnd)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  factory ComplexModel.fromJson(Map<String, dynamic> json) => ComplexModel(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    address: json['address'] as String? ?? '',
    deadline: json['deadline'] as String? ?? '',
    segment: json['segment'] as String? ?? '',
    blocks:
        (json['blocks'] as List<dynamic>?)
            ?.map((e) => BlockModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    coverStart: (json['cover_start'] as num?)?.toInt() ?? 0xFF1E3A8A,
    coverEnd: (json['cover_end'] as num?)?.toInt() ?? 0xFF3B82F6,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'deadline': deadline,
    'segment': segment,
    'blocks': blocks.map((e) => e.toJson()).toList(),
    'cover_start': coverStart,
    'cover_end': coverEnd,
  };
}
