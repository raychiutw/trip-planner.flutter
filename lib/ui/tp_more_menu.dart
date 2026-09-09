/// 選單:由 bar button 或卡片「⋯」觸發、從觸發點展開的下拉動作清單
/// (對應 iOS pull-down menu)。與固定 bar 是兩個語彙,所以獨立成檔。
library;

import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../theme/tokens.dart';
import 'tp_action_item.dart';
import 'tp_app_bar.dart';
import 'tp_glass_surface.dart';

class TpMoreMenuButton<T> extends StatefulWidget {
  const TpMoreMenuButton({
    super.key,
    required this.items,
    required this.onSelected,
    this.enabled = true,
    this.tooltip = '更多',
    this.triggerChild,
    this.controller,
  });

  final List<TpActionItem<T>> items;
  final ValueChanged<T> onSelected;
  final bool enabled;
  final String tooltip;
  final Widget? triggerChild;

  /// 外部控制器：讓觸發鈕以外的入口（例如長按整張卡片）開**同一份**選單，
  /// 而不是各自組一份。省略時自行建立，行為與過去相同。
  final MenuController? controller;

  @override
  State<TpMoreMenuButton<T>> createState() => _TpMoreMenuButtonState<T>();
}

/// 選單面板的量測基準。
abstract final class _TpMenuMetrics {
  /// leading 字符 + 間距 + 尾端勾選欄位 + 左右內距。
  static const itemChromeWidth = 22.0 + 12 + 18 + 12 + 24 + 24;
  static const minWidth = 200.0;
  static const maxWidth = 320.0;
  static const panelPadding = TpSpacing.s3;
  static const gap = TpSpacing.s2;
}

class _TpMoreMenuButtonState<T> extends State<TpMoreMenuButton<T>> {
  final _ownMenuController = MenuController();

  MenuController get _menuController => widget.controller ?? _ownMenuController;

