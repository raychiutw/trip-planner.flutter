import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../theme/tokens.dart';

LiquidGlassSettings tpNavigationGlassSettings(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final settings = LiquidGlassSettings(
    glassColor: (isDark ? TpColorsDark.secondary : TpColorsLight.background)
        .withValues(alpha: isDark ? 0.68 : 0.58),
    thickness: 16,
    blur: 16,
    chromaticAberration: 0,
    lightIntensity: isDark ? 0.56 : 0.62,
    ambientStrength: isDark ? 0.06 : 0.10,
    refractiveIndex: 1.06,
    saturation: 1.02,
    standardOpacityMultiplier: 1,
    platformViewFallbackColor:
        (isDark ? TpColorsDark.secondary : TpColorsLight.background).withValues(
          alpha: isDark ? 0.68 : 0.58,
        ),
  );
  if (!MediaQuery.highContrastOf(context)) return settings;
  final opaqueColor =
      (isDark ? TpColorsDark.background : TpColorsLight.background).withValues(
        alpha: 0.96,
      );
  return settings.copyWith(
    glassColor: opaqueColor,
    backerColor: opaqueColor,
    platformViewFallbackColor: opaqueColor,
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
    final highContrast = MediaQuery.highContrastOf(context);
    final isDark = theme.brightness == Brightness.dark;
    final defaultTint = isDark
        ? TpColorsDark.secondary.withValues(alpha: highContrast ? 0.96 : 0.68)
        : TpColorsLight.background.withValues(
            alpha: highContrast ? 0.96 : 0.58,
          );
    final tint = tintColor == null
        ? defaultTint
        : tintColor!.withValues(alpha: highContrast ? 0.96 : tintColor!.a);
    final border = isDark
        ? Colors.white.withValues(alpha: highContrast ? 0.64 : 0.18)
        : Colors.white.withValues(alpha: highContrast ? 1 : 0.88);
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
    final resolvedSettings = highContrast
        ? baseSettings.copyWith(
            glassColor: tint,
            backerColor: tint,
            platformViewFallbackColor: tint,
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
          )
        : baseSettings;

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
