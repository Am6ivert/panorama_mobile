import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'auth.dart';
import 'db.dart';
import 'fcm.dart';
import 'json.dart';

/// REST API /api/v1 для «Шахматки квартир».
class Api {
  Api(this.db, [this.fcm]);
  final Db db;
  final Fcm? fcm;
  final _rnd = Random.secure();

  Handler get handler {
    final r = Router();

    r.get('/api/v1/health', (Request _) => jsonOk({'ok': true}));

    // --- Аутентификация ---
    r.post('/api/v1/auth/login', _login);
    r.post('/api/v1/auth/register', _register);
    r.post('/api/v1/auth/logout', _logout);
    r.get('/api/v1/auth/me', _meRoute);

    // --- Пользователи ---
    r.get('/api/v1/users', _users);
    r.post('/api/v1/users', _createUser);
    r.post('/api/v1/users/<id>/block', _blockUser);
    r.post('/api/v1/users/<id>/role', _roleUser);
    r.post('/api/v1/users/<id>/password', _changePassword);

    // --- Недвижимость ---
    r.get('/api/v1/complexes', _complexes);
    r.post('/api/v1/complexes', _createComplex);
    r.post('/api/v1/blocks/bulk', _bulkBlock);

    // --- Фонд ---
    r.get('/api/v1/units', _units);
    r.get('/api/v1/units/<id>', _unit);
    r.post('/api/v1/units/<id>', _updateUnit);
    r.post('/api/v1/units/<id>/take', _take);
    r.post('/api/v1/units/<id>/book', _book);
    r.post('/api/v1/units/<id>/release', _release);
    r.post('/api/v1/units/<id>/design', _design);
    r.post('/api/v1/units/<id>/sell', _sell);
    r.post('/api/v1/units/<id>/status', _setStatus);
    r.post('/api/v1/units/<id>/extend', _extend);
    r.post('/api/v1/units/<id>/extend-request', _extendRequest);
    r.post('/api/v1/units/<id>/message', _message);

    // --- Клиенты и сделки ---
    r.get('/api/v1/clients', _clients);
    r.post('/api/v1/clients', _createClient);
    r.get('/api/v1/deals', _deals);
    r.post('/api/v1/deals/<id>/stage', _dealStage);

    // --- Уведомления и аудит ---
    r.get('/api/v1/notifications', _notifications);
    r.post('/api/v1/notifications/<id>/read', _markRead);
    r.post('/api/v1/notifications/read-all', _markAllRead);
    r.get('/api/v1/audit', _audit);

    // --- Суперадминистратор: компании и подписки ---
    r.get('/api/v1/superadmin/orgs', _superOrgs);
    r.post('/api/v1/superadmin/orgs/<id>/subscribe', _superSubscribe);
    r.post('/api/v1/superadmin/orgs/<id>/block', _superBlock);

    // --- Push-токены устройств ---
    r.post('/api/v1/devices', _registerDevice);

    return r.call;
  }

  // ===========================================================================
  // SQL-фрагменты
  // ===========================================================================

  // Все выборки ниже заканчиваются условием по компании: @org подставляет
  // хендлер из AuthContext. Данные разных застройщиков не пересекаются.

  /// Без фильтра по компании — только для входа, когда компания ещё неизвестна.
  static const _userSelectAny = '''
    SELECT u.id::text AS id, u.full_name AS name, u.login, u.phone,
           COALESCE((SELECT role_code FROM user_roles WHERE user_id=u.id LIMIT 1),'manager') AS role,
           u.blocked, u.must_change_password AS must_change_password,
           u.org_id::text AS org_id
    FROM users u WHERE u.deleted_at IS NULL''';

  static const _userSelect = '$_userSelectAny AND u.org_id=@org';

  static const _complexSelect = '''
    SELECT c.id::text AS id, c.name, COALESCE(c.address,'') AS address,
           COALESCE(c.deadline,'') AS deadline, COALESCE(c.segment,'') AS segment,
           c.cover_start, c.cover_end,
           COALESCE((SELECT json_agg(json_build_object(
               'name', b.name, 'floors', b.floors, 'units_per_floor', b.units_per_floor
             ) ORDER BY b.name)
             FROM blocks b WHERE b.complex_id=c.id AND b.deleted_at IS NULL),'[]'::json) AS blocks
    FROM complexes c WHERE c.deleted_at IS NULL AND c.org_id=@org''';

  static const _clientSelect = '''
    SELECT cl.id::text AS id, cl.full_name AS name, cl.phone,
           cl.seller_id::text AS seller_id, su.full_name AS seller_name,
           COALESCE(cl.rooms,0) AS rooms, COALESCE(cl.source,'') AS source,
           COALESCE(cl.request,'') AS request, cl.stage,
           COALESCE(cl.note,'') AS note,
           to_char(cl.next_action_at AT TIME ZONE 'Asia/Bishkek','YYYY-MM-DD"T"HH24:MI:SS.US') AS next_action_at
    FROM clients cl JOIN users su ON su.id = cl.seller_id
    WHERE cl.deleted_at IS NULL AND cl.org_id=@org''';

  /// Колонки квартиры БЕЗ истории — для списка фонда.
  ///
  /// История нужна только в карточке квартиры, а в списке она умножала объём
  /// ответа на число событий по каждой квартире. Фонд перечитывается каждые
  /// 15 секунд, поэтому это была основная часть трафика.
  static const _unitColumns = '''
    SELECT a.id::text AS id,
           a.complex_id::text AS complex_id,
           c.name AS complex_name,
           b.name AS block,
           a.floor, a.position, a.number, a.rooms,
           a.area::float8 AS area, a.status,
           COALESCE(a.kitchen,'') AS kitchen,
           COALESCE(a.view,'') AS view,
           COALESCE(a.finish,'') AS finish,
           a.bathrooms,
           a.held_by_id::text AS held_by_id,
           hu.full_name AS held_by_name,
           to_char(a.held_until AT TIME ZONE 'Asia/Bishkek','YYYY-MM-DD"T"HH24:MI:SS.US') AS held_until,
           a.client_id::text AS client_id,
           cl.full_name AS client_name,''';

  /// Подзапрос истории — только для карточки квартиры.
  static const _unitHistory = '''
           COALESCE((SELECT json_agg(json_build_object(
               'kind', CASE h.to_status
                         WHEN 'work' THEN 'taken' WHEN 'hold' THEN 'booked'
                         WHEN 'design' THEN 'design' WHEN 'sold' THEN 'sold'
                         WHEN 'off_market' THEN 'off_market' ELSE 'released' END,
               'title', COALESCE(NULLIF(h.comment,''), 'Изменение статуса'),
               'author_name', COALESCE(huh.full_name, 'Система'),
               'client_name', clh.full_name,
               'at', to_char(h.at AT TIME ZONE 'Asia/Bishkek','YYYY-MM-DD"T"HH24:MI:SS.US')
             ) ORDER BY h.at DESC)
             FROM apartment_status_history h
             LEFT JOIN users huh ON huh.id = h.changed_by
             LEFT JOIN clients clh ON clh.id = h.client_id
             WHERE h.apartment_id = a.id), '[]'::json) AS history,''';

  /// Хвост запроса: соединения, общие для списка и карточки.
  static const _unitFrom = '''
           to_char(a.updated_at AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.USZ') AS updated_at
    FROM apartments a
    JOIN complexes c ON c.id = a.complex_id
    JOIN blocks b ON b.id = a.block_id
    LEFT JOIN users hu ON hu.id = a.held_by_id
    LEFT JOIN clients cl ON cl.id = a.client_id''';

  /// Список фонда: без истории.
  static const _unitListSelect = '$_unitColumns$_unitFrom';

  /// Одна квартира: с историей.
  static const _unitSelect = '$_unitColumns$_unitHistory$_unitFrom';

  Map<String, dynamic> _unitJson(Map<String, dynamic> row) =>
      {...row, 'history': asJsonList(row['history'])};

  Map<String, dynamic> _complexJson(Map<String, dynamic> row) =>
      {...row, 'blocks': asJsonList(row['blocks'])};

  // ===========================================================================
  // Личность и права — ТОЛЬКО из контекста запроса (его заполнил
  // authMiddleware в server.dart). Поля тела запроса вида manager_id/admin_id/
  // user_id для авторизации не используются: их подделывает любой клиент.
  // ===========================================================================

  /// Автор запроса. Для непубличных маршрутов middleware гарантирует наличие.
  AuthContext _me(Request request) =>
      request.context[authContextKey]! as AuthContext;

  /// Вернуть 403, если автор не администратор; иначе null.
  Response? _adminOnly(Request request) => _me(request).isAdmin
      ? null
      : jsonError(403, 'Действие доступно только администратору');

  /// Клиент из компании автора и принадлежит ему (админу — любой в компании).
  Future<bool> _ownsClient(AuthContext me, String? clientId) async {
    if (clientId == null) return true;
    final r = await db.one(
      '''SELECT seller_id::text AS s FROM clients
         WHERE id=@c AND org_id=@org AND deleted_at IS NULL''',
      {'c': clientId, 'org': me.orgId},
    );
    if (r == null) return false; // нет такого клиента либо он в другой компании
    return me.isAdmin || r['s'] == me.userId;
  }

  /// Квартира из компании автора и удерживается им (админу — любая в компании).
  Future<bool> _holdsUnit(AuthContext me, String unitId) async {
    final r = await db.one(
      '''SELECT held_by_id::text AS h FROM apartments
         WHERE id=@id AND org_id=@org AND deleted_at IS NULL''',
      {'id': unitId, 'org': me.orgId},
    );
    if (r == null) return false;
    return me.isAdmin || r['h'] == me.userId;
  }

