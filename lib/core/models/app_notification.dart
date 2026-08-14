import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Тип события уведомления (FR-11).
enum NotificationKind {
  booked('booked', Icons.event_available),
  expiring('expiring', Icons.timer_outlined),
  released('released', Icons.lock_open),
  design('design', Icons.description_outlined),
  extendRequest('extend_request', Icons.more_time),
  handover('handover', Icons.swap_horiz),
  account('account', Icons.badge_outlined),
  message('message', Icons.mail_outline);

  const NotificationKind(this.wire, this.icon);
  final String wire;
  final IconData icon;

  static NotificationKind fromWire(String? value) =>
      NotificationKind.values.firstWhere(
        (k) => k.wire == value,
        orElse: () => NotificationKind.message,
      );

  Color get color => switch (this) {
    NotificationKind.booked => AppColors.hold,
    NotificationKind.expiring => AppColors.error,
    NotificationKind.released => AppColors.free,
    NotificationKind.design => AppColors.design,
    NotificationKind.extendRequest => AppColors.hold,
    NotificationKind.handover => AppColors.brand,
    NotificationKind.account => AppColors.work,
    NotificationKind.message => AppColors.brand,
  };
}

/// Уведомление в центре уведомлений (FR-11.9). Формируется сервером и не
/// раскрывает данные клиентов тем, кому они недоступны (FR-11.10).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.at,
    required this.recipientId,
    this.unitId,
    this.read = false,
  });

  final String id;
  final NotificationKind kind;
  final String title;
  final String body;
  final DateTime at;

  /// Кому адресовано (для изоляции доступа).
  final String recipientId;

  /// Deep link на карточку квартиры (FR-11.9).
  final String? unitId;
  final bool read;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        kind: NotificationKind.fromWire(json['kind'] as String?),
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        at: DateTime.parse(json['at'] as String),
        recipientId: json['recipient_id'] as String? ?? '',
        unitId: json['unit_id'] as String?,
        read: json['read'] as bool? ?? false,
      );

  AppNotification copyWith({bool? read}) => AppNotification(
    id: id,
    kind: kind,
    title: title,
    body: body,
    at: at,
    recipientId: recipientId,
    unitId: unitId,
    read: read ?? this.read,
  );
}
