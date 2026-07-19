import 'package:flutter/material.dart';

/// Light mode 色 token（來源：trip-planner css/tokens.css @theme）。
abstract final class TpColorsLight {
  // accent 柔褐（玩/看/買）
  static const accent = Color(0xFFA97A4A);
  static const accentDeep = Color(0xFF8A6038);
  static const accentSubtle = Color(0xFFF4EDE3);
  static const accentBg = Color(0xFFE9DBC8);
  static const navigationSelection = Color(0x2EA97A4A);
  static const rootTabSelection = navigationSelection;
  static const dayThumb = navigationSelection;

  // 表面
  static const background = Color(0xFFFFFBF5);
  static const secondary = Color(0xFFFAF4EA);
  static const tertiary = Color(0xFFF2EAD9);
  static const hover = Color(0xFFF9EDE0);

  // 文字
  static const foreground = Color(0xFF2A1F18);
  static const muted = Color(0xFF6F5A47);
  static const accentForeground = Color(0xFFFFFFFF);

  // 舊 API 相容別名：三色分類已退場，全部映射到中性暖白階。
  static const sage = muted;
  static const sageDeep = foreground;
  static const sageSubtle = tertiary;
  static const sageBg = tertiary;
  static const pink = muted;
  static const pinkDeep = foreground;
  static const pinkSubtle = tertiary;
  static const pinkBg = tertiary;

  // 線條
  static const border = Color(0xFFEADFCF);
  static const lineStrong = Color(0xFFC8B89F);

  // 語意
  static const destructive = Color(0xFFC13515);
  static const destructiveBg = Color(0xFFFDECEC);
  static const success = Color(0xFF06A77D);
  static const warning = Color(0xFFF48C06);
  static const info = Color(0xFFA97A4A);

  // 狀態
  static const disabled = Color(0xFFB8AC9B);
  static const overlay = Color(0x592A1F18); // rgba(42,31,24,.35)
}

/// Dark mode 色 token（獨立暖褐黑 palette，非反色）。
abstract final class TpColorsDark {
  static const accent = Color(0xFFCBA06E);
  static const accentDeep = Color(0xFFE0BC90);
  static const accentSubtle = tertiary;
  static const accentBg = Color(0xFF44341F);
  static const navigationSelection = Color(0x38E0BC90);
  static const rootTabSelection = navigationSelection;
  static const dayThumb = navigationSelection;

  static const background = Color(0xFF1C1C1E);
  static const secondary = Color(0xFF2C2C2E);
  static const tertiary = Color(0xFF3A3A3C);
  static const glass = secondary;
  static const hover = Color(0xFF38383A);

  static const foreground = Color(0xFFF5F5F7);
  static const muted = Color(0xFFA1A1A6);
  static const accentForeground = background;

  // 舊 API 相容別名：三色分類已退場，全部映射到中性深色階。
  static const sage = muted;
  static const sageDeep = foreground;
  static const sageSubtle = tertiary;
  static const sageBg = tertiary;
  static const pink = muted;
  static const pinkDeep = foreground;
  static const pinkSubtle = tertiary;
  static const pinkBg = tertiary;

  static const border = Color(0xFF38383A);
  static const lineStrong = Color(0xFF48484A);

  static const destructive = Color(0xFFE8A0A0);
  static const destructiveBg = Color(0x26E8A0A0); // rgba(232,160,160,.15)
  static const success = Color(0xFF7EC89A);
  static const warning = Color(0xFFFAA94B);
  static const info = Color(0xFFCBA06E);

  static const disabled = Color(0xFF5A5A5E);
  static const overlay = Color(0xA6000000); // rgba(0,0,0,.65)
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
