/// App 偏好設定的 KV 持久化(非機敏;沿用 flutter_secure_storage,免新增 dep)。
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SettingsStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class SecureSettingsStore implements SettingsStore {
  SecureSettingsStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

class InMemorySettingsStore implements SettingsStore {
  final _map = <String, String>{};

  @override
  Future<String?> read(String key) async => _map[key];

  @override
  Future<void> write(String key, String value) async => _map[key] = value;
}
