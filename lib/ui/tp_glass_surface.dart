import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../app/accessibility_scope.dart';

enum TpNavigationGlassRecipe { regular, platformView }

/// 「這一段子樹在媒體背景上」(照片或地圖圖磚)的唯一宣告點。
///
/// 由地圖 route / root shell 設定一次;浮動 header、root tab bar、bottom
/// accessory 各自讀它,不再用參數手傳 bool、也不用 tab 索引猜。缺席 = 非媒體。
///
/// 已知差異:root tab bar 掛在 shell 那一層,讀到的是 shell 依分支宣告的值;
/// root 地圖的空 / 載入 / 錯誤狀態把 header 蓋回非媒體,tab bar 仍是媒體樣式
/// (master 用索引判斷時就如此,依 ADR-0001 要真機目視才決定要不要改)。
class TpMediaBackdropScope extends InheritedWidget {
  const TpMediaBackdropScope({
    super.key,
    required this.onMedia,
    required super.child,
  });

  final bool onMedia;

  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<TpMediaBackdropScope>()
          ?.onMedia ??
      false;

  @override
  bool updateShouldNotify(TpMediaBackdropScope oldWidget) =>
      oldWidget.onMedia != onMedia;
}

/// 依 Increased Contrast 與 Reduce Transparency 的個別系統狀態，
/// 將任一 glass recipe 收斂為相同的不透明、無 blur accessibility fallback。
LiquidGlassSettings tpResolveGlassSettings(
  BuildContext context,
  LiquidGlassSettings settings, {
  Color? opaqueColor,
}) {
  if (!_usesOpaqueGlass(context)) return settings;

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
    fresnelStrength: 0,
    whitenStrength: 0,
    edgeAbsorption: 0,
    refractiveIndex: 1,
    saturation: 1,
    glowIntensity: 0,
    standardOpacityMultiplier: 1,
    shadowElevation: 0,
  );
}

/// 媒體背景的產品暗化值；搭配亮色圖磚與白色 bar 前景，不是 shader 校準。
/// 套件不會替 App 判斷原生圖磚亮度，因此透過公開色彩設定保留此語意。
const double tpMediaScrimOpacity = 0.35;

/// 日期選擇器在媒體上採 70% 中性底，搭配不透明 onSurface 前景。
/// 這是保留圖磚透出且維持文字對比的產品選擇，不改共用媒體暗化或光學參數。
Color tpMediaControlBackground(BuildContext context) => Theme.of(context)
    .colorScheme
    .surfaceContainerLow
    .withValues(alpha: _usesOpaqueGlass(context) ? 1 : 0.7);

/// 媒體上的獨立圖示按鈕保留較多背景，白色符號仍達 3:1。
/// 僅調整產品填色；光學與無障礙降級沿用共用媒體配方。
LiquidGlassSettings tpMediaIconGlassSettings(BuildContext context) {
  final scrim = Colors.black.withValues(alpha: 0.45);
  return tpResolveGlassSettings(
    context,
    tpNavigationGlassSettings(
      context,
      recipe: TpNavigationGlassRecipe.platformView,
    ).copyWith(glassColor: scrim, platformViewFallbackColor: scrim),
  );
}

/// 選單面板的模糊半徑；導覽玻璃預設 4–5 會讓後方標題字形穿透。
const double tpMenuGlassBlur = 24;

/// 文字多的選單面板走 HIG regular 類材質：白色煙燻填色加重模糊，
/// 讓後方卡片邊界與標題不再穿透（#319 真機量測，見 DESIGN §16.2）。
/// 無障礙降級改用高一階容器色，黑面板才不會落在黑頁面上失去邊界。
/// 媒體背景的 frosted 路徑同樣以 glassColor 上色；目前沒有選單開在媒體上。
LiquidGlassSettings tpMenuGlassSettings(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  final veil = Colors.white.withValues(
    alpha: scheme.brightness == Brightness.dark ? 0.18 : 0.72,
  );
  return tpResolveGlassSettings(
    context,
    tpNavigationGlassSettings(
      context,
    ).copyWith(glassColor: veil, blur: tpMenuGlassBlur),
    opaqueColor: scheme.surfaceContainerHigh,
  );
}

