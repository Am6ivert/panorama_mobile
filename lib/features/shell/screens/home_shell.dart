import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/providers/ui_providers.dart';
import '../../clients/screens/clients_screen.dart';
import '../../complexes/screens/complexes_screen.dart';
import '../../deals/screens/deals_screen.dart';
import '../../search/screens/search_screen.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  static const _tabs = [
    ComplexesScreen(),
    SearchScreen(),
    DealsScreen(),
    ClientsScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(shellTabProvider);
    final deals = ref.watch(myDealsProvider).length;

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
              icon: Icon(Icons.apartment_outlined, color: AppColors.ink3),
              selectedIcon: Icon(Icons.apartment, color: AppColors.brand),
              label: 'Объекты',
            ),
            const NavigationDestination(
              icon: Icon(Icons.my_location_outlined, color: AppColors.ink3),
              selectedIcon: Icon(Icons.my_location, color: AppColors.brand),
              label: 'Подбор',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: deals > 0,
                label: Text('$deals'),
                child: const Icon(
                  Icons.handshake_outlined,
                  color: AppColors.ink3,
                ),
              ),
              selectedIcon: Badge(
                isLabelVisible: deals > 0,
                label: Text('$deals'),
                child: const Icon(Icons.handshake, color: AppColors.brand),
              ),
              label: 'Сделки',
            ),
            const NavigationDestination(
              icon: Icon(Icons.people_outline, color: AppColors.ink3),
              selectedIcon: Icon(Icons.people, color: AppColors.brand),
              label: 'Клиенты',
            ),
          ],
        ),
      ),
    );
  }
}
