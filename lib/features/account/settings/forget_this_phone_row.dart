/// 帳號設定的「忘記這支手機」：清掉本機憑證與 DPoP 金鑰並伺服器端撤銷（ADR-0017）。
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/biometric_login.dart';
import '../../../app/forget_this_phone.dart';
import '../../../ui/tp_settings_group.dart';

class ForgetThisPhoneRow extends ConsumerWidget {
  const ForgetThisPhoneRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 手機上有受生物辨識保護的憑證才有東西可忘。
    if (!ref.watch(biometricLoginProvider).enabled) {
      return const SizedBox.shrink();
    }
    return TpSettingsRow(
      key: const ValueKey('settings-forget-phone'),
      leading: const Icon(CupertinoIcons.trash),
      title: '忘記這支手機',
      subtitle: '賣掉或借出手機前使用，清除這支手機上的登入憑證',
      onTap: () => unawaited(confirmAndForgetThisPhone(context, ref)),
    );
  }
}
