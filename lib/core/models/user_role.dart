/// Роли пользователей (ТЗ 1.1).
enum UserRole {
  manager('manager', 'Менеджер'),
  admin('admin', 'Администратор'),

  /// Не сотрудник компании: управляет компаниями и их подписками.
  /// Раньше сервер присылал 'superadmin', а перечисление про такую роль не
  /// знало — и суперадминистратор отображался менеджером.
  superadmin('superadmin', 'Суперадминистратор');

  const UserRole(this.wire, this.label);

  final String wire;
  final String label;

  bool get isAdmin => this == UserRole.admin;

  bool get isSuperadmin => this == UserRole.superadmin;

  static UserRole fromWire(String? value) => UserRole.values.firstWhere(
    (r) => r.wire == value,
    orElse: () => UserRole.manager,
  );
}
