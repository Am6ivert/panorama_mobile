import 'dart:async';
import 'dart:math';

import '../config/app_config.dart';
import '../models/client_model.dart';
import '../models/complex_model.dart';
import '../models/manager_model.dart';
import '../models/unit_event.dart';
import '../models/unit_model.dart';
import '../models/unit_status.dart';
import 'panorama_repository.dart';

/// Демо-данные до подключения API Panorama.
///
/// Фонд генерируется детерминированно (сид фиксирован), поэтому при
/// перезапуске приложения шахматка выглядит одинаково.
class MockPanoramaRepository implements PanoramaRepository {
  /// [simulateColleagues] выключается в тестах, чтобы фонд не менялся
  /// сам по себе посреди проверки.
  MockPanoramaRepository({bool simulateColleagues = true}) {
    _units = _generateUnits();
    if (simulateColleagues) {
      _simulation = Timer.periodic(
        const Duration(seconds: 20),
        (_) => _simulateOtherManager(),
      );
    }
  }

  late final List<UnitModel> _units;
  Timer? _simulation;
  final _controller = StreamController<List<UnitModel>>.broadcast();
  final _random = Random();

  static const _managers = [
    ManagerModel(
      id: 'm1',
      name: 'Азамат Кубанычбеков',
      phone: '+996 555 10-22-30',
    ),
    ManagerModel(id: 'm2', name: 'Эльвира Садыкова', phone: '+996 700 41-08-19'),
    ManagerModel(id: 'm3', name: 'Нурлан Осмонов', phone: '+996 559 77-13-04'),
    ManagerModel(id: 'm4', name: 'Бекзат Жумалиев', phone: '+996 772 60-55-21'),
  ];

  /// Клиенты живут в памяти: заведённые на объекте пропадут при перезапуске,
  /// пока не подключён API.
  late final List<ClientModel> _clients = [..._seedClients];

  /// Последний выданный номер клиента — продолжаем нумерацию демо-карточек.
  int _lastClientNumber = _seedClients.length;

  static const _seedClients = [
    ClientModel(
      id: 'c1',
      name: 'Айбек Сыдыков',
      phone: '+996 555 41-20-08',
      rooms: 2,
      budget: 62000,
      note: 'Ищет 2-комнатную до \$62 000, важен вид на горы. Ипотека Айыл Банк.',
    ),
    ClientModel(
      id: 'c2',
      name: 'Гульмира Асанова',
      phone: '+996 700 88-14-73',
      rooms: 3,
      budget: 95000,
      note: 'Семья из четырёх человек, нужна 3-комнатная не выше 8 этажа.',
    ),
    ClientModel(
      id: 'c3',
      name: 'Тимур Алиев',
      phone: '+996 559 03-77-12',
      rooms: 1,
      budget: 44000,
      note: 'Покупает под сдачу. Интересует рассрочка без процентов.',
    ),
    ClientModel(
      id: 'c4',
      name: 'Жаныл Мураталиева',
      phone: '+996 772 55-61-90',
      rooms: 0,
      budget: 33000,
      note: 'Студия для дочери-студентки, ближе к центру.',
    ),
  ];

  static const _complexes = [
    ComplexModel(
      id: 'city',
      name: 'Панорама Сити',
      address: 'ул. Ахунбаева, 121',
      deadline: 'сдача 2 кв. 2027',
      segment: 'бизнес',
      pricePerSquare: 1150,
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
      pricePerSquare: 980,
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
      pricePerSquare: 1420,
      coverStart: 0xFF7C2D12,
      coverEnd: 0xFFF59E0B,
      blocks: [
        BlockModel(name: 'А', floors: 9, unitsPerFloor: 3),
        BlockModel(name: 'Б', floors: 9, unitsPerFloor: 3),
      ],
    ),
  ];

  /// Комнатность квартир на этаже по каждому блоку.
  static const _layoutPatterns = <String, List<int>>{
    'city-А': [1, 2, 2, 3, 1, 0],
    'city-Б': [0, 1, 2, 2, 3],
    'city-В': [2, 3, 3, 2],
    'park-1': [0, 1, 1, 2, 2],
    'park-2': [1, 2, 3, 2, 1],
    'res-А': [2, 3, 4],
    'res-Б': [3, 3, 4],
  };

  /// Диапазон площадей по комнатности.
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

  @override
  Future<List<ComplexModel>> fetchComplexes() async {
    await _latency();
    return _complexes;
  }

  @override
  Future<List<ManagerModel>> fetchManagers() async {
    await _latency();
    return _managers;
  }

  @override
  Future<List<ClientModel>> fetchClients() async {
    await _latency();
    return List.unmodifiable(_clients);
  }

  @override
  Future<ClientModel> addClient({
    required String name,
    required String phone,
    required int rooms,
    required int budget,
    String note = '',
  }) async {
    await _latency();
    final client = ClientModel(
      id: 'c${++_lastClientNumber}',
      name: name,
      phone: phone,
      rooms: rooms,
      budget: budget,
      note: note,
    );
    // Свежий клиент — первым в списке: менеджер только что его завёл.
    _clients.insert(0, client);
    return client;
  }

  @override
  Future<List<UnitModel>> fetchUnits() async {
    await _latency();
    return List.unmodifiable(_units);
  }

  @override
  Stream<List<UnitModel>> watchUnits() async* {
    yield List.unmodifiable(_units);
    yield* _controller.stream;
  }

