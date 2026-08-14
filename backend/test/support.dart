import 'dart:convert';
import 'dart:math';

import 'package:panorama_backend/db.dart';
import 'package:panorama_backend/server_app.dart';
import 'package:shelf/shelf.dart';

/// Обвязка для интеграционных тестов.
///
/// Обработчик собирается тем же `buildHandler`, что и боевой сервер, и
/// вызывается напрямую — HTTP-порт не открывается, тесты быстрые и не мешают
/// запущенному серверу разработки.
///
/// База берётся из переменных окружения (см. backend/run_tests.ps1), поэтому
/// тесты работают на отдельной базе `panorama_test`, а не на рабочей.
class TestApi {
  TestApi(this.db) : handler = buildHandler(db, log: false);

  final Db db;
  final Handler handler;

  Future<TestResponse> send(
    String method,
    String path, {
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final res = await handler(Request(
      method,
      Uri.parse('http://localhost:8080$path'),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
        if (body != null) 'content-type': 'application/json',
      },
      body: body == null ? null : jsonEncode(body),
    ));
    return TestResponse(res.statusCode, await res.readAsString());
  }

  Future<TestResponse> get(String path, {String? token}) =>
      send('GET', path, token: token);

  Future<TestResponse> post(String path,
          {String? token, Map<String, dynamic>? body}) =>
      send('POST', path, token: token, body: body ?? const {});
}

class TestResponse {
  TestResponse(this.status, this.text);

  final int status;
  final String text;

  dynamic get json => text.trim().isEmpty ? null : jsonDecode(text);
  Map<String, dynamic> get map => (json as Map).cast<String, dynamic>();
  List<Map<String, dynamic>> get list =>
      (json as List).map((e) => (e as Map).cast<String, dynamic>()).toList();

  /// Текст ошибки из тела ответа (пустая строка, если ошибки нет).
  String get error {
    final j = json;
    return j is Map && j['error'] is String ? j['error'] as String : '';
  }

  @override
  String toString() => 'HTTP $status: $text';
}

/// Компания вместе с готовыми токенами администратора и менеджера.
class TestOrg {
  TestOrg({
    required this.id,
    required this.code,
    required this.adminId,
    required this.adminLogin,
    required this.adminToken,
    required this.managerId,
    required this.managerLogin,
    required this.managerToken,
  });

  final String id;
  final String code;
  final String adminId;
  final String adminLogin;
  final String adminToken;
  final String managerId;
  final String managerLogin;
  final String managerToken;
}

const testPassword = '0000';

/// Суффикс, уникальный для каждого запуска: логины и телефоны уникальны во всей
/// базе, поэтому тесты не должны сталкиваться между прогонами.
String uniqueSuffix() {
  final rnd = Random();
  return '${DateTime.now().microsecondsSinceEpoch}${rnd.nextInt(999)}';
}

/// Создаёт компанию и в ней администратора и менеджера, сразу входит обоими.
Future<TestOrg> createOrg(TestApi api, String prefix) async {
  final tag = '$prefix${uniqueSuffix()}';
  final org = await api.db.one(
    '''INSERT INTO organizations (code, name)
       VALUES (@c, @n) RETURNING id::text AS id''',
    {'c': tag, 'n': 'Тест $tag'},
  );
  final orgId = org!['id'] as String;

  final adminLogin = '$tag.admin';
  final managerLogin = '$tag.mgr';
  final adminId = await _createUser(api.db, orgId, adminLogin, 'admin');
  final managerId = await _createUser(api.db, orgId, managerLogin, 'manager');

  return TestOrg(
    id: orgId,
    code: tag,
    adminId: adminId,
    adminLogin: adminLogin,
    adminToken: await login(api, adminLogin),
    managerId: managerId,
    managerLogin: managerLogin,
    managerToken: await login(api, managerLogin),
  );
}

Future<String> _createUser(
    Db db, String orgId, String login, String role) async {
  final row = await db.one(
    '''WITH nu AS (
         INSERT INTO users (org_id, full_name, login, phone,
                            password_hash, must_change_password)
         VALUES (@org, @name, @login, @phone,
                 crypt(@pass, gen_salt('bf')), false)
         RETURNING id
       ), ur AS (
         INSERT INTO user_roles (user_id, role_code)
         SELECT id, @role FROM nu RETURNING user_id
       )
       SELECT id::text AS id FROM nu''',
    {
      'org': orgId,
      'name': 'Тест $login',
      'login': login,
      'phone': '+996 $login',
      'pass': testPassword,
      'role': role,
    },
  );
  return row!['id'] as String;
}

/// Вход через API — заодно проверяется реальный путь выдачи токена.
Future<String> login(TestApi api, String userLogin,
    [String password = testPassword]) async {
  final res = await api.post('/api/v1/auth/login',
      body: {'login': userLogin, 'password': password});
  if (res.status != 200) {
    throw StateError('Вход не удался для $userLogin: $res');
  }
  return res.map['token'] as String;
}

/// Создаёт объект с одним блоком и квартирами, возвращает id объекта.
Future<String> createComplexWithUnits(TestApi api, TestOrg org,
    {int floors = 3, List<int> rooms = const [1, 2]}) async {
  final complex = await api.post('/api/v1/complexes', token: org.adminToken,
      body: {
        'name': 'ЖК ${org.code}',
        'address': 'ул. Тестовая, 1',
        'deadline': 'сдача 2027',
        'segment': 'комфорт',
      });
  if (complex.status != 200) throw StateError('Объект не создан: $complex');
  final complexId = complex.map['id'] as String;

  final bulk = await api.post('/api/v1/blocks/bulk', token: org.adminToken,
      body: {
        'complex_id': complexId,
        'block': 'А',
        'start_number': 1,
        'groups': [
          {'floor_from': 1, 'floor_to': floors, 'rooms': rooms},
        ],
        'technical_floors': <int>[],
        'skip_numbers': <int>[],
      });
  if (bulk.status != 200) throw StateError('Блок не создан: $bulk');
  return complexId;
}

/// Меняет срок подписки компании напрямую в базе.
///
/// [days] может быть отрицательным — так проверяется истёкшая подписка.
Future<void> setPlan(TestApi api, TestOrg org,
    {required int days, int graceDays = 3, bool blocked = false}) async {
  await api.db.query(
    '''UPDATE organizations
       SET plan_until = now() + make_interval(days => @d),
           grace_days = @g, is_blocked = @b, plan_kind = 'paid'
       WHERE id = @id''',
    {'d': days, 'g': graceDays, 'b': blocked, 'id': org.id},
  );
}

/// Создаёт суперадминистратора в служебной компании и входит им.
Future<({String id, String login, String token})> createSuperadmin(
    TestApi api) async {
  final tag = 'su${uniqueSuffix()}';
  final row = await api.db.one(
    '''WITH su AS (
         INSERT INTO users (org_id, full_name, login, phone,
                            password_hash, must_change_password)
         SELECT o.id, 'Тест супер', @login, @phone,
                crypt(@pass, gen_salt('bf')), false
         FROM organizations o WHERE o.code = 'system'
         RETURNING id
       ), ur AS (
         INSERT INTO user_roles (user_id, role_code)
         SELECT id, 'superadmin' FROM su RETURNING user_id
       )
       SELECT id::text AS id FROM su''',
    {'login': tag, 'phone': '+996 $tag', 'pass': testPassword},
  );
  return (id: row!['id'] as String, login: tag, token: await login(api, tag));
}

/// Список квартир компании.
Future<List<Map<String, dynamic>>> units(TestApi api, String token) async =>
    (await api.get('/api/v1/units', token: token)).list;