  /// Учётная запись существует и принадлежит компании автора.
  Future<bool> _userInOrg(AuthContext me, String userId) async {
    final r = await db.one(
      'SELECT 1 AS x FROM users WHERE id=@id AND org_id=@org AND deleted_at IS NULL',
      {'id': userId, 'org': me.orgId},
    );
    return r != null;
  }

  // ===========================================================================
  // Аутентификация
  // ===========================================================================

  // Подбор пароля: у учёток по умолчанию пароль 0000, а API доступен по сети.
  // Считаем неудачные попытки по логину и делаем паузу.
  static const _maxLoginAttempts = 5;
  static const _loginLockout = Duration(minutes: 15);
  final _loginFails = <String, ({int count, DateTime until})>{};

  void _registerLoginFailure(String login) {
    final now = DateTime.now();
    _loginFails.removeWhere((_, v) => v.until.isBefore(now)); // чистим старое
    final prev = _loginFails[login];
    // until — одновременно окно подсчёта попыток и, после превышения лимита,
    // время до разблокировки.
    _loginFails[login] = (
      count: (prev == null ? 0 : prev.count) + 1,
      until: now.add(_loginLockout),
    );
  }

  Future<Response> _login(Request request) async {
    final body = await readJson(request);
    final login = (body['login'] as String?)?.trim().toLowerCase() ?? '';
    final password = body['password'] as String? ?? '';

    final fail = _loginFails[login];
    if (fail != null &&
        fail.count >= _maxLoginAttempts &&
        fail.until.isAfter(DateTime.now())) {
      final left = fail.until.difference(DateTime.now()).inMinutes + 1;
      return jsonError(
          429, 'Слишком много попыток входа. Повторите через $left мин.');
    }
    // Логин уникален во всей базе, поэтому компанию определяем по учётке.
    final user = await db.one(
      '''SELECT u.id::text AS id, u.org_id::text AS org_id, u.blocked,
                (u.password_hash = crypt(@p, u.password_hash)) AS ok
         FROM users u
         JOIN organizations o ON o.id = u.org_id AND o.deleted_at IS NULL
         WHERE lower(u.login) = @l AND u.deleted_at IS NULL''',
      {'l': login, 'p': password},
    );
    if (user == null) {
      _registerLoginFailure(login); // и для несуществующих — чтобы не перебирали
      return jsonError(404, 'Учётная запись не найдена');
    }
    if (user['blocked'] == true) {
      return jsonError(403, 'Учётная запись заблокирована');
    }
    if (user['ok'] != true) {
      _registerLoginFailure(login);
      return jsonError(401, 'Неверный пароль');
    }
    _loginFails.remove(login); // успешный вход снимает счётчик

    // В БД уходит только SHA-256 от токена; сам токен видит лишь клиент.
    final token = _token();
    await db.query(
      '''INSERT INTO sessions (user_id, token_hash, expires_at)
         VALUES (@u, @t, now() + interval '30 days')''',
      {'u': user['id'], 't': hashToken(token)},
    );
    final full =
        await db.one('$_userSelectAny AND u.id = @id', {'id': user['id']});
    await _log(user['org_id'] as String, user['id'] as String, 'Вход', 'user',
        user['id']);
    // Состояние подписки отдаём сразу: приложению не нужен второй запрос,
    // чтобы понять, показывать ли плашку об истечении.
    final org = await db.one(
      '''SELECT o.name, o.plan_kind,
                to_char(o.plan_until AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.USZ') AS plan_until,
                CASE WHEN o.is_blocked THEN 'blocked'
                     WHEN o.plan_until IS NOT NULL
                      AND now() <= o.plan_until + make_interval(days => o.grace_days)
                     THEN 'full' ELSE 'read_only' END AS access
         FROM organizations o WHERE o.id = @org''',
      {'org': user['org_id']},
    );
    return jsonOk({
      'user': full,
      'token': token,
      'subscription': {
        'access': org?['access'],
        'plan_kind': org?['plan_kind'],
        'plan_until': org?['plan_until'],
        'org_name': org?['name'],
        'support': _support,
      },
    });
  }

  // ===========================================================================
  // Регистрация
  // ===========================================================================

  /// Самостоятельная регистрация застройщика.
  ///
  /// Создаёт компанию и первого пользователя в ней — администратора. Дальше он
  /// сам заводит менеджеров: отдельной роли «владелец» нет, потому что первый
  /// администратор ничем не отличается от созданных им позже.
  ///
  /// Компания получает пробный период из умолчаний таблицы `organizations`
  /// (3 дня), поэтому здесь про сроки ничего не сказано: правило живёт в одном
  /// месте — в схеме.
  ///
  /// Накрутку пробных периодов ограничивает уникальность телефона: номер
  /// уникален во всей базе, поэтому с одного номера компанию можно завести
  /// только один раз.
  Future<Response> _register(Request request) async {
    final body = await readJson(request);
    final name = (body['name'] as String?)?.trim() ?? '';
    final company = (body['company'] as String?)?.trim() ?? '';
    final phone = _normalizePhone((body['phone'] as String?) ?? '');
    final login = (body['login'] as String?)?.trim().toLowerCase() ?? '';
    final password = body['password'] as String? ?? '';

    // Проверки повторяют те, что стоят в приложении: клиент можно подменить.
    if (name.length < 3) return jsonError(422, 'Укажите фамилию, имя и отчество');
    if (company.length < 2) return jsonError(422, 'Укажите название компании');
    // Верхняя граница - предел международного формата E.164 (15 цифр).
    final phoneDigits = phone.replaceAll('+', '');
    if (phoneDigits.length < 7 || phoneDigits.length > 15) {
      return jsonError(422, 'Укажите номер телефона');
    }
    if (!RegExp(r'^[a-z0-9._-]{3,32}$').hasMatch(login)) {
      return jsonError(
          422,
          'Логин: латинские буквы, цифры, точка, дефис или подчёркивание, '
          'от 3 до 32 символов');
    }
    if (password.length < 6) {
      return jsonError(422, 'Пароль должен быть не короче 6 символов');
    }

    // Заранее — чтобы вместо кода нарушения уникальности человек увидел,
    // что именно занято. Гонку всё равно ловим ниже по SQLSTATE.
    final taken = await db.one(
      '''SELECT bool_or(lower(login) = @l) AS login_taken,
                bool_or(phone = @p)        AS phone_taken
         FROM users WHERE deleted_at IS NULL AND (lower(login) = @l OR phone = @p)''',
      {'l': login, 'p': phone},
    );
    if (taken?['login_taken'] == true) {
      return jsonError(409, 'Такой логин уже занят — придумайте другой');
    }
    if (taken?['phone_taken'] == true) {
      return jsonError(
          409, 'Этот номер уже зарегистрирован. Войдите под своим логином.');
    }

    final token = _token();
    Map<String, dynamic> created;
    try {
      created = await db.tx((tx) async {
        final org = await tx.one(
          '''INSERT INTO organizations (code, name)
             VALUES (@code, @name)
             RETURNING id::text AS id, name, plan_kind,
                       to_char(plan_until AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.USZ') AS plan_until''',
          {'code': _orgCode(company), 'name': company},
        );
        final orgId = org!['id'] as String;

        // must_change_password = false: пароль человек выбрал сам, менять его
        // на первом же экране незачем.
        final user = await tx.one(
          '''INSERT INTO users (org_id, full_name, login, phone,
                                password_hash, must_change_password)
             VALUES (@org, @name, @login, @phone,
                     crypt(@pass, gen_salt('bf')), false)
             RETURNING id::text AS id''',
          {
            'org': orgId,
            'name': name,
            'login': login,
            'phone': phone,
            'pass': password,
          },
        );
        final userId = user!['id'] as String;

        await tx.query(
          "INSERT INTO user_roles (user_id, role_code) VALUES (@u, 'admin')",
          {'u': userId},
        );
        await tx.query(
          '''INSERT INTO sessions (user_id, token_hash, expires_at)
             VALUES (@u, @t, now() + interval '30 days')''',
          {'u': userId, 't': hashToken(token)},
        );
        return {'org': org, 'user_id': userId};
      });
    } catch (e) {
      // Между проверкой выше и вставкой мог вклиниться другой запрос.
      if (pgErrorCode(e) == '23505') {
        return jsonError(409, 'Такой логин или номер уже зарегистрирован');
      }
      rethrow;
    }

    final org = created['org'] as Map<String, dynamic>;
    final userId = created['user_id'] as String;
    final orgId = org['id'] as String;
    final full = await db.one('$_userSelectAny AND u.id = @id', {'id': userId});
    await _log(orgId, userId, 'Регистрация компании', 'org', orgId);

    return jsonOk({
      'user': full,
      'token': token,
      'subscription': {
        'access': 'full', // компания только что создана — пробный период идёт
        'plan_kind': org['plan_kind'],
        'plan_until': org['plan_until'],
        'org_name': org['name'],
        'support': _support,
      },
    });
  }

  /// Убирает из телефона оформление, сохраняя способ записи.
  ///
  /// Принимаются оба вида: местный «0700 123456» и международный
  /// «+996 700 123456». Код страны не подставляется и не отбрасывается —
  /// клиенты из разных стран, а угадывать страну по длине номера значит
  /// однажды подставить чужую.
  ///
  /// Нормализация нужна, чтобы «0700 123456» и «0700-123456» были одним
  /// номером: иначе уникальность телефона обходится пробелом.
  static String _normalizePhone(String raw) {
    final trimmed = raw.trim();
    var digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    // 00 в начале - тот же международный префикс, что и плюс.
    final international =
        trimmed.startsWith('+') || digits.startsWith('00');
    if (digits.startsWith('00')) digits = digits.substring(2);
    if (digits.isEmpty) return '';
    return international ? '+$digits' : digits;
  }

