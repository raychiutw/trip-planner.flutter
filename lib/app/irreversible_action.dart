import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import 'adaptive.dart';
import 'app_feedback.dart';

/// 統一不可復原動作的確認、執行中鎖定、成功與可重試失敗狀態。
Future<void> confirmAndRunIrreversibleAction(
  BuildContext context, {
  required String title,
  required String message,
  required String actionLabel,
  required String progressLabel,
  required String successMessage,
  required String failureMessage,
  required Future<bool> Function() action,
  VoidCallback? onSuccess,
  Key progressKey = const ValueKey('irreversible-action-progress'),
}) async {
  final confirmed = await showAppConfirm(
    context,
    title: title,
    message: message,
    confirmLabel: actionLabel,
    isDestructive: true,
  );
  if (!confirmed) return;

  Future<void> runAction() async {
    if (!context.mounted) return;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PopScope(
          canPop: false,
          child: AlertDialog(
            key: progressKey,
            content: Row(
              children: [
                const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: TpSpacing.s3),
                Expanded(child: Text(progressLabel)),
              ],
            ),
          ),
        ),
      ),
    );

    var succeeded = false;
    try {
      succeeded = await action();
    } on Exception {
      succeeded = false;
    }
    if (!context.mounted) return;

    Navigator.of(context, rootNavigator: true).pop();
    if (succeeded) {
      onSuccess?.call();
      unawaited(HapticFeedback.mediumImpact());
      showAppNotice(context, successMessage);
      return;
    }
    showAppError(
      context,
      failureMessage,
      onRetry: () => unawaited(runAction()),
    );
  }

  await runAction();
}

/// 行程項目與筆記沿用的永久刪除包裝。
Future<void> confirmAndDelete(
  BuildContext context, {
  required String title,
  required String message,
  required Future<void> Function() delete,
  required VoidCallback onSuccess,
}) {
  return confirmAndRunIrreversibleAction(
    context,
    title: title,
    message: message,
    actionLabel: '刪除',
    progressLabel: '正在刪除…',
    successMessage: '已刪除',
    failureMessage: '刪除失敗，原資料已保留',
    progressKey: const ValueKey('delete-progress'),
    action: () async {
      await delete();
      return true;
    },
    onSuccess: onSuccess,
  );
}
