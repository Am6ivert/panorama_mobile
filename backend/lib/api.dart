import 'dart:math';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'db.dart';
import 'json.dart';

/// REST API /api/v1 для «Шахматки квартир».
class Api {
  Api(this.db);
  final Db db;
  final _rnd = Random.secure();

  Handler get handler {
    final r = Router();

    r.get('/api/v1/health', (Request _) => jsonOk({'ok': true}));

    // --- Аутентификация ---
    r.post('/api/v1/auth/login', _login);

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
    r.post('/api/v1/units/<id>', _updateUnit);
    r.post('/api/v1/units/<id>/take', _take);
    r.post('/api/v1/units/<id>/book', _book);
    r.post('/api/v1/units/<id>/release', _release);
    r.post('/api/v1/units/<id>/design', _design);
    r.post('/api/v1/units/<id>/sell', _sell);
    r.post('/api/v1/units/<id>/status', _setStatus);
    r.post('/api/v1/units/<id>/extend', _extend);
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

    return r.call;
  }

  // ===========================================================================
  // SQL-фрагменты
  // ===========================================================================

  static const _userSelect = '''
    SELECT u.id::text AS id, u.full_name AS name, u.login, u.phone,
           COALESCE((SELECT role_code FROM user_roles WHERE user_id=u.id LIMIT 1),'manager') AS role,
           u.blocked, u.must_change_password AS must_change_password
    FROM users u WHERE u.deleted_at IS NULL''';

  static const _complexSelect = '''
    SELECT c.id::text AS id, c.name, COALESCE(c.address,'') AS address,
           COALESCE(c.deadline,'') AS deadline, COALESCE(c.segment,'') AS segment,
           c.cover_start, c.cover_end,
           COALESCE((SELECT json_agg(json_build_object(
               'name', b.name, 'floors', b.floors, 'units_per_floor', b.units_per_floor
             ) ORDER BY b.name)
             FROM blocks b WHERE b.complex_id=c.id AND b.deleted_at IS NULL),'[]'::json) AS blocks
    FROM complexes c WHERE c.deleted_at IS NULL''';

  static const _clientSelect = '''
    SELECT cl.id::text AS id, cl.full_name AS name, cl.phone,
           cl.seller_id::text AS seller_id, su.full_name AS seller_name,
           COALESCE(cl.rooms,0) AS rooms, COALESCE(cl.source,'') AS source,
           COALESCE(cl.request,'') AS request, cl.stage,
           COALESCE(cl.note,'') AS note,
           to_char(cl.next_action_at AT TIME ZONE 'Asia/Bishkek','YYYY-MM-DD"T"HH24:MI:SS.US') AS next_action_at
    FROM clients cl JOIN users su ON su.id = cl.seller_id
    WHERE cl.deleted_at IS NULL''';

  static const _unitSelect = '''
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
           cl.full_name AS client_name,
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
             WHERE h.apartment_id = a.id), '[]'::json) AS history
    FROM apartments a
    JOIN complexes c ON c.id = a.complex_id
    JOIN blocks b ON b.id = a.block_id
    LEFT JOIN users hu ON hu.id = a.held_by_id
    LEFT JOIN clients cl ON cl.id = a.client_id''';

  Map<String, dynamic> _unitJson(Map<String, dynamic> row) =>
      {...row, 'history': asJsonList(row['history'])};

  Map<String, dynamic> _complexJson(Map<String, dynamic> row) =>
      {...row, 'blocks': asJsonList(row['blocks'])};

  // ===========================================================================
  // Аутентификация
  // ===========================================================================

  Future<Response> _login(Request request) async {
    final body = await readJson(request);
    final login = (body['login'] as String?)?.trim().toLowerCase() ?? '';
    final password = body['password'] as String? ?? '';
    final user = await db.one(
      '''SELECT u.id::text AS id, u.blocked,
                (u.password_hash = crypt(@p, u.password_hash)) AS ok
         FROM users u WHERE lower(u.login) = @l AND u.deleted_at IS NULL''',
      {'l': login, 'p': password},
    );
    if (user == null) return jsonError(404, 'Учётная запись не найдена');
    if (user['blocked'] == true) {
      return jsonError(403, 'Учётная запись заблокирована');
    }
    if (user['ok'] != true) return jsonError(401, 'Неверный пароль');

    final token = _token();
    await db.query(
      '''INSERT INTO sessions (user_id, token_hash, expires_at)
         VALUES (@u, @t, now() + interval '30 days')''',
      {'u': user['id'], 't': token},
    );
    final full = await db.one('$_userSelect AND u.id = @id', {'id': user['id']});
    await _log(user['id'] as String, 'Вход', 'user', user['id']);
    return jsonOk({'user': full, 'token': token});
  }

