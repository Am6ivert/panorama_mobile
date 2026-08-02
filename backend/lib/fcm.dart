import 'dart:convert';
import 'dart:io';

import 'package:googleapis_auth/auth_io.dart';

/// Отправка push через Firebase Cloud Messaging HTTP v1.
///
/// Требует service-account.json (Firebase → Project Settings → Service
/// accounts → Generate new private key), положенный в рабочую папку сервера.
/// Если файла нет — [tryLoad] вернёт null, и push просто не отправляется
/// (уведомления остаются в БД и приходят опросом).
class Fcm {
  Fcm._(this._projectId, this._client);

  final String _projectId;
  final AutoRefreshingAuthClient _client;

  static Future<Fcm?> tryLoad() async {
    final file = File('service-account.json');
    if (!file.existsSync()) {
      stdout.writeln('FCM: service-account.json не найден — push отключён.');
      return null;
    }
    try {
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final creds = ServiceAccountCredentials.fromJson(json);
      final client = await clientViaServiceAccount(
        creds,
        ['https://www.googleapis.com/auth/firebase.messaging'],
      );
      stdout.writeln('FCM: подключён (проект ${json['project_id']}).');
      return Fcm._(json['project_id'] as String, client);
    } catch (e) {
      stderr.writeln('FCM: ошибка загрузки service-account.json: $e');
      return null;
    }
  }

  /// Шлёт push на список токенов устройств. Ошибки логируются, не бросаются.
  Future<void> sendToTokens(
    List<String> tokens, {
    required String title,
    required String body,
    String? unitId,
  }) async {
    final url = Uri.parse(
      'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send',
    );
    for (final token in tokens) {
      final message = {
        'message': {
          'token': token,
          'notification': {'title': title, 'body': body},
          if (unitId != null) 'data': {'unit_id': unitId},
          'webpush': {
            'notification': {'title': title, 'body': body},
          },
        },
      };
      try {
        final res = await _client.post(
          url,
          headers: {'content-type': 'application/json'},
          body: jsonEncode(message),
        );
        if (res.statusCode >= 400) {
          stderr.writeln('FCM send ${res.statusCode}: ${res.body}');
        }
      } catch (e) {
        stderr.writeln('FCM send error: $e');
      }
    }
  }
}
