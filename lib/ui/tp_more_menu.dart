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
    this.quickActions = const [],
    this.enabled = true,
    this.tooltip = '更多',
    this.plain = false,
    this.triggerChild,
    this.triggerBuilder,
    this.controller,
  });

  final List<TpActionItem<T>> items;

  /// 上排快捷動作：字符在上、短文字在下，最多三格並排（HIG medium 選單）。
  /// 空間不足時改為同順序直列。
  final List<TpActionItem<T>> quickActions;
  final ValueChanged<T> onSelected;
  final bool enabled;
  final String tooltip;

  /// 已坐在內容表面（卡片列）時設 true：「⋯」不套玻璃、一般態無可見外框，
  /// 只留 44×44、tooltip 與語意；提高對比時補實心邊界。
  final bool plain;
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
  int _openGeneration = 0;
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
        !_sameItems(oldWidget.quickActions, widget.quickActions) ||
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
    _openGeneration++;
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
    final generation = _openGeneration;
    while (mounted &&
        identical(_host, entry) &&
        generation == _openGeneration &&
        _menuController.isOpen) {
      await WidgetsBinding.instance.endOfFrame;
    }
    if (mounted && identical(_host, entry) && generation == _openGeneration) {
      _removeHost();
    }
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
      return Tooltip(
        message: widget.tooltip,
        child: widget.triggerBuilder!(context, onPressed),
      );
    }
    if (widget.plain) {
      // 帶 onTap 才不會被卡片的容器語意合併成「卡片名＋行程選項」。
      return Semantics(
        button: true,
        enabled: onPressed != null,
        label: widget.tooltip,
        onTap: onPressed,
        excludeSemantics: true,
        child: SizedBox.square(
          dimension: TpSpacing.tapMin,
          child: IconButton(
            onPressed: onPressed,
            tooltip: widget.tooltip,
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
              side: BorderSide(color: tpGlassEdgeColor(context)),
            ),
            icon:
                widget.triggerChild ??
                const Icon(CupertinoIcons.ellipsis, size: 22),
          ),
        ),
      );
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
            if (widget.quickActions.isNotEmpty) ...[
              ..._quickActionRow(context, menuWidth),
              if (widget.items.isNotEmpty) const GlassMenuDivider(),
            ],
            for (final item in widget.items) ...[
              if (item.dividerBefore) const GlassMenuDivider(),
              _menuItem(context, item, menuWidth),
            ],
          ],
        ),
      ),
    );
  }

  /// 唯一的 role → 顏色映射點；清單項目用 bodyLarge，快捷動作短文字用 bodyMedium。
  TextStyle _itemStyle(
    BuildContext context,
    TpActionItem<T> item, {
    bool quick = false,
  }) {
    final theme = Theme.of(context);
    final base = quick
        ? theme.textTheme.bodyMedium!
        : theme.textTheme.bodyLarge!;
    return base.copyWith(
      fontWeight: MediaQuery.boldTextOf(context) ? FontWeight.bold : null,
      color: item.role == TpActionRole.destructive
          ? theme.colorScheme.error
          : theme.colorScheme.onSurface,
    );
  }

  static const _quickIconSize = 22.0;

  /// 上排快捷動作：每格短文字單行放得下才並排；任一格放不下就整排改直列，
  /// 沿用一般項目的字符＋文字列，順序與動作不變。
  List<Widget> _quickActionRow(BuildContext context, double menuWidth) {
    final actions = widget.quickActions;
    // 面板左右各 12；格內左右各 4。
    final tileWidth = (menuWidth - 24) / actions.length;
    final textWidth = tileWidth - 8;
    var textHeight = 0.0;
    var fitsInline = tileWidth >= TpSpacing.tapMin;
    for (final item in actions) {
      final painter = TextPainter(
        text: TextSpan(
          text: item.label,
          style: _itemStyle(context, item, quick: true),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout(maxWidth: textWidth);
      if (painter.didExceedMaxLines) fitsInline = false;
      if (painter.height > textHeight) textHeight = painter.height;
      painter.dispose();
    }
    if (!fitsInline) {
      return [for (final item in actions) _menuItem(context, item, menuWidth)];
    }
    final rowHeight = (_quickIconSize + 4 + textHeight + 16).clamp(
      TpSpacing.tapMin,
      double.infinity,
    );
    return [
      GlassMenuLabel(
        height: rowHeight,
        horizontalPadding: 0,
        child: Row(
          children: [
            for (final item in actions)
              Expanded(
                child: SizedBox(
                  height: rowHeight,
                  child: _quickActionTile(context, item),
                ),
              ),
          ],
        ),
      ),
    ];
  }

  /// 開啟時焦點落在整份選單的第一個動作，方向鍵才有起點。
  bool _isInitialFocus(TpActionItem<T> item) => identical(
    item,
    widget.quickActions.isEmpty
        ? widget.items.firstOrNull
        : widget.quickActions.first,
  );

  Widget _quickActionTile(BuildContext context, TpActionItem<T> item) {
    final style = _itemStyle(context, item, quick: true);
    return Semantics(
      key: item.key,
      button: true,
      enabled: item.enabled,
      selected: item.selected,
      label: item.semanticLabel ?? item.label,
      excludeSemantics: true,
      onTap: item.enabled ? () => _select(item) : null,
      child: _TpQuickActionButton(
        enabled: item.enabled,
        autofocus: _isInitialFocus(item),
        enablePressScale: !MediaQuery.disableAnimationsOf(context),
        onTap: () => _select(item),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon, size: _quickIconSize, color: style.color),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: style,
              textAlign: TextAlign.center,
              maxLines: 1,
              softWrap: false,
            ),
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
    final style = _itemStyle(context, item);
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
        autofocus: _isInitialFocus(item),
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

/// 快捷動作格：與套件 GlassMenuItem 同一套按壓／焦點／停用回饋，
/// 但字符在上、文字在下。Enter／Space 與方向鍵走 Flutter 公開焦點機制。
class _TpQuickActionButton extends StatefulWidget {
  const _TpQuickActionButton({
    required this.enabled,
    required this.autofocus,
    required this.enablePressScale,
    required this.onTap,
    required this.child,
  });

  final bool enabled;
  final bool autofocus;
  final bool enablePressScale;
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_TpQuickActionButton> createState() => _TpQuickActionButtonState();
}

class _TpQuickActionButtonState extends State<_TpQuickActionButton> {
  var _pressed = false;
  var _focused = false;
  var _hovered = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    // 底色跟隨主題前景，深淺色與提高對比都保有對比；不寫死白色。
    final foreground = Theme.of(context).colorScheme.onSurface;
    final highlight = _pressed
        ? foreground.withValues(alpha: 0.15)
        : (_hovered || _focused)
        ? foreground.withValues(alpha: 0.1)
        : foreground.withValues(alpha: 0);
    return FocusableActionDetector(
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      onShowHoverHighlight: (value) => setState(() => _hovered = value),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.enabled ? (_) => _setPressed(true) : null,
        onTapUp: widget.enabled ? (_) => _setPressed(false) : null,
        onTapCancel: widget.enabled ? () => _setPressed(false) : null,
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedScale(
          scale: widget.enablePressScale && _pressed ? 0.98 : 1,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: _pressed
                ? Duration.zero
                : const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: BoxDecoration(
              color: highlight,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Opacity(
              opacity: widget.enabled ? 1 : 0.4,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