  /// Короткий латинский код компании: он виден в журнале и в панели
  /// суперадминистратора, поэтому кириллицу транслитерируем.
  ///
  /// Хвост из случайных символов нужен, чтобы две «Панорамы» не столкнулись на
  /// уникальном индексе.
  String _orgCode(String company) {
    const map = {
      'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ё': 'e',
      'ж': 'zh', 'з': 'z', 'и': 'i', 'й': 'y', 'к': 'k', 'л': 'l', 'м': 'm',
      'н': 'n', 'о': 'o', 'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'у': 'u',
      'ф': 'f', 'х': 'h', 'ц': 'c', 'ч': 'ch', 'ш': 'sh', 'щ': 'sch',
      'ъ': '', 'ы': 'y', 'ь': '', 'э': 'e', 'ю': 'yu', 'я': 'ya',
      'ң': 'n', 'ө': 'o', 'ү': 'u',
    };
    final buffer = StringBuffer();
    for (final ch in company.toLowerCase().split('')) {
      if (map.containsKey(ch)) {
        buffer.write(map[ch]);
      } else if (RegExp(r'[a-z0-9]').hasMatch(ch)) {
        buffer.write(ch);
      } else if (buffer.isNotEmpty && !buffer.toString().endsWith('-')) {
        buffer.write('-');
      }
    }
    var slug = buffer.toString().replaceAll(RegExp(r'-+$'), '');
    if (slug.length > 24) slug = slug.substring(0, 24);
    if (slug.isEmpty) slug = 'org';
    final tail = _rnd.nextInt(0xFFFF).toRadixString(16).padLeft(4, '0');
    return '$slug-$tail';
  }

  /// Отзыв текущей сессии — токен сразу перестаёт работать.
  Future<Response> _logout(Request request) async {
    final me = _me(request);
    await db.query(
      'UPDATE sessions SET revoked_at=now() WHERE id=@s AND revoked_at IS NULL',
      {'s': me.sessionId},
    );
    await _log(me.orgId, me.userId, 'Выход', 'user', me.userId);
    return jsonOk({'ok': true});
  }

  /// Контакты для продления подписки.
  ///
  /// По умолчанию — контакты владельца сервиса, чтобы кнопка «Связаться»
  /// работала сразу после установки. Переменные окружения их перекрывают,
  /// когда контакты поменяются или сервис передадут другим людям:
  ///   SUPPORT_EMAIL=sales@example.kg
  ///   SUPPORT_URL=https://wa.me/996555112233
  static const _defaultSupportEmail = 'esoyuzbekov@gmail.com';
  static const _defaultSupportUrl = 'https://wa.me/996777060412';

  /// Пустая строка в переменной окружения — это «контакта нет», а не
  /// «подставь значение по умолчанию»: так контакт можно осознанно убрать.
  static String _env(String name, String fallback) {
    final value = Platform.environment[name];
    return value == null ? fallback : value.trim();
  }

  static Map<String, String> get _support => {
        'email': _env('SUPPORT_EMAIL', _defaultSupportEmail),
        'url': _env('SUPPORT_URL', _defaultSupportUrl),
      };

  /// Состояние подписки в виде, пригодном для приложения.
  Map<String, dynamic> _subscriptionJson(AuthContext me) => {
        'access': me.access.wire,
        'plan_kind': me.planKind,
        'plan_until': me.planUntil,
        'org_name': me.orgName,
        'support': _support,
      };

  /// Кто я по мнению сервера — для проверки живости токена при старте app.
  Future<Response> _meRoute(Request request) async {
    final me = _me(request);
    final user =
        await db.one('$_userSelect AND u.id=@id', {'id': me.userId, 'org': me.orgId});
    return jsonOk({
      ...?user,
      'org_code': me.orgCode,
      'is_superadmin': me.isSuperadmin,
      'subscription': _subscriptionJson(me),
    });
  }

  // ===========================================================================
  // Суперадминистратор
  //
  // Единственная роль, которая видит данные всех компаний. Поэтому здесь нет
  // фильтра по org_id — вместо него на входе каждой ручки стоит _superOnly.
  // ===========================================================================

  /// Вернуть 403, если автор не суперадминистратор.
  Response? _superOnly(Request request) => _me(request).isSuperadmin
      ? null
      : jsonError(403, 'Действие доступно только суперадминистратору');

  /// Компании с подписками, администраторами и размером.
  ///
  /// По менеджерам отдаём только количество: суперадминистратору незачем видеть
  /// поимённый состав отделов продаж чужих компаний.
  Future<Response> _superOrgs(Request request) async {
    final denied = _superOnly(request);
    if (denied != null) return denied;

    return jsonOk(await db.query('''
      SELECT o.id::text AS id, o.code, o.name, o.plan_kind, o.grace_days,
             o.is_blocked,
             to_char(o.plan_until AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.USZ') AS plan_until,
             to_char(o.created_at AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.USZ') AS created_at,
             CASE WHEN o.is_blocked THEN 'blocked'
                  WHEN o.plan_until IS NOT NULL
                   AND now() <= o.plan_until + make_interval(days => o.grace_days)
                  THEN 'full' ELSE 'read_only' END AS access,
             (SELECT count(*) FROM users u
               WHERE u.org_id = o.id AND u.deleted_at IS NULL AND u.blocked = false
                 AND EXISTS (SELECT 1 FROM user_roles r
                              WHERE r.user_id = u.id AND r.role_code = 'manager')) AS managers,
             (SELECT count(*) FROM apartments a
               WHERE a.org_id = o.id AND a.deleted_at IS NULL) AS apartments,
             COALESCE((SELECT json_agg(json_build_object(
                   'id', au.id::text, 'name', au.full_name, 'login', au.login,
                   'phone', au.phone, 'blocked', au.blocked) ORDER BY au.login)
                 FROM users au
                 WHERE au.org_id = o.id AND au.deleted_at IS NULL
                   AND EXISTS (SELECT 1 FROM user_roles r
                                WHERE r.user_id = au.id AND r.role_code = 'admin')
               ), '[]'::json) AS admins
      FROM organizations o
      WHERE o.deleted_at IS NULL AND o.code <> 'system'
      ORDER BY o.name'''));
  }

  /// Продлить подписку компании на [months] месяцев.
  ///
  /// Если подписка ещё действует, продлеваем от её конца, иначе от сегодня —
  /// иначе оплата за месяц во время действующей подписки съедала бы остаток.
  Future<Response> _superSubscribe(Request request, String id) async {
    final denied = _superOnly(request);
    if (denied != null) return denied;
    final me = _me(request);
    final b = await readJson(request);
    final months = ((b['months'] as num?)?.toInt() ?? 1).clamp(1, 60);
    final note = b['note'] as String?;

    final row = await db.one(
      '''UPDATE organizations
         SET plan_kind = 'paid',
             plan_until = GREATEST(COALESCE(plan_until, now()), now())
                          + make_interval(months => @m),
             grace_days = 3,
             is_blocked = false,
             updated_at = now()
         WHERE id = @id AND deleted_at IS NULL
         RETURNING to_char(plan_until AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.USZ') AS plan_until,
                   plan_until AS raw''',
      {'m': months, 'id': id},
    );
    if (row == null) return jsonError(404, 'Компания не найдена');

    await db.query(
      '''INSERT INTO subscriptions (org_id, kind, ends_at, note, created_by)
         VALUES (@org, 'paid', @ends, @note, @by)''',
      {'org': id, 'ends': row['raw'], 'note': note, 'by': me.userId},
    );
    await _log(me.orgId, me.userId, 'Продление подписки (+$months мес.)',
        'organization', id);

    // Компания снова работает — сообщаем её администраторам.
    await _notifyUsers(await _adminIds(id), 'account', 'Подписка продлена',
        'Доступ активен до ${row['plan_until']}', null);

    return jsonOk({'plan_until': row['plan_until'], 'months': months});
  }

  /// Приостановить или возобновить работу компании.
  Future<Response> _superBlock(Request request, String id) async {
    final denied = _superOnly(request);
    if (denied != null) return denied;
    final me = _me(request);
    final b = await readJson(request);
    final blocked = b['blocked'] == true;

    final rows = await db.query(
      '''UPDATE organizations SET is_blocked = @v, updated_at = now()
         WHERE id = @id AND deleted_at IS NULL RETURNING id''',
      {'v': blocked, 'id': id},
    );
    if (rows.isEmpty) return jsonError(404, 'Компания не найдена');

    await _log(me.orgId, me.userId,
        blocked ? 'Компания приостановлена' : 'Компания возобновлена',
        'organization', id);
    return jsonOk({'blocked': blocked});
  }

  // ===========================================================================
  // Пользователи
  // ===========================================================================

  /// Список сотрудников — только своей компании.
  Future<Response> _users(Request request) async => jsonOk(await db.query(
        '$_userSelect ORDER BY u.login',
        {'org': _me(request).orgId},
      ));

