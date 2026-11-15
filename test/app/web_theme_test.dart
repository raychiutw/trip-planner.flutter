import 'dart:ui' show Brightness;

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/app/external_links.dart';
import 'package:tripline/app/web_theme.dart';

void main() {
  group('resolveWebTheme：App 當下實際顯示的明暗', () {
    test('外觀固定時不看系統', () {
      expect(resolveWebTheme(ThemeMode.dark, Brightness.light), 'dark');
      expect(resolveWebTheme(ThemeMode.light, Brightness.dark), 'light');
    });

    test('跟隨系統：用系統當下明暗解析，不傳 system', () {
      expect(resolveWebTheme(ThemeMode.system, Brightness.dark), 'dark');
      expect(resolveWebTheme(ThemeMode.system, Brightness.light), 'light');
    });
  });

  group('外開網址帶 theme', () {
    test('隱私權政策', () {
      expect(privacyPolicyUriFor('dark').queryParameters['theme'], 'dark');
      expect(privacyPolicyUriFor('light').queryParameters['theme'], 'light');
      expect(privacyPolicyUriFor('dark').path, '/privacy');
    });

    test('帳號刪除說明：theme 在 query、錨點保留', () {
      final u = accountDeletionHelpUriFor('dark');
      expect(u.queryParameters['theme'], 'dark');
      expect(u.fragment, 'delete-account');
      expect(u.path, '/privacy');
    });
  });
}
