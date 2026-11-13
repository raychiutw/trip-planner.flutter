/// 「忘記這支手機」的確認與執行：帳號設定與登入頁共用（ADR-0017）。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/providers.dart';
import 'adaptive.dart';
import 'app_feedback.dart';

Future<void> confirmAndForgetThisPhone(
  BuildContext context,
  WidgetRef ref,
) async {
  final ok = await showAppDestructiveConfirm(
    context,
    source: TpDestructiveConfirmSource.direct,
    title: '忘記這支手機？',
    message: '賣掉或借出手機前使用：會清除這支手機上的登入憑證並登出，其他裝置不受影響。之後要用瀏覽器重新登入。',
    confirmLabel: '忘記這支手機',
  );
  if (!ok || !context.mounted) return;
  final revoked = await ref.read(authStateProvider.notifier).forgetThisPhone();
  // 橫幅掛在全域 messenger，清除後被導回登入頁仍看得到；但 context 此時可能已卸載。
  if (!revoked && context.mounted) {
    showAppError(context, '伺服器端尚未撤銷，請到網頁版已登入裝置確認');
  }
}
