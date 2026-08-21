import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/settings_store.dart';
import 'package:tripline/features/account/settings/theme_mode_controller.dart';
import 'package:tripline/models/user.dart';

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

class _FailFirstWriteSettingsStore implements SettingsStore {
  String? value;
  var _writeCount = 0;

  @override
  Future<String?> read(String key) async => value;

  @override
  Future<void> write(String key, String value) async {
    _writeCount += 1;
    if (_writeCount == 1) throw StateError('unavailable');
    this.value = value;
  }
}

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  test('冷啟動載入每種已保存值，第一個 provider 狀態就正確', () async {
    for (final (stored, expected) in <(String?, ThemeMode)>[
      (null, ThemeMode.system),
      ('system', ThemeMode.system),
      ('light', ThemeMode.light),
      ('dark', ThemeMode.dark),
    ]) {
      final store = _FixedReadSettingsStore(stored);
      final initialMode = await loadInitialThemeMode(store);
      final container = ProviderContainer(
        overrides: [
          settingsStoreProvider.overrideWithValue(store),
          themeModeProvider.overrideWith(
            () => ThemeModeController(initialMode: initialMode),
          ),
        ],
      );

      expect(container.read(themeModeProvider), expected);
      container.dispose();
    }
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

  test('寫入失敗不回滾目前選擇，且後續選擇仍可保存', () async {
    final store = _FailFirstWriteSettingsStore();
    final container = ProviderContainer(
      overrides: [settingsStoreProvider.overrideWithValue(store)],
    );
    container.listen(themeModeProvider, (_, _) {});
    addTearDown(container.dispose);

    await container.read(themeModeProvider.notifier).setMode(ThemeMode.dark);

    expect(container.read(themeModeProvider), ThemeMode.dark);
    expect(store.value, isNull);

    await container.read(themeModeProvider.notifier).setMode(ThemeMode.light);

    expect(container.read(themeModeProvider), ThemeMode.light);
    expect(store.value, 'light');

    await container.read(themeModeProvider.notifier).setMode(ThemeMode.system);

    expect(container.read(themeModeProvider), ThemeMode.system);
    expect(store.value, 'system');
  });

  test('登出不清除本機外觀偏好，重新建立 provider 仍恢復深色', () async {
    final store = InMemorySettingsStore();
    final authRepository = _MockAuthRepository();
    when(authRepository.currentUser).thenAnswer(
      (_) async => const UserInfo(
        id: 'user-1',
        email: 'ray@example.com',
        emailVerified: true,
      ),
    );
    when(authRepository.logout).thenAnswer((_) async {});
    final container = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(store),
        authRepositoryProvider.overrideWithValue(authRepository),
      ],
    );
    container.listen(themeModeProvider, (_, _) {});
    addTearDown(container.dispose);
    await container.read(authStateProvider.future);
    await container.read(themeModeProvider.notifier).setMode(ThemeMode.dark);

    await container.read(authStateProvider.notifier).logout();

    expect(container.read(authStateProvider).value, isNull);
    expect(await store.read('theme_mode'), 'dark');

    final restarted = ProviderContainer(
      overrides: [settingsStoreProvider.overrideWithValue(store)],
    );
    restarted.listen(themeModeProvider, (_, _) {});
    addTearDown(restarted.dispose);
    await _flushAsyncLoad();

    expect(restarted.read(themeModeProvider), ThemeMode.dark);
  });

  test('未知儲存值與讀取失敗都安全地跟隨系統', () async {
    for (final store in <SettingsStore>[
      _FixedReadSettingsStore('sepia'),
      _FailingReadSettingsStore(),
    ]) {
      expect(await loadInitialThemeMode(store), ThemeMode.system);
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