  Future<Response> _createUser(Request request) async {
    final denied = _adminOnly(request);
    if (denied != null) return denied;
    final me = _me(request);
    final b = await readJson(request);
    // Роль приходит от клиента, поэтому список допустимых - здесь, а не там.
    // Суперадминистратора из приложения не создать: он один на весь сервис.
    final role = b['role'] == 'admin' ? 'admin' : 'manager';

    // Те же правила, что и при регистрации: иначе через этот путь в базу
    // попадали пустые имена, а null превращался в 500 про миграции.
    final name = (b['name'] as String?)?.trim() ?? '';
    final login = (b['login'] as String?)?.trim().toLowerCase() ?? '';
    final phone = _normalizePhone((b['phone'] as String?) ?? '');
    if (name.length < 3 || name.length > 120) {
      return jsonError(422, 'Укажите фамилию, имя и отчество');
    }
    if (!RegExp(r'^[a-z0-9._-]{3,32}$').hasMatch(login)) {
      return jsonError(
          422,
          'Логин: латинские буквы, цифры, точка, дефис или подчёркивание, '
          'от 3 до 32 символов');
    }
    final phoneDigits = phone.replaceAll('+', '');
    if (phoneDigits.length < 7 || phoneDigits.length > 15) {
      return jsonError(422, 'Укажите номер телефона');
    }

    final taken = await db.one(
      '''SELECT bool_or(lower(login) = @l) AS login_taken,
                bool_or(phone = @p)        AS phone_taken
         FROM users WHERE deleted_at IS NULL AND (lower(login) = @l OR phone = @p)''',
      {'l': login, 'p': phone},
    );
    if (taken?['login_taken'] == true) {
      return jsonError(409, 'Такой логин уже занят — придумайте другой');
    }
    if (taken?['phone_taken'] == true) {
      return jsonError(409, 'Этот номер уже используется другим сотрудником');
    }

    final row = await db.one(
      '''WITH nu AS (
           INSERT INTO users (org_id, full_name, login, phone, password_hash,
                              must_change_password, created_by, updated_by)
           VALUES (@org, @name, lower(@login), @phone,
                   crypt('0000', gen_salt('bf')), true, @by, @by)
           RETURNING id
         ), ur AS (
           INSERT INTO user_roles (user_id, role_code)
           SELECT id, @role FROM nu RETURNING user_id
         )
         SELECT id::text AS id FROM nu''',
      {
        'name': name,
        'login': login,
        'phone': phone,
        'role': role,
        'by': me.userId,
        'org': me.orgId,
      },
    );
    final user = await db.one(
        '$_userSelect AND u.id = @id', {'id': row!['id'], 'org': me.orgId});
    await _log(me.orgId, me.userId, 'Создан пользователь', 'user', row['id']);
    return jsonOk(user);
  }

  Future<Response> _blockUser(Request request, String id) async {
    final denied = _adminOnly(request);
    if (denied != null) return denied;
    final me = _me(request);
    if (id == me.userId) {
      return jsonError(422, 'Нельзя заблокировать собственную учётную запись');
    }
    if (!await _userInOrg(me, id)) {
      return jsonError(404, 'Учётная запись не найдена');
    }
    final b = await readJson(request);
    await db.query(
      '''UPDATE users SET blocked=@v, updated_at=now(), updated_by=@by,
             version=version+1
         WHERE id=@id AND org_id=@org''',
      {'v': b['blocked'] == true, 'id': id, 'by': me.userId, 'org': me.orgId},
    );
    if (b['blocked'] == true) {
      // Блокировка немедленно рвёт все живые сессии пользователя.
      await db.query('UPDATE sessions SET revoked_at=now() WHERE user_id=@id AND revoked_at IS NULL', {'id': id});
    }
    await _log(me.orgId, me.userId,
        b['blocked'] == true ? 'Блокировка пользователя' : 'Разблокировка пользователя',
        'user', id);
    return jsonOk(await db.one(
        '$_userSelect AND u.id=@id', {'id': id, 'org': me.orgId}));
  }

  Future<Response> _roleUser(Request request, String id) async {
    final denied = _adminOnly(request);
    if (denied != null) return denied;
    final me = _me(request);
    if (id == me.userId) {
      return jsonError(422, 'Нельзя менять роль собственной учётной записи');
    }
    if (!await _userInOrg(me, id)) {
      return jsonError(404, 'Учётная запись не найдена');
    }
    final b = await readJson(request);
    if (b['role'] != 'admin' && b['role'] != 'manager') {
      return jsonError(422, 'Неизвестная роль');
    }
    await db.query(
      '''INSERT INTO user_roles (user_id, role_code) VALUES (@id, @r)
         ON CONFLICT (user_id, role_code) DO NOTHING''',
      {'id': id, 'r': b['role']},
    );
    await db.query(
      'DELETE FROM user_roles WHERE user_id=@id AND role_code<>@r',
      {'id': id, 'r': b['role']},
    );
    await _log(me.orgId, me.userId, 'Смена роли → ${b['role']}', 'user', id);
    return jsonOk(await db.one(
        '$_userSelect AND u.id=@id', {'id': id, 'org': me.orgId}));
  }

  Future<Response> _changePassword(Request request, String id) async {
    final me = _me(request);
    // Свой пароль меняет любой; чужой — только администратор.
    if (id != me.userId && !me.isAdmin) {
      return jsonError(403, 'Менять чужой пароль может только администратор');
    }
    if (!await _userInOrg(me, id)) {
      return jsonError(404, 'Учётная запись не найдена');
    }
    final b = await readJson(request);
    final password = b['new_password'] as String? ?? '';
    if (password.length < 4) {
      return jsonError(422, 'Пароль слишком короткий');
    }
    // Свой пароль — постоянный. Пароль, назначенный администратором чужой
    // учётке, считается временным: пользователь обязан сменить его при входе
    // (FR-01.3). Раньше флаг снимался в обоих случаях.
    final isReset = id != me.userId;

    // Смену СВОЕГО пароля подтверждаем текущим. Без этого достаточно было
    // добраться до чужого открытого приложения (или до его токена), чтобы
    // сменить пароль, не зная старого: приложение спрашивало текущий пароль,
    // но сервер его не проверял, и запрос в обход приложения проходил.
    //
    // Исключение — обязательная первая смена: временный пароль пользователь
    // только что ввёл на экране входа, второй раз спрашивать его незачем.
    if (!isReset) {
      final self = await db.one(
        '''SELECT must_change_password AS forced,
                  (password_hash = crypt(@p, password_hash)) AS ok
           FROM users WHERE id=@id AND org_id=@org AND deleted_at IS NULL''',
        {'id': id, 'org': me.orgId, 'p': b['current_password'] as String? ?? ''},
      );
      if (self == null) return jsonError(404, 'Учётная запись не найдена');
      if (self['forced'] != true && self['ok'] != true) {
        return jsonError(403, 'Текущий пароль указан неверно');
      }
    }
    await db.query(
      '''UPDATE users SET password_hash = crypt(@p, gen_salt('bf')),
             must_change_password = @tmp, updated_at=now(), updated_by=@by,
             version=version+1
         WHERE id=@id AND org_id=@org AND deleted_at IS NULL''',
      {
        'p': password,
        'id': id,
        'by': me.userId,
        'org': me.orgId,
        'tmp': isReset,
      },
    );
    // Смена пароля разлогинивает все прочие устройства этого пользователя.
    await db.query(
      '''UPDATE sessions SET revoked_at=now()
         WHERE user_id=@id AND revoked_at IS NULL AND id <> @s''',
      {'id': id, 's': me.sessionId},
    );
    await _log(me.orgId, me.userId, 'Смена пароля', 'user', id);
    return jsonOk(await db.one(
        '$_userSelect AND u.id=@id', {'id': id, 'org': me.orgId}));
  }

  // ===========================================================================
  // Недвижимость
  // ===========================================================================

  Future<Response> _complexes(Request request) async => jsonOk(
        (await db.query('$_complexSelect ORDER BY c.created_at',
                {'org': _me(request).orgId}))
            .map(_complexJson)
            .toList(),
      );

  static const _covers = [
    [0xFF1E3A8A, 0xFF3B82F6],
    [0xFF065F46, 0xFF10B981],
    [0xFF7C2D12, 0xFFF59E0B],
    [0xFF4C1D95, 0xFF8B5CF6],
    [0xFF9F1239, 0xFFF43F5E],
    [0xFF0F766E, 0xFF2DD4BF],
  ];

  Future<Response> _createComplex(Request request) async {
    final denied = _adminOnly(request);
    if (denied != null) return denied;
    final me = _me(request);
    final b = await readJson(request);
    final n = (await db.one(
        'SELECT count(*) AS n FROM complexes WHERE org_id=@org',
        {'org': me.orgId}))!['n'] as int;
    final cover = _covers[n % _covers.length];
    final row = await db.one(
      '''INSERT INTO complexes (org_id, name, address, deadline, segment,
                                cover_start, cover_end, created_by, updated_by)
         VALUES (@org, @name, @address, @deadline, @segment, @cs, @ce, @by, @by)
         RETURNING id''',
      {
        'name': b['name'],
        'address': b['address'],
        'deadline': b['deadline'],
        'segment': b['segment'],
        'cs': cover[0],
        'ce': cover[1],
        'by': me.userId,
        'org': me.orgId,
      },
    );
    await _log(me.orgId, me.userId, 'Создан объект', 'complex', row!['id']);
    return jsonOk(
      _complexJson((await db.one('$_complexSelect AND c.id=@id',
          {'id': row['id'], 'org': me.orgId}))!),
    );
  }

