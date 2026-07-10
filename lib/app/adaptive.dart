/// 平台自適應 UI helper。
///
/// iOS/macOS 走 Cupertino 慣例、其餘平台走 Material。
/// 用 `Theme.of(context).platform`(而非 defaultTargetPlatform),
/// 方便測試以 `ThemeData(platform: ...)` override。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// 顯示自適應「確認 / 取消」對話框,回傳使用者是否確認。
///
/// - iOS/macOS → [CupertinoAlertDialog];破壞性操作([isDestructive])用紅字
///   destructive action。
/// - 其餘平台 → Material [AlertDialog];破壞性操作用 error 色 [FilledButton]。
///
/// 使用者關閉(點外部/返回)視同取消,回傳 `false`。
Future<bool> showAppConfirm(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  String cancelLabel = '取消',
  bool isDestructive = false,
}) async {
  final platform = Theme.of(context).platform;
  final isApple =
      platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

  if (isApple) {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: message == null ? null : Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: isDestructive,
            isDefaultAction: !isDestructive,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  final scheme = Theme.of(context).colorScheme;
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: isDestructive
              ? FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                )
              : null,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// 自適應 action sheet 的單一動作。
class AppSheetAction<T> {
  const AppSheetAction({
    required this.label,
    required this.value,
    this.isDestructive = false,
    this.icon,
  });

  /// 動作文字。
  final String label;

  /// 選中此動作時 [showAppActionSheet] 回傳的值。
  final T value;

  /// 破壞性動作(iOS 紅字;Android 紅色 icon/文字)。
  final bool isDestructive;

  /// Android 清單樣式的 leading icon(iOS 不顯示)。
  final IconData? icon;
}

/// 顯示自適應動作選單,回傳使用者選擇的動作值(取消回傳 `null`)。
///
/// - iOS/macOS → [CupertinoActionSheet](底部彈出、破壞性紅字、獨立取消鈕)。
/// - 其餘平台 → 附 drag handle 的 Material bottom sheet(ListTile 清單)。
Future<T?> showAppActionSheet<T>(
  BuildContext context, {
  String? title,
  String? message,
  required List<AppSheetAction<T>> actions,
  String cancelLabel = '取消',
}) {
  final platform = Theme.of(context).platform;
  final isApple =
      platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

  if (isApple) {
    return showCupertinoModalPopup<T>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: title == null ? null : Text(title),
        message: message == null ? null : Text(message),
        actions: [
          for (final action in actions)
            CupertinoActionSheetAction(
              isDestructiveAction: action.isDestructive,
              onPressed: () => Navigator.of(sheetContext).pop(action.value),
              child: Text(action.label),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: Text(cancelLabel),
        ),
      ),
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final error = Theme.of(sheetContext).colorScheme.error;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final action in actions)
              ListTile(
                leading: action.icon == null
                    ? null
                    : Icon(
                        action.icon,
                        color: action.isDestructive ? error : null,
                      ),
                title: Text(
                  action.label,
                  style: action.isDestructive
                      ? TextStyle(
                          color: error,
                          fontWeight: FontWeight.w600,
                        )
                      : null,
                ),
                onTap: () => Navigator.of(sheetContext).pop(action.value),
              ),
          ],
        ),
      );
    },
  );
}
