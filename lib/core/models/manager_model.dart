import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'user_role.dart';

/// Пользователь системы: продавец (менеджер) или администратор.
///
/// Держатели квартир (held_by) — это те же пользователи, поэтому единая
/// модель, а не отдельная сущность.
class ManagerModel {
  const ManagerModel({
    required this.id,
    required this.name,
    required this.login,
    required this.phone,
    this.role = UserRole.manager,
    this.blocked = false,
    this.mustChangePassword = false,
  });

  final String id;
  final String name;

  /// Логин для входа (FR-01.1). Телефон остаётся для SMS и связи.
  final String login;
  final String phone;
  final UserRole role;

  /// Учётная запись заблокирована администратором (FR-01.5).
  final bool blocked;

  /// Требуется смена временного пароля при первом входе (FR-01.3).
  final bool mustChangePassword;

  bool get isAdmin => role.isAdmin;

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

  ManagerModel copyWith({
    String? name,
    String? login,
    String? phone,
    UserRole? role,
    bool? blocked,
    bool? mustChangePassword,
  }) => ManagerModel(
    id: id,
    name: name ?? this.name,
    login: login ?? this.login,
    phone: phone ?? this.phone,
    role: role ?? this.role,
    blocked: blocked ?? this.blocked,
    mustChangePassword: mustChangePassword ?? this.mustChangePassword,
  );

  factory ManagerModel.fromJson(Map<String, dynamic> json) => ManagerModel(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    login: json['login'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    role: UserRole.fromWire(json['role'] as String?),
    blocked: json['blocked'] as bool? ?? false,
    mustChangePassword: json['must_change_password'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'login': login,
    'phone': phone,
    'role': role.wire,
    'blocked': blocked,
    'must_change_password': mustChangePassword,
  };
}
