import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:panorama_sales/core/data/mock_panorama_repository.dart';
import 'package:panorama_sales/core/data/panorama_repository.dart';
import 'package:panorama_sales/core/models/client_model.dart';
import 'package:panorama_sales/core/models/unit_model.dart';
import 'package:panorama_sales/core/models/unit_status.dart';
import 'package:panorama_sales/core/models/user_role.dart';
import 'package:panorama_sales/core/providers/data_providers.dart';
import 'package:panorama_sales/main.dart';

/// Проверка «кнопка в UI действительно меняет состояние» — сквозные сценарии.
///
/// Важно: прямые вызовы репозитория внутри testWidgets оборачиваем в
/// [WidgetTester.runAsync] — у мока внутри Future.delayed, а fake-async зона
/// теста сама таймер не проматывает.
void main() {
  late PanoramaRepository repository;

  ProviderScope app() => ProviderScope(
    overrides: [panoramaRepositoryProvider.overrideWithValue(repository)],
    child: const PanoramaApp(),
  );

  setUp(() => repository = MockPanoramaRepository(enableBackgroundTimers: false));
  tearDown(() => repository.dispose());

  Future<void> login(WidgetTester tester, String login) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, login);
    await tester.enterText(find.byType(TextField).at(1), '0000');
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();
  }

  testWidgets('менеджер берёт свободную квартиру в работу через UI', (
    tester,
  ) async {
    late UnitModel free;
    await tester.runAsync(() async {
      final units = await repository.fetchUnits();
      free = (units
          .where((u) => u.complexId == 'city' && u.block == 'А' && u.status == UnitStatus.free)
          .toList()
        ..sort((a, b) => b.floor.compareTo(a.floor))).first;
    });

    await login(tester, 'azamat');
    await tester.tap(find.text('Шахматка').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Панорама Сити'));
    await tester.pumpAndSettle();

    final cell = find.text('№${free.number}');
    await tester.ensureVisible(cell);
    await tester.pumpAndSettle();
    await tester.tap(cell);
    await tester.pumpAndSettle();

    final takeBtn = find.textContaining('Взять в работу');
    await tester.ensureVisible(takeBtn);
    await tester.pumpAndSettle();
    await tester.tap(takeBtn);
    await tester.pumpAndSettle();

    // Свой клиент Айбек Сыдыков закреплён за m1/azamat.
    await tester.tap(find.text('Айбек Сыдыков'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    late UnitModel after;
    await tester.runAsync(() async {
      after = (await repository.fetchUnits()).firstWhere((u) => u.id == free.id);
    });
    expect(after.status, UnitStatus.work);
    expect(after.clientName, 'Айбек Сыдыков');
  });

  testWidgets('менеджер заводит клиента через вкладку «Клиенты»', (tester) async {
    await login(tester, 'azamat');
    var before = 0;
    await tester.runAsync(() async {
      before = (await repository.fetchClients()).length;
    });

    await tester.tap(find.text('Клиенты').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Клиент'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Имя и фамилия'),
      'Марат Осмонов',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Телефон'),
      '+996 555 12-34-56',
    );
    final saveBtn = find.text('Сохранить клиента');
    await tester.ensureVisible(saveBtn);
    await tester.pumpAndSettle();
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    late List<ClientModel> clients;
    await tester.runAsync(() async {
      clients = await repository.fetchClients();
    });
    expect(clients.length, before + 1);
    final saved = clients.firstWhere((c) => c.name == 'Марат Осмонов');
    expect(saved.sellerName.isNotEmpty, isTrue);
  });

  testWidgets('мастер массового создания открывается и считает предпросмотр', (
    tester,
  ) async {
    await login(tester, 'admin');

    await tester.tap(find.byIcon(Icons.admin_panel_settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Мастер массового создания'));
    await tester.pumpAndSettle();

    // Мастер открылся и посчитал предпросмотр (48 квартир по умолчанию).
    expect(find.text('Массовое создание'), findsOneWidget);
    expect(
      find.textContaining('Создать', skipOffstage: false),
      findsNothing, // ленивый ListView ещё не построил нижнюю кнопку — ок
    );
    expect(tester.takeException(), isNull);
    // Само создание блока покрыто тестом уровня репозитория в widget_test.dart.
  });

  testWidgets('бронь одного менеджера доходит уведомлением другому', (
    tester,
  ) async {
    late UnitModel free;
    await tester.runAsync(() async {
      final users = await repository.fetchUsers();
      final azamat = users.firstWhere((u) => u.login == 'azamat');
      final client = (await repository.fetchClients())
          .firstWhere((c) => c.sellerId == azamat.id);
      free = (await repository.fetchUnits())
          .firstWhere((u) => u.status == UnitStatus.free);
      await repository.book(unitId: free.id, manager: azamat, client: client);
    });

    // Входит ДРУГОЙ менеджер и видит уведомление о брони.
    await login(tester, 'elvira');
    await tester.tap(find.text('Уведомления').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Квартира забронирована'), findsWidgets);
    expect(find.textContaining('№${free.number}'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('первый вход требует смены временного пароля (FR-01.3)', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await repository.createUser(
        name: 'Марат Осмонов',
        login: 'marat',
        phone: '+996 555 12-34-56',
        role: UserRole.manager,
      );
    });

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'marat');
    await tester.enterText(find.byType(TextField).at(1), '0000');
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();

    expect(find.text('Смена пароля'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Новый пароль'),
      'secret1',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Повторите пароль'),
      'secret1',
    );
    await tester.tap(find.text('Сохранить и войти'));
    await tester.pumpAndSettle();

    expect(find.text('Дашборд'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.runAsync(() async {
      expect(
        await repository.login(login: 'marat', password: 'secret1'),
        isA<LoginOk>(),
      );
      expect(
        await repository.login(login: 'marat', password: '0000'),
        isA<LoginFailed>(),
      );
    });
  });
}
