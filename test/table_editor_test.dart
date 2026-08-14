import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:panorama_sales/core/data/mock_panorama_repository.dart';
import 'package:panorama_sales/core/data/panorama_repository.dart';
import 'package:panorama_sales/core/models/manager_model.dart';
import 'package:panorama_sales/core/models/user_role.dart';
import 'package:panorama_sales/core/providers/data_providers.dart';
import 'package:panorama_sales/core/router/app_router.dart';
import 'package:panorama_sales/features/admin/screens/table_editor_screen.dart';

void main() {
  late PanoramaRepository repository;

  const admin = ManagerModel(
    id: 'u0',
    name: 'Динара Ибраимова',
    login: 'admin',
    phone: '+996 555 00-11-22',
    role: UserRole.admin,
  );

  setUp(() => repository = MockPanoramaRepository(enableBackgroundTimers: false));
  tearDown(() => repository.dispose());

  Widget wrap() => ProviderScope(
    overrides: [
      panoramaRepositoryProvider.overrideWithValue(repository),
      currentUserProvider.overrideWith((ref) => admin),
    ],
    child: const MaterialApp(
      home: TableEditorScreen(
        args: EditorArgs(complexId: 'city', block: 'А'),
      ),
    ),
  );

  testWidgets('редактор строится без исключений', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Табличный редактор · '), findsNothing); // sanity
  });

  testWidgets('наведение мыши на сетку не роняет hit-test', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    // Наводим на несколько ячеек — именно это спамит консоль на web.
    for (final cell in ['№1', '№2', '№3']) {
      final f = find.text(cell);
      if (f.evaluate().isNotEmpty) {
        await gesture.moveTo(tester.getCenter(f.first));
        await tester.pump();
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('выбор стояка показывает панель действий', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // Тапаем номер стояка «1» в тулбаре (первый '1' — в тулбаре).
    await tester.tap(find.text('1').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.textContaining('Выбрано:'), findsOneWidget);
    expect(find.text('Комнаты'), findsOneWidget);
    expect(find.text('Статус'), findsOneWidget);

    // Наводим мышь на кнопки панели действий.
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.text('Статус')));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
