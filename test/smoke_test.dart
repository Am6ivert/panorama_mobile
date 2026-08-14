import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:panorama_sales/core/data/mock_panorama_repository.dart';
import 'package:panorama_sales/core/data/panorama_repository.dart';
import 'package:panorama_sales/core/providers/data_providers.dart';
import 'package:panorama_sales/main.dart';

/// Сквозной smoke-тест: вход и проход по всем экранам, проверка что ничего
/// не падает (задача «проверь, всё ли работает»).
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

  testWidgets('админ проходит по всем вкладкам без ошибок', (tester) async {
    await login(tester, 'admin');
    expect(tester.takeException(), isNull);

    for (final tab in ['Шахматка', 'Реестр', 'Клиенты', 'Уведомления', 'Дашборд']) {
      await tester.tap(find.text(tab).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'вкладка $tab');
    }
  });

  testWidgets('шахматка открывается и карточка квартиры тоже', (tester) async {
    await login(tester, 'marat');

    await tester.tap(find.text('Шахматка').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Панорама Сити'));
    await tester.pumpAndSettle();
    expect(find.text('Блок А'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Открываем первую попавшуюся квартиру по номеру.
    final cell = find.textContaining('№').first;
    await tester.tap(cell);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('реестр: переключение вкладок и поиск', (tester) async {
    await login(tester, 'marat');
    await tester.tap(find.text('Реестр').first);
    await tester.pumpAndSettle();

    for (final t in ['Свободные', 'Мои', 'Брони', 'Истекают', 'Оформление', 'Все']) {
      await tester.tap(find.text(t).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'вкладка реестра $t');
    }
  });

  testWidgets('админ-панель и все её подэкраны открываются', (tester) async {
    await login(tester, 'admin');

    // Иконка админ-панели в шапке дашборда.
    await tester.tap(find.byIcon(Icons.admin_panel_settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Админ-панель'), findsWidgets);

    Future<void> openAndBack(String title) async {
      await tester.tap(find.text(title).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: title);
      // Кастомная кнопка «назад» в AppHeader, а не AppBar.
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new).first);
      await tester.pumpAndSettle();
    }

    await openAndBack('Пользователи');
    await openAndBack('Журнал аудита');
    await openAndBack('Мастер массового создания');

    // Табличный редактор — через чип блока.
    await tester.tap(find.text('Блок А').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Табличный редактор'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('продавец не видит вход в админку', (tester) async {
    await login(tester, 'marat');
    expect(find.byIcon(Icons.admin_panel_settings_outlined), findsNothing);
  });
}
