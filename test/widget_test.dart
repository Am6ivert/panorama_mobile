import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:panorama_sales/core/data/mock_panorama_repository.dart';
import 'package:panorama_sales/core/data/panorama_repository.dart';
import 'package:panorama_sales/core/models/client_model.dart';
import 'package:panorama_sales/core/models/manager_model.dart';
import 'package:panorama_sales/core/models/unit_status.dart';
import 'package:panorama_sales/core/models/user_role.dart';
import 'package:panorama_sales/core/providers/data_providers.dart';
import 'package:panorama_sales/main.dart';

/// Сколько квартир менеджер держит в работе, брони или оформлении.
Future<int> _dealsOf(PanoramaRepository repository, String managerId) async =>
    (await repository.fetchUnits())
        .where((u) => u.heldById == managerId && u.status.isTaken)
        .length;

void main() {
  late PanoramaRepository repository;

  ProviderScope app() => ProviderScope(
    overrides: [panoramaRepositoryProvider.overrideWithValue(repository)],
    child: const PanoramaApp(),
  );

  setUp(() => repository = MockPanoramaRepository(enableBackgroundTimers: false));
  tearDown(() => repository.dispose());

  testWidgets('вход по телефону и паролю ведёт на дашборд', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Войти'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'azamat');
    await tester.enterText(find.byType(TextField).at(1), '0000');
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();

    expect(find.text('Дашборд'), findsWidgets);
    expect(find.text('ФОНД ПО СТАТУСАМ'), findsOneWidget);
  });

  testWidgets('неверный пароль не пускает в приложение', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'azamat');
    await tester.enterText(find.byType(TextField).at(1), 'wrong');
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();

    expect(find.text('Неверный пароль'), findsOneWidget);
    expect(find.text('Фонд по статусам'), findsNothing);
  });

  test('вход администратора по логину распознаёт роль', () async {
    final result = await repository.login(login: 'admin', password: '0000');
    expect(result, isA<LoginOk>());
    expect((result as LoginOk).user.role, UserRole.admin);
  });

  test('взятие в работу требует клиента и закрепляет квартиру', () async {
    final manager = (await repository.fetchUsers())
        .firstWhere((u) => u.role == UserRole.manager);
    final before = await _dealsOf(repository, manager.id);

    final client = (await repository.fetchClients())
        .firstWhere((c) => c.sellerId == manager.id);
    final free = (await repository.fetchUnits())
        .firstWhere((u) => u.status == UnitStatus.free);

    final updated = await repository.takeToWork(
      unitId: free.id,
      manager: manager,
      client: client,
    );

    expect(updated.status, UnitStatus.work);
    expect(updated.heldById, manager.id);
    expect(updated.clientId, client.id);
    expect(await _dealsOf(repository, manager.id), before + 1);
  });

  test('бронь ставится на 3 дня и уведомляет всю команду, кроме автора', () async {
    final users = await repository.fetchUsers();
    final manager = users.firstWhere((u) => u.role == UserRole.manager);
    final admin = users.firstWhere((u) => u.isAdmin);
    final otherManager = users.firstWhere(
      (u) => u.role == UserRole.manager && u.id != manager.id,
    );
    final client = (await repository.fetchClients())
        .firstWhere((c) => c.sellerId == manager.id);
    final free = (await repository.fetchUnits())
        .firstWhere((u) => u.status == UnitStatus.free);

    final booked = await repository.book(
      unitId: free.id,
      manager: manager,
      client: client,
    );

    expect(booked.status, UnitStatus.hold);
    final days = booked.heldUntil!.difference(DateTime.now()).inHours;
    expect(days, greaterThan(60)); // ~72 часа
    expect(days, lessThanOrEqualTo(72));

    // Уведомление о брони приходит и администратору, и другому менеджеру,
    // но не автору брони (FR-11.1, FR-11.10 — без данных клиента).
    bool booking(n) => n.unitId == free.id && n.title.contains('забронирована');
    expect((await repository.fetchNotifications(admin.id)).any(booking), isTrue);
    expect(
      (await repository.fetchNotifications(otherManager.id)).any(booking),
      isTrue,
    );
    final own = await repository.fetchNotifications(manager.id);
    expect(own.any(booking), isFalse);
    // Данные клиента в теле уведомления не раскрываются.
    final note = (await repository.fetchNotifications(otherManager.id))
        .firstWhere(booking);
    expect(note.body.contains(client.name), isFalse);
  });

  test('оформление и подтверждение продажи проходит статусы', () async {
    final manager = (await repository.fetchUsers())
        .firstWhere((u) => u.role == UserRole.manager);
    final admin = (await repository.fetchUsers()).firstWhere((u) => u.isAdmin);
    final client = (await repository.fetchClients())
        .firstWhere((c) => c.sellerId == manager.id);
    final free = (await repository.fetchUnits())
        .firstWhere((u) => u.status == UnitStatus.free);

    await repository.book(unitId: free.id, manager: manager, client: client);
    final design = await repository.sendToDesign(
      unitId: free.id,
      manager: manager,
    );
    expect(design.status, UnitStatus.design);

    final sold = await repository.confirmSale(unitId: free.id, admin: admin);
    expect(sold.status, UnitStatus.sold);
  });

  test('администратор создаёт учётную запись — уходит в аудит', () async {
    final ManagerModel created = await repository.createUser(
      name: 'Марат Осмонов',
      login: 'marat',
      phone: '+996 555 12-34-56',
      role: UserRole.manager,
    );
    expect(created.mustChangePassword, isTrue);
    expect(created.login, 'marat');

    final users = await repository.fetchUsers();
    expect(users.any((u) => u.id == created.id), isTrue);

    final audit = await repository.fetchAuditLogs();
    expect(audit.any((a) => a.action.contains('Создание учётной записи')), isTrue);
  });

  test('массовое создание блока делает квартиры одной пачкой', () async {
    final admin = (await repository.fetchUsers()).firstWhere((u) => u.isAdmin);
    final before = (await repository.fetchUnits()).length;

    final created = await repository.bulkCreateBlock(
      const BulkBlockSpec(
        complexId: 'city',
        blockName: 'Г',
        startNumber: 1,
        groups: [
          FloorGroupSpec(
            floorFrom: 1,
            floorTo: 10,
            roomsPerPosition: [1, 2, 2, 3],
          ),
        ],
      ),
      by: admin,
    );

    expect(created, 40);
    expect((await repository.fetchUnits()).length, before + 40);
  });

  test('клиент заводится за менеджером и не денежный', () async {
    final manager = (await repository.fetchUsers())
        .firstWhere((u) => u.role == UserRole.manager);
    final ClientModel client = await repository.addClient(
      name: 'Айгуль Токтосунова',
      phone: '+996 700 11-22-33',
      seller: manager,
      rooms: 2,
      source: 'Сайт',
    );
    expect(client.sellerId, manager.id);
    expect(client.rooms, 2);
    expect(client.source, 'Сайт');
  });
}
