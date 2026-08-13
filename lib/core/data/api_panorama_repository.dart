import 'dart:async';

import '../models/app_notification.dart';
import '../models/audit_log.dart';
import '../models/client_model.dart';
import '../models/complex_model.dart';
import '../models/deal_model.dart';
import '../models/deal_stage.dart';
import '../models/manager_model.dart';
import '../models/org_summary.dart';
import '../models/subscription.dart';
import '../models/unit_model.dart';
import '../models/unit_status.dart';
import '../models/user_role.dart';
import '../network/api_client.dart';
import 'panorama_repository.dart';
import 'session_store.dart';

/// Реализация на REST API Panorama (версионирование пути /api/v1/).
///
/// Пути ниже — предположение до того, как компания отдаст описание своего
/// сервиса; менять нужно будет только их и разбор ответа. Пока
/// [AppConfig.useMockData] = true, класс не используется.
class ApiPanoramaRepository implements PanoramaRepository {
  ApiPanoramaRepository(this._api, [this._store = const SessionStore()]);

  final ApiClient _api;
  final SessionStore _store;

  /// Пока сервер не отдаёт события по WebSocket — перечитываем фонд.
  static const _pollInterval = Duration(seconds: 15);

  @override
  Future<LoginResult> login({
    required String login,
    required String password,
  }) async {
    try {
      final res = await _api.post(
        '/auth/login',
        body: {'login': login, 'password': password},
      );
      final token = res['token'] as String?;
      if (token != null) {
        _api.setToken(token);
        await _store.write(token); // чтобы не входить заново после перезапуска
      }
      return LoginOk(ManagerModel.fromJson(res['user'] as Map<String, dynamic>));
    } on ApiException catch (e) {
      return LoginFailed(e.message);
    } catch (e) {
      return LoginFailed('$e');
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } on ApiException {
      // Токен мог уже протухнуть — выход всё равно локально завершаем.
    } finally {
      _api.clearToken();
      await _store.clear();
    }
  }

  @override
  Future<ManagerModel?> restoreSession() async {
    final token = await _store.read();
    if (token == null) return null;
    _api.setToken(token);
    try {
      final user = ManagerModel.fromJson(await _api.getOne('/auth/me'));
      // Временный пароль обязателен к смене — проводим через экран входа.
      if (user.mustChangePassword) {
        _api.clearToken();
        await _store.clear();
        return null;
      }
      return user;
    } catch (_) {
      // Сессия отозвана, истекла или сервер недоступен — начинаем с входа.
      _api.clearToken();
      await _store.clear();
      return null;
    }
  }

  @override
  Future<LoginResult> register({
    required String name,
    required String company,
    required String phone,
    required String login,
    required String password,
  }) async {
    try {
      final res = await _api.post('/auth/register', body: {
        'name': name,
        'company': company,
        'phone': phone,
        'login': login,
        'password': password,
      });
      final token = res['token'] as String?;
      if (token != null) {
        _api.setToken(token);
        await _store.write(token);
      }
      return LoginOk(ManagerModel.fromJson(res['user'] as Map<String, dynamic>));
    } on ApiException catch (e) {
      return LoginFailed(e.message);
    } catch (e) {
      return LoginFailed('$e');
    }
  }

  @override
  Future<Subscription?> fetchSubscription() async {
    final me = await _api.getOne('/auth/me');
    final raw = me['subscription'];
    if (raw is! Map) return null;
    return Subscription.fromJson(raw.cast<String, dynamic>());
  }

  @override
  Future<List<OrgSummary>> fetchOrgs() async =>
      (await _api.getList('/superadmin/orgs')).map(OrgSummary.fromJson).toList();

  @override
  Future<void> subscribeOrg({
    required String orgId,
    required int months,
    String? note,
  }) async {
    await _api.post('/superadmin/orgs/$orgId/subscribe',
        body: {'months': months, 'note': ?note});
  }

  @override
  Future<void> setOrgBlocked({
    required String orgId,
    required bool blocked,
  }) async {
    await _api.post('/superadmin/orgs/$orgId/block', body: {'blocked': blocked});
  }

  @override
  Future<List<ManagerModel>> fetchUsers() async =>
      (await _api.getList('/users')).map(ManagerModel.fromJson).toList();

  @override
  Future<ManagerModel> createUser({
    required String name,
    required String login,
    required String phone,
    required UserRole role,
  }) async => ManagerModel.fromJson(
    await _api.post(
      '/users',
      body: {'name': name, 'login': login, 'phone': phone, 'role': role.wire},
    ),
  );

  @override
  Future<ManagerModel> setUserBlocked({
    required String userId,
    required bool blocked,
  }) async => ManagerModel.fromJson(
    await _api.post('/users/$userId/block', body: {'blocked': blocked}),
  );

  @override
  Future<ManagerModel> setUserRole({
    required String userId,
    required UserRole role,
  }) async => ManagerModel.fromJson(
    await _api.post('/users/$userId/role', body: {'role': role.wire}),
  );

