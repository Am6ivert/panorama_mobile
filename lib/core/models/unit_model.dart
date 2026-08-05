import 'unit_event.dart';
import 'unit_status.dart';

/// Квартира — центральная сущность приложения (FR-02.3).
///
/// Денежные поля отсутствуют намеренно (ТЗ 1.3): подбор идёт только по
/// характеристикам — объект, блок, этаж, комнаты, площадь, вид, отделка.
class UnitModel {
  const UnitModel({
    required this.id,
    required this.complexId,
    required this.complexName,
    required this.block,
    required this.floor,
    required this.position,
    required this.number,
    required this.rooms,
    required this.area,
    required this.status,
    this.kitchen = '',
    this.view = '',
    this.finish = '',
    this.bathrooms = 1,
    this.isPenthouse = false,
    this.heldById,
    this.heldByName,
    this.heldFrom,
    this.heldUntil,
    this.clientId,
    this.clientName,
    this.history = const [],
  });

  final String id;
  final String complexId;
  final String complexName;
  final String block;
  final int floor;

  /// Позиция квартиры на этаже слева направо (колонка в шахматке, глоссарий).
  final int position;

  /// Сквозной номер квартиры в блоке.
  final int number;

  /// 0 — студия.
  final int rooms;
  final double area;
  final UnitStatus status;

  final String kitchen;
  final String view;
  final String finish;
  final int bathrooms;

  /// Пентхаус (верхний уровень, отдельный тип квартиры).
  final bool isPenthouse;

  /// Кто держит квартиру — заполнено для «в работе», «бронь», «оформление».
  final String? heldById;
  final String? heldByName;

  /// Начало брони (FR-07: бронь на диапазон дат «с какой по какую»).
  final DateTime? heldFrom;
  final DateTime? heldUntil;

  final String? clientId;
  final String? clientName;

  final List<UnitEvent> history;

  /// «Студия», «2-комн.», «Пентхаус».
  String get layoutName =>
      isPenthouse ? 'Пентхаус' : (rooms == 0 ? 'Студия' : '$rooms-комн.');

  /// Короткая подпись для клетки шахматки: «Ст», «2к», «ПХ» (пентхаус).
  String get shortLayout =>
      isPenthouse ? 'ПХ' : (rooms == 0 ? 'Ст' : '$roomsк');

  bool heldBy(String managerId) => heldById == managerId;

  /// Остаток времени брони/показа; null — если бессрочно или снят.
  Duration? get timeLeft {
    final until = heldUntil;
    if (until == null) return null;
    final left = until.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  UnitModel copyWith({
    UnitStatus? status,
    String? heldById,
    String? heldByName,
    DateTime? heldFrom,
    DateTime? heldUntil,
    String? clientId,
    String? clientName,
    List<UnitEvent>? history,
    int? rooms,
    double? area,
    String? kitchen,
    String? view,
    String? finish,
    int? bathrooms,
    bool? isPenthouse,
    bool clearHold = false,
  }) => UnitModel(
    id: id,
    complexId: complexId,
    complexName: complexName,
    block: block,
    floor: floor,
    position: position,
    number: number,
    rooms: rooms ?? this.rooms,
    area: area ?? this.area,
    status: status ?? this.status,
    kitchen: kitchen ?? this.kitchen,
    view: view ?? this.view,
    finish: finish ?? this.finish,
    bathrooms: bathrooms ?? this.bathrooms,
    isPenthouse: isPenthouse ?? this.isPenthouse,
    heldById: clearHold ? null : (heldById ?? this.heldById),
    heldByName: clearHold ? null : (heldByName ?? this.heldByName),
    heldFrom: clearHold ? null : (heldFrom ?? this.heldFrom),
    heldUntil: clearHold ? null : (heldUntil ?? this.heldUntil),
    clientId: clearHold ? null : (clientId ?? this.clientId),
    clientName: clearHold ? null : (clientName ?? this.clientName),
    history: history ?? this.history,
  );

  factory UnitModel.fromJson(Map<String, dynamic> json) => UnitModel(
    id: json['id'] as String,
    complexId: json['complex_id'] as String? ?? '',
    complexName: json['complex_name'] as String? ?? '',
    block: json['block'] as String? ?? '',
    floor: (json['floor'] as num?)?.toInt() ?? 0,
    position: (json['position'] as num?)?.toInt() ?? 0,
    number: (json['number'] as num?)?.toInt() ?? 0,
    rooms: (json['rooms'] as num?)?.toInt() ?? 0,
    area: (json['area'] as num?)?.toDouble() ?? 0,
    status: UnitStatus.fromWire(json['status'] as String?),
    kitchen: json['kitchen'] as String? ?? '',
    view: json['view'] as String? ?? '',
    finish: json['finish'] as String? ?? '',
    bathrooms: (json['bathrooms'] as num?)?.toInt() ?? 1,
    isPenthouse: json['is_penthouse'] as bool? ?? false,
    heldById: json['held_by_id'] as String?,
    heldByName: json['held_by_name'] as String?,
    heldFrom: json['held_from'] == null
        ? null
        : DateTime.parse(json['held_from'] as String),
    heldUntil: json['held_until'] == null
        ? null
        : DateTime.parse(json['held_until'] as String),
    clientId: json['client_id'] as String?,
    clientName: json['client_name'] as String?,
    history:
        (json['history'] as List<dynamic>?)
            ?.map((e) => UnitEvent.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'complex_id': complexId,
    'complex_name': complexName,
    'block': block,
    'floor': floor,
    'position': position,
    'number': number,
    'rooms': rooms,
    'area': area,
    'status': status.wire,
    'kitchen': kitchen,
    'view': view,
    'finish': finish,
    'bathrooms': bathrooms,
    'is_penthouse': isPenthouse,
    'held_by_id': heldById,
    'held_by_name': heldByName,
    'held_from': heldFrom?.toIso8601String(),
    'held_until': heldUntil?.toIso8601String(),
    'client_id': clientId,
    'client_name': clientName,
    'history': history.map((e) => e.toJson()).toList(),
  };
}
