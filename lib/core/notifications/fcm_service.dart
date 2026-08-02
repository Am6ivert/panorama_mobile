import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';

/// Получение FCM-токена и разрешения на push. Регистрация токена на backend
/// идёт через репозиторий (registerDevice).
class FcmService {
  /// Запрашивает разрешение и возвращает FCM-токен устройства (или null).
  static Future<String?> obtainToken() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      if (kIsWeb) {
        if (AppConfig.fcmVapidKey.isEmpty) return null; // без VAPID токена нет
        return messaging.getToken(vapidKey: AppConfig.fcmVapidKey);
      }
      return messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  /// Платформа устройства для записи в БД.
  static String get platform =>
      kIsWeb ? 'web' : (defaultTargetPlatform == TargetPlatform.android ? 'android' : 'ios');
}
