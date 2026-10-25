/// 帳號設定的生物辨識登入：開啟要重新輸入帳密綁定，關閉先驗證身分再清掉帳密。
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api_error.dart';
import '../../../api/providers.dart';
import '../../../app/app_lock.dart';
import '../../../app/biometric_login.dart';
import '../../../app/error_message.dart';
import '../../../theme/tokens.dart';
import '../../../ui/tp_settings_group.dart';

class BiometricLoginRow extends ConsumerWidget {
  const BiometricLoginRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = ref.watch(appLockKindProvider).value;
    final bound = ref.watch(biometricLoginProvider).hasSaved;
    // 裝置沒有生物辨識也沒有已綁定的帳密：沒東西可開。
    if (kind == null && !bound) return const SizedBox.shrink();
    final label = kind.lockLabel;
    void toggle() {
      final controller = ref.read(biometricLoginProvider.notifier);
      if (bound) {
        unawaited(controller.disable());
      } else {
        unawaited(
          showCupertinoDialog<void>(
            context: context,
            builder: (_) => const _BindDialog(),
          ),
        );
      }
    }

    return TpSettingsRow(
      key: const ValueKey('settings-biometric-login'),
      leading: const Icon(CupertinoIcons.person_crop_circle_badge_checkmark),
      title: '$label 登入',
      subtitle: bound ? '登出後可用 $label 登入，不必輸入密碼' : '開啟時需重新輸入帳密綁定，關閉會清除',
      trailing: Switch.adaptive(value: bound, onChanged: (_) => toggle()),
      onTap: toggle,
    );
  }
}

/// 重新輸入密碼綁定；email 預設帶目前登入的帳號。
class _BindDialog extends ConsumerStatefulWidget {
  const _BindDialog();

  @override
  ConsumerState<_BindDialog> createState() => _BindDialogState();
}

class _BindDialogState extends ConsumerState<_BindDialog> {
  late final _email = TextEditingController(
    text: ref.read(authStateProvider).value?.email ?? '',
  );
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final email = _email.text.trim();
    if (email.isEmpty || _password.text.isEmpty) {
      setState(() => _error = '請輸入 Email 與密碼');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final outcome = await ref
          .read(biometricLoginProvider.notifier)
          .bind(email, _password.text);
      if (!mounted) return;
      if (outcome == BindOutcome.bound) {
        Navigator.of(context).pop();
      } else {
        setState(() {
          _busy = false;
          _error = '請輸入目前登入的帳號';
        });
      }
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = hasCjk(e.message) ? e.message : 'Email 或密碼錯誤';
      });
    } on Exception {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '驗證失敗，請檢查網路後再試';
      });
    }
  }

  @override
  Widget build(BuildContext context) => CupertinoAlertDialog(
    key: const ValueKey('bio-bind-dialog'),
    title: const Text('綁定生物辨識登入'),
    content: Column(
      children: [
        const SizedBox(height: TpSpacing.s3),
        CupertinoTextField(
          key: const ValueKey('bio-bind-email'),
          controller: _email,
          enabled: !_busy,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          placeholder: 'Email',
        ),
        const SizedBox(height: TpSpacing.s2),
        CupertinoTextField(
          key: const ValueKey('bio-bind-password'),
          controller: _password,
          enabled: !_busy,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          placeholder: '密碼',
          onSubmitted: (_) => _confirm(),
        ),
        if (_error != null) ...[
          const SizedBox(height: TpSpacing.s2),
          Text(
            _error!,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ],
    ),
    actions: [
      CupertinoDialogAction(
        key: const ValueKey('bio-bind-cancel'),
        onPressed: _busy ? null : () => Navigator.of(context).pop(),
        child: const Text('取消'),
      ),
      CupertinoDialogAction(
        key: const ValueKey('bio-bind-confirm'),
        isDefaultAction: true,
        onPressed: _busy ? null : _confirm,
        child: const Text('綁定'),
      ),
    ],
  );
}
