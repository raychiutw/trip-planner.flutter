/// 帳號設定的 App 鎖開關：用 Face ID / Touch ID 解鎖 App。
library;

import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_lock.dart';
import '../../../ui/tp_settings_group.dart';

class AppLockRow extends ConsumerWidget {
  const AppLockRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = ref.watch(appLockKindProvider);
    final enabled = ref.watch(appLockProvider).enabled;
    final unavailable = kind.hasValue && kind.value == null;
    final canToggle = kind.value != null;
    void toggle(bool value) =>
        unawaited(ref.read(appLockProvider.notifier).setEnabled(value));
    return TpSettingsRow(
      key: const ValueKey('settings-app-lock'),
      leading: const Icon(CupertinoIcons.lock),
      title: '${kind.value.lockLabel} 解鎖',
      subtitle: unavailable ? '此裝置尚未設定生物辨識或裝置密碼' : null,
      trailing: Switch.adaptive(
        value: enabled,
        onChanged: canToggle ? toggle : null,
      ),
      onTap: canToggle ? () => toggle(!enabled) : null,
    );
  }
}