  @override
  Future<ManagerModel> changePassword({
    required String userId,
    required String newPassword,
  }) async => ManagerModel.fromJson(
    await _api.post(
      '/users/$userId/password',
      body: {'new_password': newPassword},
    ),
  );

  @override
  Future<List<ComplexModel>> fetchComplexes() async =>
      (await _api.getList('/complexes')).map(ComplexModel.fromJson).toList();

  @override
  Future<ComplexModel> createComplex({
    required String name,
    required String address,
    required String deadline,
    required String segment,
    required ManagerModel by,
  }) async => ComplexModel.fromJson(
    await _api.post(
      '/complexes',
      body: {
        'name': name,
        'address': address,
        'deadline': deadline,
        'segment': segment,
      },
    ),
  );

  @override
  Future<int> bulkCreateBlock(
    BulkBlockSpec spec, {
    required ManagerModel by,
  }) async {
    // Раньше уходили только три поля, а группы этажей терялись — сервер
    // создавал блок вообще без квартир.
    final res = await _api.post(
      '/blocks/bulk',
      body: {
        'complex_id': spec.complexId,
        'block': spec.blockName,
        'start_number': spec.startNumber,
        'groups': [
          for (final g in spec.groups)
            {
              'floor_from': g.floorFrom,
              'floor_to': g.floorTo,
              'rooms': g.roomsPerPosition,
            },
        ],
        'technical_floors': spec.technicalFloors.toList(),
        'skip_numbers': spec.skipNumbers.toList(),
        'idempotency_key': spec.idempotencyKey,
      },
    );
    return (res['created'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<UnitModel> updateUnit(UnitModel unit, {required ManagerModel by}) async =>
      UnitModel.fromJson(await _api.post('/units/${unit.id}', body: unit.toJson()));

  @override
  Future<List<ClientModel>> fetchClients() async =>
      (await _api.getList('/clients')).map(ClientModel.fromJson).toList();

  @override
  Future<ClientModel> addClient({
    required String name,
    required String phone,
    required ManagerModel seller,
    int rooms = 0,
    String source = '',
    String request = '',
    String note = '',
  }) async => ClientModel.fromJson(
    await _api.post(
      '/clients',
      body: {
        'name': name,
        'phone': phone,
        'seller_id': seller.id,
        'rooms': rooms,
        'source': source,
        'request': request,
        'note': note,
      },
    ),
  );

  @override
  Future<List<DealModel>> fetchDeals() async =>
      (await _api.getList('/deals')).map(DealModel.fromJson).toList();

  @override
  Future<DealModel> setDealStage({
    required String dealId,
    required DealStage stage,
    required ManagerModel by,
  }) async => DealModel.fromJson(
    await _api.post('/deals/$dealId/stage', body: {'stage': stage.wire}),
  );

  /// Максимальный `updated_at`, полученный от сервера: граница для дельты.
  /// Берём именно серверное значение, чтобы не зависеть от часов устройства.
  String? _sinceMark;

  Future<List<Map<String, dynamic>>> _rawUnits({String? since}) => _api.getList(
        since == null
            ? '/units'
            : '/units?since=${Uri.encodeQueryComponent(since)}',
      );

  static String? _maxUpdatedAt(List<Map<String, dynamic>> rows) {
    String? max;
    for (final r in rows) {
      final v = r['updated_at'] as String?;
      // Формат фиксированной ширины (ISO-8601 в UTC), сравнение строк корректно.
      if (v != null && (max == null || v.compareTo(max) > 0)) max = v;
    }
    return max;
  }

  /// Тот же порядок, что отдаёт сервер: объект, блок, номер.
  static List<UnitModel> _sorted(Iterable<UnitModel> units) {
    final list = units.toList();
    list.sort((a, b) {
      final byComplex = a.complexName.compareTo(b.complexName);
      if (byComplex != 0) return byComplex;
      final byBlock = a.block.compareTo(b.block);
      if (byBlock != 0) return byBlock;
      return a.number.compareTo(b.number);
    });
    return list;
  }

  @override
  Future<List<UnitModel>> fetchUnits() async {
    final raw = await _rawUnits();
    _sinceMark = _maxUpdatedAt(raw) ?? _sinceMark;
    return raw.map(UnitModel.fromJson).toList();
  }

  @override
  Future<UnitModel> fetchUnit(String unitId) async =>
      UnitModel.fromJson(await _api.getOne('/units/$unitId'));

  /// Живой фонд. Первый запрос — весь список, дальше только изменившееся.
  ///
  /// Раньше каждые 15 секунд выкачивался весь фонд вместе с историей по каждой
  /// квартире. Теперь при отсутствии изменений с сервера приходит пустой
  /// список, и подписчики даже не дёргаются.
  /// Раз в столько опросов фонд перечитывается целиком.
  ///
  /// Страховка от изменения, закоммиченного задним числом: транзакция могла
  /// начаться до нашего запроса, а завершиться после, и её `updated_at`
  /// оказался бы раньше нашей метки. При 15-секундном опросе это раз в 5 минут.
  static const _fullRefreshEvery = 20;

  @override
  Stream<List<UnitModel>> watchUnits() async* {
    final byId = <String, UnitModel>{};
    var polls = 0;

    void absorb(List<Map<String, dynamic>> rows) {
      for (final row in rows) {
        final unit = UnitModel.fromJson(row);
        byId[unit.id] = unit;
      }
    }

    final first = await _rawUnits();
    _sinceMark = _maxUpdatedAt(first) ?? _sinceMark;
    absorb(first);
    yield _sorted(byId.values);

    while (true) {
      await Future<void>.delayed(_pollInterval);
      try {
        final full = ++polls % _fullRefreshEvery == 0;
        final rows = await _rawUnits(since: full ? null : _sinceMark);
        if (rows.isEmpty) continue; // ничего не поменялось
        _sinceMark = _maxUpdatedAt(rows) ?? _sinceMark;
        if (full) byId.clear(); // полное обновление заменяет весь фонд
        absorb(rows);
        yield _sorted(byId.values);
      } on ApiException {
        // Сеть моргнула или сессия истекла — попробуем на следующем круге.
      }
    }
  }

  /// Превращает 422-ответ сервера в [LimitExceeded] (FR-07.9).
  Future<UnitModel> _unitAction(String path, Map<String, dynamic> body) async {
    try {
      return UnitModel.fromJson(await _api.post(path, body: body));
    } on ApiException catch (e) {
      if (e.statusCode == 422) throw LimitExceeded(e.message);
      rethrow;
    }
  }

  @override
  Future<UnitModel> takeToWork({
    required String unitId,
    required ManagerModel manager,
    ClientModel? client,
  }) => _unitAction(
    '/units/$unitId/take',
    {'manager_id': manager.id, 'client_id': client?.id},
  );

  @override
  Future<UnitModel> book({
    required String unitId,
    required ManagerModel manager,
    ClientModel? client,
    int days = 3,
  }) => _unitAction(
    '/units/$unitId/book',
    {'client_id': client?.id, 'days': days.clamp(1, 30)},
  );

  @override
  Future<UnitModel> release({
    required String unitId,
    required ManagerModel manager,
  }) async => UnitModel.fromJson(
    await _api.post('/units/$unitId/release', body: {'manager_id': manager.id}),
  );

  @override
  Future<UnitModel> sendToDesign({
    required String unitId,
    required ManagerModel manager,
  }) async => UnitModel.fromJson(
    await _api.post('/units/$unitId/design', body: {'manager_id': manager.id}),
  );

  @override
  Future<UnitModel> confirmSale({
    required String unitId,
    required ManagerModel admin,
  }) async => UnitModel.fromJson(
    await _api.post('/units/$unitId/sell', body: {'admin_id': admin.id}),
  );

  @override
  Future<UnitModel> setStatus({
    required String unitId,
    required UnitStatus status,
    required ManagerModel by,
  }) async => UnitModel.fromJson(
    await _api.post('/units/$unitId/status', body: {'status': status.wire}),
  );

  @override
  Future<void> requestExtend({
    required String unitId,
    required ManagerModel manager,
  }) async {
    await _api.post('/units/$unitId/extend-request');
  }

  @override
  Future<UnitModel> extendBooking({
    required String unitId,
    required ManagerModel admin,
    Duration extra = const Duration(days: 3),
  }) async => UnitModel.fromJson(
    await _api.post(
      '/units/$unitId/extend',
      body: {'days': extra.inDays},
    ),
  );

  @override
  Future<List<AppNotification>> fetchNotifications(String userId) async =>
      (await _api.getList('/notifications?user_id=$userId'))
          .map(AppNotification.fromJson)
          .toList();

  @override
  Stream<List<AppNotification>> watchNotifications(String userId) async* {
    yield await fetchNotifications(userId);
    yield* Stream.periodic(_pollInterval)
        .asyncMap((_) => fetchNotifications(userId));
  }

  @override
  Future<void> markNotificationRead(String notificationId) async {
    await _api.post('/notifications/$notificationId/read');
  }

  @override
  Future<void> markAllNotificationsRead(String userId) async {
    await _api.post('/notifications/read-all', body: {'user_id': userId});
  }

  @override
  Future<void> messageHolder({
    required String unitId,
    required ManagerModel from,
  }) async {
    await _api.post('/units/$unitId/message', body: {'from_id': from.id});
  }

  @override
  Future<void> registerDevice({
    required String userId,
    required String token,
    required String platform,
  }) async {
    await _api.post(
      '/devices',
      body: {'user_id': userId, 'token': token, 'platform': platform},
    );
  }

  @override
  Future<List<AuditLog>> fetchAuditLogs() async =>
      (await _api.getList('/audit')).map(AuditLog.fromJson).toList();

  @override
  void dispose() {}
}
