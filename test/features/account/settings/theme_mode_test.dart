import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/settings_store.dart';
import 'package:tripline/features/account/settings/theme_mode_controller.dart';

Future<void> _flush() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('parse/toString round-trip', () {
    expect(themeModeToString(ThemeMode.dark), 'dark');
    expect(parseThemeMode('light'), ThemeMode.light);
    expect(parseThemeMode('system'), ThemeMode.system);
    expect(parseThemeMode(null), ThemeMode.system);
    expect(parseThemeMode('garbage'), ThemeMode.system);
  });

  test('setMode：更新 state + 寫入 store', () async {
    final store = InMemorySettingsStore();
    final c = ProviderContainer(
        overrides: [settingsStoreProvider.overrideWithValue(store)]);
    addTearDown(c.dispose);
    c.listen(themeModeProvider, (_, _) {});
    await c.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
    expect(c.read(themeModeProvider), ThemeMode.dark);
    expect(await store.read('theme_mode'), 'dark');
  });

  test('build：載入既有儲存值', () async {
    final store = InMemorySettingsStore();
    await store.write('theme_mode', 'dark');
    final c = ProviderContainer(
        overrides: [settingsStoreProvider.overrideWithValue(store)]);
    addTearDown(c.dispose);
    c.listen(themeModeProvider, (_, _) {});
    c.read(themeModeProvider); // 觸發 build + _load
    await _flush();
    expect(c.read(themeModeProvider), ThemeMode.dark);
  });
}
