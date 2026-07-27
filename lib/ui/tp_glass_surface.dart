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

/// 一般模式描一條**細邊**；「提高對比」才換成明顯的實心邊。
///
/// iOS 26 的玻璃邊緣實測是**峰值高出內部填色約 +30**，且沿周長均勻
/// （訊息 app 標題膠囊 x 360→810 全程 +28~+33；電話 app 編輯膠囊 +29）。
/// 這條細邊就是對齊那個量級，而不是舊描邊那種 +119 的貼紙感。
///
/// **量測（#169，iPhone 17 Pro 模擬器 / iOS 26.5 / @3x）**：這條邊實體上是
/// 3px 的實色，沿邊緣完全一致，左右對稱。
///
/// | | 內部填色 | 邊緣 | 差 |
/// |---|---|---|---|
/// | 深色 標題膠囊 / 選擇器軌 | 4 | 34 | **+30** |
/// | 淺色 標題膠囊 / 選擇器軌 | 255 | 224 | **−31** |
/// | 提高對比（深色） | 28 | 255 | +227 |
/// | 提高對比（淺色） | 243 | 19 | −224 |
///
/// 同一批截圖裡玻璃材質自身**沒有**產生任何邊緣（內部填色與背景只差 4）——
/// 模擬器不渲染材質邊緣光，真機上那一層是 +125，見 [tpGlassRecipe]。
/// 換句話說**上表只驗到「我們自己畫的那條邊」**，材質那一半未經真機確認。
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
/// 讓底下的玻璃層以為背景是亮的，把 shader 的 rim 壓下來。
///
/// `lightweight_glass.frag` 的邊緣強度由 `uBackdropLuma` 決定：
///
/// ```glsl
/// rimFade = 1.0 - smoothstep(0.3, 0.5, uBackdropLuma) * 0.92;
/// ```
///
/// 而 `uBackdropLuma` **不是從真實背景算的**，是 `glass_effect.dart` 裡的
/// `isDark ? 0.15 : 0.85`，`isDark` 又來自 `GlassTheme.brightnessOf(context)`。
/// 深色 → `rimFade` 1.00（滿版 rim，真機實測 **+125**）；宣告亮 → 0.08，**降 92%**。
///
/// 其餘吃 `uBackdropLuma` 的地方在我們的值域下沒有影響。PATH B（所有 standard
/// widget 走的路）是：
///
/// ```glsl
/// simulatedFrost = 0.08 + densityFactor * 0.05 + isLight * 0.04;   // ≈0.13~0.17
/// baseRgb = mix(vec3(isLight), uGlassColor.rgb,
///               min(glassAlpha / (simulatedFrost + 0.01), 1.0));
/// pmA     = max(glassAlpha, simulatedFrost);
/// ```
///
/// 我們的 `glassColor` alpha 是 **0.35~0.68**，除以 frost 遠大於 1 → mix 係數被
/// clamp 成 1.0，白霧完全混不進來；`pmA` 也仍取 alpha。剩下唯一的副作用是
/// fresnel 的 `adaptiveStrength` 從 1.2 降到 0.8，方向與我們一致。
///
/// ⚠️ **這個結論以「alpha 遠高於 frost」為前提。** 若日後有玻璃的 alpha 低於
/// 約 0.2，深色下就會冒出白霧 —— 那時要改用別的作法，不能沿用這裡。
///
/// 無障礙的不透明 fallback 不套用：那條路 `blur = 0`、不經 shader，沒有 rim
/// 可壓，而且宣告錯的明暗會影響套件自己挑的預設值。
Widget tpGlassBrightnessOverride({
  required BuildContext context,
  required Widget child,
}) {
  final increasedContrast = MediaQuery.highContrastOf(context);
  final reduceTransparency = AppAccessibilityScope.reduceTransparencyOf(
    context,
  );
  if (increasedContrast || reduceTransparency) return child;
  return GlassTheme(
    data: const GlassThemeData(brightness: Brightness.light),
    child: child,
  );
}

/// ## 材質自身的邊緣光（#169 / #178）
///
/// 真機（v0.13.0）量到標題膠囊與頭像圓鈕的邊緣高出內部填色 **+125~+138**，
/// day tab 是 **+20~+31**，iOS 26 是 **+29~+31**。
///
/// **不要試圖用 `ambientRim`／`glowIntensity` 調它 —— 在我們的算圖路徑上那兩個
/// 參數是死的。** 讀 0.22.1 與 0.23.0 原始碼皆確認:
///
/// - `AdaptiveGlass` 只在 `quality == premium` 時走 renderer 原生路徑（那裡才
///   `setFloat(settings.ambientRim)`）；我們固定傳 `standard`，走
///   `LightweightLiquidGlass`。
/// - `shaders/lightweight_glass.frag` **沒有 `ambientRim` uniform**；
///   `uData4.w`（uGlowIntensity）取的是 widget 欄位而非 `settings.glowIntensity`。
/// - 0.23.0 的 rim 常數與 0.22.1 一字未改。
///
/// 真正的旋鈕是 [tpGlassBrightnessOverride] —— 見該處說明。
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

    return tpGlassBrightnessOverride(
      context: context,
      child: TpGlassEdge(
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
      ),
    );
  }
}