  Future<Response> _bulkBlock(Request request) async {
    final denied = _adminOnly(request);
    if (denied != null) return denied;
    final me = _me(request);
    final b = await readJson(request);
    // Приведение вслепую превращало кривой запрос в 500 с системным текстом.
    final complexId = (b['complex_id'] as String?)?.trim() ?? '';
    if (complexId.isEmpty) return jsonError(422, 'Не указан объект');
    // Объект обязан принадлежать компании автора.
    final owns = await db.one(
      'SELECT 1 AS x FROM complexes WHERE id=@c AND org_id=@org AND deleted_at IS NULL',
      {'c': complexId, 'org': me.orgId},
    );
    if (owns == null) return jsonError(404, 'Объект не найден');

    // Идемпотентность (FR-03.7): повторная отправка того же мастера — например
    // после обрыва связи или второго нажатия — не должна создавать блок дважды.
    final key = (b['idempotency_key'] as String?)?.trim();
    final hasKey = key != null && key.isNotEmpty;
    if (hasKey) {
      final prev = await db.one(
        '''SELECT affected_count FROM bulk_operations
           WHERE idempotency_key=@k AND org_id=@org''',
        {'k': key, 'org': me.orgId},
      );
      if (prev != null) {
        // Уже выполняли — отдаём прежний результат, ничего не создавая.
        return jsonOk({'created': prev['affected_count'], 'repeated': true});
      }
    }

    final blockName = (b['block'] as String?)?.trim() ?? '';
    if (blockName.isEmpty) return jsonError(422, 'Не указано название блока');
    if (blockName.length > 40) {
      return jsonError(422, 'Название блока длиннее 40 символов');
    }
    // Имя блока уникально внутри объекта. Без этой проверки повторный запуск
    // мастера с тем же названием упирался в уникальный индекс и возвращал
    // «Такая запись уже существует» - по такому тексту непонятно, что делать,
    // и выглядело это как неработающая кнопка.
    final busy = await db.one(
      '''SELECT 1 AS x FROM blocks
         WHERE complex_id=@c AND lower(name)=lower(@n) AND deleted_at IS NULL''',
      {'c': complexId, 'n': blockName},
    );
    if (busy != null) {
      return jsonError(
          409,
          'Блок «$blockName» в этом объекте уже есть. '
          'Задайте другое название блока.');
    }

    final startNumber = (b['start_number'] as num?)?.toInt() ?? 1;
    final groups = (b['groups'] as List?) ?? const [];
    if (groups.isEmpty) {
      return jsonError(422, 'Не задано ни одной группы этажей');
    }
    // Ниже идёт цикл по этажам: без верхней границы запрос вида
    // floor_to = 1000000 занял бы сервер надолго.
    for (final g in groups) {
      if (g is! Map) return jsonError(422, 'Неверный формат групп этажей');
      final from = (g['floor_from'] as num?)?.toInt();
      final to = (g['floor_to'] as num?)?.toInt();
      final rooms = g['rooms'];
      if (from == null || to == null || rooms is! List || rooms.isEmpty) {
        return jsonError(422, 'В группе этажей не хватает данных');
      }
      if (from < 1 || to < from || to > 200) {
        return jsonError(422, 'Этажи: от 1 до 200, и «по» не меньше «с»');
      }
      if (rooms.length > 40) {
        return jsonError(422, 'Слишком много квартир на этаже (максимум 40)');
      }
      if (rooms.any((r) => r is! num || r < 0 || r > 9)) {
        return jsonError(422, 'Комнатность — число от 0 до 9');
      }
    }
    // Приведение вслепую ((e as num)) на строке в списке давало 500 вместо
    // внятного отказа. Нечисловые значения просто отбрасываем.
    Set<int> intSet(Object? raw) => ((raw as List?) ?? const [])
        .whereType<num>()
        .map((e) => e.toInt())
        .toSet();
    final technical = intSet(b['technical_floors']);
    final skip = intSet(b['skip_numbers']);

    const areaByRooms = {
      0: 31.0, 1: 42.0, 2: 60.0, 3: 84.0, 4: 114.0, 5: 138.0, 6: 165.0,
    };
    const kitchenByRooms = {
      0: 'кухня-ниша', 1: '12.4 м²', 2: '14.8 м²', 3: '16.2 м²',
      4: '18.0 м²', 5: '20.5 м²', 6: '24.0 м²',
    };

    // Гонка двух одинаковых запросов: второй упирается в уникальный ключ
    // операции. Это не ошибка — просто отдаём результат первого.
    int created;
    try {
      created = await db.tx((s) async {
        // Запись создаём первой: уникальный индекс по ключу не даст двум
        // одновременным запросам выполнить операцию дважды — второй откатится.
        if (hasKey) {
          await s.query(
            '''INSERT INTO bulk_operations (org_id, idempotency_key, complex_id,
                                            block_name, params, created_by)
               VALUES (@org, @k, @c, @bn, @params::jsonb, @by)''',
            {
              'org': me.orgId,
              'k': key,
              'c': complexId,
              'bn': blockName,
              'params': jsonEncode(b),
              'by': me.userId,
            },
          );
        }
        final blockRow = await s.one(
          '''INSERT INTO blocks (org_id, complex_id, name, floors, units_per_floor)
             VALUES (@org, @c, @n, @f, @u) RETURNING id''',
          {
            'org': me.orgId,
            'c': complexId,
            'n': blockName,
            'f': groups.isEmpty
                ? 1
                : groups
                    .map((g) => (g['floor_to'] as num).toInt())
                    .reduce((a, c) => a > c ? a : c),
            'u': groups.isEmpty
                ? 1
                : (groups.first['rooms'] as List).length,
          },
        );
        final blockId = blockRow!['id'];
        final maxFloor = groups
            .map((g) => (g['floor_to'] as num).toInt())
            .fold(0, (a, c) => a > c ? a : c);

        var number = startNumber;
        var count = 0;
        for (var floor = 1; floor <= maxFloor; floor++) {
          if (technical.contains(floor)) continue;
          final group = groups.cast<Map<String, dynamic>>().where((g) =>
              floor >= (g['floor_from'] as num) &&
              floor <= (g['floor_to'] as num)).firstOrNull;
          if (group == null) continue;
          final rooms = (group['rooms'] as List).cast<num>();
          for (var pos = 0; pos < rooms.length; pos++) {
            while (skip.contains(number)) {
              number++;
            }
            final r = rooms[pos].toInt();
            await s.query(
              '''INSERT INTO apartments
                   (org_id, block_id, complex_id, floor, position, number, rooms,
                    area, status, kitchen, view, finish, bathrooms)
                 VALUES (@org, @b, @c, @f, @p, @n, @r, @area, 'free', @kit, @view,
                         @fin, @bath)''',
              {
                'org': me.orgId,
                'b': blockId,
                'c': complexId,
                'f': floor,
                'p': pos + 1,
                'n': number,
                'r': r,
                'area': areaByRooms[r] ?? 42.0,
                'kit': kitchenByRooms[r] ?? '',
                'view': pos.isEven ? 'на Ала-Тоо' : 'во двор, тихая сторона',
                'fin': r >= 3 ? 'предчистовая' : 'без отделки',
                'bath': r >= 3 ? 2 : 1,
              },
            );
            number++;
            count++;
          }
        }
        if (hasKey) {
          await s.query(
            '''UPDATE bulk_operations SET affected_count=@n
               WHERE idempotency_key=@k AND org_id=@org''',
            {'n': count, 'k': key, 'org': me.orgId},
          );
        }
        return count;
      });
    } catch (e) {
      if (hasKey && pgErrorCode(e) == '23505') {
        final prev = await db.one(
          '''SELECT affected_count FROM bulk_operations
             WHERE idempotency_key=@k AND org_id=@org''',
          {'k': key, 'org': me.orgId},
        );
        if (prev != null) {
          return jsonOk({'created': prev['affected_count'], 'repeated': true});
        }
      }
      rethrow;
    }
    await _log(me.orgId, me.userId, 'Массовое создание квартир ($created)',
        'complex', complexId);
    return jsonOk({'created': created});
  }

  // ===========================================================================
  // Фонд (список; действия — в actions.dart части ниже)
  // ===========================================================================

  /// Список фонда — без истории по каждой квартире.
  ///
  /// `?since=<ISO-8601>` возвращает только изменившиеся с этого момента
  /// квартиры. Приложение опрашивает фонд каждые 15 секунд, и без этого
  /// каждый раз выкачивался весь фонд целиком.
  ///
  /// Сравнение строгое (`>`). С нестрогим квартиры, созданные одной
  /// транзакцией (у них одинаковый `updated_at`), попадали бы в КАЖДУЮ
  /// выборку — дельта не давала бы ничего. Риск пропустить изменение,
  /// закоммиченное задним числом, закрыт полным перечитыванием фонда,
  /// которое клиент делает раз в несколько минут.
  Future<Response> _units(Request request) async {
    final me = _me(request);
    final raw = request.url.queryParameters['since'];
    final since = (raw == null || raw.isEmpty) ? null : DateTime.tryParse(raw);

    final where = since == null
        ? 'WHERE a.deleted_at IS NULL AND a.org_id=@org'
        : 'WHERE a.deleted_at IS NULL AND a.org_id=@org AND a.updated_at > @since';

    // Строки отдаём как есть: _unitJson подставил бы пустой history, а он в
    // списке не нужен вовсе.
    return jsonOk(await db.query(
      '$_unitListSelect $where ORDER BY c.name, b.name, a.number',
      {'org': me.orgId, if (since != null) 'since': since},
    ));
  }

  /// Одна квартира целиком, вместе с историей.
  Future<Response> _unit(Request request, String id) async {
    final me = _me(request);
    final unit = await _unitById(id, me.orgId);
    if (unit == null) return jsonError(404, 'Квартира не найдена');
    return jsonOk(unit);
  }

  // ===========================================================================
  // Клиенты
  // ===========================================================================

  /// Менеджер видит только своих клиентов, администратор — всех (FR-05.2).
  Future<Response> _clients(Request request) async {
    final me = _me(request);
    return jsonOk(await db.query(
      me.isAdmin
          ? '$_clientSelect ORDER BY cl.created_at DESC'
          : '$_clientSelect AND cl.seller_id=@me ORDER BY cl.created_at DESC',
      me.isAdmin
          ? {'org': me.orgId}
          : {'org': me.orgId, 'me': me.userId},
    ));
  }

