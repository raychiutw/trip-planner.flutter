/// 以平台 preferences 保存非機敏 App 設定。
library;

import 'package:shared_preferences/shared_preferences.dart';

import '../api/settings_store.dart';

class SharedPreferencesSettingsStore implements SettingsStore {
  SharedPreferencesSettingsStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences;

  SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _client =>
      _preferences ??= SharedPreferencesAsync();

  @override
  Future<String?> read(String key) => _client.getString(key);

  @override
  Future<void> write(String key, String value) => _client.setString(key, value);
}
