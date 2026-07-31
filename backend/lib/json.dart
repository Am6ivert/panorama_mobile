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
  final decoded = jsonDecode(body);
  return decoded is Map<String, dynamic> ? decoded : {};
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
