/// 登出／切換帳號前的確認：登出會清掉離線佇列，有待同步筆數要先講清楚。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/providers.dart';
import 'adaptive.dart';

/// 回傳 true 才可繼續登出。[alwaysAsk] 為 false 時，沒有待同步變更就不打擾。
Future<bool> confirmLogout(
  BuildContext context,
  WidgetRef ref, {
  bool alwaysAsk = true,
  String title = '登出帳號',
  String confirmLabel = '登出',
}) async {
  final pending = (await ref.read(cacheStoreProvider).readQueue()).length;
  if (!context.mounted) return false;
  if (pending == 0 && !alwaysAsk) return true;
  return showAppDestructiveConfirm(
    context,
    source: TpDestructiveConfirmSource.direct,
    title: title,
    message: pending == 0 ? '確定要登出嗎？' : '還有 $pending 筆變更尚未同步，登出後會遺失。確定要登出嗎？',
    confirmLabel: confirmLabel,
  );
}