  Future<Response> _createClient(Request request) async {
    final me = _me(request);
    final b = await readJson(request);
    // Владелец записи — автор запроса. Администратор может завести клиента
    // на конкретного продавца, передав seller_id.
    final sellerId =
        me.isAdmin ? (b['seller_id'] as String? ?? me.userId) : me.userId;
    // Продавец обязан быть сотрудником той же компании.
    if (sellerId != me.userId && !await _userInOrg(me, sellerId)) {
      return jsonError(404, 'Продавец не найден');
    }
    final row = await db.one(
      '''INSERT INTO clients (org_id, full_name, phone, seller_id, rooms,
                              source, request, note)
         VALUES (@org, @name, @phone, @seller, @rooms, @source, @request, @note)
         ON CONFLICT (seller_id, phone) WHERE deleted_at IS NULL DO UPDATE SET full_name=EXCLUDED.full_name
         RETURNING id''',
      {
        'name': b['name'],
        'phone': b['phone'],
        'seller': sellerId,
        'rooms': (b['rooms'] as num?)?.toInt() ?? 0,
        'source': b['source'] ?? '',
        'request': b['request'] ?? '',
        'note': b['note'] ?? '',
        'org': me.orgId,
      },
    );
    return jsonOk(await db.one(
        '$_clientSelect AND cl.id=@id', {'id': row!['id'], 'org': me.orgId}));
  }

  // ===========================================================================
  // Действия с квартирой (переходы статусов)
  // ===========================================================================

  Future<Map<String, dynamic>?> _unitById(String id, String orgId) async {
    final row = await db.one(
      '$_unitSelect WHERE a.id=@id AND a.org_id=@org',
      {'id': id, 'org': orgId},
    );
    return row == null ? null : _unitJson(row);
  }

  /// Числовая настройка компании из таблицы `settings`.
  ///
  /// Раньше лимиты были зашиты в код числом 5. Значения по умолчанию остались
  /// на случай, если строки настройки нет — сервер не должен падать из-за
  /// отсутствующей записи.
  Future<int> _setting(String orgId, String key, int fallback) async {
    final row = await db.one(
      'SELECT value FROM settings WHERE org_id=@org AND key=@k',
      {'org': orgId, 'k': key},
    );
    final raw = row?['value'] as String?;
    final parsed = raw == null ? null : int.tryParse(raw.trim());
    return (parsed == null || parsed < 1) ? fallback : parsed;
  }

  Future<int> _heldCount(AuthContext me, String status) async {
    final r = await db.one(
      '''SELECT count(*) AS c FROM apartments
         WHERE held_by_id=@m AND status=@s AND org_id=@org AND deleted_at IS NULL''',
      {'m': me.userId, 's': status, 'org': me.orgId},
    );
    return r!['c'] as int;
  }

  Future<Response> _take(Request request, String id) async {
    final me = _me(request);
    final b = await readJson(request);
    final clientId = b['client_id'] as String?;
    if (!await _ownsClient(me, clientId)) {
      return jsonError(403, 'Клиент принадлежит другому менеджеру');
    }
    final workLimit = await _setting(me.orgId, 'work_limit', 5);
    if (!me.isAdmin && await _heldCount(me, 'work') >= workLimit) {
      return jsonError(422,
          'Достигнут лимит: квартир в работе — $workLimit. Освободите одну.');
    }
    return _apply(
      id,
      toStatus: 'work',
      from: const ['free'],
      orgId: me.orgId,
      managerId: me.userId,
      clientId: clientId,
      hold: "now() + interval '2 hours'",
      title: 'Взята в работу',
    );
  }

  /// Максимальный срок брони, дней. Больше — только продлением у админа.
  static const _maxBookingDays = 30;

  Future<Response> _book(Request request, String id) async {
    final me = _me(request);
    final b = await readJson(request);
    final clientId = b['client_id'] as String?;
    // Раньше срок был жёстко зашит в 3 дня, а приложение показывало срок,
    // выбранный пользователем, — цифры расходились.
    final defaultDays = await _setting(me.orgId, 'booking_days', 3);
    final days =
        ((b['days'] as num?)?.toInt() ?? defaultDays).clamp(1, _maxBookingDays);
    if (!await _ownsClient(me, clientId)) {
      return jsonError(403, 'Клиент принадлежит другому менеджеру');
    }
    final bookingLimit = await _setting(me.orgId, 'booking_limit', 5);
    if (!me.isAdmin && await _heldCount(me, 'hold') >= bookingLimit) {
      return jsonError(422,
          'Достигнут лимит: активных броней — $bookingLimit. Снимите одну.');
    }
    final res = await _apply(
      id,
      toStatus: 'hold',
      from: const ['free', 'work'],
      orgId: me.orgId,
      managerId: me.userId,
      clientId: clientId,
      // days уже приведён к int и ограничен диапазоном — подстановка безопасна.
      hold: 'now() + make_interval(days => $days)',
      title: 'Бронь на $days дн.',
    );
    if (res.statusCode == 200) {
      await _notifyTeam(me.userId, me.orgId, id, 'booked',
          'Квартира забронирована', 'Забронировал(а) ${me.name}');
    }
    return res;
  }

  Future<Response> _release(Request request, String id) async {
    final me = _me(request);
    // Чужую бронь снимает только администратор.
    if (!await _holdsUnit(me, id)) {
      return jsonError(403, 'Квартиру удерживает другой менеджер');
    }
    final res = await _apply(
      id,
      toStatus: 'free',
      from: const ['work', 'hold', 'design'],
      orgId: me.orgId,
      managerId: me.userId,
      clearHold: true,
      title: 'Снята с работы, вернулась в продажу',
    );
    if (res.statusCode == 200) {
      await _notifyTeam(me.userId, me.orgId, id, 'released',
          'Квартира освободилась', 'Снова свободна');
    }
    return res;
  }

  Future<Response> _design(Request request, String id) async {
    final me = _me(request);
    if (!await _holdsUnit(me, id)) {
      return jsonError(403, 'Квартиру удерживает другой менеджер');
    }
    final res = await _apply(
      id,
      toStatus: 'design',
      from: const ['hold'],
      orgId: me.orgId,
      managerId: me.userId,
      keepHolder: true,
      title: 'Отправлена на оформление',
    );
    // FR-11.5: отправлена на оформление → администратор.
    if (res.statusCode == 200) {
      final label = await _unitLabel(id);
      await _notifyUsers(
        await _adminIds(me.orgId),
        'design',
        'Квартира на оформление',
        '$label — ${me.name}',
        id,
      );
    }
    return res;
  }

  Future<Response> _sell(Request request, String id) async {
    // Подтверждение продажи — исключительно администратор (FR-06).
    final denied = _adminOnly(request);
    if (denied != null) return denied;
    return _apply(
      id,
      toStatus: 'sold',
      from: const ['design'],
      orgId: _me(request).orgId,
      managerId: _me(request).userId,
      keepHolder: true,
      title: 'Продажа подтверждена',
    );
  }

  static const _statuses = {'free', 'work', 'hold', 'design', 'sold', 'off_market'};

  Future<Response> _setStatus(Request request, String id) async {
    // Произвольная смена статуса в обход воронки — только администратор.
    final denied = _adminOnly(request);
    if (denied != null) return denied;
    final b = await readJson(request);
    final status = b['status'] as String? ?? '';
    if (!_statuses.contains(status)) return jsonError(422, 'Неизвестный статус');
    final clear = status == 'free' || status == 'off_market';
    return _apply(
      id,
      toStatus: status,
      from: const ['free', 'work', 'hold', 'design', 'sold', 'off_market'],
      orgId: _me(request).orgId,
      managerId: _me(request).userId,
      clearHold: clear,
      keepHolder: !clear,
      title: status == 'off_market' ? 'Снята с продажи' : 'Изменение статуса',
    );
  }

  Future<Response> _extend(Request request, String id) async {
    final me = _me(request);
    if (!await _holdsUnit(me, id)) {
      return jsonError(403, 'Квартиру удерживает другой менеджер');
    }
    final b = await readJson(request);
    final days = ((b['days'] as num?)?.toInt() ?? 3).clamp(1, 30);
    await db.query(
      '''UPDATE apartments
         SET held_until = COALESCE(held_until, now()) + make_interval(days => @d),
             updated_at=now(), version=version+1
         WHERE id=@id AND org_id=@org AND deleted_at IS NULL''',
      {'d': days, 'id': id, 'org': me.orgId},
    );
    await _log(me.orgId, me.userId, 'Продление брони (+$days дн.)', 'apartment', id);
    return jsonOk(await _unitById(id, me.orgId));
  }

  /// Менеджер просит администратора продлить свою бронь (FR-07.8).
  ///
  /// Раньше приложение показывало «Запрос отправлен администратору», но
  /// никуда не обращалось — администратор ничего не получал.
  Future<Response> _extendRequest(Request request, String id) async {
    final me = _me(request);
    if (!await _holdsUnit(me, id)) {
      return jsonError(403, 'Квартиру удерживает другой менеджер');
    }
    final label = await _unitLabel(id);
    await _notifyUsers(
      await _adminIds(me.orgId),
      'extend_request',
      'Запрос на продление брони',
      '$label — просит ${me.name}',
      id,
    );
    await _log(me.orgId, me.userId, 'Запрос на продление брони', 'apartment', id);
    return jsonOk({'ok': true});
  }

  Future<Response> _updateUnit(Request request, String id) async {
    // Правка карточки квартиры — админский редактор фонда.
    final denied = _adminOnly(request);
    if (denied != null) return denied;
    final me = _me(request);
    final b = await readJson(request);
    final status = b['status'] as String? ?? 'free';
    if (!_statuses.contains(status)) return jsonError(422, 'Неизвестный статус');
    final rows = await db.query(
      '''UPDATE apartments SET rooms=@rooms, area=@area, status=@status,
             kitchen=@kitchen, view=@view, finish=@finish, bathrooms=@bath,
             updated_at=now(), updated_by=@by, version=version+1
         WHERE id=@id AND org_id=@org AND deleted_at IS NULL
         RETURNING id''',
      {
        'rooms': (b['rooms'] as num?)?.toInt() ?? 0,
        'area': (b['area'] as num?)?.toDouble() ?? 0,
        'status': status,
        'kitchen': b['kitchen'] ?? '',
        'view': b['view'] ?? '',
        'finish': b['finish'] ?? '',
        'bath': (b['bathrooms'] as num?)?.toInt() ?? 1,
        'id': id,
        'by': me.userId,
        'org': me.orgId,
      },
    );
    // Квартиры нет либо она принадлежит другой компании.
    if (rows.isEmpty) return jsonError(404, 'Квартира не найдена');
    await _log(me.orgId, me.userId, 'Изменение карточки квартиры', 'apartment', id);
    return jsonOk(await _unitById(id, me.orgId));
  }

