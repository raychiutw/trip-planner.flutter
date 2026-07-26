import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../app/accessibility_scope.dart';
import '../theme/tokens.dart';
import 'tp_glass_surface.dart';
import 'tp_scope_menu.dart';

/// 高度與寬度共用同一份文字樣式，避免兩套基準各自漂移。
TextStyle? _labelStyle(BuildContext context) => Theme.of(
  context,
).textTheme.labelMedium?.copyWith(fontSize: 13, fontWeight: FontWeight.w700);

/// 行程／地圖頁共用的同層選擇器；跨頁動作應放在頁首工具列。
class TpHorizontalSelector<T> extends StatefulWidget {
  const TpHorizontalSelector({
    super.key,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  final T value;
  final List<TpScopeOption<T>> options;
  final ValueChanged<T> onSelected;

  /// 選擇器依目前 Dynamic Type 實際行高增高，且永遠保留 44pt 觸控高度。
  static double preferredHeight(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(text: 'DAY 00', style: _labelStyle(context)),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    return math.max(TpSpacing.tapMin, painter.height + 10);
  }

  @override
  State<TpHorizontalSelector<T>> createState() =>
      _TpHorizontalSelectorState<T>();
}

class _TpHorizontalSelectorState<T> extends State<TpHorizontalSelector<T>> {
  // 文字兩側的呼吸空間（含外層 3pt padding），讓膠囊不貼著字。
  static const _optionInset = 28.0;
  // 與導覽 chrome 同一個模糊半徑。
  static const _trackBlur = 16.0;
  static const _iconSize = 14.0;
  final ScrollController _controller = ScrollController();
  final FocusNode _focusNode = FocusNode(debugLabel: 'TpHorizontalSelector');

  @override
  void initState() {
    super.initState();
    _scheduleSelectedVisibility();
  }

  @override
  void didUpdateWidget(covariant TpHorizontalSelector<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value ||
        oldWidget.options.length != widget.options.length) {
      _scheduleSelectedVisibility();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final direction = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft => -1,
      LogicalKeyboardKey.arrowRight => 1,
      _ => 0,
    };
    if (direction == 0) return KeyEventResult.ignored;

    final currentIndex = widget.options.indexWhere(
      (option) => option.value == widget.value,
    );
    final nextIndex = currentIndex + direction;
    if (currentIndex < 0 ||
        nextIndex < 0 ||
        nextIndex >= widget.options.length) {
      return KeyEventResult.handled;
    }
    widget.onSelected(widget.options[nextIndex].value);
    return KeyEventResult.handled;
  }

  void _scheduleSelectedVisibility() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      final position = _controller.position;
      if (!position.hasViewportDimension || !position.hasContentDimensions) {
        return;
      }
      var center = 0.0;
      var found = false;
      for (final option in widget.options) {
        final width = _optionWidth(option);
        if (option.value == widget.value) {
          center += width / 2;
          found = true;
          break;
        }
        center += width;
      }
      if (!found) return;
      final target = (center - position.viewportDimension / 2).clamp(
        0.0,
        position.maxScrollExtent,
      );
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.jumpTo(target);
      } else {
        _controller.animateTo(
          target,
          duration: TpMotion.normal,
          curve: TpMotion.appleEase,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    assert(
      widget.options.every((option) => !option.isAction),
      'TpHorizontalSelector only accepts selection options.',
    );
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // iOS `UISegmentedControl`：半透明 systemGray6 軌 + 比軌更亮的膠囊，
    // 靠「浮起」表達選取。對照 iOS 26 電話 app 的通話記錄實測：深色下軌是
    // #141414（黑底上）、膠囊 #363636，背後有內容時膠囊會透出約 8 階。
    //
    // **不走 LiquidGlass shader**：shader 會把 tint 衰減到約 14%，顏色不可
    // 預測 —— 導覽配方的 tint 在淺色是 `surface`（白），疊在白色頁面上等於
    // 無色，實測軌與頁面同為 #FFFFFF。巢狀在玻璃層裡的子玻璃顏色又會被母層
    // 吃掉，選取膠囊完全畫不出來。改用 `BackdropFilter` + 半透明填色：一樣
    // 是真的模糊與內容透出，但色值完全可控。
    final opaque =
        MediaQuery.highContrastOf(context) ||
        AppAccessibilityScope.reduceTransparencyOf(context);
    final trackFill = opaque
        ? scheme.surfaceContainerLow
        : scheme.surfaceContainerLow.withValues(alpha: isDark ? 0.72 : 0.80);
    final selectedBase = isDark
        ? scheme.surfaceContainerHighest
        : scheme.surface;
    final selectedFill = opaque
        ? selectedBase
        : selectedBase.withValues(alpha: isDark ? 0.90 : 0.92);
    final height = TpHorizontalSelector.preferredHeight(context);
    final trackShape = LiquidRoundedSuperellipse(
      borderRadius: height / 2,
      // 一般模式不描邊；只有「提高對比」才補一條可見實心邊。
      side: BorderSide(color: tpGlassEdgeColor(context)),
    );
    Widget track = DecoratedBox(
      decoration: ShapeDecoration(color: trackFill, shape: trackShape),
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final option in widget.options)
              _SelectorOption<T>(
                option: option,
                selected: option.value == widget.value,
                width: _optionWidth(option),
                height: height,
                selectedFill: selectedFill,
                // 淺色的白膠囊需要一點陰影才浮得起來；深色靠亮度差即可。
                selectedShadow: !isDark,
                accentColor: scheme.primary,
                onTap: () {
                  _focusNode.requestFocus();
                  widget.onSelected(option.value);
                },
              ),
          ],
        ),
      ),
    );
    if (!opaque) {
      track = BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: _trackBlur, sigmaY: _trackBlur),
        child: track,
      );
    }
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: SizedBox(
        height: height,
        child: ClipPath(
          clipper: ShapeBorderClipper(shape: trackShape),
          child: track,
        ),
      ),
    );
  }

  /// 量測實際文字寬度，字元數階梯會把長短標籤擠在同一級距。
  ///
  /// `TextPainter` 的 `textScaler` 已把 Dynamic Type 算進去，之後不可再乘一次；
  /// 但量測值對短標籤可能低於最小點擊尺寸，所以保留 44pt 下限。
  double _optionWidth(TpScopeOption<T> option) {
    final painter = TextPainter(
      text: TextSpan(text: option.label, style: _labelStyle(context)),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    var content = painter.width;
    if (option.icon != null) content += _iconSize + TpSpacing.s1;
    if (option.indicatorColor != null) content += TpSpacing.s2 * 2;
    return math.max(TpSpacing.tapMin, content + _optionInset);
  }
}

