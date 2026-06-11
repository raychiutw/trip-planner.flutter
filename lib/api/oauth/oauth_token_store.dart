/// OAuth token pair 持久化抽象(鏡像 SessionStore;可注入測試替身)。
library;

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../models/oauth_tokens.dart';

abstract class OAuthTokenStore {
  Future<OAuthTokens?> read();
  Future<void> write(OAuthTokens tokens);
  Future<void> clear();
}

/// 正式環境:flutter_secure_storage,key `tripline_oauth_tokens`(存 JSON)。
class SecureOAuthTokenStore implements OAuthTokenStore {
  SecureOAuthTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'tripline_oauth_tokens';

  final FlutterSecureStorage _storage;

  @override
  Future<OAuthTokens?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return OAuthTokens.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Exception {
      return null; // 壞掉的資料視為未登入
    }
  }

  @override
  Future<void> write(OAuthTokens tokens) =>
      _storage.write(key: _key, value: jsonEncode(tokens.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

/// 測試用:純記憶體。
class InMemoryOAuthTokenStore implements OAuthTokenStore {
  OAuthTokens? _tokens;

  @override
  Future<OAuthTokens?> read() async => _tokens;

  @override
  Future<void> write(OAuthTokens tokens) async => _tokens = tokens;

  @override
  Future<void> clear() async => _tokens = null;
}
