import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/data/panorama_repository.dart';
import '../../../core/models/complex_model.dart';
import '../../../core/models/unit_model.dart';
import '../../../core/models/unit_status.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_format.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../search/providers/search_filter_provider.dart';
import 'client_pick_sheet.dart';
import 'unit_plan.dart';

/// Карточка квартиры (FR-06). Кнопки зависят от статуса и от того, является ли
/// пользователь ответственным менеджером или администратором. Денежных
/// значений нет (ТЗ 1.3).
class UnitSheet extends ConsumerWidget {
  const UnitSheet({super.key, required this.unitId});

  final String unitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = _find(ref.watch(unitsProvider).value);
    if (unit == null) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final user = ref.watch(currentUserProvider);
    final isAdmin = user?.isAdmin ?? false;
    final mine = user != null && unit.heldBy(user.id);
    final canSeeClient = mine || isAdmin;
    final complex = _complex(ref, unit.complexId);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Title(unit: unit),
              const SizedBox(height: 14),
              UnitGallery(
                rooms: unit.rooms,
                cover:
                    complex?.cover ??
                    const LinearGradient(
                      colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                    ),
              ),
              const SizedBox(height: 14),
              _StatusNote(unit: unit, mine: mine, canSeeClient: canSeeClient),
              _Specs(unit: unit),
              const SizedBox(height: 14),
              _Actions(unit: unit, mine: mine, isAdmin: isAdmin),
              if (unit.history.isNotEmpty) _History(unit: unit),
            ],
          ),
        ),
      ),
    );
  }

  UnitModel? _find(List<UnitModel>? units) {
    for (final unit in units ?? const <UnitModel>[]) {
      if (unit.id == unitId) return unit;
    }
    return null;
  }

  ComplexModel? _complex(WidgetRef ref, String id) {
    for (final complex in ref.watch(complexesProvider).value ?? const []) {
      if (complex.id == id) return complex;
    }
    return null;
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.unit});

  final UnitModel unit;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Кв. №${unit.number} · ${unit.layoutName}',
              style: AppTextStyles.h1.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 3),
            Text(
              '${unit.complexName} · Блок ${unit.block} · ${unit.floor} этаж',
              style: AppTextStyles.secondary,
            ),
          ],
        ),
      ),
      const SizedBox(width: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: unit.status.background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          unit.status.label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: unit.status.foreground,
          ),
        ),
      ),
    ],
  );
}

/// Объясняет менеджеру, что происходит с квартирой и можно ли её продавать.
/// Данные клиента показываются только ответственному и администратору.
class _StatusNote extends StatelessWidget {
  const _StatusNote({
    required this.unit,
    required this.mine,
    required this.canSeeClient,
  });

  final UnitModel unit;
  final bool mine;
  final bool canSeeClient;

  @override
  Widget build(BuildContext context) {
    final until = unit.heldUntil;
    final clientLine = canSeeClient && unit.clientName != null
        ? '\nКлиент: ${unit.clientName}'
        : '';

    final (text, background, foreground) = switch (unit.status) {
      UnitStatus.free => (null, null, null),
      UnitStatus.work when mine => (
        'Квартира закреплена за вами${until == null ? '' : ' ${TimeFormat.until(until)}'}. '
            'Другие менеджеры видят её занятой.$clientLine',
        AppColors.freeBg,
        AppColors.freeInk,
      ),
      UnitStatus.work => (
        '${unit.heldByName} показывает клиенту'
            '${until == null ? '' : ' ${TimeFormat.until(until)}'}. Продавать нельзя.',
        AppColors.workBg,
        AppColors.workInk,
      ),
      UnitStatus.hold => (
        'Бронь${until == null ? '' : ' ${TimeFormat.until(until)}'} · '
            'менеджер ${unit.heldByName ?? '—'}$clientLine',
        AppColors.holdBg,
        AppColors.holdInk,
      ),
      UnitStatus.design => (
        'Идёт оформление документов · менеджер ${unit.heldByName ?? '—'}$clientLine',
        AppColors.designBg,
        AppColors.designInk,
      ),
      UnitStatus.sold => (
        'Продана${unit.heldByName == null ? '' : ' · менеджер ${unit.heldByName}'}',
        AppColors.soldBg,
        AppColors.soldInk,
      ),
      UnitStatus.offMarket => (
        'Не для продажи — техническое помещение или снята с продажи.',
        AppColors.offMarketBg,
        AppColors.offMarketInk,
      ),
    };

    if (text == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, height: 1.45, color: foreground),
      ),
    );
  }
}

