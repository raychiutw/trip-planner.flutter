import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/settings_store.dart';
import 'package:tripline/features/account/settings/theme_mode_controller.dart';

Future<void> _flushAsyncLoad() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _DelayedReadSettingsStore implements SettingsStore {
  final readResult = Completer<String?>();

  @override
  Future<String?> read(String key) => readResult.future;

  @override
  Future<void> write(String key, String value) async {}
}

class _FixedReadSettingsStore implements SettingsStore {
  _FixedReadSettingsStore(this.value);

  final String? value;

  @override
  Future<String?> read(String key) async => value;

  @override
  Future<void> write(String key, String value) async {}
}

class _FailingReadSettingsStore implements SettingsStore {
  @override
  Future<String?> read(String key) => Future.error(StateError('unavailable'));

  @override
  Future<void> write(String key, String value) async {}
}

class _OutOfOrderWriteSettingsStore implements SettingsStore {
  final firstWriteStarted = Completer<void>();
  final releaseFirstWrite = Completer<void>();
  String? value;
  var _writeCount = 0;

  @override
  Future<String?> read(String key) async => value;

  @override
  Future<void> write(String key, String value) async {
    _writeCount += 1;
    if (_writeCount == 1) {
      firstWriteStarted.complete();
      await releaseFirstWrite.future;
    }
    this.value = value;
  }
}

void main() {
  test('冷啟動先載入已保存模式，第一個 provider 狀態就是深色', () async {
    final store = _FixedReadSettingsStore('dark');
    final initialMode = await loadInitialThemeMode(store);
    final container = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(store),
        themeModeProvider.overrideWith(
          () => ThemeModeController(initialMode: initialMode),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(themeModeProvider), ThemeMode.dark);
  });

  test('選擇深色後立即更新，重新建立容器仍恢復深色', () async {
    final store = InMemorySettingsStore();
    final first = ProviderContainer(
      overrides: [settingsStoreProvider.overrideWithValue(store)],
    );
    first.listen(themeModeProvider, (_, _) {});

    final saving = first
        .read(themeModeProvider.notifier)
        .setMode(ThemeMode.dark);

    expect(first.read(themeModeProvider), ThemeMode.dark);
    await saving;
    first.dispose();

    final restarted = ProviderContainer(
      overrides: [settingsStoreProvider.overrideWithValue(store)],
    );
    restarted.listen(themeModeProvider, (_, _) {});
    addTearDown(restarted.dispose);
    expect(restarted.read(themeModeProvider), ThemeMode.system);

    await _flushAsyncLoad();

    expect(restarted.read(themeModeProvider), ThemeMode.dark);
  });

  test('晚到的舊偏好不覆蓋使用者剛選的模式', () async {
    final store = _DelayedReadSettingsStore();
    final container = ProviderContainer(
      overrides: [settingsStoreProvider.overrideWithValue(store)],
    );
    container.listen(themeModeProvider, (_, _) {});
    addTearDown(container.dispose);
    expect(container.read(themeModeProvider), ThemeMode.system);

    await container.read(themeModeProvider.notifier).setMode(ThemeMode.light);
    store.readResult.complete('dark');
    await _flushAsyncLoad();

    expect(container.read(themeModeProvider), ThemeMode.light);
  });

  test('快速連續選擇會依點擊順序保存最後一個模式', () async {
    final store = _OutOfOrderWriteSettingsStore();
    final container = ProviderContainer(
      overrides: [settingsStoreProvider.overrideWithValue(store)],
    );
    container.listen(themeModeProvider, (_, _) {});
    addTearDown(container.dispose);

    final first = container
        .read(themeModeProvider.notifier)
        .setMode(ThemeMode.dark);
    await store.firstWriteStarted.future;
    final second = container
        .read(themeModeProvider.notifier)
        .setMode(ThemeMode.light);

    expect(container.read(themeModeProvider), ThemeMode.light);
    store.releaseFirstWrite.complete();
    await Future.wait([first, second]);

    expect(store.value, 'light');
  });

  test('未知儲存值與讀取失敗都安全地跟隨系統', () async {
    for (final store in <SettingsStore>[
      _FixedReadSettingsStore('sepia'),
      _FailingReadSettingsStore(),
    ]) {
      final container = ProviderContainer(
        overrides: [settingsStoreProvider.overrideWithValue(store)],
      );
      container.listen(themeModeProvider, (_, _) {});
      expect(container.read(themeModeProvider), ThemeMode.system);

      await _flushAsyncLoad();

      expect(container.read(themeModeProvider), ThemeMode.system);
      container.dispose();
    }
  });
}
