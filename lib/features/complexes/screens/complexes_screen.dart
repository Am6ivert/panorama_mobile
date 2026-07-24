import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/initials_avatar.dart';
import '../../../shared/widgets/section_title.dart';
import '../widgets/complex_card.dart';

class ComplexesScreen extends ConsumerWidget {
  const ComplexesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.watch(currentManagerProvider);
    final complexes = ref.watch(complexesProvider);
    final units = ref.watch(unitsProvider);

    return Column(
      children: [
        AppHeader(
          title: 'Panorama',
          subtitle: manager == null
              ? 'Отдел продаж'
              : '${manager.name} · отдел продаж',
          trailing: manager == null
              ? null
              : InitialsAvatar(
                  initials: manager.initials,
                  color: manager.color,
                  size: 36,
                  fontSize: 13,
                ),
          bottom: const LiveIndicator(
            text: 'Онлайн · фонд обновляется в реальном времени',
          ),
        ),
        Expanded(
          child: complexes.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Ошибка загрузки: $e')),
            data: (list) => ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                const SectionTitle('Мои объекты'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      for (final complex in list)
                        ComplexCard(
                          complex: complex,
                          stats: UnitStats.of(
                            units.value?.where(
                                  (u) => u.complexId == complex.id,
                                ) ??
                                const [],
                          ),
                          onTap: () => Navigator.of(context).pushNamed(
                            AppRoutes.board,
                            arguments: complex.id,
                          ),
                        ),
                    ],
                  ),
                ),
                if (units.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Text(
                    'Данные по квартирам приходят с сервера: если коллега взял '
                    'квартиру в работу, вы увидите это здесь без звонка в офис.',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.5,
                      color: AppColors.ink3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
