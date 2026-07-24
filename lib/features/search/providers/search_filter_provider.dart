import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/client_model.dart';
import '../../../core/models/unit_model.dart';

class SearchFilter {
  const SearchFilter({
    this.rooms = const {},
    this.budget = 60000,
    this.minArea = 30,
  });

  final Set<int> rooms;

  /// Верхняя граница бюджета в долларах.
  final int budget;
  final double minArea;

  SearchFilter copyWith({Set<int>? rooms, int? budget, double? minArea}) =>
      SearchFilter(
        rooms: rooms ?? this.rooms,
        budget: budget ?? this.budget,
        minArea: minArea ?? this.minArea,
      );
}

class SearchFilterNotifier extends Notifier<SearchFilter> {
  static const minBudget = 20000;
  static const maxBudget = 130000;

  @override
  SearchFilter build() => const SearchFilter();

  void toggleRoom(int rooms) {
    final next = {...state.rooms};
    next.contains(rooms) ? next.remove(rooms) : next.add(rooms);
    state = state.copyWith(rooms: next);
  }

  void setBudget(int value) => state = state.copyWith(budget: value);

  void setMinArea(double value) => state = state.copyWith(minArea: value);

  /// Подобрать что-то похожее на конкретную квартиру.
  void seedFrom(UnitModel unit) => state = SearchFilter(
    rooms: {unit.rooms},
    budget: (unit.price * 1.15 / 2500).round() * 2500 > maxBudget
        ? maxBudget
        : (unit.price * 1.15 / 2500).round() * 2500,
    minArea: (unit.area * 0.85).floorToDouble().clamp(25, 110),
  );

  /// Подобрать под запрос клиента.
  void seedFromClient(ClientModel client) => state = SearchFilter(
    rooms: {client.rooms},
    budget: client.budget.clamp(minBudget, maxBudget),
    minArea: 25,
  );
}

final searchFilterProvider =
    NotifierProvider<SearchFilterNotifier, SearchFilter>(
      SearchFilterNotifier.new,
    );
