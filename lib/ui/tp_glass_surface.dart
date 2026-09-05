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
    // `ambientRim` 先前漏在這串之外，fallback 仍帶著材質的邊緣光參數 ——
    // 與「收斂為不透明、無 blur」的意圖不一致，一併歸零。
    ambientRim: 0,
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

/// 一般模式**不描邊**；「提高對比」才補一條明顯的實心邊。
///
/// PR #163 曾經加過一條 `onSurface @ 0.12` 的細邊，因為當時走
/// `GlassQuality.standard`，那條路徑的材質完全不產生可見邊緣（模擬器實測
/// 差值恆為 0）。換到 `premium` 之後材質自己就給得出來 —— 真機 v0.16.0
/// 量到標題膠囊總共 **+60**，其中我們這條細邊約 **+27**、材質約 **+33**，
/// 而目標是 +30。**再畫一條等於把量翻倍**，所以拿掉。
///
/// 邊緣強度現在由 [tpGlassRecipe] 的 `fresnelStrength`／`lightIntensity`／
/// `ambientStrength` 控制，全部只在 premium 生效。
/// 把邊緣畫在玻璃**之上**（只有「提高對比」時才有顏色）。
///
/// 不能靠 shape 的 `side`：`AdaptiveGlass` 一般模式只拿 shape 去 clip，
/// **從不呼叫 `shape.paint`**，`BorderSide` 在有 blur 時畫不出來 —— 只有
/// 無障礙 fallback 走 `ShapeDecoration` 才現形。
class TpGlassEdge extends StatelessWidget {
  const TpGlassEdge({
    super.key,
    required this.borderRadius,
    required this.child,
  });

  final double borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    foregroundDecoration: ShapeDecoration(
      shape: LiquidRoundedSuperellipse(
        borderRadius: borderRadius,
        side: BorderSide(color: tpGlassEdgeColor(context)),
      ),
    ),
    child: child,
  );
}

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
/// ## 材質自身的邊緣光（#169 / #178）
///
/// 真機（v0.13.0）量到標題膠囊與頭像圓鈕的邊緣高出內部填色 **+125~+138**，
/// day tab 是 **+20~+31**，iOS 26 是 **+29~+31**。
///
/// 旋鈕是 `fresnelStrength`，它只在 `GlassQuality.premium` 生效 —— 而本檔
/// 底下傳的正是 `premium`（v0.17.0 起）。
///
/// 歷史紀錄:這段註解原本寫「`ambientRim`／`glowIntensity` 是死的，因為我們
/// 固定傳 `standard`」。前半在 `standard` 那條路徑上仍然成立
/// （`shaders/lightweight_glass.frag` 沒有 `ambientRim` uniform，
/// `uData4.w` 取的是 widget 欄位而非 `settings.glowIntensity`），但**後半的
/// 前提已經不成立**,而基於它推導出來的結論被人沿用過。改成 `premium` 之後
/// renderer 原生路徑會 `setFloat(settings.ambientRim)`，那兩個參數不再是死的。
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
    // **邊緣有兩條來源,`fresnelStrength` 只關掉其中一條。** premium shader
    // 的 specular 高光是另一條,`uLightIntensity` 在那裡被乘 3.0:
    //
    //   directional = totalInfluence^1.5 * uLightIntensity * 3.0
    //   brightness  = (directional + ambient) * edgeFactor * thicknessScale
    //
    // 真機 v0.15.0(已關 Fresnel)實測標題膠囊仍有 +100、日期選擇器 +105,
    // 目標是 +30 —— 剩下的就是這一條。原本 0.72／0.08 壓到 0.20／0.03。
    lightIntensity: onMedia ? 0.16 : 0.20,
    ambientStrength: onMedia ? 0.02 : 0.03,
    specularSharpness: GlassSpecularSharpness.medium,
    refractiveIndex: onMedia ? 1.06 : 1.15,
    saturation: onMedia ? 1.02 : (isDark ? 1.08 : 1.10),
    // **關掉物理 Fresnel 邊緣光。** 套件註解:0.0 = pure blur-overlay
    // appearance with no physics-based rim highlight, matching iOS 26 system
    // UI glass (Messages, Notification banners) —— 我們拿來當基準的正是
    // 訊息 app。`ambientRim` 是**額外再加一圈**,方向相反,維持不設定。
    fresnelStrength: 0,
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
    // 呼叫端自帶 settings(例如 tpNavigationGlassSettings)又沒指定 tint 時,
    // fallback 的不透明色已經算過,這裡不再用預設 tint 蓋掉,否則深色模式的
    // 動作群組會與旁邊的單顆玻璃鈕不同色;有指定 tintColor 才由它決定。
    final resolvedSettings = tpResolveGlassSettings(
      context,
      baseSettings,
      opaqueColor: glassSettings == null || tintColor != null ? tint : null,
    );

    return TpGlassEdge(
      borderRadius: radius,
      child: GlassContainer(
        padding: padding,
        useOwnLayer: true,
        quality: GlassQuality.premium,
        platformViewBackdrop: platformViewBackdrop,
        allowElevation: true,
        clipBehavior: Clip.antiAlias,
        shape: LiquidRoundedSuperellipse(
          borderRadius: radius,
          side: BorderSide(color: border),
        ),
        settings: resolvedSettings,
        child: child,
      ),
    );
  }
}
