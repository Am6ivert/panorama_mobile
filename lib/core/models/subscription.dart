import 'org_summary.dart' show OrgAccess;

export 'org_summary.dart' show OrgAccess;

/// Состояние подписки компании, каким его видит приложение.
///
/// Сервер присылает это при входе и в `/auth/me`, чтобы приложение знало,
/// показывать ли плашку и куда отправить за продлением.
class Subscription {
  const Subscription({
    required this.access,
    required this.planKind,
    required this.orgName,
    this.planUntil,
    this.supportEmail = '',
    this.supportUrl = '',
  });

  final OrgAccess access;

  /// 'trial' — пробный период, 'paid' — оплаченная подписка.
  final String planKind;
  final String orgName;
  final DateTime? planUntil;

  /// Куда обращаться за продлением. Задаётся на сервере переменными окружения.
  final String supportEmail;
  final String supportUrl;

  bool get isTrial => planKind == 'trial';
  bool get isActive => access == OrgAccess.full;

  /// Сколько дней осталось. Отрицательное — столько дней назад срок вышел.
  int? get daysLeft {
    final until = planUntil;
    if (until == null) return null;
    return until.difference(DateTime.now()).inHours ~/ 24;
  }

  /// Показывать ли предупреждение: подписка кончается в ближайшие 3 дня
  /// либо уже кончилась.
  bool get needsAttention {
    if (!isActive) return true;
    final left = daysLeft;
    return left != null && left <= 3;
  }

  factory Subscription.fromJson(Map<String, dynamic> json) {
    final support = (json['support'] as Map?)?.cast<String, dynamic>() ?? {};
    return Subscription(
      access: OrgAccess.fromWire(json['access'] as String?),
      planKind: json['plan_kind'] as String? ?? 'trial',
      orgName: json['org_name'] as String? ?? '',
      planUntil:
          DateTime.tryParse(json['plan_until'] as String? ?? '')?.toLocal(),
      supportEmail: support['email'] as String? ?? '',
      supportUrl: support['url'] as String? ?? '',
    );
  }
}
