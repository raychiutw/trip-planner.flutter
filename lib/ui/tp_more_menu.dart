/// 選單:由 bar button 或卡片「⋯」觸發、從觸發點展開的下拉動作清單
/// (對應 iOS pull-down menu)。與固定 bar 是兩個語彙,所以獨立成檔。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../theme/tokens.dart';
import 'tp_action_item.dart';
import 'tp_app_bar.dart';
import 'tp_glass_surface.dart';

/// 卡片長按與更多按鈕共用的選單入口。套件負責開關，App 只去重業務動作。
class TpMoreMenuController {
  final _glassController = GlassMenuController();
  bool _selectionDispatched = false;
  VoidCallback? _openHost;

  bool get isOpen => _glassController.isOpen;

  void open() {
    _selectionDispatched = false;
    _openHost?.call();
  }

  void close() => _glassController.close();

  void _select(VoidCallback action) {
    if (_selectionDispatched) return;
    _selectionDispatched = true;
    close();
    action();
  }
}

class TpMoreMenuButton<T> extends StatefulWidget {
  const TpMoreMenuButton({
    super.key,
    required this.items,
    required this.onSelected,
    this.enabled = true,
    this.tooltip = '更多',
    this.triggerChild,
    this.triggerBuilder,
    this.controller,
  });

  final List<TpActionItem<T>> items;
  final ValueChanged<T> onSelected;
  final bool enabled;
  final String tooltip;
  final Widget? triggerChild;

  /// 文字入口沿內容自然寬度，仍由本元件統一開關與最小點擊範圍。
  final Widget Function(BuildContext context, VoidCallback? onPressed)?
  triggerBuilder;

  /// 外部控制器：讓觸發鈕以外的入口（例如長按整張卡片）開**同一份**選單，
  /// 而不是各自組一份。省略時自行建立，行為與過去相同。
  final TpMoreMenuController? controller;

  @override
  State<TpMoreMenuButton<T>> createState() => _TpMoreMenuButtonState<T>();
}

class _TpMoreMenuButtonState<T> extends State<TpMoreMenuButton<T>> {
  final _ownMenuController = TpMoreMenuController();
  TpMoreMenuController get _menuController =>
      widget.controller ?? _ownMenuController;
  void _select(TpActionItem<T> item) {
    if (item.enabled) {
      _menuController._select(() => widget.onSelected(item.value));
    }
  }

  final _anchorLink = LayerLink();
  OverlayEntry? _host;
  final _routes = <ModalRoute<dynamic>>[];

  @override
  void initState() {
    super.initState();
    _menuController._openHost = _open;
  }

