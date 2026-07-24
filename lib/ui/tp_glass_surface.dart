import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../app/accessibility_scope.dart';

enum TpNavigationGlassRecipe { regular, platformView }

/// 依 Increased Contrast 與 Reduce Transparency 的個別系統狀態，
/// 將任一 glass recipe 收斂為相同的不透明、無 blur accessibility fallback。
LiquidGlassSettings tpResolveGlassSettings(
  BuildContext context,
  LiquidGlassSettings settings, {
  Color? opaqueColor,
}) {
  final increasedContrast = MediaQuery.highContrastOf(context);
  final reduceTransparency = AppAccessibilityScope.reduceTransparencyOf(
    context,
  );
  if (!increasedContrast && !reduceTransparency) return settings;

  final fallback = (opaqueColor ?? Theme.of(context).colorScheme.surface)
      .withValues(alpha: 1);
  return settings.copyWith(
    glassColor: fallback,
    backerColor: fallback,
    platformViewFallbackColor: fallback,
    thickness: 0,
    blur: 0,
    chromaticAberration: 0,
    lightIntensity: 0,
    ambientStrength: 0,
    refractiveIndex: 1,
    saturation: 1,
    glowIntensity: 0,
    standardOpacityMultiplier: 1,
    shadowElevation: 0,
  );
}

LiquidGlassSettings tpNavigationGlassSettings(
  BuildContext context, {
  TpNavigationGlassRecipe recipe = TpNavigationGlassRecipe.regular,
}) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final baseColor = isDark
      ? theme.colorScheme.surfaceContainerLow
      : theme.colorScheme.surface;
  final platformView = recipe == TpNavigationGlassRecipe.platformView;
  final tint = baseColor.withValues(
    alpha: platformView ? (isDark ? 0.62 : 0.56) : (isDark ? 0.48 : 0.40),
  );
  final settings = LiquidGlassSettings(
    glassColor: tint,
    backerColor: null,
    thickness: 16,
    blur: 16,
    chromaticAberration: 0,
    lightIntensity: isDark ? 0.56 : 0.62,
    ambientStrength: isDark ? 0.06 : 0.10,
    refractiveIndex: 1.06,
    saturation: 1.02,
    standardOpacityMultiplier: 1,
    platformViewFallbackColor: tint,
  );
  return tpResolveGlassSettings(context, settings);
}

class TpGlassSurface extends StatelessWidget {
  const TpGlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(28)),
    this.padding = EdgeInsets.zero,
    this.tintColor,
    this.blurSigma = 22,
    this.platformViewBackdrop = false,
    this.glassSettings,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? tintColor;
  final double blurSigma;
  final bool platformViewBackdrop;
  final LiquidGlassSettings? glassSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final increasedContrast = MediaQuery.highContrastOf(context);
    final reduceTransparency = AppAccessibilityScope.reduceTransparencyOf(
      context,
    );
    final useOpaqueFallback = increasedContrast || reduceTransparency;
    final isDark = theme.brightness == Brightness.dark;
    final defaultTint = isDark
        ? theme.colorScheme.surfaceContainerLow.withValues(
            alpha: useOpaqueFallback ? 1 : 0.68,
          )
        : theme.colorScheme.surface.withValues(
            alpha: useOpaqueFallback ? 1 : 0.58,
          );
    final tint = tintColor == null
        ? defaultTint
        : tintColor!.withValues(alpha: useOpaqueFallback ? 1 : tintColor!.a);
    final border = isDark
        ? Colors.white.withValues(alpha: increasedContrast ? 0.64 : 0.18)
        : Colors.white.withValues(alpha: increasedContrast ? 1 : 0.88);
    final radius = borderRadius.topLeft.x;
    final defaultSettings = LiquidGlassSettings(
      glassColor: tint,
      thickness: platformViewBackdrop ? 16 : (isDark ? 28 : 24),
      blur: blurSigma,
      chromaticAberration: platformViewBackdrop ? 0 : (isDark ? 0.004 : 0.006),
      lightIntensity: platformViewBackdrop
          ? (isDark ? 0.56 : 0.62)
          : (isDark ? 0.72 : 0.82),
      ambientStrength: platformViewBackdrop
          ? (isDark ? 0.06 : 0.10)
          : (isDark ? 0.08 : 0.18),
      refractiveIndex: platformViewBackdrop ? 1.06 : 1.15,
      saturation: platformViewBackdrop ? 1.02 : (isDark ? 1.08 : 1.10),
      standardOpacityMultiplier: 1,
      platformViewFallbackColor: tint,
    );
    final baseSettings = glassSettings ?? defaultSettings;
    final resolvedSettings = tpResolveGlassSettings(
      context,
      baseSettings,
      opaqueColor: tint,
    );

    return GlassContainer(
      padding: padding,
      useOwnLayer: true,
      quality: GlassQuality.standard,
      platformViewBackdrop: platformViewBackdrop,
      allowElevation: true,
      clipBehavior: Clip.antiAlias,
      shape: LiquidRoundedSuperellipse(
        borderRadius: radius,
        side: BorderSide(color: border),
      ),
      settings: resolvedSettings,
      child: child,
    );
  }
}
