/// 帳號設定的生物辨識登入：開啟＝refresh token 改受生物辨識保護；關閉＝登出並清掉。
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_lock.dart';
import '../../../app/biometric_login.dart';
import '../../../ui/tp_settings_group.dart';

class BiometricLoginRow extends ConsumerWidget {
  const BiometricLoginRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = ref.watch(appLockKindProvider).value;
    final enabled = ref.watch(biometricLoginProvider).enabled;
    // 沒有生物辨識（只有裝置密碼或都沒有）又沒開過：沒東西可開。
    if ((kind == null || kind == BiometricKind.passcode) && !enabled) {
      return const SizedBox.shrink();
    }
    final label = kind.lockLabel;

    Future<void> confirmDisable() async {
      final controller = ref.read(biometricLoginProvider.notifier);
      final ok = await showCupertinoDialog<bool>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          key: const ValueKey('bio-disable-dialog'),
          title: Text('關閉 $label 登入？'),
          content: const Text('會清除這支手機上的登入憑證並登出，之後要重新用瀏覽器登入。'),
          actions: [
            CupertinoDialogAction(
              key: const ValueKey('bio-disable-cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              key: const ValueKey('bio-disable-confirm'),
              isDestructiveAction: true,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('關閉並登出'),
            ),
          ],
        ),
      );
      if (ok == true) await controller.disable();
    }

    void toggle() {
      if (enabled) {
        unawaited(confirmDisable());
      } else {
        unawaited(ref.read(biometricLoginProvider.notifier).enable());
      }
    }

    return TpSettingsRow(
      key: const ValueKey('settings-biometric-login'),
      leading: const Icon(CupertinoIcons.person_crop_circle_badge_checkmark),
      title: '$label 登入',
      subtitle: enabled
          ? '開啟 App 時用 $label 解鎖登入憑證，密碼不會存在這支手機'
          : '開啟後登入憑證只能用 $label 解鎖',
      trailing: Switch.adaptive(value: enabled, onChanged: (_) => toggle()),
      onTap: toggle,
    );
  }
}
