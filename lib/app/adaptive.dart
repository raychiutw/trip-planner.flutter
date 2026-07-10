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
