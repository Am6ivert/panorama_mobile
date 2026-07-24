import 'dart:async';

import '../models/client_model.dart';
import '../models/complex_model.dart';
import '../models/manager_model.dart';
import '../models/unit_model.dart';
import '../network/api_client.dart';
import 'panorama_repository.dart';

/// Реализация на REST API Panorama.
///
/// Пути ниже — предположение до того, как компания отдаст описание своего
/// сервиса; менять нужно будет только их и разбор ответа.
class ApiPanoramaRepository implements PanoramaRepository {
  ApiPanoramaRepository(this._api);

  final ApiClient _api;

  /// Пока сервер не отдаёт события по WebSocket — перечитываем фонд.
  static const _pollInterval = Duration(seconds: 15);

  @override
  Future<List<ComplexModel>> fetchComplexes() async =>
      (await _api.getList('/complexes')).map(ComplexModel.fromJson).toList();

  @override
  Future<List<ManagerModel>> fetchManagers() async =>
      (await _api.getList('/managers')).map(ManagerModel.fromJson).toList();

  @override
  Future<List<ClientModel>> fetchClients() async =>
      (await _api.getList('/clients')).map(ClientModel.fromJson).toList();

  @override
  Future<ClientModel> addClient({
    required String name,
    required String phone,
    required int rooms,
    required int budget,
    String note = '',
  }) async => ClientModel.fromJson(
    await _api.post(
      '/clients',
      body: {
        'name': name,
        'phone': phone,
        'rooms': rooms,
        'budget': budget,
        'note': note,
      },
    ),
  );

  @override
  Future<List<UnitModel>> fetchUnits() async =>
      (await _api.getList('/units')).map(UnitModel.fromJson).toList();

  @override
  Stream<List<UnitModel>> watchUnits() async* {
    yield await fetchUnits();
    yield* Stream.periodic(_pollInterval).asyncMap((_) => fetchUnits());
  }

  @override
  Future<UnitModel> takeToWork({
    required String unitId,
    required ManagerModel manager,
    ClientModel? client,
  }) async => UnitModel.fromJson(
    await _api.post(
      '/units/$unitId/take',
      body: {'manager_id': manager.id, 'client_id': client?.id},
    ),
  );

  @override
  Future<UnitModel> book({
    required String unitId,
    required ManagerModel manager,
    ClientModel? client,
  }) async => UnitModel.fromJson(
    await _api.post(
      '/units/$unitId/book',
      body: {'manager_id': manager.id, 'client_id': client?.id},
    ),
  );

  @override
  Future<UnitModel> release({
    required String unitId,
    required ManagerModel manager,
  }) async => UnitModel.fromJson(
    await _api.post('/units/$unitId/release', body: {'manager_id': manager.id}),
  );

  @override
  void dispose() {}
}