  @override
  void didUpdateWidget(TpMoreMenuButton<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameItems(oldWidget.items, widget.items) ||
        oldWidget.enabled != widget.enabled) {
      _removeHost();
    }
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownMenuController)._openHost = null;
      _removeHost();
      _menuController._openHost = _open;
    }
  }

  bool _sameItems(List<TpActionItem<T>> before, List<TpActionItem<T>> after) {
    if (before.length != after.length) return false;
    for (var index = 0; index < before.length; index++) {
      final oldItem = before[index];
      final newItem = after[index];
      if (oldItem.value != newItem.value ||
          oldItem.label != newItem.label ||
          oldItem.icon != newItem.icon ||
          oldItem.key != newItem.key ||
          oldItem.semanticLabel != newItem.semanticLabel ||
          oldItem.selected != newItem.selected ||
          oldItem.dividerBefore != newItem.dividerBefore ||
          oldItem.role != newItem.role ||
          oldItem.enabled != newItem.enabled) {
        return false;
      }
    }
    return true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // root host 捕捉原頁 scope；設定變動先關閉，下次開啟重新捕捉。
    _removeHost();
    _removeRouteListeners();
    var route = ModalRoute.of(context);
    while (route != null && !_routes.contains(route)) {
      _routes.add(route);
      route.animation?.addStatusListener(_primaryStatus);
      route.secondaryAnimation?.addStatusListener(_secondaryStatus);
      final navigator = route.navigator;
      route = navigator == null ? null : ModalRoute.of(navigator.context);
    }
  }

  void _primaryStatus(AnimationStatus status) {
    if (status == AnimationStatus.reverse) _removeHost();
  }

  void _secondaryStatus(AnimationStatus status) {
    if (status == AnimationStatus.forward) _removeHost();
  }

  void _removeRouteListeners() {
    for (final route in _routes) {
      route.animation?.removeStatusListener(_primaryStatus);
      route.secondaryAnimation?.removeStatusListener(_secondaryStatus);
    }
    _routes.clear();
  }

  void _open() {
    if (!mounted || !widget.enabled) return;
    if (_host != null) {
      _menuController._glassController.open();
      return;
    }
    final themes = InheritedTheme.capture(
      from: context,
      to: Overlay.of(context, rootOverlay: true).context,
    );
    final mediaQuery = MediaQuery.of(context);
    final entry = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: Align(
          alignment: Alignment.topLeft,
          child: CompositedTransformFollower(
            link: _anchorLink,
            showWhenUnlinked: false,
            child: themes.wrap(
              MediaQuery(
                data: mediaQuery,
                child: FocusScope(
                  autofocus: true,
                  child: Builder(builder: _buildMenu),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    setState(() => _host = entry);
    Overlay.of(context, rootOverlay: true).insert(entry);
    // Follower 完成 layout/paint 才有真實錨點 transform；不手算螢幕位置。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(_host, entry)) {
        _menuController._glassController.open();
      }
    });
  }

  Future<void> _afterClose() async {
    final entry = _host;
    while (mounted && identical(_host, entry) && _menuController.isOpen) {
      await WidgetsBinding.instance.endOfFrame;
    }
    if (mounted && identical(_host, entry)) _removeHost();
  }

  void _removeHost({bool rebuild = true}) {
    final entry = _host;
    if (entry == null) return;
    _host = null;
    // OverlayEntry.remove 自行處理 build 階段的延後失效；不得呼叫套件的 route hide。
    entry.remove();
    entry.dispose();
    if (!rebuild || !mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _menuController._openHost = null;
    _removeRouteListeners();
    _removeHost(rebuild: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CompositedTransformTarget(
    link: _anchorLink,
    child: ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: TpSpacing.tapMin,
        minHeight: TpSpacing.tapMin,
      ),
      child: ExcludeSemantics(
        excluding: _host != null,
        child: IgnorePointer(
          ignoring: _host != null,
          child: Opacity(
            opacity: _host == null ? 1 : 0,
            child: _trigger(context),
          ),
        ),
      ),
    ),
  );

  Widget _trigger(BuildContext context) {
    final VoidCallback? onPressed = widget.enabled
        ? () {
            _menuController.isOpen
                ? _menuController.close()
                : _menuController.open();
          }
        : null;
    if (widget.triggerBuilder != null) {
      return widget.triggerBuilder!(context, onPressed);
    }
    return TpToolbarGlassButton(
      tooltip: widget.tooltip,
      onPressed: onPressed,
      child:
          widget.triggerChild ??
          Icon(
            CupertinoIcons.ellipsis,
            size: 22,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }

  Widget _buildMenu(BuildContext context) {
    final menuWidth =
        (MediaQuery.sizeOf(context).width -
                MediaQuery.paddingOf(context).horizontal -
                16)
            .clamp(120.0, 280.0);
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: TpSpacing.tapMin,
        minHeight: TpSpacing.tapMin,
      ),
      child: Focus(
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape &&
              _menuController.isOpen) {
            _menuController.close();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GlassMenu(
          controller: _menuController._glassController,
          onClose: _afterClose,
          autoAdjustToScreen: true,
          interactionScale: MediaQuery.disableAnimationsOf(context) ? 1 : 1.02,
          stretch: MediaQuery.disableAnimationsOf(context) ? 0 : 0.5,
          menuWidth: menuWidth,
          menuPadding: MediaQuery.paddingOf(context) + const EdgeInsets.all(8),
          settings: tpNavigationGlassSettings(this.context),
          quality: tpGlassQuality(this.context),
          platformViewBackdrop: TpMediaBackdropScope.of(this.context),
          triggerBuilder: (context, _) => _trigger(context),
          items: [
            for (final item in widget.items) ...[
              if (item.dividerBefore) const GlassMenuDivider(),
              _menuItem(context, item, menuWidth),
            ],
          ],
        ),
      ),
    );
  }

  Widget _menuItem(
    BuildContext context,
    TpActionItem<T> item,
    double menuWidth,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.bodyLarge!.copyWith(
      fontWeight: MediaQuery.boldTextOf(context) ? FontWeight.bold : null,
      color: item.role == TpActionRole.destructive
          ? scheme.error
          : scheme.onSurface,
    );
    // 公開自訂內容需明確高度；僅量測文字容納需求，不再計算面板位置或動畫。
    // 面板左右 12、項目左右 16，另保留字符及選取勾號的位置。
    final textWidth =
        menuWidth -
        24 -
        32 -
        (item.icon == null ? 0 : 32) -
        (item.selected ? 18 : 0);
    final painter = TextPainter(
      text: TextSpan(text: item.label, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: textWidth);
    final height = (painter.height + 16).clamp(
      TpSpacing.tapMin,
      double.infinity,
    );
    final lines = painter.computeLineMetrics().length;
    painter.dispose();
    // 1.4.1 的非捲動 GlassMenuItem clone 不派發讀屏回呼。
    // 公開自訂內容保留套件項目呈現，僅補上 App 的語意動作。
    return GlassMenuLabel(
      height: height,
      horizontalPadding: 0,
      child: Focus(
        autofocus: identical(item, widget.items.first),
        skipTraversal: true,
        child: Semantics(
          key: item.key,
          button: true,
          enabled: item.enabled,
          selected: item.selected,
          label: item.semanticLabel ?? item.label,
          excludeSemantics: true,
          onTap: item.enabled ? () => _select(item) : null,
          child: GlassMenuItem(
            title: item.label,
            enablePressScale: !MediaQuery.disableAnimationsOf(context),
            titleStyle: style,
            height: height,
            maxLines: lines,
            icon: item.icon == null ? null : Icon(item.icon),
            isDestructive: item.role == TpActionRole.destructive,
            enabled: item.enabled,
            trailing: item.selected
                ? const Icon(CupertinoIcons.check_mark, size: 18)
                : null,
            onTap: () => _select(item),
          ),
        ),
      ),
    );
  }
}
