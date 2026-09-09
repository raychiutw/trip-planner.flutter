import 'dart:async';

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

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
  });

  final Widget title;
  final Widget? leading;
  final List<Widget> actions;
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
    final onMedia = TpMediaBackdropScope.of(context);
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
            child: _TpRootBand(
              key: const ValueKey('tp-root-header-band'),
              edge: _TpBandEdge.top,
              onMedia: onMedia,
              solidExtent: TpRootGeometry.headerBottom(context),
              featherExtent: TpRootGeometry.bandFeather,
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
            child: _TpRootBand(
              key: const ValueKey('tp-root-tab-band'),
              edge: _TpBandEdge.bottom,
              onMedia: onMedia,
              solidExtent: TpRootTabGeometry.clearance(context) + TpSpacing.s4,
              featherExtent: 0,
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
    final onMedia = TpMediaBackdropScope.of(context);
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
        onMedia: onMedia,
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
                    platformViewBackdrop: onMedia,
                    glassSettings: tpNavigationGlassSettings(
                      context,
                      recipe: onMedia
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
                  KeyedSubtree(
                    key: ValueKey('tp-root-header-action-$index'),
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

enum _TpBandEdge { top, bottom }

/// 套件接手上下 edge 的漸進模糊與淡出，App 保留內容層級與無障礙整合。
class _TpRootBand extends StatelessWidget {
  const _TpRootBand({
    super.key,
    required this.edge,
    required this.onMedia,
    required this.solidExtent,
    required this.featherExtent,
  });

  final _TpBandEdge edge;
  final bool onMedia;
  final double solidExtent;
  final double featherExtent;

  bool get _top => edge == _TpBandEdge.top;

  @override
  Widget build(BuildContext context) {
    final opaqueFallback =
        MediaQuery.highContrastOf(context) ||
        AppAccessibilityScope.reduceTransparencyOf(context);
    final background = Theme.of(context).scaffoldBackgroundColor;
    final height = solidExtent + featherExtent;
    if (opaqueFallback) {
      // 套件 blur 與 soft effect 不會自行回應 App 的降低透明度。
      // 頂部保留狀態列至控制項的不透明區，底部整條遮住 tab 下的內容。
      return IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: _top ? solidExtent : height,
              child: ColoredBox(color: background),
            ),
            if (_top && featherExtent > 0)
              Positioned(
                top: solidExtent,
                left: 0,
                right: 0,
                height: featherExtent,
                child: GlassScrollEdgeEffect(
                  fadeBottom: false,
                  topFadeHeight: featherExtent,
                  fadeColor: background,
                  child: const SizedBox.expand(),
                ),
              ),
          ],
        ),
      );
    }
    return IgnorePointer(
      child: GlassScrollEdgeEffect(
        fadeTop: _top,
        fadeBottom: !_top,
        topFadeHeight: height,
        bottomFadeHeight: height,
        fadeColor: onMedia
            ? Colors.black.withValues(alpha: tpMediaScrimOpacity)
            : background,
        // ProgressiveBlur 本身裁切 route 邊界；放在淡出之下、控制項之下，
        // 不讓標題和動作參與 backdrop 取樣。材質參數採套件預設。
        child: ProgressiveBlur(
          direction: _top
              ? ProgressiveBlurDirection.topToBottom
              : ProgressiveBlurDirection.bottomToTop,
        ),
      ),
    );
  }
}
