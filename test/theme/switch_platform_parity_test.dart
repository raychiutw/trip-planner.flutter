import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/theme/app_theme.dart';

/// 設定頁的開關（`Switch.adaptive`）在 Android 走 Material，iOS 走 CupertinoSwitch。
/// Android 深色模式曾因沿用 Material 預設，關閉狀態的軌道與滑塊融進底色看不見。
/// 以 iOS 的關閉狀態為基準：Android 的「軌道對底色」「滑塊對軌道」兩個對比度
/// 都不得低於 iOS，滑塊顏色也要一致。
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  for (final brightness in Brightness.values) {
    test('Android 開關關閉狀態的對比度不低於 iOS（${brightness.name}）', () {
      final theme = brightness == Brightness.light
          ? AppTheme.light()
          : AppTheme.dark();
      final card = theme.colorScheme.surfaceContainerLow;

      // iOS 基準：CupertinoSwitch 預設的關閉軌道與白色滑塊。
      const iosFill = CupertinoColors.secondarySystemFill;
      final iosTrack = Color.alphaBlend(
        brightness == Brightness.dark ? iosFill.darkColor : iosFill.color,
        card,
      );
      const iosThumb = CupertinoColors.white;

      final track = theme.switchTheme.trackColor?.resolve({});
      final thumb = theme.switchTheme.thumbColor?.resolve({});
      expect(track, isNotNull, reason: '要明確指定關閉狀態的軌道色，不能沿用 Material 預設');
      expect(thumb, isNotNull, reason: '要明確指定關閉狀態的滑塊色');

      final androidTrack = Color.alphaBlend(track!, card);
      expect(thumb, iosThumb, reason: '滑塊顏色與 iOS 一致');
      expect(
        _contrast(androidTrack, card),
        greaterThanOrEqualTo(_contrast(iosTrack, card) - 0.01),
        reason: '軌道對底色',
      );
      expect(
        _contrast(thumb!, androidTrack),
        greaterThanOrEqualTo(_contrast(iosThumb, iosTrack) - 0.01),
        reason: '滑塊對軌道',
      );
    });
  }
}
