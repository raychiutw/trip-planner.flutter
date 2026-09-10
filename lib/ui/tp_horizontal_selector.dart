import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../app/accessibility_scope.dart';
import '../theme/tokens.dart';
import 'tp_glass_surface.dart';

/// 高度與寬度共用同一份文字樣式，避免兩套基準各自漂移。
TextStyle? _labelStyle(BuildContext context) => Theme.of(
  context,
).textTheme.labelMedium?.copyWith(fontSize: 13, fontWeight: FontWeight.w700);

/// [TpHorizontalSelector] 的單一選項描述。
class TpScopeOption<T> {
  const TpScopeOption({
    required this.value,
    required this.label,
    this.semanticsLabel,
    this.icon,
    this.indicatorColor,
    this.isAction = false,
    this.key,
  });

  final T value;
  final String label;
  final String? semanticsLabel;
  final IconData? icon;
  final Color? indicatorColor;
  final bool isAction;
  final Key? key;
}

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
    return math.max(TpSpacing.tapMin, painter.height + 10) + 4;
  }

  @override
  State<TpHorizontalSelector<T>> createState() =>
      _TpHorizontalSelectorState<T>();
}

class _TpHorizontalSelectorState<T> extends State<TpHorizontalSelector<T>> {
  static const _iconSize = 14.0;
  final _controller = _SelectorScrollController();
  final FocusNode _focusNode = FocusNode(debugLabel: 'TpHorizontalSelector');

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
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      widget.onSelected(widget.value);
      return KeyEventResult.handled;
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

  @override
  Widget build(BuildContext context) {
    assert(
      widget.options.every((option) => !option.isAction),
      'TpHorizontalSelector only accepts selection options.',
    );
    final scheme = Theme.of(context).colorScheme;
    final height = TpHorizontalSelector.preferredHeight(context);
    _controller.reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (widget.options.isEmpty) return SizedBox(height: height);
    final selectedIndex = widget.options.indexWhere(
      (option) => option.value == widget.value,
    );
    final opaque =
        MediaQuery.highContrastOf(context) ||
        AppAccessibilityScope.reduceTransparencyOf(context);
    return Listener(
      onPointerDown: (_) => _focusNode.requestFocus(),
      child: Focus(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: TpGlassEdge(
          borderRadius: height / 2,
          child: GlassSegmentedControl.scrollable(
            segments: [
              for (final option in widget.options)
                GlassSegment(
                  id: option.value,
                  semanticLabel: option.semanticsLabel ?? option.label,
                  // 公開 icon 插槽保留水平內容、操作 key 與最小觸控高度。
                  // 自然尺寸、水平拖曳、切換選取與選取底皆由套件提供。
                  // 套件不回呼目前項目；只補再次點選，不參與水平拖曳。
                  icon: GestureDetector(
                    excludeFromSemantics: true,
                    onTap: option.value == widget.value
                        ? () => widget.onSelected(option.value)
                        : null,
                    child: Semantics(
                      key: option.key,
                      // selected 與 label 唯一由套件提供，避免重複 flag 分裂節點。
                      // 具名 action 可合併到原節點，不覆蓋套件的普通 tap。
                      customSemanticsActions: option.value == widget.value
                          ? {
                              const CustomSemanticsAction(
                                label: '重新選取目前範圍',
                              ): () =>
                                  widget.onSelected(option.value),
                            }
                          : null,
                      child: ExcludeSemantics(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: TpSpacing.tapMin,
                              minHeight: height - 4,
                            ),
                            child: _OptionContent(
                              option: option,
                              color: option.value == widget.value
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
            selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
            onSegmentSelected: (index) {
              _focusNode.requestFocus();
              widget.onSelected(widget.options[index].value);
            },
            labelPadding: EdgeInsets.zero,
            height: height,
            scrollController: _controller,
            selectionAlignment: SegmentSelectionAlignment.center,
            dragBehavior: SegmentDragBehavior.scroll,
            indicatorColor: scheme.surfaceContainerHigh,
            backgroundColor: opaque ? scheme.surfaceContainerLow : null,
            settings: tpNavigationGlassSettings(context),
            quality: tpGlassQuality(context),
            useOwnLayer: true,
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

/// 1.4.1 的置中捲動尚未讀取 Reduce Motion；只取消公開 controller 的動畫。
/// 捲動目標、選取延遲與欄位幾何仍由套件決定。
class _SelectorScrollController extends ScrollController {
  bool reduceMotion = false;

  @override
  Future<void> animateTo(
    double offset, {
    required Duration duration,
    required Curve curve,
  }) {
    if (reduceMotion) {
      jumpTo(offset);
      return Future<void>.value();
    }
    return super.animateTo(offset, duration: duration, curve: curve);
  }
}
