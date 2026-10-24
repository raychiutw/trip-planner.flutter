/// 帳號設定的生物辨識登入：只在已開啟時出現，用來關閉。
///
/// 開啟只能在密碼登入成功後的詢問進行，因為要有密碼才存得進去。
library;

import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_lock.dart';
import '../../../app/biometric_login.dart';
import '../../../ui/tp_settings_group.dart';

class BiometricLoginRow extends ConsumerWidget {
  const BiometricLoginRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(biometricLoginProvider).hasSaved) {
      return const SizedBox.shrink();
    }
    final label = ref.watch(appLockKindProvider).value.lockLabel;
    void turnOff() =>
        unawaited(ref.read(biometricLoginProvider.notifier).disable());
    return TpSettingsRow(
      key: const ValueKey('settings-biometric-login'),
      leading: const Icon(CupertinoIcons.person_crop_circle_badge_checkmark),
      title: '$label 登入',
      subtitle: '登出後可用 $label 登入，不必輸入密碼',
      trailing: Switch.adaptive(value: true, onChanged: (_) => turnOff()),
      onTap: turnOff,
    );
  }
}
