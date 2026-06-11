/// trip_detail 共用的「可拖曳排序 + 左滑刪除」row 元件（timeline entry 與 notes 共用）。
library;

import 'package:flutter/material.dart';

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
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消')),
        FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('刪除')),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await delete();
    onSuccess();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已刪除')));
  } on Exception {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('刪除失敗，請稍後再試')));
  }
}

/// 左滑刪除的紅底背景（errorContainer + 刪除 icon）。
class ReorderDeleteBackground extends StatelessWidget {
  const ReorderDeleteBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.centerRight,
      margin: const EdgeInsets.only(bottom: TpSpacing.s3),
      padding: const EdgeInsets.symmetric(horizontal: TpSpacing.s4),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: const BorderRadius.all(Radius.circular(TpRadius.md)),
      ),
      child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
    );
  }
}

/// 拖曳排序 handle（須置於 ReorderableListView 內;長按拖動）。
class ReorderDragHandle extends StatelessWidget {
  const ReorderDragHandle({
    super.key,
    required this.index,
    required this.iconKey,
  });

  final int index;

  /// drag icon 的 key（測試探針:entry-drag-* / note-drag-*）。
  final Key iconKey;

  @override
  Widget build(BuildContext context) {
    return ReorderableDragStartListener(
      index: index,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(Icons.drag_handle,
            key: iconKey,
            color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

/// 左滑刪除外殼:Dismissible(endToStart) + 紅底背景。確認/刪除交給 [onDelete],
/// 一律 return false（靠 provider invalidate 重抓移除,避免與資料源雙重移除）。
class SwipeToDelete extends StatelessWidget {
  const SwipeToDelete({
    super.key,
    required this.dismissKey,
    required this.onDelete,
    required this.child,
  });

  /// Dismissible 的 key（測試探針:entry-dismiss-* / note-dismiss-*）。
  final Key dismissKey;
  final Future<void> Function() onDelete;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: dismissKey,
      direction: DismissDirection.endToStart,
      background: const ReorderDeleteBackground(),
      confirmDismiss: (_) async {
        await onDelete();
        return false;
      },
      child: child,
    );
  }
}
