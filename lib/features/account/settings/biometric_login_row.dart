/// 帳號設定的生物辨識登入開關（ADR-0019）：開啟＝驗證一次生物辨識，refresh token 改受
/// 生物辨識保護；關閉＝改回一般保存，不驗證、不登出。沒有生物辨識的裝置不顯示。
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
    // 沒有生物辨識（只有裝置密碼或都沒有）：這個功能不存在。
    if (!kind.hasBiometric) return const SizedBox.shrink();
    final enabled = ref.watch(biometricLoginProvider).enabled;
    final label = kind.lockLabel;

    void toggle() {
      final controller = ref.read(biometricLoginProvider.notifier);
      unawaited(enabled ? controller.disable() : controller.enable());
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
