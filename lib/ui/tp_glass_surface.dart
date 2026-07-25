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

/// 媒體背景上的暗化層不透明度 —— HIG 材質指引：底下內容亮時約 35%。
const double tpMediaScrimOpacity = 0.35;

/// 玻璃上的字符與文字走單色標籤語意色，並依玻璃底下內容的亮度切換深淺。
///
/// **不能用 app 的明暗模式判斷。** `tripMapColorScheme()` 丟棄了 brightness
/// 參數、永遠回傳 light，地圖在深色模式下仍是亮圖磚；媒體背景一律先加暗化層
/// （見 [tpMediaScrimOpacity]），字符再用亮色，深淺兩種模式都可讀。
Color tpBarForeground(BuildContext context, {required bool onMedia}) =>
    onMedia ? Colors.white : Theme.of(context).colorScheme.onSurface;

/// 把 [tpBarForeground] 套給整片 bar 的字符與文字。
///
/// 用框架既有的 [IconTheme] 與 [DefaultTextStyle] 傳遞，明確指定顏色的呼叫點
/// （例如選單觸發鈕的品牌 tint）自然覆蓋掉它。
class TpBarForeground extends StatelessWidget {
  const TpBarForeground({
    super.key,
    required this.onMedia,
    required this.child,
  });

  final bool onMedia;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final color = tpBarForeground(context, onMedia: onMedia);
    return IconTheme.merge(
      data: IconThemeData(color: color),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: color),
        child: child,
      ),
    );
  }
}

/// 一般模式的邊緣**交還玻璃材質**；只有「提高對比」才補一條可見實心邊。
///
/// 均勻描一圈固定顏色的實心線正是「貼紙感」的來源 —— iOS 26 的玻璃邊緣是
/// 材質沿周長算出來、受光角影響的亮邊，由 [tpGlassRecipe] 的 `ambientRim`、
/// `glowIntensity` 與 `specularSharpness` 產生。
Color tpGlassEdgeColor(BuildContext context) {
  if (!MediaQuery.highContrastOf(context)) return Colors.transparent;
  return Theme.of(context).brightness == Brightness.dark
      ? Colors.white
      : Colors.black.withValues(alpha: 0.72);
}

/// 導覽 chrome 與共用玻璃表面的**單一參數來源**。
///
/// 原本兩處各有一組（共用表面用較高的折射率／色散／飽和度，導覽配方用較低的），
/// 浮動 header 呼叫導覽配方時又把前者蓋掉。收斂為同一組，以較接近 iOS 26 的
/// 那一組為準；媒體背景（platform view）維持低色散與低折射率。
///
/// `ambientRim`／`glowIntensity`／`specularSharpness` 三個參數原本**沒有設定**，
/// 等於把 shader 的邊緣光關掉，才需要另外描一條實心線補回來。
///
/// ⚠️ 這三個參數目前是初值，**尚未真機定案**（見 #121）—— shader 折射與裝置
/// 像素比及實際背景內容有關，模擬器不準。
LiquidGlassSettings tpGlassRecipe(
  BuildContext context, {
  required Color tint,
  required bool onMedia,
  required double blur,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return LiquidGlassSettings(
    glassColor: tint,
    backerColor: null,
    thickness: onMedia ? 16 : (isDark ? 28 : 24),
    blur: blur,
    chromaticAberration: onMedia ? 0 : (isDark ? 0.004 : 0.006),
    lightIntensity: onMedia ? (isDark ? 0.56 : 0.62) : (isDark ? 0.72 : 0.82),
    ambientStrength: onMedia ? (isDark ? 0.06 : 0.10) : (isDark ? 0.08 : 0.18),
    ambientRim: onMedia ? 0.5 : 0.7,
    glowIntensity: onMedia ? 0.5 : 0.75,
    specularSharpness: GlassSpecularSharpness.medium,
    refractiveIndex: onMedia ? 1.06 : 1.15,
    saturation: onMedia ? 1.02 : (isDark ? 1.08 : 1.10),
    standardOpacityMultiplier: 1,
    platformViewFallbackColor: tint,
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
  // 媒體背景走清透玻璃：不透明度比一般背景低，暗化交給 scrim 那層負責。
  final tint = platformView
      ? Colors.black.withValues(alpha: tpMediaScrimOpacity)
      : baseColor.withValues(alpha: isDark ? 0.48 : 0.40);
  return tpResolveGlassSettings(
    context,
    tpGlassRecipe(context, tint: tint, onMedia: platformView, blur: 16),
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
    final increasedContrast = MediaQuery.highContrastOf(context);
    final reduceTransparency = AppAccessibilityScope.reduceTransparencyOf(
      context,
    );
    final useOpaqueFallback = increasedContrast || reduceTransparency;
    final isDark = theme.brightness == Brightness.dark;
    final neutralTint = isDark
        ? theme.colorScheme.surfaceContainerLow.withValues(
            alpha: useOpaqueFallback ? 1 : 0.68,
          )
        : theme.colorScheme.surface.withValues(
            alpha: useOpaqueFallback ? 1 : 0.58,
          );
    // 浮在視覺豐富背景上才用清透玻璃，且底下內容亮時要加暗化層。
    // 地圖圖磚恆為亮色（tripMapColorScheme 丟棄 brightness 參數），所以深淺
    // 兩種模式都需要暗化，不能靠 app 的明暗模式判斷。
    final defaultTint = platformViewBackdrop && !useOpaqueFallback
        ? Colors.black.withValues(alpha: tpMediaScrimOpacity)
        : neutralTint;
    final tint = tintColor == null
        ? defaultTint
        : tintColor!.withValues(alpha: useOpaqueFallback ? 1 : tintColor!.a);
    final border = tpGlassEdgeColor(context);
    final radius = borderRadius.topLeft.x;
    final baseSettings =
        glassSettings ??
        tpGlassRecipe(
          context,
          tint: tint,
          onMedia: platformViewBackdrop,
          blur: blurSigma,
        );
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
