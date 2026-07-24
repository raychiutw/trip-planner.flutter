import 'package:flutter/material.dart';

/// HIG 淺色系統角色；暖褐主色只用於選取、連結與主要動作。
abstract final class TpSystemColorsLight {
  static const tint = Color(0xFF8A6038);
  static const tintDeep = Color(0xFF6F4C2C);
  static const tintSubtle = Color(0x1F8A6038);
  static const tintBackground = Color(0x268A6038);

  static const background = Color(0xFFFFFFFF);
  static const secondary = Color(0xFFF2F2F7);
  static const tertiary = Color(0xFFE5E5EA);
  static const hover = Color(0x0F000000);

  static const label = Color(0xFF000000);
  static const secondaryLabel = Color(0x993C3C43);
  static const separator = Color(0x493C3C43);
  static const opaqueSeparator = Color(0x5C3C3C43);

  static const destructive = Color(0xFFFF3B30);
  static const destructiveBackground = Color(0x1AFF3B30);
  static const success = Color(0xFF34C759);
  static const warning = Color(0xFFFF9500);

  static const disabled = Color(0x4D3C3C43);
  static const overlay = Color(0x52000000);
}

/// HIG 深色系統角色；與淺色模式使用相同的語意層級。
abstract final class TpSystemColorsDark {
  static const tint = Color(0xFFD0A576);
  static const tintDeep = Color(0xFFE5C39F);
  static const tintSubtle = Color(0x33D0A576);
  static const tintBackground = Color(0x40D0A576);

  static const background = Color(0xFF000000);
  static const secondary = Color(0xFF1C1C1E);
  static const tertiary = Color(0xFF2C2C2E);
  static const hover = Color(0x1FFFFFFF);

  static const label = Color(0xFFFFFFFF);
  static const secondaryLabel = Color(0x99EBEBF5);
  static const separator = Color(0x5C545458);
  static const opaqueSeparator = Color(0x99545458);

  static const destructive = Color(0xFFFF453A);
  static const destructiveBackground = Color(0x33FF453A);
  static const success = Color(0xFF30D158);
  static const warning = Color(0xFFFF9F0A);

  static const disabled = Color(0x4DEBEBF5);
  static const overlay = Color(0x99000000);
}

/// 圓角 token；md 8 為卡片/按鈕主力。
abstract final class TpRadius {
  static const xs = 4.0;
  static const sm = 6.0;
  static const md = 8.0;
  static const lg = 12.0;
  static const xl = 16.0;
}

/// 間距 token（4px grid）。
abstract final class TpSpacing {
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 20.0;
  static const s6 = 24.0;
  static const s7 = 28.0;
  static const s8 = 32.0;
  static const s9 = 36.0;
  static const s10 = 40.0;

  /// 最小 tap target 44×44。
  static const tapMin = 44.0;

  /// 行動版 bottom nav 高度（含 safe area）。
  static const navHeight = 88.0;
}

/// 浮動四分頁的實際佔位；地圖 accessory 與 root scroll 共用。
abstract final class TpRootTabGeometry {
  static const horizontalMargin = 16.0;
  static const expandedBarHeight = 64.0;
  static const bottomSpacing = 16.0;
  static const safeAreaOverlap = 24.0;

  static double bottomOffsetFor(double bottomInset) {
    final offset = bottomInset - safeAreaOverlap;
    return offset > bottomSpacing ? offset : bottomSpacing;
  }

  static double bottomOffset(BuildContext context) =>
      bottomOffsetFor(MediaQuery.viewPaddingOf(context).bottom);

  static double expandedHeightFor(double bottomInset) =>
      bottomOffsetFor(bottomInset) + expandedBarHeight;

  static double expandedHeight(BuildContext context) =>
      expandedHeightFor(MediaQuery.viewPaddingOf(context).bottom);

  static double clearance(BuildContext context) {
    final shellInset = MediaQuery.paddingOf(context).bottom;
    final fallback = expandedHeight(context);
    return shellInset > fallback ? shellInset : fallback;
  }
}

/// Motion token（Apple 曲線體系）。
abstract final class TpMotion {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 350);

  static const appleEase = Cubic(0.2, 0.8, 0.2, 1);
  static const springEase = Cubic(0.32, 1.28, 0.6, 1);
  static const sheetClose = Cubic(0.4, 0, 1, 1);

  /// 系統要求減少動態效果時，保留狀態變更但移除過場時間。
  static Duration resolve(BuildContext context, Duration preferred) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : preferred;
}
