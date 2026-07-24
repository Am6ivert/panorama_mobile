import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../data/api_panorama_repository.dart';
import '../data/mock_panorama_repository.dart';
import '../data/panorama_repository.dart';
import '../models/client_model.dart';
import '../models/complex_model.dart';
import '../models/manager_model.dart';
import '../models/unit_model.dart';
import '../models/unit_status.dart';
import '../network/api_client.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final panoramaRepositoryProvider = Provider<PanoramaRepository>((ref) {
  final repository = AppConfig.useMockData
      ? MockPanoramaRepository()
      : ApiPanoramaRepository(ref.read(apiClientProvider));
  ref.onDispose(repository.dispose);
  return repository;
});

final complexesProvider = FutureProvider<List<ComplexModel>>(
  (ref) => ref.read(panoramaRepositoryProvider).fetchComplexes(),
);

final managersProvider = FutureProvider<List<ManagerModel>>(
  (ref) => ref.read(panoramaRepositoryProvider).fetchManagers(),
);

final clientsProvider = FutureProvider<List<ClientModel>>(
  (ref) => ref.read(panoramaRepositoryProvider).fetchClients(),
);

/// Живой фонд квартир: обновляется, как только кто-то из менеджеров
/// взял квартиру в работу, забронировал или закрыл продажу.
final unitsProvider = StreamProvider<List<UnitModel>>(
  (ref) => ref.read(panoramaRepositoryProvider).watchUnits(),
);

/// Менеджер, работающий в приложении. Пока выбирается из списка на старте.
final currentManagerProvider = StateProvider<ManagerModel?>((ref) => null);

/// Квартиры конкретного ЖК.
final complexUnitsProvider = Provider.family<List<UnitModel>, String>(
  (ref, complexId) => ref
      .watch(unitsProvider)
      .value
      ?.where((u) => u.complexId == complexId)
      .toList(growable: false) ??
      const [],
);

/// Квартиры блока, отсортированные по этажу и номеру.
final blockUnitsProvider =
    Provider.family<List<UnitModel>, ({String complexId, String block})>((
  ref,
  key,
) {
  final units = ref
      .watch(complexUnitsProvider(key.complexId))
      .where((u) => u.block == key.block)
      .toList();
  units.sort((a, b) {
    final byFloor = b.floor.compareTo(a.floor);
    return byFloor != 0 ? byFloor : a.number.compareTo(b.number);
  });
  return units;
});

/// Мои показы и брони.
final myDealsProvider = Provider<List<UnitModel>>((ref) {
  final manager = ref.watch(currentManagerProvider);
  if (manager == null) return const [];
  return ref.watch(unitsProvider).value
          ?.where((u) => u.heldBy(manager.id) && u.status.isTaken)
          .toList(growable: false) ??
      const [];
});

/// Счётчики по статусам — для карточек ЖК и легенды шахматки.
class UnitStats {
  const UnitStats(this.free, this.work, this.hold, this.sold);

  final int free;
  final int work;
  final int hold;
  final int sold;

  int get total => free + work + hold + sold;

  factory UnitStats.of(Iterable<UnitModel> units) {
    var free = 0, work = 0, hold = 0, sold = 0;
    for (final unit in units) {
      switch (unit.status) {
        case UnitStatus.free:
          free++;
        case UnitStatus.work:
          work++;
        case UnitStatus.hold:
          hold++;
        case UnitStatus.sold:
          sold++;
      }
    }
    return UnitStats(free, work, hold, sold);
  }
}
