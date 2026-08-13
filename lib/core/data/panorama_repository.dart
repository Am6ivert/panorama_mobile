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

/// Результат входа.
sealed class LoginResult {
  const LoginResult();
}

class LoginOk extends LoginResult {
  const LoginOk(this.user);
  final ManagerModel user;
}

class LoginFailed extends LoginResult {
  const LoginFailed(this.message);
  final String message;
}

/// Превышен лимит активных операций менеджера (FR-07.9 и смежные).
class LimitExceeded implements Exception {
  const LimitExceeded(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Одна группа этажей мастера массового создания (FR-03.2).
class FloorGroupSpec {
  const FloorGroupSpec({
    required this.floorFrom,
    required this.floorTo,
    required this.roomsPerPosition,
  });

  final int floorFrom;
  final int floorTo;

  /// Комнатность по позициям слева направо; длина = квартир на этаже.
  final List<int> roomsPerPosition;
}

/// Параметры мастера массового создания блока (FR-03).
class BulkBlockSpec {
  const BulkBlockSpec({
    required this.complexId,
    required this.blockName,
    required this.startNumber,
    required this.groups,
    this.technicalFloors = const {},
    this.skipNumbers = const {},
    this.idempotencyKey,
  });

  /// Ключ повторной отправки (FR-03.7). Один и тот же ключ при повторе после
  /// ошибки не создаёт блок второй раз — сервер вернёт прежний результат.
  final String? idempotencyKey;

  final String complexId;
  final String blockName;
  final int startNumber;
  final List<FloorGroupSpec> groups;

  /// Технические этажи — строка в шахматке пустая, нумерация без разрыва.
  final Set<int> technicalFloors;

  /// Пропускаемые номера (например 13).
  final Set<int> skipNumbers;
}

/// Контракт источника данных.
///
/// Сейчас за ним стоит [MockPanoramaRepository], позже — реализация на REST
/// API Panorama. Экраны работают только с этим интерфейсом.
abstract interface class PanoramaRepository {
  // --- Аутентификация и пользователи (FR-01) ---

  Future<LoginResult> login({required String login, required String password});

  /// Регистрация застройщика: создаёт компанию и её первого администратора,
  /// сразу выполняя вход. Возвращает тот же результат, что и [login].
  Future<LoginResult> register({
    required String name,
    required String company,
    required String phone,
    required String login,
    required String password,
  });

  /// Завершить сессию: сервер отзывает токен, клиент его забывает.
  Future<void> logout();

  /// Состояние подписки своей компании. null — сервер её не прислал
  /// (например, приложение работает на моках).
  Future<Subscription?> fetchSubscription();

  // --- Суперадминистратор: компании и подписки ---

  /// Все компании с подписками и администраторами.
  Future<List<OrgSummary>> fetchOrgs();

  /// Продлить подписку компании на [months] месяцев.
  Future<void> subscribeOrg({
    required String orgId,
    required int months,
    String? note,
  });

  /// Приостановить или возобновить работу компании.
  Future<void> setOrgBlocked({required String orgId, required bool blocked});

  /// Восстановить сессию сохранённым токеном при запуске приложения.
  ///
  /// Возвращает пользователя, если токен ещё действителен, иначе `null`
  /// (сессия истекла, отозвана, учётка заблокирована или токена нет).
  Future<ManagerModel?> restoreSession();

  Future<List<ManagerModel>> fetchUsers();

  Future<ManagerModel> createUser({
    required String name,
    required String login,
    required String phone,
    required UserRole role,
  });

  Future<ManagerModel> setUserBlocked({
    required String userId,
    required bool blocked,
  });

  Future<ManagerModel> setUserRole({
    required String userId,
    required UserRole role,
  });

  /// Смена пароля (в т.ч. обязательная при первом входе, FR-01.3).
  Future<ManagerModel> changePassword({
    required String userId,
    required String newPassword,
  });

  // --- Недвижимость (FR-02) ---

  Future<List<ComplexModel>> fetchComplexes();

  /// Создание нового объекта (ЖК) — FR-02.1.
  Future<ComplexModel> createComplex({
    required String name,
    required String address,
    required String deadline,
    required String segment,
    required ManagerModel by,
  });

  /// Массовое создание квартир блока одной транзакцией (FR-03).
  Future<int> bulkCreateBlock(BulkBlockSpec spec, {required ManagerModel by});

  /// Редактирование характеристик квартиры (FR-04).
  Future<UnitModel> updateUnit(
    UnitModel unit, {
    required ManagerModel by,
  });

  // --- Клиенты и сделки (FR-08) ---

  Future<List<ClientModel>> fetchClients();

  Future<ClientModel> addClient({
    required String name,
    required String phone,
    required ManagerModel seller,
    int rooms,
    String source,
    String request,
    String note,
  });

  Future<List<DealModel>> fetchDeals();

  Future<DealModel> setDealStage({
    required String dealId,
    required DealStage stage,
    required ManagerModel by,
  });

  // --- Фонд квартир (FR-05, FR-06, FR-07) ---

  Future<List<UnitModel>> fetchUnits();

  /// Одна квартира целиком, вместе с историей.
  ///
  /// В списке фонда истории нет: она нужна только в карточке, а в списке
  /// умножала объём ответа на число событий по каждой квартире.
  Future<UnitModel> fetchUnit(String unitId);

  Stream<List<UnitModel>> watchUnits();

  /// Закрепить квартиру за менеджером на время показа. Данные клиента
  /// опциональны — можно внести позже.
  Future<UnitModel> takeToWork({
    required String unitId,
    required ManagerModel manager,
    ClientModel? client,
  });

  /// Поставить бронь на [days] дней. Клиент опционален.
  ///
  /// Раньше принимался диапазон дат, хотя сервер работает со сроком в днях:
  /// диапазон всё равно сворачивался в число, а тесты про это не знали.
  Future<UnitModel> book({
    required String unitId,
    required ManagerModel manager,
    ClientModel? client,
    int days = 3,
  });

  /// Вернуть квартиру в свободный фонд.
  Future<UnitModel> release({
    required String unitId,
    required ManagerModel manager,
  });

  /// Отправить бронь на оформление (hold → design).
  Future<UnitModel> sendToDesign({
    required String unitId,
    required ManagerModel manager,
  });

  /// Подтвердить продажу (design → sold), только администратор (FR-06).
  Future<UnitModel> confirmSale({
    required String unitId,
    required ManagerModel admin,
  });

  /// Снять с продажи / вернуть в продажу (только администратор).
  Future<UnitModel> setStatus({
    required String unitId,
    required UnitStatus status,
    required ManagerModel by,
  });

  /// Попросить администратора продлить бронь (FR-07.8): менеджер сам продлить
  /// не может, администратор получает уведомление.
  Future<void> requestExtend({
    required String unitId,
    required ManagerModel manager,
  });

  /// Продлить бронь (только администратор, FR-07.8).
  Future<UnitModel> extendBooking({
    required String unitId,
    required ManagerModel admin,
    Duration extra,
  });

  // --- Уведомления (FR-11) ---

  Future<List<AppNotification>> fetchNotifications(String userId);

  Stream<List<AppNotification>> watchNotifications(String userId);

  Future<void> markNotificationRead(String notificationId);

  Future<void> markAllNotificationsRead(String userId);

  /// «Написать менеджеру» по квартире (FR-06.5).
  Future<void> messageHolder({
    required String unitId,
    required ManagerModel from,
  });

  /// Регистрация push-токена устройства (FCM/APNs) для доставки уведомлений.
  Future<void> registerDevice({
    required String userId,
    required String token,
    required String platform,
  });

  // --- Аудит (FR-12) ---

  Future<List<AuditLog>> fetchAuditLogs();

  void dispose();
}
