import 'package:flutter/material.dart';

/// Light mode 色 token（來源：trip-planner css/tokens.css @theme）。
abstract final class TpColorsLight {
  // accent 柔褐（玩/看/買）
  static const accent = Color(0xFFA97A4A);
  static const accentDeep = Color(0xFF805126);
  static const accentSubtle = Color(0xFFF4EDE3);
  static const accentBg = Color(0xFFE9DBC8);

  // sage 綠（住/移動）
  static const sage = Color(0xFFA8BAAA);
  static const sageDeep = Color(0xFF4F6652);
  static const sageSubtle = Color(0xFFECF0ED);
  static const sageBg = Color(0xFFD4DDD5);

  // 玫瑰粉（吃）
  static const pink = Color(0xFFE78C99);
  static const pinkDeep = Color(0xFF8A3947);
  static const pinkSubtle = Color(0xFFFAF1F3);
  static const pinkBg = Color(0xFFF2DBE0);

  // 表面
  static const background = Color(0xFFFFFBF5);
  static const secondary = Color(0xFFFAF4EA);
  static const tertiary = Color(0xFFF2EAD9);
  static const hover = Color(0xFFF9EDE0);

  // 文字
  static const foreground = Color(0xFF2A1F18);
  static const muted = Color(0xFF6F5A47);
  static const accentForeground = Color(0xFFFFFFFF);

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
  static const accent = Color(0xFFD7A96D);
  static const accentDeep = Color(0xFFF0C58E);
  static const accentSubtle = Color(0xFF30291F);
  static const accentBg = Color(0xFF443724);

  static const sage = Color(0xFF8FBE9C);
  static const sageDeep = Color(0xFFA8D0B4);
  static const sageSubtle = Color(0xFF243A2C);
  static const sageBg = Color(0xFF2E3D30);

  static const pink = Color(0xFFE8A0AB);
  static const pinkDeep = Color(0xFFF0B8C0);
  static const pinkSubtle = Color(0xFF4A2A3A);
  static const pinkBg = Color(0xFF6B3F52);

  static const background = Color(0xFF111315);
  static const secondary = Color(0xFF1A1D1F);
  static const tertiary = Color(0xFF24282B);
  static const hover = Color(0xFF2B3033);

  static const foreground = Color(0xFFF3F4F4);
  static const muted = Color(0xFFADB3B7);
  static const accentForeground = Color(0xFF19130C);

  static const border = Color(0xFF34393D);
  static const lineStrong = Color(0xFF4B5257);

  static const destructive = Color(0xFFE8A0A0);
  static const destructiveBg = Color(0x26E8A0A0); // rgba(232,160,160,.15)
  static const success = Color(0xFF7EC89A);
  static const warning = Color(0xFFFAA94B);
  static const info = Color(0xFFCBA06E);

  static const disabled = Color(0xFF596066);
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

/// Motion token（Apple 曲線體系）。
abstract final class TpMotion {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 350);

  static const appleEase = Cubic(0.2, 0.8, 0.2, 1);
  static const springEase = Cubic(0.32, 1.28, 0.6, 1);
  static const sheetClose = Cubic(0.4, 0, 1, 1);
}
