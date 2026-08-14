import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:firebase_messaging/firebase_messaging.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/app_notification.dart';
import '../../../core/notifications/fcm_service.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/providers/ui_providers.dart';
import '../../clients/screens/clients_screen.dart';
import '../../complexes/screens/complexes_screen.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../registry/screens/registry_screen.dart';
import '../../../shared/widgets/subscription_banner.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  static const _tabs = [
    DashboardScreen(),
    ComplexesScreen(),
    RegistryScreen(),
    ClientsScreen(),
    NotificationsScreen(),
  ];

  late final NotificationService _push = ref.read(notificationServiceProvider);
  final _seen = <String>{};
  bool _firstBatch = true;

  @override
  void initState() {
    super.initState();
    _push.init();
    _setupFcm();
  }

  /// Регистрирует FCM-токен на backend для фонового push и настраивает переход
  /// по нажатию на пуш. Тихо выходит, если Firebase недоступен.
  Future<void> _setupFcm() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    try {
      final token = await FcmService.obtainToken();
      if (token != null) {
        await ref.read(panoramaRepositoryProvider).registerDevice(
              userId: user.id,
              token: token,
              platform: FcmService.platform,
            );
      }
      FirebaseMessaging.onMessageOpenedApp.listen((_) {
        if (mounted) {
          ref.read(shellTabProvider.notifier).state = ShellTab.notifications;
        }
      });
    } catch (_) {
      // Firebase недоступен (тесты/без конфигурации) — работаем на поллинге.
    }
  }

  /// Показывает системное/браузерное уведомление о новых непрочитанных.
  void _surfaceNew(List<AppNotification> list) {
    if (_firstBatch) {
      _seen.addAll(list.map((n) => n.id)); // при входе не спамим старыми
      _firstBatch = false;
      return;
    }
    for (final n in list) {
      if (!n.read && _seen.add(n.id)) {
        _push.show(title: n.title, body: n.body);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(notificationsProvider, (_, next) {
      final list = next.value;
      if (list != null) _surfaceNew(list);
    });

    final index = ref.watch(shellTabProvider);
    final unread = ref.watch(unreadCountProvider);

    return Scaffold(
      body: Column(
        children: [
          // Плашка о подписке: видна на всех вкладках и только когда есть
          // о чём предупредить.
          const SubscriptionBanner(),
          Expanded(child: IndexedStack(index: index, children: _tabs)),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) =>
              ref.read(shellTabProvider.notifier).state = i,
          height: 62,
          backgroundColor: AppColors.surface,
          indicatorColor: Colors.transparent,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.dashboard_outlined, color: AppColors.ink3),
              selectedIcon: Icon(Icons.dashboard, color: AppColors.brand),
              label: 'Дашборд',
            ),
            const NavigationDestination(
              icon: Icon(Icons.grid_view_outlined, color: AppColors.ink3),
              selectedIcon: Icon(Icons.grid_view, color: AppColors.brand),
              label: 'Шахматка',
            ),
            const NavigationDestination(
              icon: Icon(Icons.list_alt_outlined, color: AppColors.ink3),
              selectedIcon: Icon(Icons.list_alt, color: AppColors.brand),
              label: 'Реестр',
            ),
            const NavigationDestination(
              icon: Icon(Icons.people_outline, color: AppColors.ink3),
              selectedIcon: Icon(Icons.people, color: AppColors.brand),
              label: 'Клиенты',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: unread > 0,
                label: Text('$unread'),
                child: const Icon(
                  Icons.notifications_outlined,
                  color: AppColors.ink3,
                ),
              ),
              selectedIcon: Badge(
                isLabelVisible: unread > 0,
                label: Text('$unread'),
                child: const Icon(Icons.notifications, color: AppColors.brand),
              ),
              label: 'Уведомления',
            ),
          ],
        ),
      ),
    );
  }
}
