/// trip_detail 共用的可拖曳排序 row 元件（timeline entry 與 notes 共用）。
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/adaptive.dart';
import '../../../app/app_feedback.dart';
import '../../../theme/tokens.dart';

/// 確認對話框 → 執行 [delete] → [onSuccess]（通常是 invalidate provider）→ 成功/失敗 snackbar。
/// timeline 與 notes 的左滑刪除共用,收斂重複的 dialog + try/catch 樣板。
Future<void> confirmAndDelete(
  BuildContext context, {
  required String title,
  required String message,
  required Future<void> Function() delete,
  required void Function() onSuccess,
}) async {
  final ok = await showAppConfirm(
    context,
    title: title,
    message: message,
    confirmLabel: '刪除',
    isDestructive: true,
  );
  if (!ok) return;
  try {
    await delete();
    onSuccess();
    HapticFeedback.mediumImpact();
    if (!context.mounted) return;
    showAppNotice(context, '已刪除');
  } on Exception {
    if (!context.mounted) return;
    showAppError(context, '刪除失敗，請稍後再試');
  }
}

/// 拖曳排序 handle（須置於 ReorderableListView 內;長按拖動）。
class ReorderDragHandle extends StatefulWidget {
  const ReorderDragHandle({
    super.key,
    required this.index,
    required this.iconKey,
  });

  final int index;

  /// drag icon 的 key（測試探針:entry-drag-* / note-drag-*）。
  final Key iconKey;

  @override
  State<ReorderDragHandle> createState() => _ReorderDragHandleState();
}

class _ReorderDragHandleState extends State<ReorderDragHandle> {
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    return ReorderableDragStartListener(
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
          child: TpInlineEditControlVisual(
            icon: CupertinoIcons.line_horizontal_3,
            pressed: _pressed,
          ),
        ),
      ),
    );
  }
}

class TpInlineEditActionButton extends StatefulWidget {
  const TpInlineEditActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  State<TpInlineEditActionButton> createState() =>
      _TpInlineEditActionButtonState();
}

class _TpInlineEditActionButtonState extends State<TpInlineEditActionButton> {
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.tooltip,
      child: Tooltip(
        message: widget.tooltip,
        excludeFromSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onPressed,
          child: TpInlineEditControlVisual(
            icon: widget.icon,
            pressed: _pressed,
          ),
        ),
      ),
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
