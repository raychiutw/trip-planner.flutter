/// 帳號設定的「忘記這支手機」：清掉本機憑證與 DPoP 金鑰並伺服器端撤銷（ADR-0017）。
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/providers.dart';
import '../../../app/adaptive.dart';
import '../../../app/app_feedback.dart';
import '../../../app/biometric_login.dart';
import '../../../ui/tp_settings_group.dart';

class ForgetThisPhoneRow extends ConsumerWidget {
  const ForgetThisPhoneRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 手機上有受生物辨識保護的憑證才有東西可忘。
    if (!ref.watch(biometricLoginProvider).enabled) {
      return const SizedBox.shrink();
    }

    Future<void> forget() async {
      final ok = await showCupertinoDialog<bool>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          key: const ValueKey('forget-phone-dialog'),
          title: const Text('忘記這支手機？'),
          content: const Text(
            '賣掉或借出手機前使用：會清除這支手機上的登入憑證並登出，'
            '其他裝置不受影響。之後要用瀏覽器重新登入。',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              key: const ValueKey('forget-phone-confirm'),
              isDestructiveAction: true,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                '忘記這支手機',
                style: tpDestructiveActionStyle(dialogContext),
              ),
            ),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
      final notifier = ref.read(authStateProvider.notifier);
      final revoked = await notifier.forgetThisPhone();
      // 橫幅掛在全域 messenger，清除後被導回登入頁仍看得到；但 context 此時可能已卸載。
      if (!revoked && context.mounted) {
        showAppError(context, '伺服器端尚未撤銷，請到網頁版已登入裝置確認');
      }
    }

    return TpSettingsRow(
      key: const ValueKey('settings-forget-phone'),
      leading: const Icon(CupertinoIcons.trash),
      title: '忘記這支手機',
      subtitle: '賣掉或借出手機前使用，清除這支手機上的登入憑證',
      onTap: () => unawaited(forget()),
    );
  }
}
