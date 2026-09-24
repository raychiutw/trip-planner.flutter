import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../app/accessibility_scope.dart';
import '../theme/tokens.dart';

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

/// 深色選單沿用 root tab bar 的底色，避免額外白膜讓面板泛灰；
/// 文字多的面板保留加重模糊，淺色維持白色煙燻填色（見 DESIGN §16.2）。
/// 無障礙降級改用高一階容器色，黑面板才不會落在黑頁面上失去邊界。
/// 媒體背景的 frosted 路徑同樣以 glassColor 上色；目前沒有選單開在媒體上。
LiquidGlassSettings tpMenuGlassSettings(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  final navigation = tpNavigationGlassSettings(context);
  final veil = scheme.brightness == Brightness.dark
      ? navigation.glassColor
      : Colors.white.withValues(alpha: 0.72);
  return tpResolveGlassSettings(
    context,
    navigation.copyWith(glassColor: veil, blur: tpMenuGlassBlur),
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
/// 減半後 premium 的環幾乎沒變，主要來源是下面的 lightIntensity（#319）。
const double tpNavigationFresnelStrength = 0.5;

/// premium 的邊緣高光 ∝ lightIntensity 且反方向也亮（寫死 0.8）；theme 預設的
/// 0.35 倍讓最強一側落到 Apple 參考頂緣量級，standard 路徑幾乎無感（DESIGN §16.2）。
const double tpNavigationLightIntensityScale = 0.35;

/// standard 路徑的環由套件常數主導，edgeAbsorption 是其末端唯一公開的 rim 壓低項；
/// 只在深色套用，premium 在淺色白底會刻出暗框（DESIGN §16.2）。
const double tpNavigationDarkEdgeAbsorption = 0.3;

LiquidGlassSettings tpNavigationGlassSettings(
  BuildContext context, {
  TpNavigationGlassRecipe recipe = TpNavigationGlassRecipe.regular,
}) {
  final packageDefaults =
      GlassThemeData.of(
        context,
      ).settingsFor(context)?.applyTo(const LiquidGlassSettings()) ??
      const LiquidGlassSettings();
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final defaults = packageDefaults.copyWith(
    fresnelStrength: tpNavigationFresnelStrength,
    lightIntensity:
        packageDefaults.lightIntensity * tpNavigationLightIntensityScale,
    edgeAbsorption: isDark
        ? tpNavigationDarkEdgeAbsorption
        : packageDefaults.edgeAbsorption,
  );
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

enum _TpNavigationGlassRole { bar, mediaIcon, dateSelector }

/// 所有導覽角色共用的配對決策；光學值仍由既有設定函式提供。
class _TpNavigationGlassAppearance {
  _TpNavigationGlassAppearance(
    BuildContext context, {
    _TpNavigationGlassRole role = _TpNavigationGlassRole.bar,
  }) : onMedia = TpMediaBackdropScope.of(context),
       quality = tpGlassQuality(context),
       edgeColor = tpGlassEdgeColor(context) {
    final scheme = Theme.of(context).colorScheme;
    final dateSelector = role == _TpNavigationGlassRole.dateSelector;
    settings = role == _TpNavigationGlassRole.mediaIcon && onMedia
        ? tpMediaIconGlassSettings(context)
        : tpNavigationGlassSettings(
            context,
            // 日期軌道保留 regular 光學；媒體可讀性由中性底與前景成套提供。
            recipe: onMedia && !dateSelector
                ? TpNavigationGlassRecipe.platformView
                : TpNavigationGlassRecipe.regular,
          );
    foreground = dateSelector
        ? onMedia
              ? scheme.onSurface.withValues(alpha: 1)
              : scheme.onSurfaceVariant
        : tpBarForeground(context, onMedia: onMedia);
    selectedForeground = scheme.primary;
    indicatorColor = scheme.surfaceContainerHigh;
    backgroundColor = dateSelector
        ? onMedia
              ? tpMediaControlBackground(context)
              : _usesOpaqueGlass(context)
              ? scheme.surfaceContainerLow
              : null
        : null;
  }

  final bool onMedia;
  final GlassQuality? quality;
  final Color edgeColor;
  late final LiquidGlassSettings settings;
  late final Color foreground;
  late final Color selectedForeground;
  late final Color indicatorColor;
  late final Color? backgroundColor;

  Widget wrapForeground(Widget child, {bool selected = false}) =>
      IconTheme.merge(
        data: IconThemeData(color: selected ? selectedForeground : foreground),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: selected ? selectedForeground : foreground),
          child: child,
        ),
      );
}

/// root tab 的材質、選取底與前景成套組裝；套件保留上下兩種配置與指標互動。
/// 呼叫端只提供分頁內容、選取與操作，鍵盤及讀屏 adapter 仍由 root tab 持有。
class TpNavigationGlassTabBar extends StatelessWidget {
  const TpNavigationGlassTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
    this.inline = false,
  });

  final List<GlassTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appearance = _TpNavigationGlassAppearance(context);
    final selectedLabelStyle = theme.textTheme.labelSmall?.copyWith(
      color: appearance.selectedForeground,
      fontWeight: FontWeight.w700,
      fontSize: TpRootTabGeometry.labelFontSize,
      height: TpRootTabGeometry.labelLineHeight,
    );
    final unselectedLabelStyle = theme.textTheme.labelSmall?.copyWith(
      color: appearance.foreground,
      fontWeight: FontWeight.w500,
      fontSize: TpRootTabGeometry.labelFontSize,
      height: TpRootTabGeometry.labelLineHeight,
    );
    final indicatorSettings = tpResolveGlassSettings(
      context,
      appearance.settings,
      opaqueColor: appearance.indicatorColor,
    );
    return inline
        ? GlassTabBar.inline(
            tabs: tabs,
            selectedIndex: selectedIndex,
            onTabSelected: onSelected,
            barHeight: TpRootTabGeometry.barHeight(context),
            barBorderRadius: 32,
            iconSize: TpRootTabGeometry.iconSize,
            iconLabelSpacing: TpRootTabGeometry.iconLabelSpacing,
            horizontalPadding: 0,
            verticalPadding: 0,
            settings: appearance.settings,
            selectedIconColor: appearance.selectedForeground,
            selectedLabelColor: appearance.selectedForeground,
            unselectedIconColor: appearance.foreground,
            unselectedLabelColor: appearance.foreground,
            selectedLabelStyle: selectedLabelStyle,
            unselectedLabelStyle: unselectedLabelStyle,
            indicatorColor: appearance.indicatorColor,
            indicatorSettings: indicatorSettings,
            quality: appearance.quality,
            platformViewBackdrop: appearance.onMedia,
          )
        : GlassTabBar.bottom(
            iconSize: TpRootTabGeometry.iconSize,
            iconLabelSpacing: TpRootTabGeometry.iconLabelSpacing,
            barHeight: TpRootTabGeometry.barHeight(context),
            tabs: tabs,
            selectedIndex: selectedIndex,
            onTabSelected: onSelected,
            horizontalPadding: 0,
            verticalPadding: 0,
            settings: appearance.settings,
            selectedIconColor: appearance.selectedForeground,
            selectedLabelColor: appearance.selectedForeground,
            unselectedIconColor: appearance.foreground,
            unselectedLabelColor: appearance.foreground,
            selectedLabelStyle: selectedLabelStyle,
            unselectedLabelStyle: unselectedLabelStyle,
            indicatorColor: appearance.indicatorColor,
            indicatorSettings: indicatorSettings,
            quality: appearance.quality,
            platformViewBackdrop: appearance.onMedia,
          );
  }
}

