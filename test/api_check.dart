// Интеграционная проверка ApiPanoramaRepository против ЖИВОГО backend.
// Требует запущенный сервер (dart run bin/server.dart) и накатанную БД.
// Запуск: flutter test test/api_check.dart
// Не оканчивается на _test.dart, поэтому обычный `flutter test` его пропускает.
import 'package:flutter_test/flutter_test.dart';

import 'package:panorama_sales/core/data/api_panorama_repository.dart';
import 'package:panorama_sales/core/data/panorama_repository.dart';
import 'package:panorama_sales/core/models/unit_status.dart';
import 'package:panorama_sales/core/models/user_role.dart';
import 'package:panorama_sales/core/network/api_client.dart';

void main() {
  final repo = ApiPanoramaRepository(ApiClient('http://localhost:8080/api/v1'));

  test('вход, роль и токен', () async {
    final res = await repo.login(login: 'admin', password: '0000');
    expect(res, isA<LoginOk>());
    expect((res as LoginOk).user.role, UserRole.admin);

    final bad = await repo.login(login: 'admin', password: 'wrong');
    expect(bad, isA<LoginFailed>());
    expect((bad as LoginFailed).message, contains('пароль'));
  });

  test('справочники и фонд читаются', () async {
    final users = await repo.fetchUsers();
    expect(users.length, greaterThanOrEqualTo(5));
    final complexes = await repo.fetchComplexes();
    expect(complexes, isNotEmpty);
    expect(complexes.first.blocks, isNotEmpty);
    final units = await repo.fetchUnits();
    expect(units.length, greaterThan(50));
    expect(units.first.area, greaterThan(0));
  });

  test('take → book → release с историей', () async {
    final manager =
        (await repo.fetchUsers()).firstWhere((u) => u.role == UserRole.manager);
    final free = (await repo.fetchUnits())
        .firstWhere((u) => u.status == UnitStatus.free);

    final worked = await repo.takeToWork(unitId: free.id, manager: manager);
    expect(worked.status, UnitStatus.work);
    expect(worked.history, isNotEmpty);

    final booked = await repo.book(unitId: free.id, manager: manager);
    expect(booked.status, UnitStatus.hold);

    final released = await repo.release(unitId: free.id, manager: manager);
    expect(released.status, UnitStatus.free);
    expect(released.heldById, isNull);
  });

  test('уведомления доходят другому менеджеру', () async {
    final managers = (await repo.fetchUsers())
        .where((u) => u.role == UserRole.manager)
        .toList();
    final free = (await repo.fetchUnits())
        .firstWhere((u) => u.status == UnitStatus.free);
    await repo.book(unitId: free.id, manager: managers.first);

    final notes = await repo.fetchNotifications(managers[1].id);
    expect(notes.any((n) => n.title.contains('забронирована')), isTrue);

    await repo.release(unitId: free.id, manager: managers.first);
  });
}
