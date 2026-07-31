import 'dart:async';

import '../models/app_notification.dart';
import '../models/audit_log.dart';
import '../models/client_model.dart';
import '../models/complex_model.dart';
import '../models/deal_model.dart';
import '../models/deal_stage.dart';
import '../models/manager_model.dart';
import '../models/unit_model.dart';
import '../models/unit_status.dart';
import '../models/user_role.dart';
import '../network/api_client.dart';
import 'panorama_repository.dart';

/// Реализация на REST API Panorama (версионирование пути /api/v1/).
///
/// Пути ниже — предположение до того, как компания отдаст описание своего
/// сервиса; менять нужно будет только их и разбор ответа. Пока
/// [AppConfig.useMockData] = true, класс не используется.
class ApiPanoramaRepository implements PanoramaRepository {
  ApiPanoramaRepository(this._api);

  final ApiClient _api;

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
      if (token != null) _api.setToken(token);
      return LoginOk(ManagerModel.fromJson(res['user'] as Map<String, dynamic>));
    } on ApiException catch (e) {
      return LoginFailed(e.message);
    } catch (e) {
      return LoginFailed('$e');
    }
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
    final res = await _api.post(
      '/blocks/bulk',
      body: {
        'complex_id': spec.complexId,
        'block': spec.blockName,
        'start_number': spec.startNumber,
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

  @override
  Future<List<UnitModel>> fetchUnits() async =>
      (await _api.getList('/units')).map(UnitModel.fromJson).toList();

  @override
  Stream<List<UnitModel>> watchUnits() async* {
    yield await fetchUnits();
    yield* Stream.periodic(_pollInterval).asyncMap((_) => fetchUnits());
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
  }) => _unitAction(
    '/units/$unitId/book',
    {'manager_id': manager.id, 'client_id': client?.id},
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
  Future<List<AuditLog>> fetchAuditLogs() async =>
      (await _api.getList('/audit')).map(AuditLog.fromJson).toList();

  @override
  void dispose() {}
}
