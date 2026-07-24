import 'package:flutter/material.dart';

/// 顯示會持續留在畫面上的錯誤訊息，直到使用者關閉或重試。
void showAppError(
  BuildContext context,
  String message, {
  VoidCallback? onRetry,
  String retryLabel = '重試',
}) {
  final messenger = ScaffoldMessenger.of(context);

  void dismiss() => messenger.hideCurrentMaterialBanner();

  messenger
    ..hideCurrentMaterialBanner()
    ..showMaterialBanner(
      MaterialBanner(
        key: const ValueKey('app-error-banner'),
        leading: Icon(
          Icons.error_outline,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
        content: Semantics(
          liveRegion: true,
          child: Text(
            message,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
        ),
        actions: [
          if (onRetry != null)
            TextButton(
              onPressed: () {
                dismiss();
                onRetry();
              },
              child: Text(retryLabel),
            ),
          TextButton(onPressed: dismiss, child: const Text('關閉')),
        ],
      ),
    );
}
