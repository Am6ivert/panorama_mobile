import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Хранит токен сессии между запусками приложения.
///
/// Раньше токен жил только в памяти: после перезапуска пользователь каждый раз
/// вводил логин и пароль заново, хотя сессия на сервере действует 30 дней.
///
/// Хранилище — штатное шифрованное хранилище ОС: Keystore на Android
/// (`EncryptedSharedPreferences`) и Keychain на iOS. Токен не лежит в обычном
/// файле приложения, поэтому его не достать даже с root-доступом к устройству.
///
/// Здесь лежит только токен. Пароль не сохраняется никогда, а сам токен
/// проверяется на сервере при каждом запуске (`GET /auth/me`): если сессию
/// отозвали или учётку заблокировали, он тут же удаляется.
class SessionStore {
  const SessionStore();

  static const _tokenKey = 'panorama.session_token';

  static const _storage = FlutterSecureStorage(
    // Без этого на Android используется устаревшее хранилище на RSA-ключе.
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  Future<String?> read() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      return (token == null || token.isEmpty) ? null : token;
    } catch (_) {
      // Повреждённое хранилище (например, после переустановки ключей) не должно
      // мешать войти заново.
      return null;
    }
  }

  Future<void> write(String token) async {
    try {
      await _storage.write(key: _tokenKey, value: token);
    } catch (_) {
      // Не смогли сохранить — вход всё равно состоялся, просто в следующий раз
      // придётся ввести пароль.
    }
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {
      // Выход из приложения не должен падать из-за хранилища.
    }
  }
}