/// 玻璃上的字符與文字走單色標籤語意色，並依玻璃底下內容的亮度切換深淺。
///
/// **不能用 app 的明暗模式判斷。** `tripMapColorScheme()` 丟棄了 brightness
/// 參數、永遠回傳 light，地圖在深色模式下仍是亮圖磚；媒體背景一律先加暗化層
/// （見 [tpMediaScrimOpacity]），字符再用亮色，深淺兩種模式都可讀。
/// 不透明無障礙降級已遮住媒體，前景改回 system surface 的對應語意色。
Color tpBarForeground(BuildContext context, {required bool onMedia}) =>
    onMedia && !_usesOpaqueGlass(context)
    ? Colors.white
    : Theme.of(context).colorScheme.onSurface;

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
/// 一般模式的邊緣交給套件預設；只在提高對比時補邊界。
/// 舊 shader 的邊緣強度校準歷史保留於 ADR-0004。
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

/// 套件預設 1.0 的全周 Fresnel 亮環在深色真機量到 Apple 參考的 1.2～2 倍；
/// 減半預期降回參考量級、待真機確認，方向性高光仍由套件 lightIntensity 提供（#319）。
const double tpNavigationFresnelStrength = 0.5;

LiquidGlassSettings tpNavigationGlassSettings(
  BuildContext context, {
  TpNavigationGlassRecipe recipe = TpNavigationGlassRecipe.regular,
}) {
  final defaults =
      (GlassThemeData.of(
                context,
              ).settingsFor(context)?.applyTo(const LiquidGlassSettings()) ??
              const LiquidGlassSettings())
          .copyWith(fresnelStrength: tpNavigationFresnelStrength);
  final onMedia = recipe == TpNavigationGlassRecipe.platformView;
  final scrim = Colors.black.withValues(alpha: tpMediaScrimOpacity);
  return tpResolveGlassSettings(
    context,
    onMedia
        ? defaults.copyWith(glassColor: scrim, platformViewFallbackColor: scrim)
        : defaults,
  );
}

/// 無障礙狀態明確走無 shader 材質；1.x 的 blur: 0 仍保留光學效果。
GlassQuality? tpGlassQuality(BuildContext context) =>
    _usesOpaqueGlass(context) ? GlassQuality.minimal : null;

bool _usesOpaqueGlass(BuildContext context) =>
    MediaQuery.highContrastOf(context) ||
    AppAccessibilityScope.reduceTransparencyOf(context);

class TpGlassSurface extends StatelessWidget {
  const TpGlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(28)),
    this.padding = EdgeInsets.zero,
    this.tintColor,
    this.platformViewBackdrop = false,
    this.glassSettings,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? tintColor;
  final bool platformViewBackdrop;
  final LiquidGlassSettings? glassSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fallback = theme.brightness == Brightness.dark
        ? theme.colorScheme.surfaceContainerLow
        : theme.colorScheme.surface;
    final baseSettings =
        glassSettings ??
        tpNavigationGlassSettings(
          context,
          recipe: platformViewBackdrop
              ? TpNavigationGlassRecipe.platformView
              : TpNavigationGlassRecipe.regular,
        );
    final resolvedSettings = tpResolveGlassSettings(
      context,
      glassSettings != null || tintColor == null
          ? baseSettings
          : baseSettings.copyWith(glassColor: tintColor),
      opaqueColor: tintColor ?? fallback,
    );
    final border = tpGlassEdgeColor(context);
    final radius = borderRadius.topLeft.x;

    return TpGlassEdge(
      borderRadius: radius,
      child: GlassContainer(
        padding: padding,
        useOwnLayer: true,
        quality: tpGlassQuality(context),
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
