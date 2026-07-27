import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../app/accessibility_scope.dart';
import '../theme/tokens.dart';
import 'tp_app_bar.dart';
import 'tp_glass_surface.dart';

@immutable
class TpRootHeaderConfig {
  const TpRootHeaderConfig({
    required this.title,
    this.leading,
    this.actions = const <Widget>[],
    this.platformViewBackdrop = false,
  });

  final Widget title;
  final Widget? leading;
  final List<Widget> actions;
  final bool platformViewBackdrop;
}

abstract final class TpRootGeometry {
  static const double topGap = 8;
  static const double horizontalInset = 16;
  static const double headerHeight = 64;
  static const double headerContentInset = 16;
  static const double actionGap = 8;

  static double headerTop(BuildContext context) =>
      MediaQuery.paddingOf(context).top + topGap;

  static double headerBottom(BuildContext context) =>
      headerTop(context) + headerHeight;

  /// 帶狀遮蔽在膠囊下緣之外多留的羽化長度。
  ///
  /// 刻意等於 header 下方既有的 8pt 排版溝槽：日期選擇軌這類 chrome 就坐在
  /// `headerBottom + TpSpacing.s2`，帶剛好收在它的上緣 —— chrome 不會被遮蔽
  /// 層糊掉，內容（起點在 `initialContentTop`）也還在帶外，靜止時是清晰的。
  static const double bandFeather = TpSpacing.s2;

  /// 帶狀遮蔽的下緣。從畫面最頂（含狀態列）一路蓋到這裡。
  static double bandBottom(BuildContext context) =>
      headerBottom(context) + bandFeather;

  static double initialContentTop(BuildContext context) =>
      headerBottom(context) + TpSpacing.s3;
}

class TpRootScaffold extends StatelessWidget {
  const TpRootScaffold({super.key, required this.header, required this.body});

  final TpRootHeaderConfig header;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(child: body),
          // 遮蔽層夾在內容與膠囊之間：它只取樣底下的內容，膠囊畫在它之上，
          // 所以膠囊自己不會被糊到。六個 root 畫面共用這一條，不是 opt-in。
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: TpRootGeometry.bandBottom(context),
            child: _TpRootHeaderBand(
              key: const ValueKey('tp-root-header-band'),
              onMedia: header.platformViewBackdrop,
            ),
          ),
          // 底部同一套。root tab bar 自己是玻璃，但玻璃只糊它蓋住的那一塊，
          // 而且 shader 的模糊在模擬器上不渲染 —— 內容照樣清晰地穿過 tab bar
          // 與「行程」「地圖」的文字疊在一起（#167 之後的真機與模擬器皆可見）。
          // 帶狀遮蔽是內容側的處理，與 tab bar 自己的材質不互相取代。
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: TpRootTabGeometry.clearance(context) + TpSpacing.s4,
            child: _TpRootTabBand(
              key: const ValueKey('tp-root-tab-band'),
              onMedia: header.platformViewBackdrop,
            ),
          ),
          Positioned(
            top: TpRootGeometry.headerTop(context),
            left: TpRootGeometry.horizontalInset,
            right: TpRootGeometry.horizontalInset,
            child: TpRootGlassHeader(config: header),
          ),
        ],
      ),
    );
  }
}

class TpRootGlassHeader extends StatelessWidget {
  const TpRootGlassHeader({super.key, required this.config});

  final TpRootHeaderConfig config;

