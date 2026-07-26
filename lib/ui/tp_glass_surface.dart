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

/// 一般模式描一條**細邊**；「提高對比」才換成明顯的實心邊。
///
/// 曾經相信「移除描邊之後由材質接手」（`ambientRim`／`glowIntensity`／
/// `specularSharpness` 會沿周長算出亮邊），據此把四處描邊全部移除。**模擬器
/// 實測那個前提不成立**：用真正的 [TpGlassSurface] 量，不論背後是純黑或壓在
/// 內容上，邊緣峰值與內部填色的差都是 **0**；把 `ambientRim` 從 0.70 到 0.07
/// 試了五組值，在純黑背景上一律是 0。邊緣就這樣整個消失了。
///
/// iOS 26 的玻璃邊緣實測是**峰值高出內部填色約 +30**，且沿周長均勻
/// （訊息 app 標題膠囊 x 360→810 全程 +28~+33；電話 app 編輯膠囊 +29）。
/// 所以這裡把邊緣做回來，強度對齊 Apple，而不是舊描邊那種 +119 的貼紙感。
///
/// 顏色由 `onSurface` 導出而非寫死白色：深色模式得到偏亮的細邊，淺色模式得到
/// 偏暗的細邊 —— 淺色的填色本來就接近白，再加白邊等於沒有。
const double _tpGlassEdgeAlpha = 0.12;

/// 把邊緣畫在玻璃**之上**。
///
/// 不能靠 shape 的 `side`：`AdaptiveGlass` 一般模式只拿 shape 去 clip
/// （`ClipRRect`／`ClipPath`），**從不呼叫 `shape.paint`**，所以 `BorderSide`
/// 在有 blur 時完全畫不出來 —— 只有無障礙 fallback 走 `ShapeDecoration` 才會
/// 現形。這是先前「日期選擇器軌道 18% 細邊是死碼」那條的同一個機制。
///
/// `ShapeDecoration` 會畫 side，所以改用 `foregroundDecoration` 疊在玻璃上。
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
  final scheme = Theme.of(context).colorScheme;
  if (!MediaQuery.highContrastOf(context)) {
    return scheme.onSurface.withValues(alpha: _tpGlassEdgeAlpha);
  }
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

    return TpGlassEdge(
      borderRadius: radius,
      child: GlassContainer(
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
      ),
    );
  }
}
