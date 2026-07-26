import 'dart:async';

import 'package:flutter/material.dart';

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

  static double initialContentTop(BuildContext context) =>
      headerBottom(context) + TpSpacing.s3;
}

class TpRootScaffold extends StatelessWidget {
  const TpRootScaffold({
    super.key,
    required this.header,
    required this.body,
    this.showSoftEdge = false,
  });

  final TpRootHeaderConfig header;
  final Widget body;
  final bool showSoftEdge;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(child: body),
          if (showSoftEdge)
            Positioned(
              key: const ValueKey('tp-root-soft-edge'),
              top: TpRootGeometry.headerBottom(context),
              left: 0,
              right: 0,
              child: const _TpRootSoftEdge(),
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
            if (config.leading != null) ...[
              SizedBox.square(
                key: const ValueKey('tp-root-header-leading'),
                dimension: TpSpacing.tapMin,
                child: config.leading,
              ),
              const SizedBox(width: TpSpacing.s2),
            ],
            // `Expanded` + `Align`：膠囊保持自然寬度靠左，剩下的空間交給
            // 右側動作。不能用 `Flexible` 搭 `Spacer` —— 兩者都有 flex，會
            // 平分剩餘空間，動作就靠不到右邊。
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
                    borderRadius: const BorderRadius.all(Radius.circular(32)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: TpRootGeometry.headerContentInset,
                      vertical: TpSpacing.s2,
                    ),
                    child: TpHeaderTitle(
                      key: const ValueKey('tp-root-header-title'),
                      child: config.title,
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

class _TpRootSoftEdge extends StatelessWidget {
  const _TpRootSoftEdge();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).scaffoldBackgroundColor;
    return IgnorePointer(
      child: SizedBox(
        height: TpSpacing.s4,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: 0.38),
                color.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
