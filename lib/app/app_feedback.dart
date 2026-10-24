import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

final _bannerVisible = ValueNotifier<bool>(false);
var _bannerSerial = 0;

/// 錯誤橫幅顯示期間，移除內容區的頂部 safe area。
///
/// 橫幅貼在外層 Scaffold 最上緣、已經讓出狀態列，內層頁面的 app bar 若仍讀到
/// 完整的 `padding.top`，橫幅與標題之間就會多出一段狀態列高度的空白。
class AppErrorBannerInset extends StatelessWidget {
  const AppErrorBannerInset({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: _bannerVisible,
    builder: (context, visible, child) => MediaQuery.removePadding(
      context: context,
      removeTop: visible,
      child: child!,
    ),
    child: child,
  );
}

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

  messenger.hideCurrentMaterialBanner();
  _bannerVisible.value = true;
  final shown = ++_bannerSerial;
  final controller = messenger.showMaterialBanner(
    MaterialBanner(
      key: const ValueKey('app-error-banner'),
      leading: Icon(
        CupertinoIcons.exclamationmark_circle,
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
  // 被新橫幅取代時，舊橫幅的 closed 不能把新橫幅的狀態關掉。
  unawaited(
    controller.closed.then((_) {
      if (shown == _bannerSerial) _bannerVisible.value = false;
    }),
  );
}
