import 'dart:async';
import 'dart:math';

import '../config/app_config.dart';
import '../models/app_notification.dart';
import '../models/audit_log.dart';
import '../models/client_model.dart';
import '../models/complex_model.dart';
import '../models/deal_model.dart';
import '../models/deal_stage.dart';
import '../models/manager_model.dart';
import '../models/unit_event.dart';
import '../models/unit_model.dart';
import '../models/unit_status.dart';
import '../models/user_role.dart';
import 'panorama_repository.dart';

/// Демо-данные до подключения API Panorama. Без денежных значений (ТЗ 1.3).
///
/// Фонд генерируется детерминированно (сид фиксирован), поэтому при
/// перезапуске приложения шахматка выглядит одинаково.
class MockPanoramaRepository implements PanoramaRepository {
  /// [enableBackgroundTimers] выключается в тестах, чтобы фоновые таймеры
  /// не мешали `pumpAndSettle`.
  MockPanoramaRepository({bool enableBackgroundTimers = true}) {
    _units = _generateUnits();
    _seedDeals();
    _seedNotifications();
    if (enableBackgroundTimers) {
      // Автоснятие истёкших броней (FR-07.7).
      _expiry = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _sweepExpired(),
      );
    }
  }

  late final List<UnitModel> _units;
  Timer? _expiry;
  final _unitsController = StreamController<List<UnitModel>>.broadcast();
  final _notificationsController =
      StreamController<List<AppNotification>>.broadcast();

  var _lastId = 0;
  String _nextId(String prefix) => '$prefix${++_lastId}';

  // --- Пользователи -----------------------------------------------------------

  final List<ManagerModel> _users = [
    const ManagerModel(
      id: 'u0',
      name: 'Динара Ибраимова',
      login: 'admin',
      phone: '+996 555 00-11-22',
      role: UserRole.admin,
    ),
    const ManagerModel(
      id: 'm1',
      name: 'Азамат Кубанычбеков',
      login: 'azamat',
      phone: '+996 555 10-22-30',
    ),
    const ManagerModel(
      id: 'm2',
      name: 'Эльвира Садыкова',
      login: 'elvira',
      phone: '+996 700 41-08-19',
    ),
    const ManagerModel(
      id: 'm3',
      name: 'Нурлан Осмонов',
      login: 'nurlan',
      phone: '+996 559 77-13-04',
    ),
    const ManagerModel(
      id: 'm4',
      name: 'Бекзат Жумалиев',
      login: 'bekzat',
      phone: '+996 772 60-55-21',
    ),
  ];

  List<ManagerModel> get _managers =>
      _users.where((u) => u.role == UserRole.manager).toList(growable: false);

  ManagerModel get _admin => _users.firstWhere((u) => u.isAdmin);

  // --- Клиенты ----------------------------------------------------------------

  late final List<ClientModel> _clients = _seedClients();

  List<ClientModel> _seedClients() {
    final m = _managers;
    return [
      ClientModel(
        id: 'c1',
        name: 'Айбек Сыдыков',
        phone: '+996 555 41-20-08',
        sellerId: m[0].id,
        sellerName: m[0].shortName,
        rooms: 2,
        source: 'Реклама Instagram',
        request: 'Ищет 2-комнатную, важен вид на горы.',
        stage: DealStage.negotiation,
        note: 'Готов внести бронь на этой неделе.',
        nextActionAt: DateTime.now().add(const Duration(days: 1)),
      ),
      ClientModel(
        id: 'c2',
        name: 'Гульмира Асанова',
        phone: '+996 700 88-14-73',
        sellerId: m[1].id,
        sellerName: m[1].shortName,
        rooms: 3,
        source: 'Рекомендация',
        request: 'Семья из четырёх человек, не выше 8 этажа.',
        stage: DealStage.show,
        nextActionAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      ClientModel(
        id: 'c3',
        name: 'Тимур Алиев',
        phone: '+996 559 03-77-12',
        sellerId: m[2].id,
        sellerName: m[2].shortName,
        rooms: 1,
        source: 'Сайт',
        request: 'Покупает под сдачу, интересует высокий этаж.',
        stage: DealStage.booking,
      ),
      ClientModel(
        id: 'c4',
        name: 'Жаныл Мураталиева',
        phone: '+996 772 55-61-90',
        sellerId: m[0].id,
        sellerName: m[0].shortName,
        rooms: 0,
        source: 'Реклама 2ГИС',
        request: 'Студия для дочери-студентки, ближе к центру.',
        stage: DealStage.show,
      ),
    ];
  }

  final List<DealModel> _deals = [];
  final List<AppNotification> _notifications = [];
  final List<AuditLog> _audit = [];

  // --- Справочник объектов ----------------------------------------------------

  static const _complexes = [
    ComplexModel(
      id: 'city',
      name: 'Панорама Сити',
      address: 'ул. Ахунбаева, 121',
      deadline: 'сдача 2 кв. 2027',
      segment: 'бизнес',
      coverStart: 0xFF1E3A8A,
      coverEnd: 0xFF3B82F6,
      blocks: [
        BlockModel(name: 'А', floors: 16, unitsPerFloor: 6),
        BlockModel(name: 'Б', floors: 16, unitsPerFloor: 5),
        BlockModel(name: 'В', floors: 12, unitsPerFloor: 4),
      ],
    ),
    ComplexModel(
      id: 'park',
      name: 'Панорама Парк',
      address: 'ул. Токомбаева, 43/1',
      deadline: 'сдача 4 кв. 2026',
      segment: 'комфорт',
      coverStart: 0xFF065F46,
      coverEnd: 0xFF10B981,
      blocks: [
        BlockModel(name: '1', floors: 12, unitsPerFloor: 5),
        BlockModel(name: '2', floors: 12, unitsPerFloor: 5),
      ],
    ),
    ComplexModel(
      id: 'res',
      name: 'Панорама Резиденс',
      address: 'пр. Чуй, 219',
      deadline: 'сдан',
      segment: 'премиум',
      coverStart: 0xFF7C2D12,
      coverEnd: 0xFFF59E0B,
      blocks: [
        BlockModel(name: 'А', floors: 9, unitsPerFloor: 3),
        BlockModel(name: 'Б', floors: 9, unitsPerFloor: 3),
      ],
    ),
  ];

  /// Комнатность квартир на этаже по каждому блоку (позиции слева направо).
  static const _layoutPatterns = <String, List<int>>{
    'city-А': [1, 2, 2, 3, 1, 0],
    'city-Б': [0, 1, 2, 2, 3],
    'city-В': [2, 3, 3, 2],
    'park-1': [0, 1, 1, 2, 2],
    'park-2': [1, 2, 3, 2, 1],
    'res-А': [2, 3, 4],
    'res-Б': [3, 3, 4],
  };

  static const _areaRanges = <int, (double, double)>{
    0: (28, 34),
    1: (38, 46),
    2: (54, 68),
    3: (76, 92),
    4: (104, 124),
  };

  static const _kitchens = <int, String>{
    0: 'кухня-ниша',
    1: '12.4 м²',
    2: '14.8 м²',
    3: '16.2 м²',
    4: '18.0 м²',
  };

  // ===========================================================================
  // Аутентификация и пользователи
  // ===========================================================================

  @override
  Future<LoginResult> login({
    required String login,
    required String password,
  }) async {
    await _latency();
    final key = login.trim().toLowerCase();
    final user =
        _users.where((u) => u.login.toLowerCase() == key).firstOrNull;
    if (user == null) {
      return const LoginFailed('Учётная запись не найдена');
    }
    if (user.blocked) {
      return const LoginFailed('Учётная запись заблокирована');
    }
    if (password != AppConfig.defaultPassword) {
      return const LoginFailed('Неверный пароль');
    }
    _log(user, 'Вход', 'Учётная запись ${user.name}');
    return LoginOk(user);
  }

  @override
  Future<List<ManagerModel>> fetchUsers() async {
    await _latency();
    return List.unmodifiable(_users);
  }

  @override
  Future<ManagerModel> createUser({
    required String name,
    required String login,
    required String phone,
    required UserRole role,
  }) async {
    await _latency();
    final user = ManagerModel(
      id: _nextId('u'),
      name: name,
      login: login.trim().toLowerCase(),
      phone: phone,
      role: role,
      mustChangePassword: true,
    );
    _users.add(user);
    _log(_admin, 'Создание учётной записи', '${user.name} · ${role.label}');
    _pushNotification(
      recipientId: user.id,
      kind: NotificationKind.account,
      title: 'Учётная запись создана',
      body: 'Временный пароль отправлен по SMS. Смените его при первом входе.',
    );
    return user;
  }

  @override
  Future<ManagerModel> setUserBlocked({
    required String userId,
    required bool blocked,
  }) async {
    await _latency();
    final i = _users.indexWhere((u) => u.id == userId);
    final updated = _users[i].copyWith(blocked: blocked);
    _users[i] = updated;
    _log(
      _admin,
      blocked ? 'Блокировка учётной записи' : 'Разблокировка учётной записи',
      updated.name,
    );
    return updated;
  }

  @override
  Future<ManagerModel> setUserRole({
    required String userId,
    required UserRole role,
  }) async {
    await _latency();
    final i = _users.indexWhere((u) => u.id == userId);
    final updated = _users[i].copyWith(role: role);
    _users[i] = updated;
    _log(_admin, 'Смена роли', '${updated.name} → ${role.label}');
    return updated;
  }

  // ===========================================================================
  // Недвижимость
  // ===========================================================================

  @override
  Future<List<ComplexModel>> fetchComplexes() async {
    await _latency();
    return _complexes;
  }

  @override
  Future<int> bulkCreateBlock(
    BulkBlockSpec spec, {
    required ManagerModel by,
  }) async {
    await _latency();
    final complex = _complexes.firstWhere((c) => c.id == spec.complexId);
    final created = <UnitModel>[];
    var number = spec.startNumber;

    final maxFloor = spec.groups
        .map((g) => g.floorTo)
        .fold(0, (a, b) => a > b ? a : b);

    for (var floor = 1; floor <= maxFloor; floor++) {
      if (spec.technicalFloors.contains(floor)) continue;
      final group = spec.groups.firstWhere(
        (g) => floor >= g.floorFrom && floor <= g.floorTo,
        orElse: () => spec.groups.last,
      );
      for (var pos = 0; pos < group.roomsPerPosition.length; pos++) {
        while (spec.skipNumbers.contains(number)) {
          number++;
        }
        final rooms = group.roomsPerPosition[pos];
        final range = _areaRanges[rooms] ?? _areaRanges[1]!;
        final area = double.parse(
          (range.$1 + (range.$2 - range.$1) / 2).toStringAsFixed(1),
        );
        created.add(
          UnitModel(
            id: '${spec.complexId}-${spec.blockName}-$number',
            complexId: complex.id,
            complexName: complex.name,
            block: spec.blockName,
            floor: floor,
            position: pos + 1,
            number: number,
            rooms: rooms,
            area: area,
            status: UnitStatus.free,
            kitchen: _kitchens[rooms] ?? '',
            view: pos.isEven ? 'на Ала-Тоо' : 'во двор, тихая сторона',
            finish: rooms >= 3 ? 'предчистовая' : 'без отделки',
            bathrooms: rooms >= 3 ? 2 : 1,
          ),
        );
        number++;
      }
    }

    _units.addAll(created);
    _log(
      by,
      'Массовое создание',
      '${complex.name} · блок ${spec.blockName}',
      details: 'Создано ${created.length} квартир',
    );
    _emitUnits();
    return created.length;
  }

  @override
  Future<UnitModel> updateUnit(UnitModel unit, {required ManagerModel by}) async {
    await _latency();
    final i = _units.indexWhere((u) => u.id == unit.id);
    final updated = unit.copyWith(
      history: [
        UnitEvent(
          kind: UnitEventKind.edited,
          title: 'Изменены характеристики',
          authorName: by.shortName,
          at: DateTime.now(),
        ),
        ..._units[i].history,
      ],
    );
    _units[i] = updated;
    _log(by, 'Изменение квартиры', _unitLabel(updated));
    _emitUnits();
    return updated;
  }

  // ===========================================================================
  // Клиенты и сделки
  // ===========================================================================

  @override
  Future<List<ClientModel>> fetchClients() async {
    await _latency();
    return List.unmodifiable(_clients);
  }

  @override
  Future<ClientModel> addClient({
    required String name,
    required String phone,
    required ManagerModel seller,
    int rooms = 0,
    String source = '',
    String request = '',
    String note = '',
  }) async {
    await _latency();
    // Проверка дубликата телефона (FR-07.3).
    final digits = _digits(phone);
    final duplicate =
        _clients.where((c) => _digits(c.phone) == digits).firstOrNull;
    if (duplicate != null && duplicate.sellerId == seller.id) {
      return duplicate;
    }
    final client = ClientModel(
      id: _nextId('c'),
      name: name,
      phone: phone,
      sellerId: seller.id,
      sellerName: seller.shortName,
      rooms: rooms,
      source: source,
      request: request,
      note: note,
    );
    _clients.insert(0, client);
    _log(seller, 'Создание клиента', client.name);
    return client;
  }

  @override
  Future<List<DealModel>> fetchDeals() async {
    await _latency();
    return List.unmodifiable(_deals);
  }

  @override
  Future<DealModel> setDealStage({
    required String dealId,
    required DealStage stage,
    required ManagerModel by,
  }) async {
    await _latency();
    final i = _deals.indexWhere((d) => d.id == dealId);
    final updated = _deals[i].copyWith(stage: stage);
    _deals[i] = updated;
    _log(by, 'Стадия сделки', '${updated.clientName}: ${stage.label}');
    return updated;
  }

  // ===========================================================================
  // Фонд квартир
  // ===========================================================================

  @override
  Future<List<UnitModel>> fetchUnits() async {
    await _latency();
    return List.unmodifiable(_units);
  }

  @override
  Stream<List<UnitModel>> watchUnits() async* {
    yield List.unmodifiable(_units);
    yield* _unitsController.stream;
  }

  @override
  Future<UnitModel> takeToWork({
    required String unitId,
    required ManagerModel manager,
    required ClientModel client,
  }) => _apply(
    unitId,
    status: UnitStatus.work,
    manager: manager,
    client: client,
    until: DateTime.now().add(AppConfig.workHoldDuration),
    event: UnitEventKind.taken,
    title: 'Взята в работу — ${client.name}',
    action: 'Взятие в работу',
  );

  @override
  Future<UnitModel> book({
    required String unitId,
    required ManagerModel manager,
    required ClientModel client,
  }) async {
    final unit = await _apply(
      unitId,
      status: UnitStatus.hold,
      manager: manager,
      client: client,
      until: DateTime.now().add(AppConfig.bookingDuration),
      event: UnitEventKind.booked,
      title: 'Бронь на 3 дня — ${client.name}',
      action: 'Бронирование',
    );
    _ensureDeal(unit, manager, client, DealStage.booking);
    // FR-11.1: бронь → администратор и ответственный менеджер.
    _pushNotification(
      recipientId: _admin.id,
      kind: NotificationKind.booked,
      title: 'Новая бронь',
      body: '${_unitLabel(unit)} — ${manager.shortName}',
      unitId: unit.id,
    );
    return unit;
  }

  @override
  Future<UnitModel> release({
    required String unitId,
    required ManagerModel manager,
  }) async {
    await _latency();
    final i = _units.indexWhere((u) => u.id == unitId);
    final unit = _units[i];
    final holderId = unit.heldById;
    final updated = unit.copyWith(
      status: UnitStatus.free,
      clearHold: true,
      history: [
        UnitEvent(
          kind: UnitEventKind.released,
          title: 'Снята с работы, вернулась в продажу',
          authorName: manager.shortName,
          at: DateTime.now(),
        ),
        ...unit.history,
      ],
    );
    _units[i] = updated;
    _log(manager, 'Освобождение квартиры', _unitLabel(updated));
    // FR-11.4: квартира освободилась → менеджеры с незакрытыми сделками.
    if (holderId != null && holderId != manager.id) {
      _pushNotification(
        recipientId: holderId,
        kind: NotificationKind.released,
        title: 'Бронь снята',
        body: '${_unitLabel(updated)} снова свободна',
        unitId: updated.id,
      );
    }
    _emitUnits();
    return updated;
  }

  @override
  Future<UnitModel> sendToDesign({
    required String unitId,
    required ManagerModel manager,
  }) async {
    final unit = await _apply(
      unitId,
      status: UnitStatus.design,
      manager: manager,
      until: null,
      keepClient: true,
      event: UnitEventKind.design,
      title: 'Отправлена на оформление',
      action: 'Отправка на оформление',
    );
    _updateDealForUnit(unit, DealStage.design);
    // FR-11.5: отправлена на оформление → администратор.
    _pushNotification(
      recipientId: _admin.id,
      kind: NotificationKind.design,
      title: 'Квартира на оформление',
      body: '${_unitLabel(unit)} — ${manager.shortName}',
      unitId: unit.id,
    );
    return unit;
  }

  @override
  Future<UnitModel> confirmSale({
    required String unitId,
    required ManagerModel admin,
  }) async {
    await _latency();
    final i = _units.indexWhere((u) => u.id == unitId);
    final unit = _units[i];
    final holderId = unit.heldById;
    final updated = unit.copyWith(
      status: UnitStatus.sold,
      history: [
        UnitEvent(
          kind: UnitEventKind.sold,
          title: 'Продажа подтверждена',
          authorName: admin.shortName,
          at: DateTime.now(),
        ),
        ...unit.history,
      ],
    );
    _units[i] = updated;
    _updateDealForUnit(updated, DealStage.done);
    _log(admin, 'Подтверждение продажи', _unitLabel(updated));
    if (holderId != null) {
      _pushNotification(
        recipientId: holderId,
        kind: NotificationKind.design,
        title: 'Продажа подтверждена',
        body: '${_unitLabel(updated)} — сделка завершена',
        unitId: updated.id,
      );
    }
    _emitUnits();
    return updated;
  }

  @override
  Future<UnitModel> setStatus({
    required String unitId,
    required UnitStatus status,
    required ManagerModel by,
  }) async {
    await _latency();
    final i = _units.indexWhere((u) => u.id == unitId);
    final unit = _units[i];
    final clear = status == UnitStatus.free || status == UnitStatus.offMarket;
    final updated = unit.copyWith(
      status: status,
      clearHold: clear,
      history: [
        UnitEvent(
          kind: status == UnitStatus.offMarket
              ? UnitEventKind.offMarket
              : UnitEventKind.released,
          title: status == UnitStatus.offMarket
              ? 'Снята с продажи'
              : 'Возвращена в свободные',
          authorName: by.shortName,
          at: DateTime.now(),
        ),
        ...unit.history,
      ],
    );
    _units[i] = updated;
    _log(by, 'Изменение статуса', '${_unitLabel(updated)} → ${status.label}');
    _emitUnits();
    return updated;
  }

  @override
  Future<UnitModel> extendBooking({
    required String unitId,
    required ManagerModel admin,
    Duration extra = const Duration(days: 3),
  }) async {
    await _latency();
    final i = _units.indexWhere((u) => u.id == unitId);
    final unit = _units[i];
    final base = unit.heldUntil ?? DateTime.now();
    final updated = unit.copyWith(
      heldUntil: base.add(extra),
      history: [
        UnitEvent(
          kind: UnitEventKind.extended,
          title: 'Бронь продлена',
          authorName: admin.shortName,
          at: DateTime.now(),
        ),
        ...unit.history,
      ],
    );
    _units[i] = updated;
    _log(admin, 'Продление брони', _unitLabel(updated));
    if (unit.heldById != null) {
      _pushNotification(
        recipientId: unit.heldById!,
        kind: NotificationKind.extendRequest,
        title: 'Бронь продлена',
        body: '${_unitLabel(updated)} — срок продлён администратором',
        unitId: updated.id,
      );
    }
    _emitUnits();
    return updated;
  }

  // ===========================================================================
  // Уведомления
  // ===========================================================================

  @override
  Future<List<AppNotification>> fetchNotifications(String userId) async {
    await _latency();
    return _forUser(userId);
  }

  @override
  Stream<List<AppNotification>> watchNotifications(String userId) async* {
    yield _forUser(userId);
    yield* _notificationsController.stream.map((_) => _forUser(userId));
  }

  @override
  Future<void> markNotificationRead(String notificationId) async {
    final i = _notifications.indexWhere((n) => n.id == notificationId);
    if (i < 0) return;
    _notifications[i] = _notifications[i].copyWith(read: true);
    _emitNotifications();
  }

  @override
  Future<void> markAllNotificationsRead(String userId) async {
    for (var i = 0; i < _notifications.length; i++) {
      if (_notifications[i].recipientId == userId && !_notifications[i].read) {
        _notifications[i] = _notifications[i].copyWith(read: true);
      }
    }
    _emitNotifications();
  }

  @override
  Future<void> messageHolder({
    required String unitId,
    required ManagerModel from,
  }) async {
    await _latency();
    final unit = _units.firstWhere((u) => u.id == unitId);
    if (unit.heldById == null) return;
    _pushNotification(
      recipientId: unit.heldById!,
      kind: NotificationKind.message,
      title: 'Сообщение по квартире',
      body: '${from.shortName} спрашивает про ${_unitLabel(unit)}',
      unitId: unit.id,
    );
  }

  List<AppNotification> _forUser(String userId) => _notifications
      .where((n) => n.recipientId == userId)
      .toList(growable: false)
    ..sort((a, b) => b.at.compareTo(a.at));

  // ===========================================================================
  // Аудит
  // ===========================================================================

  @override
  Future<List<AuditLog>> fetchAuditLogs() async {
    await _latency();
    return _audit.reversed.toList(growable: false);
  }

  @override
  void dispose() {
    _expiry?.cancel();
    _unitsController.close();
    _notificationsController.close();
  }

  // ===========================================================================
  // Внутреннее
  // ===========================================================================

  Future<UnitModel> _apply(
    String unitId, {
    required UnitStatus status,
    required ManagerModel manager,
    required DateTime? until,
    required UnitEventKind event,
    required String title,
    required String action,
    ClientModel? client,
    bool keepClient = false,
  }) async {
    await _latency();
    final i = _units.indexWhere((u) => u.id == unitId);
    final unit = _units[i];
    final updated = unit.copyWith(
      status: status,
      heldById: manager.id,
      heldByName: manager.shortName,
      heldUntil: until,
      clientId: keepClient ? unit.clientId : client?.id,
      clientName: keepClient ? unit.clientName : client?.name,
      history: [
        UnitEvent(
          kind: event,
          title: title,
          authorName: manager.shortName,
          at: DateTime.now(),
          clientName: keepClient ? unit.clientName : client?.name,
        ),
        ...unit.history,
      ],
    );
    _units[i] = updated;
    if (client != null) _ensureDeal(updated, manager, client, DealStage.show);
    _log(manager, action, _unitLabel(updated));
    _emitUnits();
    return updated;
  }

  void _ensureDeal(
    UnitModel unit,
    ManagerModel manager,
    ClientModel client,
    DealStage stage,
  ) {
    final existing = _deals.indexWhere(
      (d) => d.unitId == unit.id && d.isActive,
    );
    if (existing >= 0) {
      _deals[existing] = _deals[existing].copyWith(stage: stage);
      return;
    }
    _deals.insert(
      0,
      DealModel(
        id: _nextId('d'),
        clientId: client.id,
        clientName: client.name,
        unitId: unit.id,
        unitLabel: _unitLabel(unit),
        sellerId: manager.id,
        sellerName: manager.shortName,
        stage: stage,
        createdAt: DateTime.now(),
      ),
    );
  }

  void _updateDealForUnit(UnitModel unit, DealStage stage) {
    final i = _deals.indexWhere((d) => d.unitId == unit.id && d.isActive);
    if (i >= 0) _deals[i] = _deals[i].copyWith(stage: stage);
  }

  void _emitUnits() {
    if (!_unitsController.isClosed) {
      _unitsController.add(List.unmodifiable(_units));
    }
  }

  void _emitNotifications() {
    if (!_notificationsController.isClosed) {
      _notificationsController.add(List.unmodifiable(_notifications));
    }
  }

  void _pushNotification({
    required String recipientId,
    required NotificationKind kind,
    required String title,
    required String body,
    String? unitId,
  }) {
    _notifications.insert(
      0,
      AppNotification(
        id: _nextId('n'),
        kind: kind,
        title: title,
        body: body,
        at: DateTime.now(),
        recipientId: recipientId,
        unitId: unitId,
      ),
    );
    _emitNotifications();
  }

  void _log(
    ManagerModel user,
    String action,
    String entity, {
    String details = '',
  }) {
    _audit.add(
      AuditLog(
        id: _nextId('a'),
        at: DateTime.now(),
        userName: user.name,
        action: action,
        entity: entity,
        details: details,
      ),
    );
  }

  String _unitLabel(UnitModel u) =>
      '${u.complexName} · ${u.block} · №${u.number}';

  Future<void> _latency() =>
      Future<void>.delayed(const Duration(milliseconds: 160));

  String _digits(String phone) => phone.replaceAll(RegExp(r'[^0-9]'), '');

  /// Автоснятие истёкших броней (FR-07.7).
  void _sweepExpired() {
    if (_unitsController.isClosed) return;
    var changed = false;
    final now = DateTime.now();
    for (var i = 0; i < _units.length; i++) {
      final u = _units[i];
      if (u.status == UnitStatus.hold &&
          u.heldUntil != null &&
          u.heldUntil!.isBefore(now)) {
        final holderId = u.heldById;
        _units[i] = u.copyWith(
          status: UnitStatus.free,
          clearHold: true,
          history: [
            UnitEvent(
              kind: UnitEventKind.released,
              title: 'Бронь снята автоматически по истечении срока',
              authorName: 'Система',
              at: now,
            ),
            ...u.history,
          ],
        );
        if (holderId != null) {
          _pushNotification(
            recipientId: holderId,
            kind: NotificationKind.released,
            title: 'Бронь истекла',
            body: '${_unitLabel(u)} — бронь снята автоматически',
            unitId: u.id,
          );
        }
        changed = true;
      }
    }
    if (changed) _emitUnits();
  }

  void _seedDeals() {
    // Сделки по квартирам, которые уже держат менеджеры с клиентом.
    for (final client in _clients) {
      final held = _units
          .where((u) => u.heldById == client.sellerId && u.status.isTaken)
          .toList();
      if (held.isEmpty) continue;
      final unit = held.first;
      _deals.add(
        DealModel(
          id: _nextId('d'),
          clientId: client.id,
          clientName: client.name,
          unitId: unit.id,
          unitLabel: _unitLabel(unit),
          sellerId: client.sellerId,
          sellerName: client.sellerName,
          stage: unit.status == UnitStatus.hold
              ? DealStage.booking
              : DealStage.show,
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          nextActionAt: client.nextActionAt,
        ),
      );
    }
  }

  void _seedNotifications() {
    final m = _managers;
    _notifications.addAll([
      AppNotification(
        id: _nextId('n'),
        kind: NotificationKind.expiring,
        title: 'Бронь истекает',
        body: 'Панорама Сити · А · №14 — осталось меньше 24 часов',
        at: DateTime.now().subtract(const Duration(minutes: 25)),
        recipientId: m[0].id,
      ),
      AppNotification(
        id: _nextId('n'),
        kind: NotificationKind.booked,
        title: 'Новая бронь по объекту',
        body: 'Панорама Парк · 1 · №7 забронирована',
        at: DateTime.now().subtract(const Duration(hours: 2)),
        recipientId: _admin.id,
      ),
    ]);
  }

  List<UnitModel> _generateUnits() {
    final units = <UnitModel>[];
    final managers = _managers;

    for (var ci = 0; ci < _complexes.length; ci++) {
      final complex = _complexes[ci];
      final random = Random(1000 + ci * 97);

      for (final block in complex.blocks) {
        final pattern = _layoutPatterns['${complex.id}-${block.name}']!;
        var number = 1;

        for (var floor = 1; floor <= block.floors; floor++) {
          for (var i = 0; i < pattern.length; i++) {
            final rooms = pattern[i];
            final range = _areaRanges[rooms]!;
            final area = double.parse(
              (range.$1 + random.nextDouble() * (range.$2 - range.$1))
                  .toStringAsFixed(1),
            );

            // Нижние этажи распроданы сильнее верхних.
            final soldBias = 0.62 - (floor / block.floors) * 0.44;
            final roll = random.nextDouble();
            var status = roll < soldBias
                ? UnitStatus.sold
                : roll < soldBias + 0.06
                ? UnitStatus.design
                : roll < soldBias + 0.14
                ? UnitStatus.hold
                : roll < soldBias + 0.20
                ? UnitStatus.work
                : UnitStatus.free;
            if (complex.deadline == 'сдан' &&
                status == UnitStatus.free &&
                random.nextDouble() < 0.3) {
              status = UnitStatus.sold;
            }
            // Немного техпомещений на первых этажах.
            if (floor == 1 && i == 0 && random.nextDouble() < 0.4) {
              status = UnitStatus.offMarket;
            }

            final holder = status.isTaken
                ? managers[random.nextInt(managers.length)]
                : null;

            units.add(
              UnitModel(
                id: '${complex.id}-${block.name}-$number',
                complexId: complex.id,
                complexName: complex.name,
                block: block.name,
                floor: floor,
                position: i + 1,
                number: number,
                rooms: rooms,
                area: area,
                status: status,
                kitchen: _kitchens[rooms]!,
                view: i.isEven ? 'на Ала-Тоо' : 'во двор, тихая сторона',
                finish: rooms >= 3 ? 'предчистовая' : 'без отделки',
                bathrooms: rooms >= 3 ? 2 : 1,
                heldById: holder?.id,
                heldByName: holder?.shortName,
                heldUntil: switch (status) {
                  UnitStatus.work => DateTime.now().add(
                    Duration(minutes: 40 + random.nextInt(80)),
                  ),
                  UnitStatus.hold => DateTime.now().add(
                    Duration(hours: 4 + random.nextInt(60)),
                  ),
                  _ => null,
                },
              ),
            );
            number++;
          }
        }
      }
    }
    return units;
  }
}
