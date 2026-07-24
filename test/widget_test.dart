import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:panorama_sales/core/data/mock_panorama_repository.dart';
import 'package:panorama_sales/core/data/panorama_repository.dart';
import 'package:panorama_sales/core/models/client_model.dart';
import 'package:panorama_sales/core/models/manager_model.dart';
import 'package:panorama_sales/core/models/unit_model.dart';
import 'package:panorama_sales/core/models/unit_status.dart';
import 'package:panorama_sales/core/providers/data_providers.dart';
import 'package:panorama_sales/main.dart';

/// Сколько квартир менеджер держит в работе или в брони.
Future<int> _dealsOf(PanoramaRepository repository, String managerId) async =>
    (await repository.fetchUnits())
        .where((u) => u.heldById == managerId && u.status.isTaken)
        .length;

/// Форма клиента выше окна теста, поэтому докручиваем до цели перед нажатием.
Future<void> _tapButton(WidgetTester tester, String label) async {
  final target = find.text(label);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  late PanoramaRepository repository;

  ProviderScope app() => ProviderScope(
    overrides: [panoramaRepositoryProvider.overrideWithValue(repository)],
    child: const PanoramaApp(),
  );

  setUp(() => repository = MockPanoramaRepository(simulateColleagues: false));
  tearDown(() => repository.dispose());

  testWidgets('менеджер выбирает себя и попадает к списку объектов', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Азамат Кубанычбеков'), findsOneWidget);

    await tester.tap(find.text('Азамат Кубанычбеков'));
    await tester.pumpAndSettle();

    expect(find.text('МОИ ОБЪЕКТЫ'), findsOneWidget);
    expect(find.text('Панорама Сити'), findsOneWidget);
  });

  testWidgets('шахматка открывается и показывает блоки', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Азамат Кубанычбеков'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Панорама Сити'));
    await tester.pumpAndSettle();

    expect(find.text('Блок А'), findsOneWidget);
    expect(find.text('Блок Б'), findsOneWidget);
    expect(find.text('Свободно'), findsOneWidget);
  });

  testWidgets('взятие в работу закрепляет квартиру за менеджером', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Азамат Кубанычбеков'));
    await tester.pumpAndSettle();

    // Вызовы репозитория идут через runAsync: у мока внутри Future.delayed,
    // а в fake-async зоне теста такой таймер сам по себе не сработает.
    late final UnitModel updated;
    late final ManagerModel manager;
    var dealsBefore = 0;
    var dealsAfter = 0;
    await tester.runAsync(() async {
      manager = (await repository.fetchManagers()).first;
      dealsBefore = await _dealsOf(repository, manager.id);

      final free = (await repository.fetchUnits()).firstWhere(
        (u) => u.status == UnitStatus.free,
      );
      await repository.takeToWork(unitId: free.id, manager: manager);

      updated = (await repository.fetchUnits()).firstWhere(
        (u) => u.id == free.id,
      );
      dealsAfter = await _dealsOf(repository, manager.id);
    });
    await tester.pumpAndSettle();

    expect(updated.status, UnitStatus.work);
    expect(updated.heldById, manager.id);
    expect(updated.history.first.title, 'Взята в работу');
    expect(dealsAfter, dealsBefore + 1);

    // Счётчик сделок в нижней навигации подхватывает изменение.
    expect(find.widgetWithText(Badge, '$dealsAfter'), findsWidgets);
  });

  testWidgets('менеджер заводит клиента прямо на объекте', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Азамат Кубанычбеков'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Клиенты'));
    await tester.pumpAndSettle();
    expect(find.text('АКТИВНЫЕ КЛИЕНТЫ (4)'), findsOneWidget);

    await tester.tap(find.text('Клиент'));
    await tester.pumpAndSettle();
    expect(find.text('Новый клиент'), findsOneWidget);

    // Пустая форма не сохраняется: без имени и телефона карточка бесполезна.
    await _tapButton(tester, 'Сохранить клиента');
    expect(find.text('Без имени карточку не найти'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Имя и фамилия'),
      'Марат Осмонов',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Телефон'),
      '+996 555 12-34-56',
    );
    await _tapButton(tester, '3к');
    await _tapButton(tester, 'Сохранить клиента');

    // Карточка нового клиента открылась поверх списка.
    final card = find.textContaining('ПОДХОДИТ СЕЙЧАС');
    expect(card, findsOneWidget);
    expect(find.text('+996 555 12-34-56'), findsWidgets);

    late final ClientModel saved;
    await tester.runAsync(() async {
      saved = (await repository.fetchClients()).first;
    });
    expect(saved.name, 'Марат Осмонов');
    expect(saved.rooms, 3);
    expect(saved.budget, 60000);

    // Список пополнился и показывает нового клиента первым.
    Navigator.of(tester.element(card)).pop();
    await tester.pumpAndSettle();
    expect(find.text('АКТИВНЫЕ КЛИЕНТЫ (5)'), findsOneWidget);
    expect(find.text('Марат Осмонов'), findsOneWidget);
  });
}