class _SelectorOption<T> extends StatelessWidget {
  const _SelectorOption({
    required this.option,
    required this.selected,
    required this.width,
    required this.height,
    required this.selectedFill,
    required this.selectedShadow,
    required this.accentColor,
    required this.onTap,
  });

  final TpScopeOption<T> option;
  final bool selected;
  final double width;
  final double height;
  final Color selectedFill;
  final bool selectedShadow;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected ? accentColor : theme.colorScheme.onSurfaceVariant;
    return Semantics(
      key: option.key,
      button: true,
      selected: selected,
      label: option.semanticsLabel ?? option.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: width,
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
            child: selected
                ? DecoratedBox(
                    decoration: ShapeDecoration(
                      color: selectedFill,
                      shape: LiquidRoundedSuperellipse(
                        borderRadius: (height - 10) / 2,
                      ),
                      shadows: selectedShadow
                          ? const [
                              BoxShadow(
                                color: Color(0x1A000000),
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: _OptionContent(option: option, color: color),
                    ),
                  )
                : Center(
                    child: _OptionContent(option: option, color: color),
                  ),
          ),
        ),
      ),
    );
  }
}

class _OptionContent<T> extends StatelessWidget {
  const _OptionContent({required this.option, required this.color});

  final TpScopeOption<T> option;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (option.icon != null) ...[
          Icon(
            option.icon,
            size: _TpHorizontalSelectorState._iconSize,
            color: color,
          ),
          const SizedBox(width: TpSpacing.s1),
        ],
        if (option.indicatorColor != null) ...[
          Container(
            width: TpSpacing.s2,
            height: TpSpacing.s2,
            decoration: BoxDecoration(
              color: option.indicatorColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: TpSpacing.s2),
        ],
        Text(
          option.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _labelStyle(context)?.copyWith(color: color),
        ),
      ],
    );
  }
}
