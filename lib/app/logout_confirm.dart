/// 登出／切換帳號前的確認：登出會清掉離線佇列，有待同步筆數要先講清楚。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/providers.dart';
import 'adaptive.dart';

/// 登出確認的說明：有待同步變更就先講清楚會遺失。App 鎖畫面的登出確認共用這段。
String logoutConfirmMessage(int pending) =>
    pending == 0 ? '確定要登出嗎？' : '還有 $pending 筆變更尚未同步，登出後會遺失。確定要登出嗎？';

/// 回傳 true 才可繼續登出。[alwaysAsk] 為 false 時，沒有待同步變更就不打擾。
Future<bool> confirmLogout(
  BuildContext context,
  WidgetRef ref, {
  bool alwaysAsk = true,
  String title = '登出帳號',
  String confirmLabel = '登出',
  String? message,
}) async {
  final pending = (await ref.read(cacheStoreProvider).readQueue()).length;
  if (!context.mounted) return false;
  if (pending == 0 && !alwaysAsk) return true;
  return showAppDestructiveConfirm(
    context,
    source: TpDestructiveConfirmSource.direct,
    title: title,
    message: message != null
        ? (pending == 0 ? message : '$message還有 $pending 筆變更尚未同步，登出後會遺失。')
        : logoutConfirmMessage(pending),
    confirmLabel: confirmLabel,
  );
}
