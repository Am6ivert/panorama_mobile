import 'package:panorama_backend/auth.dart';
import 'package:panorama_backend/db.dart';
import 'package:panorama_backend/server_app.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// Быстрые проверки без базы: запускаются за доли секунды и не требуют
/// установленного PostgreSQL.
///
///   dart test test/unit_test.dart
void main() {
  Request get(String path, {Map<String, String>? headers}) =>
      Request('GET', Uri.parse('http://localhost:8080$path'), headers: headers);

  group('hashToken', () {
    test('даёт 64 hex-символа (SHA-256)', () {
      final h = hashToken('abc');
      expect(h.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(h), isTrue);
    });

    test('детерминирован', () {
      expect(hashToken('one'), hashToken('one'));
    });

    test('разные токены дают разный хеш', () {
      expect(hashToken('one'), isNot(hashToken('two')));
    });

    test('не содержит исходный токен', () {
      expect(hashToken('secret-token'), isNot(contains('secret')));
    });
  });

  group('bearerToken', () {
    test('разбирает корректный заголовок', () {
      expect(bearerToken(get('/x', headers: {'Authorization': 'Bearer abc'})),
          'abc');
    });

    test('схема нечувствительна к регистру', () {
      expect(bearerToken(get('/x', headers: {'Authorization': 'bearer abc'})),
          'abc');
    });

    test('без заголовка — null', () {
      expect(bearerToken(get('/x')), isNull);
    });

    test('чужая схема — null', () {
      expect(bearerToken(get('/x', headers: {'Authorization': 'Basic abc'})),
          isNull);
    });

    test('пустой токен — null', () {
      expect(bearerToken(get('/x', headers: {'Authorization': 'Bearer '})),
          isNull);
    });

    test('лишние части — null', () {
      expect(bearerToken(get('/x', headers: {'Authorization': 'Bearer a b'})),
          isNull);
    });
  });

  group('isPublicRoute', () {
    test('health и login открыты', () {
      expect(isPublicRoute(get('/api/v1/health')), isTrue);
      expect(
          isPublicRoute(Request(
              'POST', Uri.parse('http://localhost:8080/api/v1/auth/login'))),
          isTrue);
    });

    test('CORS preflight открыт', () {
      expect(
          isPublicRoute(Request(
              'OPTIONS', Uri.parse('http://localhost:8080/api/v1/units'))),
          isTrue);
    });

    test('всё остальное закрыто', () {
      for (final p in const [
        '/api/v1/units',
        '/api/v1/users',
        '/api/v1/clients',
        '/api/v1/audit',
        '/api/v1/auth/logout',
        '/api/v1/auth/me',
        '/', // неизвестный путь тоже требует токена
      ]) {
        expect(isPublicRoute(get(p)), isFalse, reason: p);
      }
    });
  });

  group('AuthContext', () {
    AuthContext ctx(String role) => AuthContext(
          sessionId: 's',
          userId: 'u',
          name: 'n',
          role: role,
          orgId: 'o',
          orgCode: 'c',
          orgName: 'N',
        );

    test('роль admin даёт isAdmin', () {
      expect(ctx('admin').isAdmin, isTrue);
      expect(ctx('manager').isAdmin, isFalse);
    });
  });

  group('перевод ошибок PostgreSQL', () {
    test('нарушение уникальности — 409', () {
      expect(httpStatusForPgError('23505'), 409);
    });

    test('нарушение внешнего ключа — 409', () {
      expect(httpStatusForPgError('23503'), 409);
    });

    test('нарушение CHECK — 422', () {
      expect(httpStatusForPgError('23514'), 422);
    });

    test('неизвестная ошибка — 500', () {
      expect(httpStatusForPgError(null), 500);
      expect(httpStatusForPgError('XX000'), 500);
    });

    test('NOT NULL подсказывает накатить миграции', () {
      expect(messageForPgError('23502', 'boom'), contains('миграции'));
    });

    test('код SQLSTATE достаётся из исключения драйвера', () {
      expect(pgErrorCode(_FakePgException('23505')), '23505');
      expect(pgErrorCode(Exception('обычное исключение')), isNull);
    });
  });
}

/// Подделка исключения драйвера: важно только поле code.
class _FakePgException implements Exception {
  _FakePgException(this.code);
  final String code;
}