class _Specs extends StatelessWidget {
  const _Specs({required this.unit});

  final UnitModel unit;

  @override
  Widget build(BuildContext context) {
    final rows = [
      [('Общая площадь', '${unit.area} м²'), ('Кухня', unit.kitchen)],
      [('Санузлов', '${unit.bathrooms}'), ('Этаж · позиция', '${unit.floor} · ${unit.position}')],
      [('Вид из окон', unit.view), ('Отделка', unit.finish)],
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.line),
            SizedBox(
              height: 58,
              child: Row(
                children: [
                  Expanded(child: _cell(rows[i][0])),
                  Container(width: 1, color: AppColors.line),
                  Expanded(child: _cell(rows[i][1])),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _cell((String, String) data) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 13),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(data.$1, style: AppTextStyles.caption),
        const SizedBox(height: 2),
        Text(
          data.$2,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
      ],
    ),
  );
}

class _Actions extends ConsumerWidget {
  const _Actions({
    required this.unit,
    required this.mine,
    required this.isAdmin,
  });

  final UnitModel unit;
  final bool mine;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buttons = <Widget>[];

    switch (unit.status) {
      case UnitStatus.free:
        buttons.addAll([
          _Button(
            label: 'Взять в работу — еду показывать',
            color: AppColors.work,
            onTap: () => _take(context, ref),
          ),
          _Button(label: 'Забронировать', onTap: () => _book(context, ref)),
          _Button(
            label: 'Похожие варианты',
            outlined: true,
            onTap: () => _similar(context, ref),
          ),
        ]);
        if (isAdmin) {
          buttons.add(
            _Button(
              label: 'Снять с продажи',
              outlined: true,
              onTap: () => _setStatus(context, ref, UnitStatus.offMarket),
            ),
          );
        }
      case UnitStatus.work when mine:
        buttons.addAll([
          _Button(
            label: 'Клиент согласен — забронировать',
            onTap: () => _book(context, ref),
          ),
          _Button(
            label: 'Освободить',
            secondary: true,
            onTap: () => _release(context, ref),
          ),
        ]);
      case UnitStatus.hold when mine:
        buttons.addAll([
          _Button(
            label: 'Отправить на оформление',
            onTap: () => _design(context, ref),
          ),
          _Row([
            _Button(
              label: 'Продлить бронь',
              secondary: true,
              onTap: () => _requestExtend(context, ref),
            ),
            _Button(
              label: 'Снять бронь',
              secondary: true,
              onTap: () => _release(context, ref),
            ),
          ]),
        ]);
      case UnitStatus.hold when isAdmin:
        buttons.addAll([
          _Button(
            label: 'Перевести на оформление',
            onTap: () => _design(context, ref),
          ),
          _Row([
            _Button(
              label: 'Продлить бронь',
              secondary: true,
              onTap: () => _extend(context, ref),
            ),
            _Button(
              label: 'Снять чужую бронь',
              secondary: true,
              onTap: () => _release(context, ref),
            ),
          ]),
        ]);
      case UnitStatus.design when isAdmin:
        buttons.addAll([
          _Button(
            label: 'Подтвердить продажу',
            color: AppColors.free,
            onTap: () => _confirmSale(context, ref),
          ),
          _Button(
            label: 'Вернуть в свободные',
            outlined: true,
            onTap: () => _setStatus(context, ref, UnitStatus.free),
          ),
        ]);
      case UnitStatus.design when mine:
        // Ответственный менеджер: продажу подтверждает администратор — ждём.
        buttons.add(
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.designBg,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Text(
              'Документы на оформлении. Продажу подтвердит администратор — '
              'вы получите уведомление.',
              style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.designInk),
            ),
          ),
        );
      case UnitStatus.work || UnitStatus.hold || UnitStatus.design:
        // Другой сотрудник: имя видно, клиент не раскрывается.
        buttons.addAll([
          _Button(
            label: 'Написать ${unit.heldByName ?? 'менеджеру'}',
            secondary: true,
            onTap: () => _message(context, ref),
          ),
          _Button(
            label: 'Показать похожие свободные',
            onTap: () => _similar(context, ref),
          ),
        ]);
      case UnitStatus.sold:
        buttons.add(
          _Button(
            label: 'Показать похожие свободные',
            onTap: () => _similar(context, ref),
          ),
        );
      case UnitStatus.offMarket:
        if (isAdmin) {
          buttons.add(
            _Button(
              label: 'Вернуть в продажу',
              onTap: () => _setStatus(context, ref, UnitStatus.free),
            ),
          );
        } else {
          buttons.add(
            _Button(
              label: 'Показать похожие свободные',
              onTap: () => _similar(context, ref),
            ),
          );
        }
    }

    return Column(children: buttons);
  }

  Future<void> _take(BuildContext context, WidgetRef ref) async {
    final pick = await pickClient(context);
    if (pick == null || !context.mounted) return;
    final manager = ref.read(currentUserProvider);
    if (manager == null) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final updated = await ref
          .read(panoramaRepositoryProvider)
          .takeToWork(unitId: unit.id, manager: manager, client: pick.client);
      ref.invalidate(dealsProvider);
      if (context.mounted) Navigator.of(context).pop();
      _snack(
        messenger,
        'Квартира закреплена за вами',
        'Кв. №${unit.number}'
            '${updated.heldUntil == null ? '' : ' · ${TimeFormat.until(updated.heldUntil!)}'}.',
      );
    } on LimitExceeded catch (e) {
      _snack(messenger, 'Лимит достигнут', e.message);
    }
  }

  Future<void> _book(BuildContext context, WidgetRef ref) async {
    final manager = ref.read(currentUserProvider);
    if (manager == null) return;

    final pick = await pickClient(context);
    if (pick == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(panoramaRepositoryProvider)
          .book(unitId: unit.id, manager: manager, client: pick.client);
      ref.invalidate(dealsProvider);
      if (context.mounted) Navigator.of(context).pop();
      _snack(
        messenger,
        'Бронь оформлена',
        'Кв. №${unit.number} держится 3 дня. Офис уведомлён.',
      );
    } on LimitExceeded catch (e) {
      _snack(messenger, 'Лимит достигнут', e.message);
    }
  }

  Future<void> _release(BuildContext context, WidgetRef ref) async {
    final manager = ref.read(currentUserProvider);
    if (manager == null) return;
    // Снятие чужой брони/работы (админом) — подтверждаем.
    if (!mine) {
      final ok = await confirmDialog(
        context,
        title: 'Снять бронь',
        message: 'Кв. №${unit.number} держит ${unit.heldByName ?? 'другой менеджер'}. '
            'Снять и вернуть в свободные?',
        confirmLabel: 'Снять',
        danger: true,
      );
      if (!ok || !context.mounted) return;
    }
    final messenger = ScaffoldMessenger.of(context);
    await ref
        .read(panoramaRepositoryProvider)
        .release(unitId: unit.id, manager: manager);
    if (context.mounted) Navigator.of(context).pop();
    _snack(messenger, 'Квартира снова свободна', 'Кв. №${unit.number} в фонде');
  }

  Future<void> _design(BuildContext context, WidgetRef ref) async {
    final manager = ref.read(currentUserProvider);
    if (manager == null) return;
    final messenger = ScaffoldMessenger.of(context);
    await ref
        .read(panoramaRepositoryProvider)
        .sendToDesign(unitId: unit.id, manager: manager);
    ref.invalidate(dealsProvider);
    if (context.mounted) Navigator.of(context).pop();
    _snack(
      messenger,
      'Отправлено на оформление',
      'Кв. №${unit.number} — администратор подтвердит продажу.',
    );
  }

  Future<void> _confirmSale(BuildContext context, WidgetRef ref) async {
    final admin = ref.read(currentUserProvider);
    if (admin == null) return;
    final ok = await confirmDialog(
      context,
      title: 'Подтвердить продажу',
      message: 'Кв. №${unit.number} будет отмечена проданной. '
          'Действие необратимо.',
      confirmLabel: 'Подтвердить',
    );
    if (!ok || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await ref
        .read(panoramaRepositoryProvider)
        .confirmSale(unitId: unit.id, admin: admin);
    ref.invalidate(dealsProvider);
    if (context.mounted) Navigator.of(context).pop();
    _snack(messenger, 'Продажа подтверждена', 'Кв. №${unit.number} продана.');
  }

  Future<void> _extend(BuildContext context, WidgetRef ref) async {
    final admin = ref.read(currentUserProvider);
    if (admin == null) return;
    final messenger = ScaffoldMessenger.of(context);
    await ref
        .read(panoramaRepositoryProvider)
        .extendBooking(unitId: unit.id, admin: admin);
    if (context.mounted) Navigator.of(context).pop();
    _snack(messenger, 'Бронь продлена', 'Кв. №${unit.number} — +3 дня.');
  }

  Future<void> _setStatus(
    BuildContext context,
    WidgetRef ref,
    UnitStatus status,
  ) async {
    final by = ref.read(currentUserProvider);
    if (by == null) return;
    final messenger = ScaffoldMessenger.of(context);
    await ref
        .read(panoramaRepositoryProvider)
        .setStatus(unitId: unit.id, status: status, by: by);
    if (context.mounted) Navigator.of(context).pop();
    _snack(messenger, 'Статус изменён', 'Кв. №${unit.number} — ${status.label}.');
  }

  Future<void> _message(BuildContext context, WidgetRef ref) async {
    final from = ref.read(currentUserProvider);
    if (from == null) return;
    final messenger = ScaffoldMessenger.of(context);
    await ref
        .read(panoramaRepositoryProvider)
        .messageHolder(unitId: unit.id, from: from);
    _snack(
      messenger,
      'Запрос отправлен',
      '${unit.heldByName ?? 'Менеджер'} получит уведомление в приложении',
    );
  }

  void _requestExtend(BuildContext context, WidgetRef ref) => _snack(
    ScaffoldMessenger.of(context),
    'Запрос отправлен администратору',
    'Продление брони кв. №${unit.number} подтверждает администратор.',
  );

  void _similar(BuildContext context, WidgetRef ref) {
    ref.read(searchFilterProvider.notifier).seedFrom(unit);
    Navigator.of(context).popUntil((route) => route.isFirst);
    Navigator.of(context).pushNamed(AppRoutes.similar);
  }

  static void _snack(
    ScaffoldMessengerState messenger,
    String title,
    String message,
  ) {
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: Color(0xFF8FE3C4),
              ),
            ),
            const SizedBox(height: 3),
            Text(message, style: const TextStyle(fontSize: 13, height: 1.4)),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.children);

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(width: 9),
        Expanded(child: children[i]),
      ],
    ],
  );
}

class _Button extends StatelessWidget {
  const _Button({
    required this.label,
    required this.onTap,
    this.color,
    this.secondary = false,
    this.outlined = false,
  });

  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool secondary;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final child = Text(
      label,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: outlined
          ? OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                side: const BorderSide(color: AppColors.line),
                foregroundColor: AppColors.ink2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: child,
            )
          : FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: secondary
                    ? const Color(0xFFEEF2F9)
                    : (color ?? AppColors.brand),
                foregroundColor: secondary ? AppColors.ink : Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: child,
            ),
    );
  }
}

class _History extends StatelessWidget {
  const _History({required this.unit});

  final UnitModel unit;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 8),
      const Text('ИСТОРИЯ КВАРТИРЫ', style: AppTextStyles.section),
      const SizedBox(height: 10),
      for (final event in unit.history)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 3),
                decoration: BoxDecoration(
                  color: event.kind.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${TimeFormat.dayTime(event.at)} · ${event.authorName}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
    ],
  );
}
