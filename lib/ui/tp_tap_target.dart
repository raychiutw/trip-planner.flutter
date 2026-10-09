import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Tp 控制項共用的互動外殼:點擊、鍵盤焦點與 Enter／Space 啟動、可朗讀語意、
/// 最小點擊區。
///
/// [onTap] 為 null 即停用:不可聚焦、不回呼,語意 `enabled: false`(VoiceOver
/// 會念「已停用」),不靠 `Opacity`／`IgnorePointer` 假裝。停用的視覺變淡由呼叫端
/// 用顏色表達。內部子樹的語意一律被 [label]／[value] 取代。
class TpTapTarget extends StatefulWidget {
  const TpTapTarget({
    super.key,
    required this.onTap,
    required this.child,
    this.label,
    this.value,
    this.button = false,
    this.selected,
    this.checked,
    this.toggled,
    this.inMutuallyExclusiveGroup,
    this.minWidth = 0,
    this.minHeight = TpSpacing.tapMin,
    this.focusRadius = TpRadius.md,
  });

  final VoidCallback? onTap;
  final Widget child;
  final String? label;
  final String? value;
  final bool button;
  final bool? selected;
  final bool? checked;
  final bool? toggled;
  final bool? inMutuallyExclusiveGroup;
  final double minWidth;
  final double minHeight;

  /// 鍵盤焦點框的圓角。
  final double focusRadius;

  @override
  State<TpTapTarget> createState() => _TpTapTargetState();
}

class _TpTapTargetState extends State<TpTapTarget> {
  bool _focusVisible = false;

  void _activate() => widget.onTap?.call();

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      enabled: enabled,
      button: widget.button,
      label: widget.label,
      value: widget.value,
      selected: widget.selected,
      checked: widget.checked,
      toggled: widget.toggled,
      inMutuallyExclusiveGroup: widget.inMutuallyExclusiveGroup,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: FocusableActionDetector(
        enabled: enabled,
        onShowFocusHighlight: (v) => setState(() => _focusVisible = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _activate();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: widget.minWidth,
              minHeight: widget.minHeight,
            ),
            child: DecoratedBox(
              key: const ValueKey('tp-focus-ring'),
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.focusRadius),
                border: _focusVisible
                    ? Border.all(color: scheme.primary, width: 2)
                    : null,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
