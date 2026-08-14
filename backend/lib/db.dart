import 'dart:io';

import 'package:postgres/postgres.dart';

/// Тонкая обёртка над пулом соединений PostgreSQL.
///
/// Настройки берутся из переменных окружения (см. .env.example), иначе —
/// значения по умолчанию для локальной БД, созданной db/setup.ps1.
class Db {
  Db._(this._pool);

  final Pool _pool;

  static Future<Db> open() async {
    final env = Platform.environment;
    final endpoint = Endpoint(
      host: env['PGHOST'] ?? 'localhost',
      port: int.tryParse(env['PGPORT'] ?? '') ?? 5432,
      database: env['PGDATABASE'] ?? 'panorama',
      username: env['PGUSER'] ?? 'panorama',
      password: env['PGPASSWORD'] ?? 'panorama',
    );
    final pool = Pool.withEndpoints(
      [endpoint],
      settings: const PoolSettings(
        maxConnectionCount: 8,
        sslMode: SslMode.disable,
      ),
    );
    // Проверка соединения на старте.
    await pool.execute('SELECT 1');
    return Db._(pool);
  }

  /// Выполнить запрос с именованными параметрами, вернуть строки как map'ы.
  Future<List<Map<String, dynamic>>> query(
    String sql, [
    Map<String, dynamic> params = const {},
  ]) async {
    final result = await _pool.execute(
      Sql.named(sql),
      parameters: params,
    );
    return result.map((row) => row.toColumnMap()).toList();
  }

  /// Первая строка или null.
  Future<Map<String, dynamic>?> one(
    String sql, [
    Map<String, dynamic> params = const {},
  ]) async {
    final rows = await query(sql, params);
    return rows.isEmpty ? null : rows.first;
  }

  /// Выполнить в транзакции (для связных изменений — FR-07.4).
  Future<T> tx<T>(Future<T> Function(TxSession s) body) =>
      _pool.runTx((session) => body(TxSession(session)));

  Future<void> close() => _pool.close();
}

/// Обёртка над сессией транзакции с тем же удобным API.
class TxSession {
  TxSession(this._session);
  final TxSession$Runner _session;

  Future<List<Map<String, dynamic>>> query(
    String sql, [
    Map<String, dynamic> params = const {},
  ]) async {
    final result =
        await _session.execute(Sql.named(sql), parameters: params);
    return result.map((row) => row.toColumnMap()).toList();
  }

  Future<Map<String, dynamic>?> one(
    String sql, [
    Map<String, dynamic> params = const {},
  ]) async {
    final rows = await query(sql, params);
    return rows.isEmpty ? null : rows.first;
  }
}

/// SQLSTATE из исключения драйвера, если оно пришло от PostgreSQL.
///
/// Драйвер не экспортирует единый тип ошибки, поэтому читаем поле динамически.
String? pgErrorCode(Object e) {
  try {
    final code = (e as dynamic).code;
    return code is String ? code : null;
  } catch (_) {
    return null;
  }
}

/// Псевдоним типа сессии postgres (TxSession принимает Session/TxSession).
typedef TxSession$Runner = Session;