/// 日期選擇器的中性軌道、選取底與前景成套組裝，不外包第二層玻璃。
/// 選項內容與再次選取 adapter 由呼叫端提供；套件負責欄寬、捲動與選取。
class TpNavigationGlassSelector extends StatelessWidget {
  const TpNavigationGlassSelector({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onSelected,
    required this.height,
    required this.scrollController,
  });

  final List<GlassSegment> segments;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final double height;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final appearance = _TpNavigationGlassAppearance(
      context,
      role: _TpNavigationGlassRole.dateSelector,
    );
    return TpGlassEdge(
      borderRadius: height / 2,
      child: GlassSegmentedControl.scrollable(
        segments: [
          for (final (index, segment) in segments.indexed)
            GlassSegment(
              id: segment.id,
              label: segment.label,
              semanticLabel: segment.semanticLabel,
              tooltip: segment.tooltip,
              enabled: segment.enabled,
              icon: segment.icon == null
                  ? null
                  : appearance.wrapForeground(
                      segment.icon!,
                      selected: index == selectedIndex,
                    ),
            ),
        ],
        selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
        onSegmentSelected: onSelected,
        labelPadding: EdgeInsets.zero,
        height: height,
        scrollController: scrollController,
        selectionAlignment: SegmentSelectionAlignment.center,
        dragBehavior: SegmentDragBehavior.scroll,
        indicatorColor: appearance.indicatorColor,
        backgroundColor: appearance.backgroundColor,
        settings: appearance.settings,
        quality: appearance.quality,
        useOwnLayer: true,
      ),
    );
  }
}