  Future<Response> _message(Request request, String id) async {
    final me = _me(request);
    final unit = await db.one(
      'SELECT held_by_id::text AS h FROM apartments WHERE id=@id AND org_id=@org',
      {'id': id, 'org': me.orgId},
    );
    final holder = unit?['h'] as String?;
    if (holder != null && holder != me.userId) {
      final body = '${me.name} спрашивает по квартире';
      await db.query(
        '''INSERT INTO notifications (recipient_id, kind, title, body, apartment_id)
           VALUES (@r, 'message', 'Сообщение по квартире', @body, @id)''',
        {'r': holder, 'body': body, 'id': id},
      );
      await _pushFcm(
        'SELECT push_token AS t FROM devices WHERE user_id=@u',
        {'u': holder},
        title: 'Сообщение по квартире',
        body: body,
        unitId: id,
      );
    }
    return jsonOk({});
  }

  /// Общий переход статуса с историей и аудитом (в транзакции, FR-06.4).
  Future<Response> _apply(
    String id, {
    required String toStatus,
    required List<String> from,
    required String orgId,
    String? managerId,
    String? clientId,
    String? hold, // SQL-выражение для held_until, иначе NULL
    bool clearHold = false,
    bool keepHolder = false,
    required String title,
  }) async {
    final heldExpr = clearHold
        ? 'NULL'
        : keepHolder
            ? 'held_until'
            : (hold ?? 'NULL');
    final holderExpr = clearHold
        ? 'NULL'
        : keepHolder
            ? 'held_by_id'
            : '@m';
    final clientExpr = clearHold
        ? 'NULL'
        : keepHolder
            ? 'client_id'
            : '@c';

    final ok = await db.tx((s) async {
      final rows = await s.query(
        '''UPDATE apartments
           SET status=@to, held_by_id=$holderExpr, held_until=$heldExpr,
               client_id=$clientExpr, updated_at=now(), version=version+1
           WHERE id=@id AND org_id=@org AND status = ANY(@from)
                 AND deleted_at IS NULL
           RETURNING id''',
        {
          'to': toStatus,
          'from': from,
          'id': id,
          'org': orgId,
          if (!keepHolder && !clearHold) 'm': managerId,
          if (!keepHolder && !clearHold) 'c': clientId,
        },
      );
      if (rows.isEmpty) return false;
      await s.query(
        '''INSERT INTO apartment_status_history
             (apartment_id, to_status, changed_by, client_id, comment)
           VALUES (@id, @to, @by, @c, @t)''',
        {'id': id, 'to': toStatus, 'by': managerId, 'c': clientId, 't': title},
      );
      await s.query(
        '''INSERT INTO audit_logs (org_id, user_id, action, entity_type, entity_id)
           VALUES (@org, @u, @a, 'apartment', @id)''',
        {
          'org': orgId,
          'u': managerId,
          'a': 'Смена статуса → $toStatus',
          'id': id,
        },
      );
      await _syncDeal(s, id, toStatus, orgId);
      return true;
    });
    if (!ok) {
      return jsonError(409, 'Статус квартиры изменился — обновите фонд.');
    }
    return jsonOk(await _unitById(id, orgId));
  }

  static const _stageByStatus = {
    'work': 'show',
    'hold': 'booking',
    'design': 'design',
    'sold': 'done',
  };

  /// Синхронизирует сделку с состоянием квартиры (FR-08.3, FR-08.4 — не более
  /// одной активной сделки на квартиру).
  Future<void> _syncDeal(
      TxSession s, String aptId, String toStatus, String orgId) async {
    final stage = _stageByStatus[toStatus];
    if (stage == null) return; // free/off_market — сделку не трогаем
    final apt = await s.one(
      '''SELECT client_id::text AS c, held_by_id::text AS h
         FROM apartments WHERE id=@id AND org_id=@org''',
      {'id': aptId, 'org': orgId},
    );
    final clientId = apt?['c'] as String?;
    final sellerId = apt?['h'] as String?;
    final active = await s.one(
      '''SELECT id::text AS id FROM deals
         WHERE apartment_id=@a AND org_id=@org AND deleted_at IS NULL
               AND stage NOT IN ('done','rejected')''',
      {'a': aptId, 'org': orgId},
    );
    if (active != null) {
      await s.query(
        'UPDATE deals SET stage=@st, updated_at=now(), version=version+1 WHERE id=@id',
        {'st': stage, 'id': active['id']},
      );
    } else if (clientId != null && sellerId != null && stage != 'done') {
      await s.query(
        '''INSERT INTO deals (org_id, client_id, apartment_id, seller_id, stage)
           VALUES (@org, @c, @a, @s, @st)''',
        {'org': orgId, 'c': clientId, 'a': aptId, 's': sellerId, 'st': stage},
      );
    }
  }

  /// Уведомляет всех, кроме [actorId]. `null` — уведомить всех (например,
  /// когда бронь сняла система по истечении срока, а держателя уже нет).
  Future<void> _notifyTeam(
    String? actorId,
    String orgId,
    String unitId,
    String kind,
    String title,
    String body,
  ) async {
    // Пустая строка вместо uuid валит запрос, поэтому условие подставляем
    // только когда автор действительно известен.
    final skipUser = actorId == null ? '' : ' AND id <> @actor';
    final skipDevice = actorId == null ? '' : ' AND u.id <> @actor';
    await db.query(
      '''INSERT INTO notifications (recipient_id, kind, title, body, apartment_id)
         SELECT id, @kind, @title, @body, @apt
         FROM users
         WHERE org_id=@org AND blocked=false AND deleted_at IS NULL$skipUser''',
      {
        if (actorId != null) 'actor': actorId,
        'org': orgId,
        'kind': kind,
        'title': title,
        'body': body,
        'apt': unitId,
      },
    );
    await _pushFcm(
      '''SELECT d.push_token AS t FROM devices d JOIN users u ON u.id=d.user_id
         WHERE u.org_id=@org AND u.blocked=false
               AND u.deleted_at IS NULL$skipDevice''',
      {if (actorId != null) 'actor': actorId, 'org': orgId},
      title: title,
      body: body,
      unitId: unitId,
    );
  }

  /// Отправляет push на токены устройств, выбранные [tokenSql] (не блокирует
  /// ответ API). Если FCM не подключён — тихо пропускает.
  Future<void> _pushFcm(
    String tokenSql,
    Map<String, dynamic> params, {
    required String title,
    required String body,
    String? unitId,
  }) async {
    if (fcm == null) return;
    final tokens = (await db.query(tokenSql, params))
        .map((r) => r['t'] as String)
        .toList();
    if (tokens.isNotEmpty) {
      unawaited(fcm!.sendToTokens(tokens, title: title, body: body, unitId: unitId));
    }
  }

  Future<Response> _registerDevice(Request request) async {
    final b = await readJson(request);
    final platform = b['platform'] as String? ?? '';
    if (!const {'ios', 'android', 'web'}.contains(platform)) {
      return jsonError(422, 'Неизвестная платформа');
    }
    // Устройство всегда привязывается к автору запроса.
    await db.query(
      '''INSERT INTO devices (user_id, platform, push_token)
         VALUES (@u, @p, @t)
         ON CONFLICT (push_token) DO UPDATE SET user_id=@u, updated_at=now()''',
      {'u': _me(request).userId, 'p': platform, 't': b['token']},
    );
    return jsonOk({'ok': true});
  }

  // ===========================================================================
  // Сделки, уведомления, аудит
  // ===========================================================================

  static const _dealSelect = '''
    SELECT d.id::text AS id,
           d.client_id::text AS client_id, cl.full_name AS client_name,
           d.apartment_id::text AS unit_id,
           (c.name || ' · ' || b.name || ' · №' || a.number::text) AS unit_label,
           d.seller_id::text AS seller_id, su.full_name AS seller_name,
           d.stage,
           to_char(d.created_at AT TIME ZONE 'Asia/Bishkek','YYYY-MM-DD"T"HH24:MI:SS.US') AS created_at,
           to_char(d.next_action_at AT TIME ZONE 'Asia/Bishkek','YYYY-MM-DD"T"HH24:MI:SS.US') AS next_action_at
    FROM deals d
    JOIN clients cl ON cl.id = d.client_id
    JOIN apartments a ON a.id = d.apartment_id
    JOIN complexes c ON c.id = a.complex_id
    JOIN blocks b ON b.id = a.block_id
    JOIN users su ON su.id = d.seller_id
    WHERE d.deleted_at IS NULL AND d.org_id=@org''';

  /// Менеджер видит только свои сделки, администратор — все.
  Future<Response> _deals(Request request) async {
    final me = _me(request);
    return jsonOk(await db.query(
      me.isAdmin
          ? '$_dealSelect ORDER BY d.created_at DESC'
          : '$_dealSelect AND d.seller_id=@me ORDER BY d.created_at DESC',
      me.isAdmin
          ? {'org': me.orgId}
          : {'org': me.orgId, 'me': me.userId},
    ));
  }

  static const _stages = {
    'show', 'negotiation', 'booking', 'design', 'done', 'rejected',
  };

