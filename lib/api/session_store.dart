/// Session token 儲存抽象（可注入測試替身）。
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// session token 持久化介面。
abstract class SessionStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

/// 正式環境實作：flutter_secure_storage，key `tripline_session`。
class SecureSessionStore implements SessionStore {
  SecureSessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _sessionKey = 'tripline_session';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _sessionKey);

  @override
  Future<void> write(String token) =>
      _storage.write(key: _sessionKey, value: token);

  @override
  Future<void> clear() => _storage.delete(key: _sessionKey);
}

/// 測試用：純記憶體實作。
class InMemorySessionStore implements SessionStore {
  String? _sessionToken;

  @override
  Future<String?> read() async => _sessionToken;

  @override
  Future<void> write(String token) async => _sessionToken = token;

  @override
  Future<void> clear() async => _sessionToken = null;
}
