/// App 偏好設定的 KV 持久化（非機敏，隨 App 移除）。
library;

abstract class SettingsStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class InMemorySettingsStore implements SettingsStore {
  final _map = <String, String>{};

  @override
  Future<String?> read(String key) async => _map[key];

  @override
  Future<void> write(String key, String value) async => _map[key] = value;
}
