import '../utils/money.dart';
import 'unit_event.dart';
import 'unit_status.dart';

/// Квартира — центральная сущность приложения.
class UnitModel {
  const UnitModel({
    required this.id,
    required this.complexId,
    required this.complexName,
    required this.block,
    required this.floor,
    required this.number,
    required this.rooms,
    required this.area,
    required this.price,
    required this.status,
    this.kitchen = '',
    this.view = '',
    this.finish = '',
    this.bathrooms = 1,
    this.heldById,
    this.heldByName,
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

  /// Номер квартиры в блоке.
  final int number;

  /// 0 — студия.
  final int rooms;
  final double area;

  /// Полная стоимость в долларах.
  final int price;
  final UnitStatus status;

  final String kitchen;
  final String view;
  final String finish;
  final int bathrooms;

  /// Кто держит квартиру — заполнено для статусов «в работе» и «бронь».
  final String? heldById;
  final String? heldByName;
  final DateTime? heldUntil;

  final String? clientId;
  final String? clientName;

  final List<UnitEvent> history;

  /// «Студия», «2-комн.»
  String get layoutName => rooms == 0 ? 'Студия' : '$rooms-комн.';

  /// Короткая подпись для клетки шахматки: «Ст», «2к».
  String get shortLayout => rooms == 0 ? 'Ст' : '$roomsк';

  String get priceUsd => Money.usd(price);
  String get priceKgs => Money.kgsApprox(price);
  String get pricePerSquare => Money.perSquare(price, area);

  bool heldBy(String managerId) => heldById == managerId;

  UnitModel copyWith({
    UnitStatus? status,
    String? heldById,
    String? heldByName,
    DateTime? heldUntil,
    String? clientId,
    String? clientName,
    List<UnitEvent>? history,
    bool clearHold = false,
  }) => UnitModel(
    id: id,
    complexId: complexId,
    complexName: complexName,
    block: block,
    floor: floor,
    number: number,
    rooms: rooms,
    area: area,
    price: price,
    status: status ?? this.status,
    kitchen: kitchen,
    view: view,
    finish: finish,
    bathrooms: bathrooms,
    heldById: clearHold ? null : (heldById ?? this.heldById),
    heldByName: clearHold ? null : (heldByName ?? this.heldByName),
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
    number: (json['number'] as num?)?.toInt() ?? 0,
    rooms: (json['rooms'] as num?)?.toInt() ?? 0,
    area: (json['area'] as num?)?.toDouble() ?? 0,
    price: (json['price'] as num?)?.toInt() ?? 0,
    status: UnitStatus.fromWire(json['status'] as String?),
    kitchen: json['kitchen'] as String? ?? '',
    view: json['view'] as String? ?? '',
    finish: json['finish'] as String? ?? '',
    bathrooms: (json['bathrooms'] as num?)?.toInt() ?? 1,
    heldById: json['held_by_id'] as String?,
    heldByName: json['held_by_name'] as String?,
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
    'number': number,
    'rooms': rooms,
    'area': area,
    'price': price,
    'status': status.wire,
    'kitchen': kitchen,
    'view': view,
    'finish': finish,
    'bathrooms': bathrooms,
    'held_by_id': heldById,
    'held_by_name': heldByName,
    'held_until': heldUntil?.toIso8601String(),
    'client_id': clientId,
    'client_name': clientName,
    'history': history.map((e) => e.toJson()).toList(),
  };
}
