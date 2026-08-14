import 'dart:convert';

import 'package:shelf/shelf.dart';

const _headers = {'content-type': 'application/json; charset=utf-8'};

Response jsonOk(Object? data) =>
    Response.ok(jsonEncode(data), headers: _headers);

Response jsonError(int status, String message) =>
    Response(status, body: jsonEncode({'error': message}), headers: _headers);

/// Разобрать JSON-тело запроса (или пустая карта).
Future<Map<String, dynamic>> readJson(Request request) async {
  final body = await request.readAsString();
  if (body.trim().isEmpty) return {};
  try {
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic> ? decoded : {};
  } on FormatException {
    // Битое тело запроса - это ошибка клиента, а не сбой сервера. Без этой
    // ветки исключение уходило в общий обработчик и возвращалось как 500
    // «Внутренняя ошибка сервера».
    throw BadRequest('Тело запроса не разобрано как JSON');
  }
}

/// Значение json-колонки истории: postgres может вернуть List или строку.
List<dynamic> asJsonList(Object? value) {
  if (value is List) return value;
  if (value is String && value.trim().isNotEmpty) {
    final decoded = jsonDecode(value);
    return decoded is List ? decoded : const [];
  }
  return const [];
}

/// Ошибка в запросе клиента: возвращается как 400, а не как сбой сервера.
class BadRequest implements Exception {
  const BadRequest(this.message);
  final String message;

  @override
  String toString() => message;
}
