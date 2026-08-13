import 'package:dio/dio.dart';
import '../config/app_config.dart';

/// Ошибка API с кодом статуса и сообщением сервера.
class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);
  final int? statusCode;
  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient([String? baseUrl])
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: {'Accept': 'application/json'},
        ),
      );

  final Dio _dio;

  /// Вызывается, когда сервер ответил 401 (сессия истекла или отозвана) —
  /// приложение должно вернуть пользователя на экран входа.
  void Function()? onUnauthorized;

  /// Есть ли действующий токен в заголовках.
  bool get hasToken => _dio.options.headers.containsKey('Authorization');

  /// Токен авторизации — ставится после входа. Дальше сервер сам определяет,
  /// кто автор запроса: идентификаторы в теле запроса он игнорирует.
  void setToken(String token) =>
      _dio.options.headers['Authorization'] = 'Bearer $token';

  /// Забыть токен (выход, истёкшая сессия).
  void clearToken() => _dio.options.headers.remove('Authorization');

  Future<List<Map<String, dynamic>>> getList(String path) async {
    try {
      final response = await _dio.get<List<dynamic>>(path);
      return (response.data ?? const [])
          .cast<Map<String, dynamic>>()
          .toList(growable: false);
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  /// GET одного объекта (в отличие от [getList], который ждёт массив).
  Future<Map<String, dynamic>> getOne(String path) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(path);
      return response.data ?? const {};
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(path, data: body);
      return response.data ?? const {};
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  ApiException _toApiException(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    final message = data is Map && data['error'] is String
        ? data['error'] as String
        : (e.message ?? 'Ошибка сети');
    if (status == 401) {
      clearToken();
      onUnauthorized?.call();
    }
    return ApiException(status, message);
  }
}
