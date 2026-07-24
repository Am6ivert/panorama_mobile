import '../models/client_model.dart';
import '../models/complex_model.dart';
import '../models/manager_model.dart';
import '../models/unit_model.dart';

/// Контракт источника данных.
///
/// Сейчас за ним стоит [MockPanoramaRepository], позже — реализация на REST API
/// Panorama. Экраны работают только с этим интерфейсом, поэтому подмена
/// источника не заденет UI.
abstract interface class PanoramaRepository {
  Future<List<ComplexModel>> fetchComplexes();

  Future<List<ManagerModel>> fetchManagers();

  Future<List<ClientModel>> fetchClients();

  /// Завести клиента прямо на объекте. Возвращает карточку с присвоенным id.
  Future<ClientModel> addClient({
    required String name,
    required String phone,
    required int rooms,
    required int budget,
    String note,
  });

  /// Текущий срез фонда квартир.
  Future<List<UnitModel>> fetchUnits();

  /// Поток изменений фонда: как только другой менеджер взял квартиру в работу
  /// или закрыл продажу, шахматка обновляется у всех.
  Stream<List<UnitModel>> watchUnits();

  /// Закрепить квартиру за менеджером на время показа.
  Future<UnitModel> takeToWork({
    required String unitId,
    required ManagerModel manager,
    ClientModel? client,
  });

  /// Поставить бронь.
  Future<UnitModel> book({
    required String unitId,
    required ManagerModel manager,
    ClientModel? client,
  });

  /// Вернуть квартиру в свободный фонд.
  Future<UnitModel> release({
    required String unitId,
    required ManagerModel manager,
  });

  void dispose();
}
