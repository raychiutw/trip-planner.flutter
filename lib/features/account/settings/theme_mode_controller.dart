/// App 外觀模式的本機狀態與持久化。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/providers.dart';
import '../../../api/settings_store.dart';

const _themeModeKey = 'theme_mode';

String _encodeThemeMode(ThemeMode mode) => switch (mode) {
  ThemeMode.system => 'system',
  ThemeMode.light => 'light',
  ThemeMode.dark => 'dark',
};

ThemeMode _decodeThemeMode(String? value) => switch (value) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  _ => ThemeMode.system,
};

/// 在建立 App 前恢復外觀，避免冷啟動先畫出錯誤主題再切換。
Future<ThemeMode> loadInitialThemeMode(SettingsStore store) async {
  try {
    return _decodeThemeMode(await store.read(_themeModeKey));
  } catch (_) {
    return ThemeMode.system;
  }
}

class ThemeModeController extends Notifier<ThemeMode> {
  ThemeModeController({ThemeMode? initialMode}) : _initialMode = initialMode;

  final ThemeMode? _initialMode;
  bool _userSelectedMode = false;
  Future<void> _pendingWrite = Future.value();

  @override
  ThemeMode build() {
    if (_initialMode case final initialMode?) return initialMode;
    unawaited(_loadSavedMode());
    return ThemeMode.system;
  }

  Future<void> _loadSavedMode() async {
    String? savedMode;
    try {
      savedMode = await ref.read(settingsStoreProvider).read(_themeModeKey);
    } catch (_) {
      return;
    }
    if (_userSelectedMode) return;
    state = _decodeThemeMode(savedMode);
  }

  Future<void> setMode(ThemeMode mode) async {
    _userSelectedMode = true;
    state = mode;
    final store = ref.read(settingsStoreProvider);
    final encodedMode = _encodeThemeMode(mode);
    _pendingWrite = _pendingWrite.then((_) async {
      try {
        await store.write(_themeModeKey, encodedMode);
      } catch (_) {
        // 本機偏好寫入失敗不回滾目前工作階段的可見選擇。
      }
    });
    await _pendingWrite;
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);