  // ===========================================================================
  // Пользователи
  // ===========================================================================

  Future<Response> _users(Request request) async =>
      jsonOk(await db.query('$_userSelect ORDER BY u.login'));

  Future<Response> _createUser(Request request) async {
    final b = await readJson(request);
    final row = await db.one(
      '''WITH nu AS (
           INSERT INTO users (full_name, login, phone, password_hash, must_change_password)
           VALUES (@name, lower(@login), @phone, crypt('0000', gen_salt('bf')), true)
           RETURNING id
         ), ur AS (
           INSERT INTO user_roles (user_id, role_code)
           SELECT id, @role FROM nu RETURNING user_id
         )
         SELECT id::text AS id FROM nu''',
      {
        'name': b['name'],
        'login': b['login'],
        'phone': b['phone'],
        'role': b['role'] ?? 'manager',
      },
    );
    final user = await db.one('$_userSelect AND u.id = @id', {'id': row!['id']});
    return jsonOk(user);
  }

  Future<Response> _blockUser(Request request, String id) async {
    final b = await readJson(request);
    await db.query(
      'UPDATE users SET blocked=@v, updated_at=now(), version=version+1 WHERE id=@id',
      {'v': b['blocked'] == true, 'id': id},
    );
    if (b['blocked'] == true) {
      await db.query('UPDATE sessions SET revoked_at=now() WHERE user_id=@id AND revoked_at IS NULL', {'id': id});
    }
    return jsonOk(await db.one('$_userSelect AND u.id=@id', {'id': id}));
  }

  Future<Response> _roleUser(Request request, String id) async {
    final b = await readJson(request);
    await db.query(
      '''INSERT INTO user_roles (user_id, role_code) VALUES (@id, @r)
         ON CONFLICT (user_id, role_code) DO NOTHING''',
      {'id': id, 'r': b['role']},
    );
    await db.query(
      'DELETE FROM user_roles WHERE user_id=@id AND role_code<>@r',
      {'id': id, 'r': b['role']},
    );
    return jsonOk(await db.one('$_userSelect AND u.id=@id', {'id': id}));
  }

  Future<Response> _changePassword(Request request, String id) async {
    final b = await readJson(request);
    await db.query(
      '''UPDATE users SET password_hash = crypt(@p, gen_salt('bf')),
             must_change_password = false, updated_at=now(), version=version+1
         WHERE id=@id''',
      {'p': b['new_password'], 'id': id},
    );
    return jsonOk(await db.one('$_userSelect AND u.id=@id', {'id': id}));
  }

  // ===========================================================================
  // Недвижимость
  // ===========================================================================

  Future<Response> _complexes(Request request) async => jsonOk(
        (await db.query('$_complexSelect ORDER BY c.created_at'))
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
    final b = await readJson(request);
    final n = (await db.one('SELECT count(*) AS n FROM complexes'))!['n'] as int;
    final cover = _covers[n % _covers.length];
    final row = await db.one(
      '''INSERT INTO complexes (name, address, deadline, segment, cover_start, cover_end)
         VALUES (@name, @address, @deadline, @segment, @cs, @ce) RETURNING id''',
      {
        'name': b['name'],
        'address': b['address'],
        'deadline': b['deadline'],
        'segment': b['segment'],
        'cs': cover[0],
        'ce': cover[1],
      },
    );
    return jsonOk(
      _complexJson((await db.one('$_complexSelect AND c.id=@id', {'id': row!['id']}))!),
    );
  }

