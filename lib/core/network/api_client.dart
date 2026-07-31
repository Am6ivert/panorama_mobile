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

  /// Токен авторизации — ставится после входа.
  void setToken(String token) =>
      _dio.options.headers['Authorization'] = 'Bearer $token';

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
    final data = e.response?.data;
    final message = data is Map && data['error'] is String
        ? data['error'] as String
        : (e.message ?? 'Ошибка сети');
    return ApiException(e.response?.statusCode, message);
  }
}
