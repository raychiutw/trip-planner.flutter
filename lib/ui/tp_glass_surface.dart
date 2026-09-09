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

LiquidGlassSettings tpNavigationGlassSettings(
  BuildContext context, {
  TpNavigationGlassRecipe recipe = TpNavigationGlassRecipe.regular,
}) {
  final defaults =
      GlassThemeData.of(
        context,
      ).settingsFor(context)?.applyTo(const LiquidGlassSettings()) ??
      const LiquidGlassSettings();
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
