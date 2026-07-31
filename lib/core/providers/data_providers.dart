import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../data/api_panorama_repository.dart';
import '../data/mock_panorama_repository.dart';
import '../data/panorama_repository.dart';
import '../models/app_notification.dart';
import '../models/audit_log.dart';
import '../models/client_model.dart';
import '../models/complex_model.dart';
import '../models/deal_model.dart';
import '../models/manager_model.dart';
import '../models/unit_model.dart';
import '../models/unit_status.dart';
import '../models/user_role.dart';
import '../network/api_client.dart';
import '../notifications/notification_service.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

/// Сервис системных/браузерных уведомлений (push уровня ОС, пока приложение
/// открыто). Создаётся один раз на приложение.
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => createNotificationService(),
);

final panoramaRepositoryProvider = Provider<PanoramaRepository>((ref) {
  final repository = AppConfig.useMockData
      ? MockPanoramaRepository()
      : ApiPanoramaRepository(ref.read(apiClientProvider));
  ref.onDispose(repository.dispose);
  return repository;
});

/// Вошедший пользователь. null — не авторизован (экран входа).
final currentUserProvider = StateProvider<ManagerModel?>((ref) => null);

/// Текущий пользователь — администратор.
final isAdminProvider = Provider<bool>(
  (ref) => ref.watch(currentUserProvider)?.isAdmin ?? false,
);

// --- Справочники ------------------------------------------------------------

final complexesProvider = FutureProvider<List<ComplexModel>>(
  (ref) => ref.read(panoramaRepositoryProvider).fetchComplexes(),
);

/// Все учётные записи (для админ-панели и фильтра по менеджеру).
final usersProvider = FutureProvider<List<ManagerModel>>(
  (ref) => ref.read(panoramaRepositoryProvider).fetchUsers(),
);

/// Только продавцы — для фильтра шахматки/реестра по менеджеру.
final managersProvider = Provider<List<ManagerModel>>(
  (ref) =>
      ref.watch(usersProvider).value
          ?.where((u) => u.role == UserRole.manager)
          .toList(growable: false) ??
      const [],
);

// --- Клиенты и сделки -------------------------------------------------------

final clientsProvider = FutureProvider<List<ClientModel>>(
  (ref) => ref.read(panoramaRepositoryProvider).fetchClients(),
);

/// Клиенты, видимые текущему пользователю: продавец — только свои, админ — все
/// (FR-05.2 изоляция, 5.2).
final visibleClientsProvider = Provider<List<ClientModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  final all = ref.watch(clientsProvider).value ?? const <ClientModel>[];
  if (user == null) return const [];
  if (user.isAdmin) return all;
  return all.where((c) => c.ownedBy(user.id)).toList(growable: false);
});

final dealsProvider = FutureProvider<List<DealModel>>(
  (ref) => ref.read(panoramaRepositoryProvider).fetchDeals(),
);

/// Сделки, видимые текущему пользователю.
final visibleDealsProvider = Provider<List<DealModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  final all = ref.watch(dealsProvider).value ?? const <DealModel>[];
  if (user == null) return const [];
  if (user.isAdmin) return all;
  return all.where((d) => d.sellerId == user.id).toList(growable: false);
});

// --- Фонд квартир -----------------------------------------------------------

/// Живой фонд квартир: обновляется, как только кто-то из менеджеров
/// взял квартиру в работу, забронировал или закрыл продажу (FR-05.5).
final unitsProvider = StreamProvider<List<UnitModel>>(
  (ref) => ref.read(panoramaRepositoryProvider).watchUnits(),
);

/// Квартиры конкретного ЖК.
final complexUnitsProvider = Provider.family<List<UnitModel>, String>(
  (ref, complexId) =>
      ref
          .watch(unitsProvider)
          .value
          ?.where((u) => u.complexId == complexId)
          .toList(growable: false) ??
      const [],
);

/// Квартиры блока, отсортированные по этажу и позиции.
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
        return byFloor != 0 ? byFloor : a.position.compareTo(b.position);
      });
      return units;
    });

/// Мои показы, брони и оформления.
final myDealsProvider = Provider<List<UnitModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.watch(unitsProvider).value
          ?.where((u) => u.heldBy(user.id) && u.status.isTaken)
          .toList(growable: false) ??
      const [];
});

// --- Уведомления ------------------------------------------------------------

/// Поток уведомлений текущего пользователя (FR-11.9).
final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.read(panoramaRepositoryProvider).watchNotifications(user.id);
});

final unreadCountProvider = Provider<int>(
  (ref) =>
      ref.watch(notificationsProvider).value?.where((n) => !n.read).length ?? 0,
);

// --- Аудит ------------------------------------------------------------------

final auditProvider = FutureProvider<List<AuditLog>>(
  (ref) => ref.read(panoramaRepositoryProvider).fetchAuditLogs(),
);

// --- Статистика -------------------------------------------------------------

/// Счётчики по статусам — для дашборда, карточек ЖК и легенды шахматки.
class UnitStats {
  const UnitStats({
    required this.free,
    required this.work,
    required this.hold,
    required this.design,
    required this.sold,
    required this.offMarket,
  });

  final int free;
  final int work;
  final int hold;
  final int design;
  final int sold;
  final int offMarket;

  /// В продаже (без техпомещений).
  int get sellable => free + work + hold + design + sold;

  int get total => sellable + offMarket;

  factory UnitStats.of(Iterable<UnitModel> units) {
    var free = 0, work = 0, hold = 0, design = 0, sold = 0, offMarket = 0;
    for (final unit in units) {
      switch (unit.status) {
        case UnitStatus.free:
          free++;
        case UnitStatus.work:
          work++;
        case UnitStatus.hold:
          hold++;
        case UnitStatus.design:
          design++;
        case UnitStatus.sold:
          sold++;
        case UnitStatus.offMarket:
          offMarket++;
      }
    }
    return UnitStats(
      free: free,
      work: work,
      hold: hold,
      design: design,
      sold: sold,
      offMarket: offMarket,
    );
  }
}