  @override
  Widget build(BuildContext context) {
    assert(
      config.actions.length <= 2 &&
          (config.actions.length <= 1 ||
              tpActionsIncludeMoreMenu(config.actions)),
      'Root headers support one direct action; extra actions use More.',
    );
    // **每個控制項各自成膠囊，不是一整片玻璃板。**
    //
    // iOS 26 的頂部只有按鈕群是玻璃，標題與背景之間沒有玻璃板 —— WWDC25
    // 明講玻璃不取樣玻璃。原本這裡是一整片 64pt 的玻璃板，裡面又塞了標題與
    // 數顆玻璃圓鈕（動作與頭像本來就各自是 `TpToolbarGlassButton`），
    // 玻璃疊玻璃。#111 把這一條列為「本 app 與 iOS 26 觀感差距最大的結構
    // 決定」並暫時擱置，ADR-0004 決定處理。
    //
    // 拆開後標題自己包一顆膠囊（對照 iOS 26「訊息」app 的
    // `roybee903@icl… ›`），動作與頭像維持各自的圓鈕，中間的空隙直接透出
    // 底下的內容。
    return SizedBox(
      key: const ValueKey('tp-root-glass-header'),
      height: TpRootGeometry.headerHeight,
      child: TpBarForeground(
        onMedia: config.platformViewBackdrop,
        child: Row(
          children: [
            // 返回鍵與標題是**同一組**,包在同一顆膠囊裡 —— 對照 iOS 26
            // 「訊息」app 的 `‹ 121`:返回與它所屬的內容是一組,不是兩顆
            // 各自浮著。
            //
            // `Expanded` + `Align`:膠囊保持自然寬度靠左,剩下的空間交給
            // 右側動作。不能用 `Flexible` 搭 `Spacer` —— 兩者都有 flex,會
            // 平分剩餘空間,動作就靠不到右邊。
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: KeyedSubtree(
                  key: const ValueKey('tp-glass-surface'),
                  child: TpGlassSurface(
                    platformViewBackdrop: config.platformViewBackdrop,
                    glassSettings: tpNavigationGlassSettings(
                      context,
                      recipe: config.platformViewBackdrop
                          ? TpNavigationGlassRecipe.platformView
                          : TpNavigationGlassRecipe.regular,
                    ),
                    borderRadius: const BorderRadius.all(
                      Radius.circular(TpSpacing.tapMin / 2),
                    ),
                    padding: EdgeInsets.only(
                      // 有返回鍵時左側交給按鈕自己的觸控區,不再另外內縮。
                      left: config.leading == null
                          ? TpRootGeometry.headerContentInset
                          : 0,
                      right: TpRootGeometry.headerContentInset,
                    ),
                    // 整列等高:三顆圓鈕都是 44pt,標題先前只給內距、讓
                    // `headlineSmall` 自己撐,實測撐到 63.7pt。
                    child: SizedBox(
                      height: TpSpacing.tapMin,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (config.leading != null) ...[
                            SizedBox.square(
                              key: const ValueKey('tp-root-header-leading'),
                              dimension: TpSpacing.tapMin,
                              child: config.leading,
                            ),
                            const SizedBox(width: TpSpacing.s1),
                          ],
                          Flexible(
                            child: TpHeaderTitle(
                              key: const ValueKey('tp-root-header-title'),
                              child: config.title,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: TpSpacing.s2),
            TpHeaderActionRow(
              children: [
                for (var index = 0; index < config.actions.length; index++)
                  if (config.actions[index] is TpToolbarTextButton)
                    KeyedSubtree(
                      key: ValueKey('tp-root-header-action-$index'),
                      child: config.actions[index],
                    )
                  else
                    SizedBox(
                      key: ValueKey('tp-root-header-action-$index'),
                      // 群組容器佔一個 slot，但寬度是它包住的按鈕數量。
                      width: TpToolbarSlots.slotWidth(
                        context,
                        config.actions[index],
                      ),
                      height: TpSpacing.tapMin,
                      child: config.actions[index],
                    ),
                const TpAccountAvatarButton(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 已選取的 root tab 再次被點選時，通知目前作用中的 root branch。
class TpRootReselectScope extends InheritedNotifier<ValueNotifier<int>> {
  const TpRootReselectScope({
    super.key,
    required ValueNotifier<int> notifier,
    required super.child,
  }) : super(notifier: notifier);

  static ValueNotifier<int>? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<TpRootReselectScope>()
      ?.notifier;
}

class TpRootScrollView extends StatefulWidget {
  const TpRootScrollView({
    super.key,
    required this.slivers,
    this.onRefresh,
    this.controller,
    this.physics = const AlwaysScrollableScrollPhysics(),
  });

  final List<Widget> slivers;
  final Future<void> Function()? onRefresh;
  final ScrollController? controller;
  final ScrollPhysics physics;

  @override
  State<TpRootScrollView> createState() => _TpRootScrollViewState();
}

class _TpRootScrollViewState extends State<TpRootScrollView> {
  ScrollController? _fallbackController;
  ValueNotifier<int>? _reselects;
  var _active = true;

  ScrollController get _controller =>
      widget.controller ?? (_fallbackController ??= ScrollController());

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _active = TickerMode.valuesOf(context).enabled;
    final next = TpRootReselectScope.maybeOf(context);
    if (next == _reselects) return;
    _reselects?.removeListener(_scrollToTop);
    _reselects = next?..addListener(_scrollToTop);
  }

  @override
  void didUpdateWidget(covariant TpRootScrollView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == null && widget.controller != null) {
      _fallbackController?.dispose();
      _fallbackController = null;
    }
  }

  void _scrollToTop() {
    if (!_active || !_controller.hasClients) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpTo(0);
      return;
    }
    unawaited(
      _controller.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _reselects?.removeListener(_scrollToTop);
    _fallbackController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scrollView = CustomScrollView(
      key: const ValueKey('tp-root-scroll-view'),
      controller: _controller,
      physics: widget.physics,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(height: TpRootGeometry.initialContentTop(context)),
        ),
        ...widget.slivers,
        SliverToBoxAdapter(
          child: SizedBox(
            key: const ValueKey('root-scroll-bottom-inset'),
            height: TpRootTabGeometry.clearance(context) + TpSpacing.s4,
          ),
        ),
      ],
    );
    return widget.onRefresh == null
        ? scrollView
        : RefreshIndicator.adaptive(
            onRefresh: widget.onRefresh!,
            child: scrollView,
          );
  }
}

/// header 佔的那一整條帶，對**底下的內容**做漸進模糊加淡出。
///
/// 取代原本的 `_TpRootSoftEdge`：那條只有 16pt、掛在 header **下方**、而且只有
/// 顏色漸層沒有模糊，所以 #162 把 header 拆成獨立膠囊之後，內容直接從膠囊之間
/// 的縫隙穿上來 —— 日期被標題膠囊蓋掉一半、返回鍵旁漏出一個孤零零的「0」。
/// 依據 iOS 26「電話」app：控制項上方與後方的內容是漸進模糊加淡出，不是硬切。
/// 底部 root tab 帶的遮蔽，與 [_TpRootHeaderBand] 同一組參數，方向相反。
///
/// 為什麼底部也要一條:root tab bar 自己是玻璃，但玻璃只糊它**蓋住的那一塊**，
/// 而且 shader 的模糊在模擬器上不渲染。實際看到的是內容清晰地穿過 tab bar、
/// 與「行程」「地圖」的文字疊在一起。帶狀遮蔽是內容側的處理，兩者不互相取代。
class _TpRootTabBand extends StatelessWidget {
  const _TpRootTabBand({super.key, required this.onMedia});

  final bool onMedia;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final opaqueFallback =
        MediaQuery.highContrastOf(context) ||
        AppAccessibilityScope.reduceTransparencyOf(context);
    final veil = onMedia && !opaqueFallback
        ? Colors.black
        : theme.scaffoldBackgroundColor;
    final peak = opaqueFallback
        ? 1.0
        : (onMedia ? tpMediaScrimOpacity : _TpRootHeaderBand.veilPeakAlpha);
    final edge = opaqueFallback ? 1.0 : peak * _TpRootHeaderBand.veilEdgeRatio;

    return IgnorePointer(
      child: Stack(
        children: [
          if (!opaqueFallback)
            for (var index = 0; index < _TpRootHeaderBand.blurLayers; index++)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                // 逐層縮短:最底層最厚，越往上越薄，疊出漸進的模糊。
                height:
                    (index + 1) /
                    _TpRootHeaderBand.blurLayers *
                    _bandHeight(context),
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(
                      sigmaX: _TpRootHeaderBand.blurSigmaPerLayer,
                      sigmaY: _TpRootHeaderBand.blurSigmaPerLayer,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
          Positioned.fill(
            child: opaqueFallback
                ? ColoredBox(color: veil)
                : DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          veil.withValues(alpha: peak),
                          veil.withValues(alpha: edge),
                          veil.withValues(alpha: 0),
                        ],
                        stops: const [0, 0.55, 1],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  static double _bandHeight(BuildContext context) =>
      TpRootTabGeometry.clearance(context) + TpSpacing.s4;
}

class _TpRootHeaderBand extends StatelessWidget {
  const _TpRootHeaderBand({super.key, required this.onMedia});

  /// 底下是 platform view（地圖）時走清透 scrim，與玻璃膠囊同一套暗化語彙。
  final bool onMedia;

  /// 漸進模糊靠**疊層**做，因為 Flutter 沒有「可遮罩的 backdrop filter」。
  ///
  /// `BackdropFilter` 取樣的是它底下已經合成的畫面；用 `ShaderMask` 或
  /// `Opacity` 包住它會另開 save layer，backdrop 變成空的，模糊就消失。所以
  /// 這裡疊一組都從帶頂出發、往下逐層縮短的 filter：越靠近帶頂被越多層蓋到，
  /// 模糊越重，到帶底只剩一層，形成連續的斜坡而不是硬邊。
  ///
  /// 這些層彼此重疊，**不能**共用 `BackdropGroup`／`BackdropKey` —— 框架文件
  /// 明講重疊的 backdrop filter 共用 key 時，重疊區會變成只套到其中一層。
  static const int blurLayers = 6;

  /// 單層 sigma。高斯疊加是平方和開根號，帶頂的等效 sigma ≈ 5 × √6 ≈ 12。
  static const double blurSigmaPerLayer = 5;

  /// 帶頂的淡出強度；膠囊下緣收到 [_veilEdgeRatio] 倍，再到帶底歸零。
  static const double veilPeakAlpha = 0.62;
  static const double veilEdgeRatio = 0.78;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 與玻璃同一組無障礙開關：這兩個狀態下不做模糊，改成不透明帶，
    // 內容一格都不透出來，對比與可讀性最高。
    final opaqueFallback =
        MediaQuery.highContrastOf(context) ||
        AppAccessibilityScope.reduceTransparencyOf(context);
    final headerBottom = TpRootGeometry.headerBottom(context);
    final feather = TpRootGeometry.bandFeather;
    final veil = onMedia && !opaqueFallback
        ? Colors.black
        : theme.scaffoldBackgroundColor;
    final peak = opaqueFallback
        ? 1.0
        : (onMedia ? tpMediaScrimOpacity : veilPeakAlpha);
    final edge = opaqueFallback ? 1.0 : peak * veilEdgeRatio;

    return IgnorePointer(
      child: Stack(
        children: [
          if (!opaqueFallback)
            for (var index = 0; index < blurLayers; index++)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height:
                    headerBottom + feather * (blurLayers - index) / blurLayers,
                child: ClipRect(
                  // tileMode 用預設的 clamp：畫面邊界外沿用邊緣像素，跟系統
                  // bar 的模糊一致。decal 會在畫面最頂端淡成透明，露出一條縫。
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(
                      sigmaX: blurSigmaPerLayer,
                      sigmaY: blurSigmaPerLayer,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: headerBottom,
            // 無障礙 fallback 用純色而不是同色漸層：漸層著色器會 dither，
            // 帶內就量得到 ±1 的雜訊，「內容一格都不透出」便驗不乾淨。
            child: opaqueFallback
                ? ColoredBox(color: veil)
                : DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          veil.withValues(alpha: peak),
                          veil.withValues(alpha: edge),
                        ],
                      ),
                    ),
                  ),
          ),
          Positioned(
            top: headerBottom,
            left: 0,
            right: 0,
            height: feather,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    veil.withValues(alpha: edge),
                    veil.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