  @override
  Future<UnitModel> takeToWork({
    required String unitId,
    required ManagerModel manager,
    ClientModel? client,
  }) => _apply(
    unitId,
    status: UnitStatus.work,
    manager: manager,
    client: client,
    until: DateTime.now().add(AppConfig.workHoldDuration),
    event: UnitEventKind.taken,
    title: client == null
        ? 'Взята в работу'
        : 'Взята в работу — ${client.name}',
  );

  @override
  Future<UnitModel> book({
    required String unitId,
    required ManagerModel manager,
    ClientModel? client,
  }) => _apply(
    unitId,
    status: UnitStatus.hold,
    manager: manager,
    client: client,
    until: DateTime.now().add(AppConfig.bookingDuration),
    event: UnitEventKind.booked,
    title: client == null
        ? 'Бронь на 24 часа'
        : 'Бронь на 24 часа — ${client.name}',
  );

  @override
  Future<UnitModel> release({
    required String unitId,
    required ManagerModel manager,
  }) async {
    await _latency();
    final index = _units.indexWhere((u) => u.id == unitId);
    final unit = _units[index];
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
    _units[index] = updated;
    _emit();
    return updated;
  }

  @override
  void dispose() {
    _simulation?.cancel();
    _controller.close();
  }

  // ---------------------------------------------------------------------------

  Future<UnitModel> _apply(
    String unitId, {
    required UnitStatus status,
    required ManagerModel manager,
    required DateTime until,
    required UnitEventKind event,
    required String title,
    ClientModel? client,
  }) async {
    await _latency();
    final index = _units.indexWhere((u) => u.id == unitId);
    final unit = _units[index];
    final updated = unit.copyWith(
      status: status,
      heldById: manager.id,
      heldByName: manager.shortName,
      heldUntil: until,
      clientId: client?.id,
      clientName: client?.name,
      history: [
        UnitEvent(
          kind: event,
          title: title,
          authorName: manager.shortName,
          at: DateTime.now(),
        ),
        ...unit.history,
      ],
    );
    _units[index] = updated;
    _emit();
    return updated;
  }

  void _emit() => _controller.add(List.unmodifiable(_units));

  Future<void> _latency() =>
      Future<void>.delayed(const Duration(milliseconds: 180));

  /// Имитация работы коллег: пока подключён мок, фонд «живёт» —
  /// видно, что шахматка обновляется без звонка в офис.
  void _simulateOtherManager() {
    if (_controller.isClosed) return;
    final free = _units
        .where((u) => u.status == UnitStatus.free)
        .toList(growable: false);
    if (free.isEmpty) return;

    final unit = free[_random.nextInt(free.length)];
    final manager = _managers[1 + _random.nextInt(_managers.length - 1)];
    final roll = _random.nextInt(3);

    final (status, kind, title, until) = switch (roll) {
      0 => (
        UnitStatus.work,
        UnitEventKind.taken,
        'Взята в работу',
        DateTime.now().add(AppConfig.workHoldDuration),
      ),
      1 => (
        UnitStatus.hold,
        UnitEventKind.booked,
        'Бронь на 24 часа',
        DateTime.now().add(AppConfig.bookingDuration),
      ),
      _ => (UnitStatus.sold, UnitEventKind.sold, 'Продана', null),
    };

    final index = _units.indexWhere((u) => u.id == unit.id);
    _units[index] = unit.copyWith(
      status: status,
      heldById: manager.id,
      heldByName: manager.shortName,
      heldUntil: until,
      history: [
        UnitEvent(
          kind: kind,
          title: title,
          authorName: manager.shortName,
          at: DateTime.now(),
        ),
        ...unit.history,
      ],
    );
    _emit();
  }

  List<UnitModel> _generateUnits() {
    final units = <UnitModel>[];

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
            final soldBias = 0.72 - (floor / block.floors) * 0.52;
            final roll = random.nextDouble();
            var status = roll < soldBias
                ? UnitStatus.sold
                : roll < soldBias + 0.09
                ? UnitStatus.hold
                : roll < soldBias + 0.13
                ? UnitStatus.work
                : UnitStatus.free;
            if (complex.deadline == 'сдан' &&
                status == UnitStatus.free &&
                random.nextDouble() < 0.3) {
              status = UnitStatus.sold;
            }

            final floorFactor = floor >= block.floors - 2
                ? 1.06
                : floor <= 2
                ? 0.95
                : 1 + floor / block.floors * 0.05;
            final price =
                (area * complex.pricePerSquare * floorFactor / 100).round() *
                100;

            final holder = status == UnitStatus.free
                ? null
                : _managers[random.nextInt(_managers.length)];

            units.add(
              UnitModel(
                id: '${complex.id}-${block.name}-$number',
                complexId: complex.id,
                complexName: complex.name,
                block: block.name,
                floor: floor,
                number: number,
                rooms: rooms,
                area: area,
                price: price,
                status: status,
                kitchen: _kitchens[rooms]!,
                view: i.isEven ? 'на Ала-Тоо' : 'во двор, тихая сторона',
                finish: rooms >= 3 ? 'предчистовая' : 'без отделки',
                bathrooms: rooms >= 3 ? 2 : 1,
                heldById: status == UnitStatus.sold ? null : holder?.id,
                heldByName: status == UnitStatus.sold
                    ? null
                    : holder?.shortName,
                heldUntil: switch (status) {
                  UnitStatus.work => DateTime.now().add(
                    Duration(minutes: 40 + random.nextInt(80)),
                  ),
                  UnitStatus.hold => DateTime.now().add(
                    Duration(hours: 4 + random.nextInt(20)),
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
