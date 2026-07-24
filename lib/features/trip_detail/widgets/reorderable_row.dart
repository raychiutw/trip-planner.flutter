/// trip_detail 共用的可拖曳排序 row 元件（timeline entry 與 notes 共用）。
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../../theme/tokens.dart';

/// 拖曳排序 handle（須置於 ReorderableListView 內；按住即可拖動）。
class ReorderDragHandle extends StatefulWidget {
  const ReorderDragHandle({
    super.key,
    required this.index,
    required this.iconKey,
    this.onMoveUp,
    this.onMoveDown,
  });

  final int index;

  /// drag icon 的 key（測試探針:entry-drag-* / note-drag-*）。
  final Key iconKey;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  State<ReorderDragHandle> createState() => _ReorderDragHandleState();
}

class _ReorderDragHandleState extends State<ReorderDragHandle> {
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    void invoke(VoidCallback callback) {
      HapticFeedback.selectionClick();
      callback();
    }

    final handle = ReorderableDragStartListener(
      index: widget.index,
      child: Listener(
        onPointerDown: (_) {
          setState(() => _pressed = true);
          HapticFeedback.selectionClick();
        },
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: Semantics(
          key: widget.iconKey,
          button: true,
          label: '拖曳調整順序',
          hint: widget.onMoveUp != null || widget.onMoveDown != null
              ? '使用上或下方向鍵調整順序'
              : null,
          customSemanticsActions: {
            if (widget.onMoveUp != null)
              CustomSemanticsAction(label: '上移'): () =>
                  invoke(widget.onMoveUp!),
            if (widget.onMoveDown != null)
              CustomSemanticsAction(label: '下移'): () =>
                  invoke(widget.onMoveDown!),
          },
          child: TpInlineEditControlVisual(
            icon: CupertinoIcons.line_horizontal_3,
            pressed: _pressed,
          ),
        ),
      ),
    );
    return CallbackShortcuts(
      bindings: {
        if (widget.onMoveUp != null)
          const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
              invoke(widget.onMoveUp!),
        if (widget.onMoveDown != null)
          const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
              invoke(widget.onMoveDown!),
      },
      child: Focus(child: handle),
    );
  }
}

class TpInlineEditControlVisual extends StatelessWidget {
  const TpInlineEditControlVisual({
    super.key,
    required this.icon,
    this.pressed = false,
  });

  final IconData icon;
  final bool pressed;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      width: TpSpacing.tapMin,
      height: TpSpacing.tapMin,
      decoration: BoxDecoration(
        color: pressed ? primary.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: const BorderRadius.all(Radius.circular(22)),
      ),
      child: Icon(icon, size: 20, color: primary),
    );
  }
}
