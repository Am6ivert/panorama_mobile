import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/providers/ui_providers.dart';
import '../../clients/screens/clients_screen.dart';
import '../../complexes/screens/complexes_screen.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../registry/screens/registry_screen.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  static const _tabs = [
    DashboardScreen(),
    ComplexesScreen(),
    RegistryScreen(),
    ClientsScreen(),
    NotificationsScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(shellTabProvider);
    final unread = ref.watch(unreadCountProvider);

    return Scaffold(
      body: IndexedStack(index: index, children: _tabs),
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