/// 浮動 header 標題與返回共用的玻璃；呼叫端只保留內容與自然寬度留白。
class TpNavigationGlassTitleSurface extends StatelessWidget {
  const TpNavigationGlassTitleSurface({
    super.key,
    required this.padding,
    required this.child,
  });

  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final appearance = _TpNavigationGlassAppearance(context);
    return TpGlassSurface(
      platformViewBackdrop: appearance.onMedia,
      glassSettings: appearance.settings,
      borderRadius: const BorderRadius.all(
        Radius.circular(TpSpacing.tapMin / 2),
      ),
      padding: padding,
      child: appearance.wrapForeground(child),
    );
  }
}

/// 獨立導覽按鈕的 production 角色；兩者保留既有的圓角差異。
enum TpNavigationGlassButtonRole { barButton, floatingControl }

/// 將獨立圖示按鈕的材質、媒體前景與無障礙降級成套組裝。
///
/// 呼叫端只提供角色、內容與操作。媒體情境沿用 [TpMediaBackdropScope]；
/// 忙碌時保留進度與不透明底，不讓套件的 disabled 淡化整片表面。
class TpNavigationGlassButton extends StatelessWidget {
  const TpNavigationGlassButton({
    super.key,
    required this.role,
    required this.tooltip,
    required this.onPressed,
    required this.child,
    this.busy = false,
  });

  final TpNavigationGlassButtonRole role;
  final String tooltip;
  final VoidCallback? onPressed;
  final Widget child;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final appearance = _TpNavigationGlassAppearance(
      context,
      role: _TpNavigationGlassRole.mediaIcon,
    );
    final radius = switch (role) {
      TpNavigationGlassButtonRole.barButton => 22.0,
      TpNavigationGlassButtonRole.floatingControl => TpRadius.sm,
    };

