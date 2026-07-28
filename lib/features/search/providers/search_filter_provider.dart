import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/client_model.dart';
import '../../../core/models/unit_model.dart';

/// Фильтр подбора — только по характеристикам (ТЗ 1.3), без бюджета.
class SearchFilter {
  const SearchFilter({
    this.rooms = const {},
    this.minArea = 25,
    this.complexId,
  });

  final Set<int> rooms;
  final double minArea;

  /// Ограничить одним объектом; null — по всем.
  final String? complexId;

  SearchFilter copyWith({
    Set<int>? rooms,
    double? minArea,
    String? complexId,
    bool clearComplex = false,
  }) => SearchFilter(
    rooms: rooms ?? this.rooms,
    minArea: minArea ?? this.minArea,
    complexId: clearComplex ? null : (complexId ?? this.complexId),
  );
}

class SearchFilterNotifier extends Notifier<SearchFilter> {
  @override
  SearchFilter build() => const SearchFilter();

  void toggleRoom(int rooms) {
    final next = {...state.rooms};
    next.contains(rooms) ? next.remove(rooms) : next.add(rooms);
    state = state.copyWith(rooms: next);
  }

  void setMinArea(double value) => state = state.copyWith(minArea: value);

  void setComplex(String? id) => id == null
      ? state = state.copyWith(clearComplex: true)
      : state = state.copyWith(complexId: id);

  /// Подобрать что-то похожее на конкретную квартиру.
  void seedFrom(UnitModel unit) => state = SearchFilter(
    rooms: {unit.rooms},
    minArea: (unit.area * 0.85).floorToDouble().clamp(25, 130),
  );

  /// Подобрать под запрос клиента.
  void seedFromClient(ClientModel client) => state = SearchFilter(
    rooms: {client.rooms},
    minArea: 25,
  );
}

final searchFilterProvider =
    NotifierProvider<SearchFilterNotifier, SearchFilter>(
      SearchFilterNotifier.new,
    );
