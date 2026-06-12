/// app 主題模式(system/light/dark);純 client + 持久化到 SettingsStore。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/providers.dart';

const _themeKey = 'theme_mode';

String themeModeToString(ThemeMode m) => switch (m) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };

ThemeMode parseThemeMode(String? s) => switch (s) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

class ThemeModeController extends Notifier<ThemeMode> {
  bool _userOverrode = false;

  @override
  ThemeMode build() {
    unawaited(_load());
    return ThemeMode.system; // 載入前預設;載完套用儲存值
  }

  Future<void> _load() async {
    final v = await ref.read(settingsStoreProvider).read(_themeKey);
    // 若使用者在載入完成前已手動切換,以使用者選擇為準(避免被晚到的 _load 蓋掉)。
    if (_userOverrode) return;
    state = parseThemeMode(v);
  }

  Future<void> setMode(ThemeMode mode) async {
    _userOverrode = true;
    state = mode;
    await ref
        .read(settingsStoreProvider)
        .write(_themeKey, themeModeToString(mode));
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
