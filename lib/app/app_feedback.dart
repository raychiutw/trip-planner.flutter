import 'package:flutter/material.dart';

/// 顯示會持續留在畫面上的錯誤訊息，直到使用者關閉或重試。
void showAppError(
  BuildContext context,
  String message, {
  VoidCallback? onRetry,
  bool allowDismiss = true,
  String retryLabel = '重試',
}) {
  assert(
    allowDismiss || onRetry != null,
    'A non-dismissible error must provide a retry action.',
  );
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
          if (allowDismiss)
            TextButton(onPressed: dismiss, child: const Text('關閉')),
        ],
      ),
    );
}
