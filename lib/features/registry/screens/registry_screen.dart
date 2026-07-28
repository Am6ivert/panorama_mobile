import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/unit_model.dart';
import '../../../core/models/unit_status.dart';
import '../../../core/providers/data_providers.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/choice_chip_bar.dart';
import '../../../shared/widgets/unit_tile.dart';
import '../../unit/widgets/unit_sheet.dart';

enum _Tab { all, free, mine, booked, expiring, design }

extension on _Tab {
  String get label => switch (this) {
    _Tab.all => 'Все',
    _Tab.free => 'Свободные',
    _Tab.mine => 'Мои',
    _Tab.booked => 'Брони',
    _Tab.expiring => 'Истекают',
    _Tab.design => 'Оформление',
  };
}

/// Реестр квартир и броней (FR-09): списочное представление всего фонда.
class RegistryScreen extends ConsumerStatefulWidget {
  const RegistryScreen({super.key});

  @override
  ConsumerState<RegistryScreen> createState() => _RegistryScreenState();
}

class _RegistryScreenState extends ConsumerState<RegistryScreen> {
  _Tab _tab = _Tab.all;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final all = ref.watch(unitsProvider).value ?? const <UnitModel>[];

    final rows = _filter(all, user?.id).toList()
      ..sort((a, b) {
        final c = a.complexName.compareTo(b.complexName);
        if (c != 0) return c;
        final bl = a.block.compareTo(b.block);
        if (bl != 0) return bl;
        return a.number.compareTo(b.number);
      });

    return Column(
      children: [
        AppHeader(
          title: 'Реестр',
          subtitle: 'Весь фонд: статусы, менеджеры, брони',
          bottom: _SearchField(
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.line)),
          ),
          child: ChoiceChipBar<_Tab>(
            options: [
              for (final t in _Tab.values) ChipOption(value: t, label: t.label),
            ],
            isSelected: (t) => t == _tab,
            onTap: (t) => setState(() => _tab = t),
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? const EmptyState(
                  icon: Icons.inbox_outlined,
                  text: 'В этой вкладке пока пусто.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: rows.length,
                  itemBuilder: (_, i) => _RegistryRow(
                    unit: rows[i],
                    canSeeClient:
                        isAdmin || rows[i].heldById == user?.id,
                    onTap: () => _open(rows[i]),
                    onCall: () => _call(rows[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Iterable<UnitModel> _filter(List<UnitModel> all, String? userId) {
    final now = DateTime.now();
    return all.where((u) {
      if (_query.isNotEmpty) {
        final hay = '${u.number} ${u.clientName ?? ''} ${u.heldByName ?? ''}'
            .toLowerCase();
        if (!hay.contains(_query)) return false;
      }
      return switch (_tab) {
        _Tab.all => u.status != UnitStatus.offMarket,
        _Tab.free => u.status == UnitStatus.free,
        _Tab.mine => u.heldById == userId,
        _Tab.booked => u.status == UnitStatus.hold,
        _Tab.expiring =>
          u.status == UnitStatus.hold &&
              u.heldUntil != null &&
              u.heldUntil!.difference(now) < AppConfig.bookingExpiryWarning,
        _Tab.design => u.status == UnitStatus.design,
      };
    });
  }

  void _open(UnitModel unit) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => UnitSheet(unitId: unit.id),
  );

  void _call(UnitModel unit) {
    // Телефон клиента доступен по правам через карточку клиента. В демо
    // ведём в карточку квартиры, где видны участники сделки.
    final client = ref
        .read(visibleClientsProvider)
        .where((c) => c.id == unit.clientId)
        .firstOrNull;
    if (client != null) {
      launchUrl(Uri.parse('tel:${client.phone.replaceAll(RegExp(r'[^0-9+]'), '')}'));
    } else {
      _open(unit);
    }
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    onChanged: onChanged,
    style: const TextStyle(fontSize: 14, color: Colors.white),
    decoration: InputDecoration(
      isDense: true,
      hintText: 'Поиск: номер, клиент, менеджер',
      hintStyle: const TextStyle(color: AppColors.onDarkSub, fontSize: 13.5),
      prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.onDarkSub),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.1),
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: BorderSide.none,
      ),
    ),
  );
}

class _RegistryRow extends StatelessWidget {
  const _RegistryRow({
    required this.unit,
    required this.canSeeClient,
    required this.onTap,
    required this.onCall,
  });

  final UnitModel unit;
  final bool canSeeClient;
  final VoidCallback onTap;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final left = unit.heldUntil?.difference(DateTime.now());
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Container(
              width: 5,
              height: 42,
              decoration: BoxDecoration(
                color: unit.status.color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '№${unit.number} · ${unit.layoutName} · ${unit.area} м²',
                    style: AppTextStyles.bodyStrong,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${unit.complexName} · бл. ${unit.block} · ${unit.floor} эт.'
                    '${unit.heldByName == null ? '' : ' · ${unit.heldByName}'}'
                    '${canSeeClient && unit.clientName != null ? ' · ${unit.clientName}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.ink2),
                  ),
                ],
              ),
            ),
            // Звонок клиенту нажатием на телефон (FR-09.6) — по своим строкам.
            if (canSeeClient && unit.clientName != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onCall,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.freeBg,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.call, size: 16, color: AppColors.free),
                ),
              ),
            ],
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  unit.status.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: unit.status.foreground,
                  ),
                ),
                if (unit.status == UnitStatus.hold && left != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    left.isNegative
                        ? 'истекла'
                        : left.inHours < 24
                        ? 'через ${left.inHours} ч'
                        : 'через ${left.inDays} дн',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: left.inHours < 24
                          ? AppColors.error
                          : AppColors.ink3,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
