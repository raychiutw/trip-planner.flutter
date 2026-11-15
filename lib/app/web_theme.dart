import 'dart:ui' show Brightness;

import 'package:flutter/material.dart' show ThemeMode;

/// 開 web 時帶的 `theme` 值：App 當下實際顯示的明暗。跟隨系統就用系統當下明暗解析，
/// 不傳 `system`（web 無法可靠得知 App 端的系統明暗）。
String resolveWebTheme(ThemeMode mode, Brightness platformBrightness) =>
    switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system =>
        platformBrightness == Brightness.dark ? 'dark' : 'light',
    };
