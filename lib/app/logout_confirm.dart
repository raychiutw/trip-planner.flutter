/// 登出／切換帳號前的確認：登出會清掉離線佇列，有待同步筆數要先講清楚。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/providers.dart';
import 'adaptive.dart';
import 'app_lock.dart';
import 'biometric_login.dart';

/// 回傳 true 才可繼續登出。[alwaysAsk] 為 false 時，沒有待同步變更就不打擾。
Future<bool> confirmLogout(
  BuildContext context,
  WidgetRef ref, {
  bool alwaysAsk = true,
  String title = '登出帳號',
  String confirmLabel = '登出',
  String? message,
}) async {
  // 開啟生物辨識登入者登出會保留憑證（#614），要誠實說明。
  if (message == null && ref.read(biometricLoginProvider).enabled) {
    final kind = await ref.read(appLockKindProvider.future);
    message = '這支手機仍可用 ${kind.lockLabel} 登入，要完全清除請選忘記這支手機。';
  }
  final pending = (await ref.read(cacheStoreProvider).readQueue()).length;
  if (!context.mounted) return false;
  if (pending == 0 && !alwaysAsk) return true;
  return showAppDestructiveConfirm(
    context,
    source: TpDestructiveConfirmSource.direct,
    title: title,
    message: message != null
        ? (pending == 0 ? message : '$message還有 $pending 筆變更尚未同步，登出後會遺失。')
        : (pending == 0 ? '確定要登出嗎？' : '還有 $pending 筆變更尚未同步，登出後會遺失。確定要登出嗎？'),
    confirmLabel: confirmLabel,
  );
}