  Future<Response> _bulkBlock(Request request) async {
    final b = await readJson(request);
    final complexId = b['complex_id'] as String;
    final blockName = b['block'] as String;
    final startNumber = (b['start_number'] as num?)?.toInt() ?? 1;
    final groups = (b['groups'] as List?) ?? const [];
    final technical = ((b['technical_floors'] as List?) ?? const [])
        .map((e) => (e as num).toInt())
        .toSet();
    final skip = ((b['skip_numbers'] as List?) ?? const [])
        .map((e) => (e as num).toInt())
        .toSet();

    const areaByRooms = {0: 31.0, 1: 42.0, 2: 60.0, 3: 84.0, 4: 114.0};
    const kitchenByRooms = {
      0: 'кухня-ниша', 1: '12.4 м²', 2: '14.8 м²', 3: '16.2 м²', 4: '18.0 м²',
    };

    final created = await db.tx((s) async {
      final blockRow = await s.one(
        '''INSERT INTO blocks (complex_id, name, floors, units_per_floor)
           VALUES (@c, @n, @f, @u) RETURNING id''',
        {
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
                 (block_id, complex_id, floor, position, number, rooms, area, status, kitchen, view, finish, bathrooms)
               VALUES (@b, @c, @f, @p, @n, @r, @area, 'free', @kit, @view, @fin, @bath)''',
            {
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
      return count;
    });
    return jsonOk({'created': created});
  }

  // ===========================================================================
  // Фонд (список; действия — в actions.dart части ниже)
  // ===========================================================================

  Future<Response> _units(Request request) async => jsonOk(
        (await db.query('$_unitSelect WHERE a.deleted_at IS NULL ORDER BY c.name, b.name, a.number'))
            .map(_unitJson)
            .toList(),
      );

  // ===========================================================================
  // Клиенты
  // ===========================================================================

  Future<Response> _clients(Request request) async =>
      jsonOk(await db.query('$_clientSelect ORDER BY cl.created_at DESC'));

  Future<Response> _createClient(Request request) async {
    final b = await readJson(request);
    final row = await db.one(
      '''INSERT INTO clients (full_name, phone, seller_id, rooms, source, request, note)
         VALUES (@name, @phone, @seller, @rooms, @source, @request, @note)
         ON CONFLICT (seller_id, phone) WHERE deleted_at IS NULL DO UPDATE SET full_name=EXCLUDED.full_name
         RETURNING id''',
      {
        'name': b['name'],
        'phone': b['phone'],
        'seller': b['seller_id'],
        'rooms': (b['rooms'] as num?)?.toInt() ?? 0,
        'source': b['source'] ?? '',
        'request': b['request'] ?? '',
        'note': b['note'] ?? '',
      },
    );
    return jsonOk(await db.one('$_clientSelect AND cl.id=@id', {'id': row!['id']}));
  }

  // ===========================================================================
  // Действия с квартирой (переходы статусов)
  // ===========================================================================

  Future<Map<String, dynamic>?> _unitById(String id) async {
    final row = await db.one('$_unitSelect WHERE a.id=@id', {'id': id});
    return row == null ? null : _unitJson(row);
  }

  Future<({String name, bool isAdmin})?> _actor(String? id) async {
    if (id == null) return null;
    final r = await db.one(
      '''SELECT full_name,
                EXISTS(SELECT 1 FROM user_roles WHERE user_id=@id AND role_code='admin') AS admin
         FROM users WHERE id=@id''',
      {'id': id},
    );
    if (r == null) return null;
    return (name: r['full_name'] as String, isAdmin: r['admin'] == true);
  }

  Future<int> _heldCount(String managerId, String status) async {
    final r = await db.one(
      'SELECT count(*) AS c FROM apartments WHERE held_by_id=@m AND status=@s AND deleted_at IS NULL',
      {'m': managerId, 's': status},
    );
    return r!['c'] as int;
  }

  Future<Response> _take(Request request, String id) async {
    final b = await readJson(request);
    final actor = await _actor(b['manager_id'] as String?);
    if (actor == null) return jsonError(404, 'Пользователь не найден');
    if (!actor.isAdmin && await _heldCount(b['manager_id'] as String, 'work') >= 5) {
      return jsonError(409, 'Достигнут лимит: квартир в работе — 5. Освободите одну.');
    }
    return _apply(
      id,
      toStatus: 'work',
      from: const ['free'],
      managerId: b['manager_id'] as String,
      clientId: b['client_id'] as String?,
      hold: "now() + interval '2 hours'",
      title: 'Взята в работу',
    );
  }

  Future<Response> _book(Request request, String id) async {
    final b = await readJson(request);
    final actor = await _actor(b['manager_id'] as String?);
    if (actor == null) return jsonError(404, 'Пользователь не найден');
    if (!actor.isAdmin && await _heldCount(b['manager_id'] as String, 'hold') >= 5) {
      return jsonError(409, 'Достигнут лимит: активных броней — 5. Снимите одну.');
    }
    final res = await _apply(
      id,
      toStatus: 'hold',
      from: const ['free', 'work'],
      managerId: b['manager_id'] as String,
      clientId: b['client_id'] as String?,
      hold: "now() + interval '3 days'",
      title: 'Бронь на 3 дня',
    );
    if (res.statusCode == 200) {
      await _notifyTeam(b['manager_id'] as String, id, 'booked',
          'Квартира забронирована', 'Забронировал(а) ${actor.name}');
    }
    return res;
  }

  Future<Response> _release(Request request, String id) async {
    final b = await readJson(request);
    final actor = await _actor(b['manager_id'] as String?);
    if (actor == null) return jsonError(404, 'Пользователь не найден');
    final res = await _apply(
      id,
      toStatus: 'free',
      from: const ['work', 'hold', 'design'],
      managerId: b['manager_id'] as String,
      clearHold: true,
      title: 'Снята с работы, вернулась в продажу',
    );
    if (res.statusCode == 200) {
      await _notifyTeam(b['manager_id'] as String, id, 'released',
          'Квартира освободилась', 'Снова свободна');
    }
    return res;
  }

  Future<Response> _design(Request request, String id) async {
    final b = await readJson(request);
    final actor = await _actor(b['manager_id'] as String?);
    if (actor == null) return jsonError(404, 'Пользователь не найден');
    return _apply(
      id,
      toStatus: 'design',
      from: const ['hold'],
      managerId: b['manager_id'] as String,
      keepHolder: true,
      title: 'Отправлена на оформление',
    );
  }

  Future<Response> _sell(Request request, String id) async {
    final b = await readJson(request);
    final actor = await _actor(b['admin_id'] as String?);
    if (actor == null) return jsonError(404, 'Пользователь не найден');
    return _apply(
      id,
      toStatus: 'sold',
      from: const ['design'],
      managerId: b['admin_id'] as String,
      keepHolder: true,
      title: 'Продажа подтверждена',
    );
  }

  Future<Response> _setStatus(Request request, String id) async {
    final b = await readJson(request);
    final status = b['status'] as String;
    final clear = status == 'free' || status == 'off_market';
    return _apply(
      id,
      toStatus: status,
      from: const ['free', 'work', 'hold', 'design', 'sold', 'off_market'],
      clearHold: clear,
      title: status == 'off_market' ? 'Снята с продажи' : 'Изменение статуса',
    );
  }

  Future<Response> _extend(Request request, String id) async {
    final b = await readJson(request);
    final days = (b['days'] as num?)?.toInt() ?? 3;
    await db.query(
      '''UPDATE apartments
         SET held_until = COALESCE(held_until, now()) + make_interval(days => @d),
             updated_at=now(), version=version+1
         WHERE id=@id AND deleted_at IS NULL''',
      {'d': days, 'id': id},
    );
    return jsonOk(await _unitById(id));
  }

  Future<Response> _updateUnit(Request request, String id) async {
    final b = await readJson(request);
    await db.query(
      '''UPDATE apartments SET rooms=@rooms, area=@area, status=@status,
             kitchen=@kitchen, view=@view, finish=@finish, bathrooms=@bath,
             updated_at=now(), version=version+1
         WHERE id=@id AND deleted_at IS NULL''',
      {
        'rooms': (b['rooms'] as num?)?.toInt() ?? 0,
        'area': (b['area'] as num?)?.toDouble() ?? 0,
        'status': b['status'] ?? 'free',
        'kitchen': b['kitchen'] ?? '',
        'view': b['view'] ?? '',
        'finish': b['finish'] ?? '',
        'bath': (b['bathrooms'] as num?)?.toInt() ?? 1,
        'id': id,
      },
    );
    return jsonOk(await _unitById(id));
  }

  Future<Response> _message(Request request, String id) async {
    final b = await readJson(request);
    final from = await _actor(b['from_id'] as String?);
    final unit = await db.one(
      'SELECT held_by_id::text AS h FROM apartments WHERE id=@id',
      {'id': id},
    );
    if (from != null && unit?['h'] != null) {
      await db.query(
        '''INSERT INTO notifications (recipient_id, kind, title, body, apartment_id)
           VALUES (@r, 'message', 'Сообщение по квартире', @body, @id)''',
        {'r': unit!['h'], 'body': '${from.name} спрашивает по квартире', 'id': id},
      );
    }
    return jsonOk({});
  }

  /// Общий переход статуса с историей и аудитом (в транзакции, FR-06.4).
  Future<Response> _apply(
    String id, {
    required String toStatus,
    required List<String> from,
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
           WHERE id=@id AND status = ANY(@from) AND deleted_at IS NULL
           RETURNING id''',
        {
          'to': toStatus,
          'from': from,
          'id': id,
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
        '''INSERT INTO audit_logs (user_id, action, entity_type, entity_id)
           VALUES (@u, @a, 'apartment', @id)''',
        {'u': managerId, 'a': 'Смена статуса → $toStatus', 'id': id},
      );
      return true;
    });
    if (!ok) {
      return jsonError(409, 'Статус квартиры изменился — обновите фонд.');
    }
    return jsonOk(await _unitById(id));
  }

  Future<void> _notifyTeam(
    String actorId,
    String unitId,
    String kind,
    String title,
    String body,
  ) =>
      db.query(
        '''INSERT INTO notifications (recipient_id, kind, title, body, apartment_id)
           SELECT id, @kind, @title, @body, @apt
           FROM users WHERE id <> @actor AND blocked=false AND deleted_at IS NULL''',
        {'actor': actorId, 'kind': kind, 'title': title, 'body': body, 'apt': unitId},
      );

  // ===========================================================================
  // Сделки, уведомления, аудит
  // ===========================================================================

  Future<Response> _deals(Request request) async => jsonOk(const []);

  Future<Response> _dealStage(Request request, String id) async =>
      jsonOk({'id': id});

  Future<Response> _notifications(Request request) async {
    final userId = request.url.queryParameters['user_id'];
    if (userId == null) return jsonOk(const []);
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
      'UPDATE notifications SET read_at=now() WHERE id=@id AND read_at IS NULL',
      {'id': id},
    );
    return jsonOk({});
  }

  Future<Response> _markAllRead(Request request) async {
    final b = await readJson(request);
    await db.query(
      'UPDATE notifications SET read_at=now() WHERE recipient_id=@u AND read_at IS NULL',
      {'u': b['user_id']},
    );
    return jsonOk({});
  }

  Future<Response> _audit(Request request) async => jsonOk(await db.query(
        '''SELECT a.id::text AS id,
                  to_char(a.at AT TIME ZONE 'Asia/Bishkek','YYYY-MM-DD"T"HH24:MI:SS.US') AS at,
                  COALESCE(u.full_name,'Система') AS user_name,
                  a.action, COALESCE(a.entity_type,'') AS entity,
                  COALESCE(a.entity_id,'') AS details
           FROM audit_logs a LEFT JOIN users u ON u.id=a.user_id
           ORDER BY a.at DESC LIMIT 200''',
      ));

  // ===========================================================================
  // Вспомогательное
  // ===========================================================================

  Future<void> _log(String userId, String action, String entity, Object? entityId) =>
      db.query(
        '''INSERT INTO audit_logs (user_id, action, entity_type, entity_id)
           VALUES (@u, @a, @e, @id)''',
        {'u': userId, 'a': action, 'e': entity, 'id': entityId?.toString()},
      );

  String _token() {
    final bytes = List<int>.generate(24, (_) => _rnd.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
