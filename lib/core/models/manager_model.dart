import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class ManagerModel {
  const ManagerModel({
    required this.id,
    required this.name,
    required this.phone,
  });

  final String id;
  final String name;
  final String phone;

  /// «Азамат Кубанычбеков» -> «АК»
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts[0].characters.first + parts[1].characters.first)
        .toUpperCase();
  }

  /// «Азамат Кубанычбеков» -> «Азамат К.»
  String get shortName {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first;
    return '${parts[0]} ${parts[1].characters.first}.';
  }

  Color get color => AppColors.fromSeed(id);

  factory ManagerModel.fromJson(Map<String, dynamic> json) => ManagerModel(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'phone': phone};
}