    final Widget control;
    if (busy) {
      control = Semantics(
        label: tooltip,
        button: true,
        enabled: false,
        child: TpGlassSurface(
          borderRadius: BorderRadius.all(Radius.circular(radius)),
          platformViewBackdrop: appearance.onMedia,
          glassSettings: appearance.settings,
          tintColor: Theme.of(context).colorScheme.surface,
          child: SizedBox.square(
            dimension: TpSpacing.tapMin,
            child: Center(
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: appearance.foreground,
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      return TpToolbarGlassButton._resolved(
        tooltip: tooltip,
        onPressed: onPressed,
        appearance: appearance,
        borderRadius: radius,
        child: child,
      );
    }

    return SizedBox.square(
      dimension: TpSpacing.tapMin,
      child: Tooltip(
        message: tooltip,
        excludeFromSemantics: true,
        child: control,
      ),
    );
  }
}

/// 固定 bar 與浮動 header 共用的標題字階、省略及語意前景。
class TpHeaderTitle extends StatelessWidget {
  const TpHeaderTitle({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DefaultTextStyle.merge(
    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
      color: tpBarForeground(
        context,
        onMedia: TpMediaBackdropScope.of(context),
      ),
    ),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    child: child,
  );
}

/// 標記「目前在群組容器裡」，讓子按鈕不要再各自畫一片玻璃。
class _TpToolbarGroupScope extends InheritedWidget {
  const _TpToolbarGroupScope({required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_TpToolbarGroupScope>() !=
      null;

  @override
  bool updateShouldNotify(_TpToolbarGroupScope oldWidget) => false;
}

/// 一列上相關的動作收在同一片玻璃裡，彼此只有間距。
///
/// **不畫分隔線** —— HIG Toolbars 只提間距（SwiftUI 也只有 `ToolbarSpacer`）；
/// 分隔線是選單語彙，選單內部的分組分隔線是另一回事，仍然正確。
/// 不相關的動作各自成一顆容器，一列最多約三組。
class TpToolbarActionGroup extends StatelessWidget {
  const TpToolbarActionGroup({super.key, required this.children})
    : assert(children.length >= 2, '單一動作不需要群組容器');

  final List<Widget> children;

  /// 群組內按鈕之間的間距，比群組與群組之間更窄。
  static const innerGap = TpSpacing.s1;

  @override
  Widget build(BuildContext context) {
    final appearance = _TpNavigationGlassAppearance(context);
    return appearance.wrapForeground(
      TpGlassEdge(
        borderRadius: 22,
        child: _TpToolbarGroupScope(
          child: GlassButtonGroup(
            key: const ValueKey('tp-toolbar-action-group'),
            showDividers: false,
            useOwnLayer: true,
            borderRadius: 22,
            settings: appearance.settings,
            quality: appearance.quality,
            platformViewBackdrop: appearance.onMedia,
            children: [
              for (var index = 0; index < children.length; index++) ...[
                if (index > 0) const SizedBox(width: innerGap),
                children[index],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Header 共用的 44pt 按鈕；材質與前景沿用媒體 scope，群組內不再畫玻璃。
/// 呼叫端只提供內容與操作，獨立圖示的角色配方在 module 內成套傳遞。
class TpToolbarGlassButton extends StatelessWidget {
  const TpToolbarGlassButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.child,
  }) : _appearance = null,
       _borderRadius = 22;

  const TpToolbarGlassButton._resolved({
    required this.tooltip,
    required this.onPressed,
    required this.child,
    required _TpNavigationGlassAppearance appearance,
    required double borderRadius,
  }) : _appearance = appearance,
       _borderRadius = borderRadius;

  final String tooltip;
  final VoidCallback? onPressed;
  final Widget child;
  final _TpNavigationGlassAppearance? _appearance;
  final double _borderRadius;

  @override
  Widget build(BuildContext context) {
    final grouped = _TpToolbarGroupScope.of(context);
    final appearance = _appearance ?? _TpNavigationGlassAppearance(context);
    return SizedBox.square(
      dimension: TpSpacing.tapMin,
      child: Tooltip(
        message: tooltip,
        excludeFromSemantics: true,
        child: GlassButton.custom(
          key: const ValueKey('tp-toolbar-glass-button'),
          label: tooltip,
          width: TpSpacing.tapMin,
          height: TpSpacing.tapMin,
          enabled: onPressed != null,
          onTap: onPressed ?? () {},
          // 群組提供材質，個別按鈕仍由套件處理 pointer、鍵盤與語意。
          style: grouped
              ? GlassButtonStyle.transparent
              : GlassButtonStyle.filled,
          useOwnLayer: !grouped,
          quality: appearance.quality,
          platformViewBackdrop: appearance.onMedia,
          shape: LiquidRoundedSuperellipse(
            borderRadius: _borderRadius,
            side: BorderSide(color: appearance.edgeColor),
          ),
          settings: appearance.settings,
          child: appearance.wrapForeground(child),
        ),
      ),
    );
  }
}

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
