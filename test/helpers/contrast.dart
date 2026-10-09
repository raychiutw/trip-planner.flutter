import 'package:flutter/material.dart';

/// WCAG 2.x 對比。`bg` 可為半透明，會先疊在 `under` 上。
double wcagContrast(Color fg, Color bg, {required Color under}) {
  final solidBg = Color.alphaBlend(bg, under);
  final solidFg = Color.alphaBlend(fg, solidBg);
  final l1 = solidFg.computeLuminance();
  final l2 = solidBg.computeLuminance();
  final hi = l1 > l2 ? l1 : l2;
  final lo = l1 > l2 ? l2 : l1;
  return (hi + 0.05) / (lo + 0.05);
}

/// 文字（`textColor`，null 代表繼承 onSurface）疊在 errorContainer 底色上的對比。
double errorTextContrast(Color? textColor, ColorScheme scheme) => wcagContrast(
  textColor ?? scheme.onSurface,
  scheme.errorContainer,
  under: scheme.surface,
);
