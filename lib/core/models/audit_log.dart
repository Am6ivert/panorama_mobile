/// Запись журнала аудита (FR-12). Неизменяема, хранит кто/что/когда.
class AuditLog {
  const AuditLog({
    required this.id,
    required this.at,
    required this.userName,
    required this.action,
    required this.entity,
    this.details = '',
  });

  final String id;
  final DateTime at;

  /// Кто выполнил действие.
  final String userName;

  /// Что сделал: «Вход», «Бронь», «Изменение статуса», «Экспорт»…
  final String action;

  /// Над какой сущностью: «Кв. Панорама Сити · А · №14».
  final String entity;

  /// Значения до/после или дополнительный контекст.
  final String details;
}