  Future<Response> _dealStage(Request request, String id) async {
    final me = _me(request);
    final b = await readJson(request);
    final stage = b['stage'] as String? ?? '';
    if (!_stages.contains(stage)) return jsonError(422, 'Неизвестный этап');
    const setSql = '''UPDATE deals SET stage=@s, updated_at=now(),
             updated_by=@by, version=version+1
         WHERE id=@id AND org_id=@org AND deleted_at IS NULL''';
    final rows = await db.query(
      me.isAdmin ? '$setSql RETURNING id' : '$setSql AND seller_id=@by RETURNING id',
      {'s': stage, 'id': id, 'by': me.userId, 'org': me.orgId},
    );
    if (rows.isEmpty) return jsonError(403, 'Сделка принадлежит другому менеджеру');
    await db.query(
      '''INSERT INTO deal_stage_history (deal_id, to_stage, changed_by)
         VALUES (@id, @s, @by)''',
      {'id': id, 's': stage, 'by': me.userId},
    );
    return jsonOk(await db.one(
        '$_dealSelect AND d.id=@id', {'id': id, 'org': me.orgId}));
  }

  /// Ящик всегда свой: параметр user_id из запроса игнорируется.
  Future<Response> _notifications(Request request) async {
    final userId = _me(request).userId;
    return jsonOk(await db.query(
      '''SELECT n.id::text AS id, n.kind, n.title, n.body,
                to_char(n.created_at AT TIME ZONE 'Asia/Bishkek','YYYY-MM-DD"T"HH24:MI:SS.US') AS at,
                n.recipient_id::text AS recipient_id,
                n.apartment_id::text AS unit_id,
                (n.read_at IS NOT NULL) AS read
         FROM notifications n WHERE n.recipient_id=@u
         ORDER BY n.created_at DESC''',
      {'u': userId},
    ));
  }

  Future<Response> _markRead(Request request, String id) async {
    await db.query(
      '''UPDATE notifications SET read_at=now()
         WHERE id=@id AND recipient_id=@u AND read_at IS NULL''',
      {'id': id, 'u': _me(request).userId},
    );
    return jsonOk({});
  }

  Future<Response> _markAllRead(Request request) async {
    await db.query(
      'UPDATE notifications SET read_at=now() WHERE recipient_id=@u AND read_at IS NULL',
      {'u': _me(request).userId},
    );
    return jsonOk({});
  }

  Future<Response> _audit(Request request) async {
    final denied = _adminOnly(request);
    if (denied != null) return denied;
    return jsonOk(await db.query(
        '''SELECT a.id::text AS id,
                  to_char(a.at AT TIME ZONE 'Asia/Bishkek','YYYY-MM-DD"T"HH24:MI:SS.US') AS at,
                  COALESCE(u.full_name,'Система') AS user_name,
                  a.action, COALESCE(a.entity_type,'') AS entity,
                  COALESCE(a.entity_id,'') AS details
           FROM audit_logs a LEFT JOIN users u ON u.id=a.user_id
           WHERE a.org_id=@org
           ORDER BY a.at DESC LIMIT 200''',
      {'org': _me(request).orgId},
    ));
  }

  // ===========================================================================
  // Вспомогательное
  // ===========================================================================

  Future<void> _log(String orgId, String userId, String action, String entity,
          Object? entityId) =>
      db.query(
        '''INSERT INTO audit_logs (org_id, user_id, action, entity_type, entity_id)
           VALUES (@org, @u, @a, @e, @id)''',
        {
          'org': orgId,
          'u': userId,
          'a': action,
          'e': entity,
          'id': entityId?.toString(),
        },
      );

  String _token() {
    final bytes = List<int>.generate(24, (_) => _rnd.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  // ===========================================================================
  // Адресные уведомления + проверка истечения броней (FR-11.2/11.3/11.4/11.5)
  // ===========================================================================

  // Кого уже предупреждали об истечении (apartmentId -> held_until).
  final _warned = <String, String>{};

  /// Администраторы конкретной компании.
  Future<List<String>> _adminIds(String orgId) async => (await db.query(
        '''SELECT ur.user_id::text AS id
           FROM user_roles ur JOIN users u ON u.id = ur.user_id
           WHERE ur.role_code='admin' AND u.org_id=@org
                 AND u.blocked=false AND u.deleted_at IS NULL''',
        {'org': orgId},
      ))
          .map((r) => r['id'] as String)
          .toList();

  Future<String> _unitLabel(String id) async {
    final r = await db.one(
      '''SELECT (c.name || ' · ' || b.name || ' · №' || a.number::text) AS label
         FROM apartments a JOIN complexes c ON c.id=a.complex_id
         JOIN blocks b ON b.id=a.block_id WHERE a.id=@id''',
      {'id': id},
    );
    return r?['label'] as String? ?? 'Квартира';
  }

  /// Вставляет уведомление конкретным пользователям и шлёт им push.
  Future<void> _notifyUsers(
    List<String> userIds,
    String kind,
    String title,
    String body,
    String? unitId,
  ) async {
    if (userIds.isEmpty) return;
    await db.query(
      '''INSERT INTO notifications (recipient_id, kind, title, body, apartment_id)
         SELECT id, @kind, @title, @body, @apt
         FROM users WHERE id = ANY(@ids) AND deleted_at IS NULL''',
      {'kind': kind, 'title': title, 'body': body, 'apt': unitId, 'ids': userIds},
    );
    await _pushFcm(
      'SELECT push_token AS t FROM devices WHERE user_id = ANY(@ids)',
      {'ids': userIds},
      title: title,
      body: body,
      unitId: unitId,
    );
  }

  // Компании, которым уже сообщили об истечении (orgId -> дата окончания).
  final _planWarned = <String, String>{};

  /// Предупреждение администраторам за 3 дня до окончания подписки.
  ///
  /// Ключ в [_planWarned] — сама дата окончания, поэтому после продления
  /// компания снова получит предупреждение в свой срок.
  Future<void> _checkSubscriptions() async {
    final soon = await db.query('''
      SELECT o.id::text AS id, o.name,
             to_char(o.plan_until AT TIME ZONE 'Asia/Bishkek','DD.MM.YYYY') AS until,
             to_char(o.plan_until,'YYYY-MM-DD"T"HH24:MI:SS') AS mark
      FROM organizations o
      WHERE o.deleted_at IS NULL AND o.is_blocked = false
        AND o.plan_until IS NOT NULL
        AND o.plan_until > now()
        AND o.plan_until < now() + interval '3 days' ''');

    for (final org in soon) {
      final id = org['id'] as String;
      final mark = org['mark'] as String;
      if (_planWarned[id] == mark) continue;
      _planWarned[id] = mark;

      await _notifyUsers(
        await _adminIds(id),
        'account',
        'Подписка заканчивается',
        'Доступ к «${org['name']}» действует до ${org['until']}. '
            'Свяжитесь с нами, чтобы продлить.',
        null,
      );
    }
  }

  /// Периодическая проверка броней (FR-11.2, FR-11.3, FR-11.4). Зовётся раз в
  /// минуту из server.dart.
  Future<void> runExpiryChecks() async {
    await _checkSubscriptions();
    // 1) Истёкшие брони — снять и уведомить.
    final expired = await db.query(
      '''SELECT a.id::text AS id, a.held_by_id::text AS holder,
                a.org_id::text AS org,
                (c.name || ' · ' || b.name || ' · №' || a.number::text) AS label
         FROM apartments a JOIN complexes c ON c.id=a.complex_id
         JOIN blocks b ON b.id=a.block_id
         WHERE a.status='hold' AND a.held_until < now() AND a.deleted_at IS NULL''',
    );
    for (final u in expired) {
      final id = u['id'] as String;
      final holder = u['holder'] as String?;
      final org = u['org'] as String;
      final label = u['label'] as String;
      await db.query(
        '''UPDATE apartments SET status='free', held_by_id=NULL, held_until=NULL,
               client_id=NULL, updated_at=now(), version=version+1 WHERE id=@id''',
        {'id': id},
      );
      await db.query(
        '''INSERT INTO apartment_status_history (apartment_id, to_status, comment)
           VALUES (@id, 'free', 'Бронь снята автоматически по истечении срока')''',
        {'id': id},
      );
      if (holder != null) {
        await _notifyUsers([holder], 'expiring', 'Ваша бронь истекла',
            '$label — бронь снята автоматически', id); // FR-11.3
      }
      await _notifyTeam(holder, org, id, 'released', 'Квартира освободилась',
          '$label снова свободна'); // FR-11.4
      _warned.remove(id);
    }

    // 2) Брони, истекающие в ближайшие 24 часа — предупредить один раз (FR-11.2).
    final soon = await db.query(
      '''SELECT a.id::text AS id, a.held_by_id::text AS holder,
                a.org_id::text AS org,
                to_char(a.held_until,'YYYY-MM-DD"T"HH24:MI:SS') AS until,
                (c.name || ' · ' || b.name || ' · №' || a.number::text) AS label
         FROM apartments a JOIN complexes c ON c.id=a.complex_id
         JOIN blocks b ON b.id=a.block_id
         WHERE a.status='hold' AND a.held_until > now()
               AND a.held_until < now() + interval '24 hours'
               AND a.deleted_at IS NULL''',
    );
    // Администраторов запрашиваем по одному разу на компанию.
    final adminsByOrg = <String, List<String>>{};
    for (final u in soon) {
      final id = u['id'] as String;
      final until = u['until'] as String;
      if (_warned[id] == until) continue;
      _warned[id] = until;
      final holder = u['holder'] as String?;
      final org = u['org'] as String;
      final label = u['label'] as String;
      final admins = adminsByOrg[org] ??= await _adminIds(org);
      final recipients = <String>{if (holder != null) holder, ...admins}.toList();
      await _notifyUsers(recipients, 'expiring', 'Бронь истекает',
          '$label — осталось меньше 24 часов', id);
    }
  }
}
