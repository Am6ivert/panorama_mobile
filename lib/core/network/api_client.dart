import 'package:dio/dio.dart';
import '../config/app_config.dart';

class ApiClient {
  ApiClient()
    : _dio = Dio(
        BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: {'Accept': 'application/json'},
        ),
      );

  final Dio _dio;

  /// Токен появится, когда в Panorama решат, как авторизовать менеджеров.
  void setToken(String token) =>
      _dio.options.headers['Authorization'] = 'Bearer $token';

  Future<List<Map<String, dynamic>>> getList(String path) async {
    final response = await _dio.get<List<dynamic>>(path);
    return (response.data ?? const [])
        .cast<Map<String, dynamic>>()
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(path, data: body);
    return response.data ?? const {};
  }
}
