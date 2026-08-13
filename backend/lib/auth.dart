import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';

import 'db.dart';
import 'json.dart';

/// Ключ, под которым разрешённая личность лежит в `Request.context`.
const authContextKey = 'panorama.auth';

/// Личность и роль автора запроса, вычисленные сервером по токену сессии.
///
/// Единственный источник правды об «кто я» для всех хендлеров: тело запроса
/// (`manager_id`, `admin_id`, `user_id`, …) больше не используется для
/// авторизации — его может подделать любой клиент.
class AuthContext {
  const AuthContext({
    required this.sessionId,
    required this.userId,
    required this.name,
    required this.role,
    required this.orgId,
    required this.orgCode,
    required this.orgName,
  });

  final String sessionId;
  final String userId;
  final String name;
  final String role; // 'admin' | 'manager'

  /// Компания (застройщик), которой принадлежит пользователь. Каждый запрос
  /// к данным фильтруется по ней — компании в общей базе не пересекаются.
  final String orgId;
  final String orgCode;
  final String orgName;

  bool get isAdmin => role == 'admin';
}

/// Хеш токена сессии: SHA-256 в hex.
///
/// В БД (`sessions.token_hash`) хранится ТОЛЬКО хеш — исходный токен
/// существует лишь у клиента. Утечка дампа таблицы не даёт доступа к API.
String hashToken(String token) => sha256.convert(utf8.encode(token)).toString();

/// Достаёт токен из заголовка `Authorization: Bearer <token>`.
String? bearerToken(Request request) {
  final header = request.headers['authorization'];
  if (header == null) return null;
  final parts = header.split(' ');
  if (parts.length != 2 || parts.first.toLowerCase() != 'bearer') return null;
  final token = parts.last.trim();
  return token.isEmpty ? null : token;
}

/// Публичные маршруты — единственное, что доступно без действующей сессии.
///
/// Публичная функция, а не приватная: на неё опираются тесты.
bool isPublicRoute(Request request) {
  if (request.method == 'OPTIONS') return true; // CORS preflight
  final path = request.requestedUri.path;
  return path == '/api/v1/health' || path == '/api/v1/auth/login';
}

/// SQL разрешения токена в личность.
///
/// Отсекает: отозванные (`revoked_at`) и просроченные (`expires_at`) сессии,
/// заблокированных и удалённых пользователей.
const _resolveSql = '''
  SELECT s.id::text        AS session_id,
         u.id::text        AS user_id,
         u.full_name       AS name,
         o.id::text        AS org_id,
         o.code            AS org_code,
         o.name            AS org_name,
         CASE WHEN EXISTS (SELECT 1 FROM user_roles r
                            WHERE r.user_id = u.id AND r.role_code = 'admin')
              THEN 'admin' ELSE 'manager' END AS role
  FROM sessions s
  JOIN users u ON u.id = s.user_id
  JOIN organizations o ON o.id = u.org_id
  WHERE s.token_hash = @h
    AND s.revoked_at IS NULL
    AND s.expires_at > now()
    AND u.blocked = false
    AND u.deleted_at IS NULL
    AND o.deleted_at IS NULL''';

/// Разрешает токен в [AuthContext] или возвращает null.
Future<AuthContext?> resolveToken(Db db, String token) async {
  final row = await db.one(_resolveSql, {'h': hashToken(token)});
  if (row == null) return null;
  return AuthContext(
    sessionId: row['session_id'] as String,
    userId: row['user_id'] as String,
    name: row['name'] as String,
    role: row['role'] as String,
    orgId: row['org_id'] as String,
    orgCode: row['org_code'] as String,
    orgName: row['org_name'] as String,
  );
}

/// Middleware аутентификации.
///
/// Для всех непубличных маршрутов требует `Authorization: Bearer <token>`,
/// сверяет хеш токена с `sessions.token_hash` (с проверкой `expires_at` и
/// `revoked_at`) и кладёт результат в `request.context[authContextKey]`.
/// Без действующей сессии дальше хендлеров запрос не проходит.
Middleware authMiddleware(Db db) => (Handler inner) => (Request request) async {
      if (isPublicRoute(request)) return inner(request);

      final token = bearerToken(request);
      if (token == null) {
        return jsonError(401, 'Требуется авторизация');
      }

      AuthContext? auth;
      try {
        auth = await resolveToken(db, token);
      } catch (_) {
        return jsonError(503, 'Сервис временно недоступен');
      }
      if (auth == null) {
        return jsonError(401, 'Сессия недействительна или истекла');
      }

      return inner(request.change(context: {authContextKey: auth}));
    };
