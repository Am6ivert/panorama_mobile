import 'dart:io';

import 'package:shelf/shelf.dart';

import 'api.dart';
import 'auth.dart';
import 'db.dart';
import 'fcm.dart';
import 'json.dart';

/// Собирает полный обработчик запросов: CORS, лог, обработка ошибок,
/// аутентификация и маршруты.
///
/// Вынесено из `bin/server.dart`, чтобы тесты поднимали ровно тот же стек, что
/// и боевой сервер, но без открытия порта: обработчик можно вызывать напрямую.
Handler buildHandler(Db db, {Fcm? fcm, Api? api, bool log = true}) {
  final application = api ?? Api(db, fcm);
  var pipeline = const Pipeline().addMiddleware(corsMiddleware());
  if (log) pipeline = pipeline.addMiddleware(logRequests());
  return pipeline
      .addMiddleware(errorsMiddleware())
      .addMiddleware(authMiddleware(db))
      .addMiddleware(subscriptionMiddleware())
      .addHandler(application.handler);
}

/// Подписка компании: после истечения остаётся только просмотр.
///
/// Правило простое: читать (GET) можно всегда, менять (POST) — только пока
/// подписка действует. Так отдел продаж не теряет доступ к своим данным и
/// видит, что именно нужно продлить, а не упирается в пустой экран.
///
/// Исключения:
///   * суперадминистратор — управляет подписками, ограничение на него не
///     распространяется;
///   * выход из приложения — работает всегда, иначе пользователь застрянет
///     в чужой сессии;
///   * смена собственного пароля — вопрос безопасности, а не подписки.
Middleware subscriptionMiddleware() => (Handler inner) => (Request req) async {
      final auth = req.context[authContextKey];
      if (auth is! AuthContext) return inner(req); // публичные маршруты
      if (auth.isSuperadmin) return inner(req);
      if (req.method != 'POST') return inner(req);

      final path = req.requestedUri.path;
      if (path == '/api/v1/auth/logout') return inner(req);
      if (path == '/api/v1/users/${auth.userId}/password') return inner(req);

      if (auth.access == OrgAccess.full) return inner(req);

      return jsonError(
        402,
        auth.access == OrgAccess.blocked
            ? 'Доступ приостановлен. Свяжитесь с нами, чтобы возобновить работу.'
            : 'Подписка истекла — доступен только просмотр. '
                'Свяжитесь с нами, чтобы продлить.',
      );
    };

/// Единая обработка исключений.
///
/// Без неё любая ошибка в хендлере уходит клиенту как пустой 500, и в
/// приложении это выглядит как вечный спиннер: показать пользователю нечего.
/// Здесь же ошибки PostgreSQL переводятся в понятный текст.
Middleware errorsMiddleware() => (Handler inner) => (Request req) async {
      try {
        return await inner(req);
      } catch (e, st) {
        final code = pgErrorCode(e);
        stderr.writeln('[${req.method} ${req.requestedUri.path}] '
            '${code == null ? '' : 'SQLSTATE $code '}$e');
        stderr.writeln(st);
        return jsonError(httpStatusForPgError(code), messageForPgError(code, e));
      }
    };

int httpStatusForPgError(String? sqlState) => switch (sqlState) {
      '23505' => 409, // unique_violation
      '23503' => 409, // foreign_key_violation
      '23514' => 422, // check_violation
      '22P02' => 422, // invalid_text_representation (кривой uuid и т.п.)
      _ => 500,
    };

String messageForPgError(String? sqlState, Object e) => switch (sqlState) {
      '23505' => 'Такая запись уже существует.',
      '23503' => 'Связанная запись не найдена или принадлежит другой компании.',
      '23514' => 'Значение не проходит проверку — исправьте данные.',
      '22P02' => 'Некорректный идентификатор в запросе.',
      // Обязательная колонка, о которой сервер не знает: верный признак того,
      // что база отличается от db/schema.sql и не накачены миграции.
      '23502' => 'В базе есть обязательная колонка, которую сервер не '
          'заполняет. Накатите миграции: db\\migrate.ps1. Подробности: $e',
      _ => 'Внутренняя ошибка сервера. Подробности в логе сервера.',
    };

/// CORS — чтобы web-версия приложения могла обращаться к API.
Middleware corsMiddleware() => (Handler inner) => (Request req) async {
      const headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
      };
      if (req.method == 'OPTIONS') return Response.ok('', headers: headers);
      final res = await inner(req);
      return res.change(headers: {...res.headers, ...headers});
    };
