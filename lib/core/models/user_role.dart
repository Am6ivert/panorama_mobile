/// Роли пользователей (ТЗ 1.1).
enum UserRole {
  manager('manager', 'Менеджер'),
  admin('admin', 'Администратор');

  const UserRole(this.wire, this.label);

  final String wire;
  final String label;

  bool get isAdmin => this == UserRole.admin;

  static UserRole fromWire(String? value) => UserRole.values.firstWhere(
    (r) => r.wire == value,
    orElse: () => UserRole.manager,
  );
}
