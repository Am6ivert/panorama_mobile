import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Клиент менеджера. Показы и брони привязываются к нему,
/// чтобы история не терялась при передаче клиента другому продажнику.
class ClientModel {
  const ClientModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.rooms,
    required this.budget,
    this.note = '',
  });

  final String id;
  final String name;
  final String phone;

  /// Сколько комнат ищет: 0 — студия.
  final int rooms;

  /// Бюджет в долларах.
  final int budget;
  final String note;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts[0].characters.first + parts[1].characters.first)
        .toUpperCase();
  }

  Color get color => AppColors.fromSeed(id);

  factory ClientModel.fromJson(Map<String, dynamic> json) => ClientModel(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    rooms: (json['rooms'] as num?)?.toInt() ?? 0,
    budget: (json['budget'] as num?)?.toInt() ?? 0,
    note: json['note'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'rooms': rooms,
    'budget': budget,
    'note': note,
  };
}