  /// 選擇的派發時機維持在**項目本身的回呼**。
  ///
  /// 不得移到 overlay 的關閉回呼 —— 框架文件明載 overlay 在 dispose 之後呼叫
  /// hide 是 no-op、不會觸發關閉回呼；時間軸每張卡片都掛一顆觸發鈕，清單重建
  /// 或捲出視窗時會讓點擊靜默消失。
  void _select(T value) {
    _menuController.close();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onSelected(value);
    });
  }

  /// 寬度依最長標籤量測，並保留 min/max 區間 —— 短標籤不撐出空白。
  double _panelWidth(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    var widest = 0.0;
    for (final item in widget.items) {
      final painter = TextPainter(
        text: TextSpan(text: item.label, style: style),
        textScaler: scaler,
        textDirection: direction,
        maxLines: 1,
      )..layout();
      widest = math.max(widest, painter.width);
    }
    return (widest + _TpMenuMetrics.itemChromeWidth).clamp(
      _TpMenuMetrics.minWidth,
      _TpMenuMetrics.maxWidth,
    );
  }

  /// 估算高度，只用來決定往下展開還是往上翻 —— 往上翻以 `bottom` 定位，
  /// 所以不需要精確值。
  double _estimatedHeight(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final fontSize = Theme.of(context).textTheme.bodyLarge?.fontSize ?? 16;
    final rowHeight = math.max(TpSpacing.tapMin, scaler.scale(fontSize) + 20);
    final dividers = widget.items.where((item) => item.dividerBefore).length;
    return widget.items.length * rowHeight +
        dividers * TpSpacing.s4 +
        _TpMenuMetrics.panelPadding * 2;
  }

  /// 面板走中性語意層 —— 品牌柔褐不再當背景鋪滿。
  LiquidGlassSettings _panelSettings(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tint = theme.colorScheme.surfaceContainerHigh.withValues(
      alpha: isDark ? 0.62 : 0.68,
    );
    return LiquidGlassSettings(
      glassColor: tint,
      thickness: 22,
      blur: 22,
      chromaticAberration: 0,
      lightIntensity: isDark ? 0.62 : 0.72,
      ambientStrength: isDark ? 0.08 : 0.14,
      refractiveIndex: 1.08,
      saturation: 1.02,
      standardOpacityMultiplier: isDark ? 0.64 : 0.52,
      platformViewFallbackColor: theme.colorScheme.surfaceContainerHigh
          .withValues(alpha: isDark ? 0.84 : 0.90),
    );
  }

  @override
  Widget build(BuildContext context) {
    final triggerForeground = Theme.of(context).colorScheme.primary;
    return SizedBox.square(
      dimension: TpSpacing.tapMin,
      child: RawMenuAnchor(
        controller: _menuController,
        useRootOverlay: true,
        consumeOutsideTaps: true,
        overlayBuilder: (_, info) => _buildOverlay(context, info),
        builder: (menuContext, controller, _) => TpToolbarGlassButton(
          tooltip: widget.tooltip,
          onPressed: widget.enabled
              ? () => controller.isOpen ? controller.close() : controller.open()
              : null,
          // 觸發鈕本體與按壓高亮沿用中性導覽玻璃（不再傳品牌褐的 settings 與
          // rimColor）；品牌色只留給字符。
          child:
              widget.triggerChild ??
              Icon(CupertinoIcons.ellipsis, size: 22, color: triggerForeground),
        ),
      ),
    );
  }

  Widget _buildOverlay(BuildContext context, RawMenuOverlayInfo info) {
    final scheme = Theme.of(context).colorScheme;
    final width = _panelWidth(context);
    const gap = _TpMenuMetrics.gap;

    // 下方空間不夠、且上方更寬裕時往上翻。往上翻改以 bottom 定位，因此不需要
    // 事先量到面板的精確高度。
    final spaceBelow = info.overlaySize.height - info.anchorRect.bottom - gap;
    final spaceAbove = info.anchorRect.top - gap;
    final flipUp =
        _estimatedHeight(context) > spaceBelow && spaceAbove > spaceBelow;

    return TapRegion(
      groupId: info.tapRegionGroupId,
      consumeOutsideTaps: true,
      onTapOutside: (_) => _menuController.close(),
      child: Actions(
        actions: <Type, Action<Intent>>{
          DismissIntent: DismissMenuAction(controller: _menuController),
        },
        // 面板開啟時就把焦點收進來，方向鍵才有東西可以走 —— 方向鍵 traversal
        // 本身由框架預設提供，不需要自己再掛一組 shortcuts。
        child: FocusScope(
          autofocus: true,
          child: Stack(
            children: [
              Positioned(
                right: math.max(
                  0,
                  info.overlaySize.width - info.anchorRect.right,
                ),
                top: flipUp ? null : info.anchorRect.bottom + gap,
                bottom: flipUp
                    ? info.overlaySize.height - info.anchorRect.top + gap
                    : null,
                width: width,
                child: _TpMenuPanel(
                  flipUp: flipUp,
                  settings: _panelSettings(context),
                  children: [
                    for (final item in widget.items) ...[
                      if (item.dividerBefore)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Divider(
                            height: TpSpacing.s4,
                            // 選單內部的分組分隔線是選單語彙，HIG 明文允許 ——
                            // 與工具列動作群組不同。
                            color: scheme.onSurface.withValues(alpha: 0.18),
                          ),
                        ),
                      _TpMenuItem<T>(
                        key: item.key,
                        item: item,
                        onSelected: _select,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 面板本體：以錨點為原點 scale 加淡入。
class _TpMenuPanel extends StatefulWidget {
  const _TpMenuPanel({
    required this.flipUp,
    required this.settings,
    required this.children,
  });

  final bool flipUp;
  final LiquidGlassSettings settings;
  final List<Widget> children;

  @override
  State<_TpMenuPanel> createState() => _TpMenuPanelState();
}

class _TpMenuPanelState extends State<_TpMenuPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: TpMotion.normal,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(
      parent: _controller,
      curve: TpMotion.appleEase,
    );
    return ScaleTransition(
      scale: Tween<double>(begin: 0.92, end: 1).animate(curve),
      // 空間不足往上翻時，scale 原點必須跟著改成底部對齊，否則面板會從遠離
      // 觸發鈕的那一端長出來。時間軸卡片是最常觸發往上翻的呼叫點。
      alignment: widget.flipUp ? Alignment.bottomRight : Alignment.topRight,
      // 淡入只包內容，不包玻璃。玻璃被 opacity 包住時引擎會為它開一層
      // saveLayer，面板的兩個 backdrop filter 因此失去直接翻用 onscreen
      // target 的資格 —— 整段 250ms 玻璃讀到的是空背景，到最後一幀才突然
      // 變成毛玻璃。套件作者自己的 `GlassPopover` 也是只淡內容。
      child: TpGlassSurface(
        key: const ValueKey('tp-menu-panel'),
        borderRadius: const BorderRadius.all(Radius.circular(24)),
        padding: const EdgeInsets.all(_TpMenuMetrics.panelPadding),
        glassSettings: widget.settings,
        child: FadeTransition(
          opacity: curve,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: widget.children,
          ),
        ),
      ),
    );
  }
}

/// 選單項目。字符在前、標題在後。
///
/// 這個方位是**對照真實 iOS 26 系統選單的觀察結果**，不是 HIG 的規定 —— HIG
/// `menus` 整頁沒有任何圖示方位的敘述（唯一出現 `leading` 的地方是一張插圖的
/// alt text，講的還是勾號）；`pull-down-buttons` 唯一提到方位的句子是「you can
/// display an interface icon or image **after its label**」，方向與這裡相反，
/// 但那頁的 change log 停在 2022 年，文本已落後於系統。
///
/// 要翻版面前請先取得真機系統選單的截圖當證據，不要拿 HIG 文本當依據。
class _TpMenuItem<T> extends StatelessWidget {
  const _TpMenuItem({super.key, required this.item, required this.onSelected});

  final TpActionItem<T> item;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // 深色模式的項目文字用標籤色，不再是品牌褐。
    final foreground = item.role == TpActionRole.destructive
        ? scheme.error
        : scheme.onSurface;
    return Semantics(
      button: true,
      enabled: item.enabled,
      // 停用原因寫在 semanticLabel，停用時仍要被朗讀。
      label: item.semanticLabel ?? item.label,
      excludeSemantics: true,
      child: TextButton(
        onPressed: item.enabled ? () => onSelected(item.value) : null,
        style: TextButton.styleFrom(
          alignment: AlignmentDirectional.centerStart,
          minimumSize: const Size(0, TpSpacing.tapMin),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          foregroundColor: foreground,
          backgroundColor: Colors.transparent,
          disabledForegroundColor: foreground.withValues(alpha: 0.38),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: theme.textTheme.bodyLarge,
        ),
        child: Row(
          children: [
            // 選單項目本來就該有字符;省略只發生在 action sheet 專用的項目上,
            // 那種項目不會走到這裡。
            if (item.icon != null) ...[
              Icon(item.icon, size: 22),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 選取態保留項目原本的字符，勾選另外顯示在尾端。
            if (item.selected) ...[
              const SizedBox(width: 12),
              const Icon(CupertinoIcons.check_mark, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}
