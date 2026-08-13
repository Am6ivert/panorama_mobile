import 'package:panorama_backend/auth.dart';
import 'package:panorama_backend/db.dart';
import 'package:test/test.dart';

import 'support.dart';

/// Интеграционные тесты: требуют PostgreSQL с накатанными schema.sql и
/// seed.sql в ОТДЕЛЬНОЙ базе. Проще всего запускать через
///
///   powershell -ExecutionPolicy Bypass -File backend\run_tests.ps1
///
/// который создаёт базу panorama_test и настраивает переменные окружения.
void main() {
  late Db db;
  late TestApi api;

  setUpAll(() async {
    db = await Db.open();
    api = TestApi(db);
  });

  tearDownAll(() async => db.close());

  // ===========================================================================
  group('Аутентификация', () {
    test('без токена закрыто всё, кроме health и login', () async {
      expect((await api.get('/api/v1/health')).status, 200);
      for (final p in const [
        '/api/v1/units',
        '/api/v1/users',
        '/api/v1/clients',
        '/api/v1/deals',
        '/api/v1/audit',
      ]) {
        expect((await api.get(p)).status, 401, reason: p);
      }
    });

    test('мусорный токен не пускает', () async {
      expect((await api.get('/api/v1/units', token: 'deadbeef')).status, 401);
    });

    test('неверный пароль — 401, верный — токен', () async {
      final org = await createOrg(api, 'auth');
      final bad = await api.post('/api/v1/auth/login',
          body: {'login': org.adminLogin, 'password': 'неверный'});
      expect(bad.status, 401);
      expect(org.adminToken, isNotEmpty);
    });

    test('в базе лежит только хеш токена, не сам токен', () async {
      final org = await createOrg(api, 'hash');
      final row = await db.one(
        'SELECT token_hash FROM sessions WHERE user_id=@u ORDER BY created_at DESC LIMIT 1',
        {'u': org.adminId},
      );
      final stored = row!['token_hash'] as String;
      expect(stored, isNot(org.adminToken));
      expect(stored, hashToken(org.adminToken));
      expect(stored.length, 64);
    });

    test('выход отзывает токен', () async {
      final org = await createOrg(api, 'logout');
      expect((await api.post('/api/v1/auth/logout', token: org.managerToken))
          .status, 200);
      expect((await api.get('/api/v1/units', token: org.managerToken)).status,
          401);
    });

    test('блокировка пользователя мгновенно рвёт его сессию', () async {
      final org = await createOrg(api, 'block');
      expect((await api.get('/api/v1/units', token: org.managerToken)).status,
          200);
      await api.post('/api/v1/users/${org.managerId}/block',
          token: org.adminToken, body: {'blocked': true});
      expect((await api.get('/api/v1/units', token: org.managerToken)).status,
          401);
    });

    test('после 5 неудачных попыток вход блокируется на время', () async {
      final org = await createOrg(api, 'brute');
      for (var i = 0; i < 5; i++) {
        final r = await api.post('/api/v1/auth/login',
            body: {'login': org.managerLogin, 'password': 'нет'});
        expect(r.status, 401, reason: 'попытка $i');
      }
      final blocked = await api.post('/api/v1/auth/login',
          body: {'login': org.managerLogin, 'password': testPassword});
      expect(blocked.status, 429);
      expect(blocked.error, contains('попыток'));
    });
  });

  // ===========================================================================
  group('Роли', () {
    late TestOrg org;
    setUpAll(() async => org = await createOrg(api, 'roles'));

    test('менеджеру закрыты админские действия', () async {
      expect((await api.get('/api/v1/audit', token: org.managerToken)).status,
          403);
      expect(
          (await api.post('/api/v1/users', token: org.managerToken, body: {
            'name': 'Кто-то',
            'login': 'someone${uniqueSuffix()}',
            'phone': '+996 ${uniqueSuffix()}',
          }))
              .status,
          403);
      expect(
          (await api.post('/api/v1/complexes', token: org.managerToken, body: {
            'name': 'ЖК',
            'address': 'ул.',
            'deadline': '',
            'segment': ''
          }))
              .status,
          403);
    });

    test('администратору те же действия открыты', () async {
      expect(
          (await api.get('/api/v1/audit', token: org.adminToken)).status, 200);
    });

    test('менеджер видит только своих клиентов, админ — всех', () async {
      final mine = await api.post('/api/v1/clients', token: org.managerToken,
          body: {'name': 'Клиент менеджера', 'phone': '+996 ${uniqueSuffix()}'});
      expect(mine.status, 200);

      final managerSees = (await api.get('/api/v1/clients',
              token: org.managerToken))
          .list;
      expect(managerSees.length, 1);

      final adminSees =
          (await api.get('/api/v1/clients', token: org.adminToken)).list;
      expect(adminSees.length, greaterThanOrEqualTo(1));
    });

    test('нельзя заблокировать себя и сменить себе роль', () async {
      expect(
          (await api.post('/api/v1/users/${org.adminId}/block',
                  token: org.adminToken, body: {'blocked': true}))
              .status,
          422);
      expect(
          (await api.post('/api/v1/users/${org.adminId}/role',
                  token: org.adminToken, body: {'role': 'manager'}))
              .status,
          422);
    });
  });

  // ===========================================================================
  group('Изоляция компаний', () {
    late TestOrg a;
    late TestOrg b;
    late String unitA;

    setUpAll(() async {
      a = await createOrg(api, 'orga');
      b = await createOrg(api, 'orgb');
      await createComplexWithUnits(api, a);
      unitA = (await units(api, a.adminToken)).first['id'] as String;
    });

    test('фонд компаний не пересекается', () async {
      final idsA = (await units(api, a.adminToken)).map((u) => u['id']).toSet();
      final idsB = (await units(api, b.adminToken)).map((u) => u['id']).toSet();
      expect(idsA, isNotEmpty);
      expect(idsA.intersection(idsB), isEmpty);
    });

    test('сотрудники компаний не пересекаются', () async {
      final ua = (await api.get('/api/v1/users', token: a.adminToken)).list;
      final ub = (await api.get('/api/v1/users', token: b.adminToken)).list;
      final idsA = ua.map((u) => u['id']).toSet();
      final idsB = ub.map((u) => u['id']).toSet();
      expect(idsA.intersection(idsB), isEmpty);
      expect(idsA, contains(a.adminId));
      expect(idsB, isNot(contains(a.adminId)));
    });

    test('чужую квартиру нельзя изменить', () async {
      expect(
          (await api.post('/api/v1/units/$unitA/status',
                  token: b.adminToken, body: {'status': 'off_market'}))
              .status,
          409);
      expect(
          (await api.post('/api/v1/units/$unitA', token: b.adminToken, body: {
            'rooms': 1,
            'area': 40,
            'status': 'free',
            'kitchen': '',
            'view': '',
            'finish': '',
            'bathrooms': 1,
          }))
              .status,
          404);
      expect(
          (await api.post('/api/v1/units/$unitA/take', token: b.managerToken))
              .status,
          409);
      expect(
          (await api.post('/api/v1/units/$unitA/release', token: b.managerToken))
              .status,
          403);
    });

    test('чужого сотрудника нельзя тронуть', () async {
      expect(
          (await api.post('/api/v1/users/${a.managerId}/block',
                  token: b.adminToken, body: {'blocked': true}))
              .status,
          404);
      expect(
          (await api.post('/api/v1/users/${a.managerId}/role',
                  token: b.adminToken, body: {'role': 'admin'}))
              .status,
          404);
      expect(
          (await api.post('/api/v1/users/${a.managerId}/password',
                  token: b.adminToken, body: {'new_password': 'взломано'}))
              .status,
          404);
    });

    test('журнал аудита у каждой компании свой', () async {
      final la = (await api.get('/api/v1/audit', token: a.adminToken)).list;
      final lb = (await api.get('/api/v1/audit', token: b.adminToken)).list;
      final idsA = la.map((e) => e['id']).toSet();
      final idsB = lb.map((e) => e['id']).toSet();
      expect(idsA.intersection(idsB), isEmpty);
    });

    test('в базе нет ссылок между компаниями', () async {
      final row = await db.one('''
        SELECT
          (SELECT count(*) FROM apartments a JOIN complexes c ON c.id=a.complex_id
             WHERE c.org_id <> a.org_id) +
          (SELECT count(*) FROM apartments a JOIN blocks b ON b.id=a.block_id
             WHERE b.org_id <> a.org_id) +
          (SELECT count(*) FROM clients k JOIN users u ON u.id=k.seller_id
             WHERE u.org_id <> k.org_id) +
          (SELECT count(*) FROM deals d JOIN apartments a ON a.id=d.apartment_id
             WHERE a.org_id <> d.org_id) AS cross_links''');
      expect(row!['cross_links'], 0);
    });
  });

  // ===========================================================================
  group('Регистрация', () {
    /// Уникальный хвост, чтобы прогоны не сталкивались на уникальных индексах.
    String tag() => uniqueSuffix();

    Future<TestResponse> register(String t,
            {String? login, String? phone, String company = 'ОсОО Тест'}) =>
        api.post('/api/v1/auth/register', body: {
          'name': 'Тестов Тест Тестович',
          'company': company,
          // Хвост метки времени, а не начало: начало у всех вызовов прогона
          // одинаковое, и номера сталкивались бы между собой.
          'phone': phone ?? '+${t.substring(t.length - 12)}',
          'login': login ?? 'reg$t',
          'password': 'secret123',
        });

    test('регистрация создаёт компанию и её администратора', () async {
      final t = tag();
      final res = await register(t, login: 'reg.ok$t');
      expect(res.status, 200, reason: res.text);

      // Токен выдаётся сразу: второй раз входить не нужно.
      final token = res.map['token'] as String;
      expect(token, isNotEmpty);
      expect((res.map['user'] as Map)['role'], 'admin');
      // Пароль человек выбрал сам — принуждать к смене незачем.
      expect((res.map['user'] as Map)['must_change_password'], false);

      // Компания на пробном периоде и работать можно прямо сейчас.
      final sub = res.map['subscription'] as Map;
      expect(sub['plan_kind'], 'trial');
      expect(sub['access'], 'full');
      expect(
          (await api.post('/api/v1/complexes', token: token, body: {
            'name': 'ЖК', 'address': 'ул.', 'deadline': '', 'segment': ''
          }))
              .status,
          200);
    });

    test('регистрация без токена, но с проверкой полей', () async {
      // Короткий пароль, кривой логин и пустая компания до базы не доходят.
      for (final body in [
        {'name': 'Т', 'company': 'К', 'phone': '0700111222',
         'login': 'abc', 'password': 'secret123'},
        {'name': 'Тестов Тест', 'company': 'ОсОО', 'phone': '0700111222',
         'login': 'ab', 'password': 'secret123'},
        {'name': 'Тестов Тест', 'company': 'ОсОО', 'phone': '0700111222',
         'login': 'normal', 'password': '123'},
      ]) {
        expect((await api.post('/api/v1/auth/register', body: body)).status, 422,
            reason: '$body');
      }
    });

    test('занятый логин отклоняется', () async {
      final t = tag();
      expect((await register(t, login: 'reg.dup$t')).status, 200);

      final again = await register(tag(), login: 'reg.dup$t');
      expect(again.status, 409);
      expect(again.error, contains('логин'));
    });

    test('оформление номера не создаёт второй учётной записи', () async {
      // Иначе «0700 123456» и «0700-123456» считались бы разными номерами,
      // и с одного телефона можно было бы набирать пробные периоды без конца.
      final suffix = tag();
      final digits = suffix.substring(suffix.length - 6); // шесть цифр

      expect(
          (await register(tag(),
                  login: 'ph.a${tag()}', phone: '0700 $digits'))
              .status,
          200);

      final same =
          await register(tag(), login: 'ph.b${tag()}', phone: '0700-$digits');
      expect(same.status, 409);
      expect(same.error, contains('номер'));
    });

    test('принимаются и местные, и иностранные номера', () async {
      // Код страны не требуем и не подставляем: «0700 123456» - обычный ввод,
      // «+7 700 1234567» - иностранный клиент.
      final suffix = tag();
      final d = suffix.substring(suffix.length - 6); // шесть цифр на прогон
      for (final phone in [
        '0700 $d',        // местная запись
        '+7 700 1$d',     // Казахстан
        '+998 90 1$d',    // Узбекистан
        '00996 701 $d',   // международный префикс вместо плюса
      ]) {
        final res = await register(tag(), login: 'ph${tag()}', phone: phone);
        expect(res.status, 200, reason: '$phone -> ${res.text}');
      }
    });

    test('слишком короткий номер отклоняется', () async {
      final res =
          await register(tag(), login: 'ph.short${tag()}', phone: '12345');
      expect(res.status, 422);
      expect(res.error, contains('номер телефона'));
    });

  });

  // ===========================================================================
  group('Подписка компании', () {
    test('новая компания сразу получает 3 пробных дня', () async {
      // Пробный период задан умолчанием таблицы, а не скриптом заведения
      // компании: иначе компания, созданная любым другим путём, с первой
      // секунды оказывается в режиме только чтения.
      final org = await createOrg(api, 'plan.trial');
      final row = await api.db.one(
        '''SELECT plan_kind, grace_days,
                  (plan_until > now() + interval '2 days'
                   AND plan_until < now() + interval '4 days') AS three_days
           FROM organizations WHERE id = @id''',
        {'id': org.id},
      );
      expect(row!['plan_kind'], 'trial');
      expect(row['three_days'], isTrue);
      // Льготные дни - привилегия платной подписки.
      expect(row['grace_days'], 0);

      // И этими днями можно пользоваться: никакого setPlan не потребовалось.
      expect(
          (await api.post('/api/v1/complexes', token: org.adminToken, body: {
            'name': 'ЖК', 'address': 'ул.', 'deadline': '', 'segment': ''
          }))
              .status,
          200);
    });

    test('пока подписка действует, менять данные можно', () async {
      final org = await createOrg(api, 'plan.ok');
      await setPlan(api, org, days: 10);
      expect(
          (await api.post('/api/v1/complexes', token: org.adminToken, body: {
            'name': 'ЖК', 'address': 'ул.', 'deadline': '', 'segment': ''
          }))
              .status,
          200);
    });

    test('после истечения остаётся только чтение', () async {
      final org = await createOrg(api, 'plan.exp');
      await createComplexWithUnits(api, org, floors: 2, rooms: [1]);
      // Срок вышел 5 дней назад, льготные 3 дня тоже прошли.
      await setPlan(api, org, days: -5, graceDays: 3);

      // Читать можно.
      expect((await api.get('/api/v1/units', token: org.adminToken)).status, 200);
      expect((await api.get('/api/v1/complexes', token: org.adminToken)).status, 200);

      // Менять нельзя.
      final create = await api.post('/api/v1/complexes',
          token: org.adminToken,
          body: {'name': 'ЖК 2', 'address': 'ул.', 'deadline': '', 'segment': ''});
      expect(create.status, 402);
      expect(create.error, contains('одписка'));

      final unit = (await units(api, org.adminToken)).first['id'] as String;
      expect(
          (await api.post('/api/v1/units/$unit/take', token: org.managerToken))
              .status,
          402);
    });

    test('льготные дни после срока ещё дают полный доступ', () async {
      final org = await createOrg(api, 'plan.grace');
      // Срок вышел вчера, но льготных дней 3 — работа продолжается.
      await setPlan(api, org, days: -1, graceDays: 3);
      expect(
          (await api.post('/api/v1/complexes', token: org.adminToken, body: {
            'name': 'ЖК', 'address': 'ул.', 'deadline': '', 'segment': ''
          }))
              .status,
          200);
    });

    test('приостановленная компания не может менять данные', () async {
      final org = await createOrg(api, 'plan.block');
      await setPlan(api, org, days: 30, blocked: true);
      final res = await api.post('/api/v1/complexes',
          token: org.adminToken,
          body: {'name': 'ЖК', 'address': 'ул.', 'deadline': '', 'segment': ''});
      expect(res.status, 402);
      expect(res.error, contains('риостановлен'));
    });

    test('выход и смена своего пароля работают даже без подписки', () async {
      final org = await createOrg(api, 'plan.esc');
      await setPlan(api, org, days: -30);
      expect(
          (await api.post('/api/v1/users/${org.managerId}/password',
                  token: org.managerToken, body: {'new_password': 'secret1'}))
              .status,
          200);
      expect(
          (await api.post('/api/v1/auth/logout', token: org.adminToken)).status,
          200);
    });

    test('вход возвращает состояние подписки', () async {
      final org = await createOrg(api, 'plan.info');
      await setPlan(api, org, days: 10);
      final res = await api.post('/api/v1/auth/login',
          body: {'login': org.adminLogin, 'password': testPassword});
      expect(res.status, 200);
      final sub = (res.map['subscription'] as Map).cast<String, dynamic>();
      expect(sub['access'], 'full');
      expect(sub['plan_until'], isNotNull);
    });
  });

  // ===========================================================================
  group('Суперадминистратор', () {
    test('обычному админу панель суперадмина закрыта', () async {
      final org = await createOrg(api, 'nosuper');
      expect((await api.get('/api/v1/superadmin/orgs', token: org.adminToken))
          .status, 403);
      expect(
          (await api.post('/api/v1/superadmin/orgs/${org.id}/subscribe',
                  token: org.adminToken, body: {'months': 12}))
              .status,
          403);
    });

    test('видит компании, их админов и число менеджеров', () async {
      final org = await createOrg(api, 'seen');
      final su = await createSuperadmin(api);

      final list = (await api.get('/api/v1/superadmin/orgs', token: su.token)).list;
      final row = list.firstWhere((o) => o['id'] == org.id);
      expect(row['managers'], 1);
      final admins = (row['admins'] as List).cast<Map<String, dynamic>>();
      expect(admins.map((a) => a['login']), contains(org.adminLogin));
      // Служебная компания в списке не участвует.
      expect(list.any((o) => o['code'] == 'system'), isFalse);
    });

    test('продление возвращает компанию в работу', () async {
      final org = await createOrg(api, 'renew');
      final su = await createSuperadmin(api);
      await setPlan(api, org, days: -30);

      // До продления — только чтение.
      expect(
          (await api.post('/api/v1/complexes', token: org.adminToken, body: {
            'name': 'ЖК', 'address': 'ул.', 'deadline': '', 'segment': ''
          }))
              .status,
          402);

      final renew = await api.post('/api/v1/superadmin/orgs/${org.id}/subscribe',
          token: su.token, body: {'months': 1, 'note': 'оплата за март'});
      expect(renew.status, 200);

      // После продления — снова полный доступ.
      expect(
          (await api.post('/api/v1/complexes', token: org.adminToken, body: {
            'name': 'ЖК', 'address': 'ул.', 'deadline': '', 'segment': ''
          }))
              .status,
          200);

      // Операция попала в историю.
      final hist = await db.one(
        'SELECT count(*) AS n FROM subscriptions WHERE org_id=@o AND kind=@k',
        {'o': org.id, 'k': 'paid'},
      );
      expect(hist!['n'], 1);
    });

    test('блокировка и разблокировка компании', () async {
      final org = await createOrg(api, 'blk');
      final su = await createSuperadmin(api);

      expect(
          (await api.post('/api/v1/superadmin/orgs/${org.id}/block',
                  token: su.token, body: {'blocked': true}))
              .status,
          200);
      expect(
          (await api.post('/api/v1/complexes', token: org.adminToken, body: {
            'name': 'ЖК', 'address': 'ул.', 'deadline': '', 'segment': ''
          }))
              .status,
          402);

      expect(
          (await api.post('/api/v1/superadmin/orgs/${org.id}/block',
                  token: su.token, body: {'blocked': false}))
              .status,
          200);
      expect(
          (await api.post('/api/v1/complexes', token: org.adminToken, body: {
            'name': 'ЖК 2', 'address': 'ул.', 'deadline': '', 'segment': ''
          }))
              .status,
          200);
    });

    test('суперадмин не видит квартиры и клиентов компаний', () async {
      final org = await createOrg(api, 'privacy');
      await createComplexWithUnits(api, org, floors: 2, rooms: [1]);
      final su = await createSuperadmin(api);
      // Своя служебная компания пуста — чужой фонд ему не виден.
      expect((await units(api, su.token)), isEmpty);
      expect((await api.get('/api/v1/clients', token: su.token)).list, isEmpty);
    });
  });

  // ===========================================================================
  group('Работа с квартирой', () {
    late TestOrg org;
    late List<Map<String, dynamic>> fond;

    setUpAll(() async {
      org = await createOrg(api, 'flow');
      await createComplexWithUnits(api, org, floors: 6, rooms: [1, 2]);
      fond = await units(api, org.adminToken);
    });

    test('мастер массового создания действительно создаёт квартиры', () {
      // 6 этажей по 2 квартиры
      expect(fond.length, 12);
    });

    test('срок брони берётся из запроса, а не из зашитых 3 дней', () async {
      final unit = fond[0]['id'] as String;
      final res = await api.post('/api/v1/units/$unit/book',
          token: org.managerToken, body: {'days': 7});
      expect(res.status, 200);

      final check = await db.one(
        '''SELECT held_until > now() + interval '6 days'
               AND held_until < now() + interval '8 days' AS ok
           FROM apartments WHERE id=@id''',
        {'id': unit},
      );
      expect(check!['ok'], isTrue, reason: 'бронь должна быть на 7 дней');
    });

    test('продажу подтверждает только администратор', () async {
      final unit = fond[1]['id'] as String;
      expect(
          (await api.post('/api/v1/units/$unit/book', token: org.managerToken,
                  body: {'days': 3}))
              .status,
          200);
      expect(
          (await api.post('/api/v1/units/$unit/design', token: org.managerToken))
              .status,
          200);
      expect(
          (await api.post('/api/v1/units/$unit/sell', token: org.managerToken))
              .status,
          403);
      expect(
          (await api.post('/api/v1/units/$unit/sell', token: org.adminToken))
              .status,
          200);
    });

    test('чужую бронь менеджер снять не может, администратор может', () async {
      final unit = fond[2]['id'] as String;
      await api.post('/api/v1/units/$unit/book',
          token: org.managerToken, body: {'days': 3});

      final other = await createOrg(api, 'other');
      // менеджер другой компании вообще не видит квартиру
      expect(
          (await api.post('/api/v1/units/$unit/release',
                  token: other.managerToken))
              .status,
          403);
      // а свой администратор — может
      expect(
          (await api.post('/api/v1/units/$unit/release', token: org.adminToken))
              .status,
          200);
    });

    test('запрос на продление доходит до администратора', () async {
      final unit = fond[3]['id'] as String;
      await api.post('/api/v1/units/$unit/book',
          token: org.managerToken, body: {'days': 3});
      expect(
          (await api.post('/api/v1/units/$unit/extend-request',
                  token: org.managerToken))
              .status,
          200);

      final inbox =
          (await api.get('/api/v1/notifications', token: org.adminToken)).list;
      expect(inbox.any((n) => n['kind'] == 'extend_request'), isTrue);
    });

    test('лимит квартир в работе — 5', () async {
      final limitOrg = await createOrg(api, 'limit');
      await createComplexWithUnits(api, limitOrg, floors: 6, rooms: [1, 2]);
      final list = await units(api, limitOrg.adminToken);

      for (var i = 0; i < 5; i++) {
        final r = await api.post('/api/v1/units/${list[i]['id']}/take',
            token: limitOrg.managerToken);
        expect(r.status, 200, reason: 'квартира $i');
      }
      final sixth = await api.post('/api/v1/units/${list[5]['id']}/take',
          token: limitOrg.managerToken);
      expect(sixth.status, 422);
      expect(sixth.error, contains('лимит'));
    });

    test('список фонда без истории, карточка квартиры — с историей', () async {
      final unit = fond[4]['id'] as String;
      await api.post('/api/v1/units/$unit/take', token: org.managerToken);

      final row = (await units(api, org.adminToken))
          .firstWhere((u) => u['id'] == unit);
      expect(row.containsKey('history'), isFalse,
          reason: 'история раздувала список фонда');
      expect(row['updated_at'], isNotNull,
          reason: 'нужна метка для инкрементального опроса');

      final card =
          (await api.get('/api/v1/units/$unit', token: org.adminToken)).map;
      expect(card['history'], isNotEmpty);
    });

    test('чужую квартиру по прямой ссылке не открыть', () async {
      final stranger = await createOrg(api, 'peek');
      expect(
          (await api.get('/api/v1/units/${fond[0]['id']}',
                  token: stranger.adminToken))
              .status,
          404);
    });

    test('повторный опрос отдаёт только изменившиеся квартиры', () async {
      final org2 = await createOrg(api, 'delta');
      await createComplexWithUnits(api, org2, floors: 4, rooms: [1, 2]);

      final before = await units(api, org2.adminToken);
      expect(before.length, 8);
      final mark = before
          .map((u) => u['updated_at'] as String)
          .reduce((a, b) => a.compareTo(b) > 0 ? a : b);

      final target = before.last['id'] as String;
      await api.post('/api/v1/units/$target/take', token: org2.managerToken);

      final delta = (await api.get(
        '/api/v1/units?since=${Uri.encodeQueryComponent(mark)}',
        token: org2.adminToken,
      ))
          .list;
      expect(delta.map((u) => u['id']), contains(target));
      expect(delta.length, lessThan(before.length),
          reason: 'должны прийти только изменения, а не весь фонд');
    });

    test('лимит берётся из настроек компании, а не из кода', () async {
      final small = await createOrg(api, 'limitcfg');
      // Компания разрешает всего 2 квартиры в работе.
      await db.query(
        '''INSERT INTO settings (org_id, key, value) VALUES (@o,'work_limit','2')
           ON CONFLICT (org_id, key) DO UPDATE SET value='2' ''',
        {'o': small.id},
      );
      await createComplexWithUnits(api, small, floors: 3, rooms: [1, 2]);
      final list = await units(api, small.adminToken);

      for (var i = 0; i < 2; i++) {
        expect(
            (await api.post('/api/v1/units/${list[i]['id']}/take',
                    token: small.managerToken))
                .status,
            200,
            reason: 'квартира $i');
      }
      final third = await api.post('/api/v1/units/${list[2]['id']}/take',
          token: small.managerToken);
      expect(third.status, 422);
      expect(third.error, contains('2'),
          reason: 'в сообщении должен быть лимит из настроек');
    });

    test('повторная отправка мастера не создаёт блок дважды', () async {
      final org2 = await createOrg(api, 'idem');
      final complex = await api.post('/api/v1/complexes',
          token: org2.adminToken,
          body: {
            'name': 'ЖК повтор',
            'address': 'ул. Тестовая',
            'deadline': '',
            'segment': ''
          });
      expect(complex.status, 200);

      Map<String, dynamic> payload(String key) => {
            'complex_id': complex.map['id'],
            'block': 'Б',
            'start_number': 1,
            'idempotency_key': key,
            'groups': [
              {'floor_from': 1, 'floor_to': 2, 'rooms': [1, 2]},
            ],
            'technical_floors': <int>[],
            'skip_numbers': <int>[],
          };

      final key = 'kлюч-${uniqueSuffix()}';
      final first = await api.post('/api/v1/blocks/bulk',
          token: org2.adminToken, body: payload(key));
      expect(first.status, 200);
      expect(first.map['created'], 4);

      // Тот же ключ: сервер обязан вернуть прежний результат и ничего не создать.
      final again = await api.post('/api/v1/blocks/bulk',
          token: org2.adminToken, body: payload(key));
      expect(again.status, 200);
      expect(again.map['created'], 4);
      expect(again.map['repeated'], isTrue);

      expect((await units(api, org2.adminToken)).length, 4,
          reason: 'повтор не должен был удвоить фонд');

      // Новый ключ — это уже другая операция, блок с тем же именем не пройдёт
      // из-за уникальности имени блока в объекте.
      final other = await api.post('/api/v1/blocks/bulk',
          token: org2.adminToken, body: payload('kлюч-${uniqueSuffix()}'));
      expect(other.status, 409);
    });

    test('уведомления видны только адресату', () async {
      final one = await createOrg(api, 'ntf');
      final inbox =
          (await api.get('/api/v1/notifications', token: one.managerToken)).list;
      for (final n in inbox) {
        expect(n['recipient_id'], one.managerId);
      }
    });
  });
}
