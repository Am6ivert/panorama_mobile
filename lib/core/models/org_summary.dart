/// Состояние подписки компании.
enum OrgAccess {
  /// Подписка действует — компания работает полностью.
  full('full', 'Активна'),

  /// Срок вышел: сотрудники видят данные, но ничего не меняют.
  readOnly('read_only', 'Истекла'),

  /// Приостановлена суперадминистратором.
  blocked('blocked', 'Приостановлена');

  const OrgAccess(this.wire, this.label);

  final String wire;
  final String label;

  static OrgAccess fromWire(String? value) => OrgAccess.values.firstWhere(
        (a) => a.wire == value,
        orElse: () => OrgAccess.readOnly,
      );
}

/// Администратор компании — то, что видит суперадминистратор.
class OrgAdmin {
  const OrgAdmin({
    required this.id,
    required this.name,
    required this.login,
    required this.phone,
    this.blocked = false,
  });

  final String id;
  final String name;
  final String login;
  final String phone;
  final bool blocked;

  factory OrgAdmin.fromJson(Map<String, dynamic> json) => OrgAdmin(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        login: json['login'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        blocked: json['blocked'] as bool? ?? false,
      );
}

/// Компания глазами суперадминистратора: подписка, администраторы и размер.
///
/// Поимённого состава отдела продаж здесь нет — только количество менеджеров:
/// для управления подписками имена чужих сотрудников не нужны.
class OrgSummary {
  const OrgSummary({
    required this.id,
    required this.code,
    required this.name,
    required this.access,
    required this.planKind,
    required this.graceDays,
    required this.isBlocked,
    required this.managers,
    required this.apartments,
    required this.admins,
    this.planUntil,
    this.createdAt,
  });

  final String id;
  final String code;
  final String name;
  final OrgAccess access;

  /// 'trial' — пробный период, 'paid' — оплаченная подписка.
  final String planKind;

  /// Сколько дней доступ работает сверх [planUntil].
  final int graceDays;
  final bool isBlocked;
  final int managers;
  final int apartments;
  final List<OrgAdmin> admins;
  final DateTime? planUntil;
  final DateTime? createdAt;

  bool get isTrial => planKind == 'trial';

  /// Сколько дней осталось до конца оплаченного срока.
  /// Отрицательное — столько дней назад срок вышел.
  int? get daysLeft {
    final until = planUntil;
    if (until == null) return null;
    return until.difference(DateTime.now()).inHours ~/ 24;
  }

  factory OrgSummary.fromJson(Map<String, dynamic> json) => OrgSummary(
        id: json['id'] as String,
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        access: OrgAccess.fromWire(json['access'] as String?),
        planKind: json['plan_kind'] as String? ?? 'trial',
        graceDays: (json['grace_days'] as num?)?.toInt() ?? 0,
        isBlocked: json['is_blocked'] as bool? ?? false,
        managers: (json['managers'] as num?)?.toInt() ?? 0,
        apartments: (json['apartments'] as num?)?.toInt() ?? 0,
        admins: ((json['admins'] as List<dynamic>?) ?? const [])
            .map((e) => OrgAdmin.fromJson((e as Map).cast<String, dynamic>()))
            .toList(growable: false),
        planUntil: DateTime.tryParse(json['plan_until'] as String? ?? '')?.toLocal(),
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal(),
      );
}
