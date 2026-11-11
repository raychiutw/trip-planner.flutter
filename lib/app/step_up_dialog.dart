/// 敏感操作的重新驗證對話框（ADR-0016）：有 passkey 用 passkey，否則（或使用者選擇）用目前密碼。
///
/// 對話框自己向 api 換證明並在框內顯示錯誤（驗證沒過、限流、平台失敗），所以
/// 使用者可以在同一個框裡重試；只有「換到證明」或「取消」才會結束。密碼只留在輸入框
/// 與送出的那一個請求，不寫入任何儲存、不進 log（App 不保管密碼，ADR-0014）。
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/providers.dart';
import '../api/step_up.dart';
import '../theme/tokens.dart';
import 'error_message.dart';
import 'passkey_reauth_platform.dart';
import 'router.dart';

const _errorByCode = {
  'REAUTH_INVALID': '驗證沒有通過，請再試一次',
  'REAUTH_RATE_LIMITED': '嘗試次數過多，請稍後再試',
  'REAUTH_NO_PASSWORD':
      '這個帳號沒有設定密碼，請改用 passkey；若也沒有 passkey，請先到「帳號 → 安全性 → Passkey」新增一組',
};

/// 把 [StepUpPrompter] 接到畫面：用 [contextOf] 取得目前的 navigator context 開對話框。
class DialogStepUpPrompter implements StepUpPrompter {
  DialogStepUpPrompter({
    required this.repository,
    required this.platform,
    required this.contextOf,
  });

  final StepUpRepository repository;
  final PasskeyReauthPlatform platform;
  final BuildContext? Function() contextOf;

  @override
  Future<StepUpProof?> prompt() async {
    final context = contextOf();
    if (context == null || !context.mounted) return null;
    return showCupertinoDialog<StepUpProof>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StepUpDialog(repository: repository, platform: platform),
    );
  }
}

/// `main()` 用：以 go_router 的 navigator 當 context 來源。
StepUpPrompter appStepUpPrompter(Ref ref) => DialogStepUpPrompter(
  repository: ref.read(stepUpRepositoryProvider),
  platform: ref.read(passkeyReauthPlatformProvider),
  contextOf: () =>
      ref.read(appRouterProvider).routerDelegate.navigatorKey.currentContext,
);

class StepUpDialog extends StatefulWidget {
  const StepUpDialog({
    super.key,
    required this.repository,
    required this.platform,
  });

  final StepUpRepository repository;
  final PasskeyReauthPlatform platform;

  @override
  State<StepUpDialog> createState() => _StepUpDialogState();
}

class _StepUpDialogState extends State<StepUpDialog> {
  final _password = TextEditingController();
  Map<String, dynamic>? _options;
  bool _hasPasskey = false;
  bool _usePassword = false;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() => _error = null));
    unawaited(_loadOptions());
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    try {
      final options = await widget.repository.options();
      final allowed = options['allowCredentials'];
      if (!mounted) return;
      setState(() {
        _options = options;
        _hasPasskey = allowed is List && allowed.isNotEmpty;
        _usePassword = !_hasPasskey;
        _loading = false;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _usePassword = true;
        _loading = false;
        _error = _message(error);
      });
    }
  }

  String _message(Object error) =>
      userFacingApiError(error, fallback: '驗證失敗，請稍後再試', byCode: _errorByCode);

  /// [exchange] 回 null 代表「留在框內、不顯示錯誤」（使用者取消了系統的 passkey 對話框）。
  Future<void> _run(Future<StepUpProof?> Function() exchange) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final proof = await exchange();
      if (!mounted) return;
      if (proof != null) {
        Navigator.of(context).pop(proof);
      } else {
        setState(() => _busy = false);
      }
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error is _PlatformFailed ? error.message : _message(error);
      });
    }
  }

  Future<void> _withPasskey() => _run(() async {
    // 挑戰單次有效：送過 api 的挑戰（不論成敗）不能再用，下次要重新取。
    final options = _options ?? await widget.repository.options();
    _options = null;
    final outcome = await widget.platform.authenticate(options);
    switch (outcome) {
      case PasskeyAsserted(:final credential):
        return widget.repository.passkey(credential);
      case PasskeyAssertCancelled():
        return null;
      case PasskeyAssertFailed():
        throw const _PlatformFailed();
    }
  });

  Future<void> _withPassword() {
    if (_password.text.isEmpty) return Future.value();
    return _run(() => widget.repository.password(_password.text));
  }

  @override
  Widget build(BuildContext context) {
    final passkeyMode = _hasPasskey && !_usePassword;
    return CupertinoAlertDialog(
      key: const ValueKey('step-up-dialog'),
      title: const Text('需要重新驗證'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: TpSpacing.s2),
          Text(
            passkeyMode
                ? '這項操作需要確認是你本人，請使用 passkey 驗證。'
                : '這項操作需要確認是你本人，請輸入目前密碼。',
          ),
          if (_loading || _busy) ...[
            const SizedBox(height: TpSpacing.s3),
            const CupertinoActivityIndicator(),
          ] else if (!passkeyMode) ...[
            const SizedBox(height: TpSpacing.s3),
            CupertinoTextField(
              key: const ValueKey('step-up-password-field'),
              controller: _password,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [AutofillHints.password],
              placeholder: '目前密碼（重新驗證）',
              onSubmitted: (_) => unawaited(_withPassword()),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: TpSpacing.s2),
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                key: const ValueKey('step-up-error'),
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        CupertinoDialogAction(
          key: const ValueKey('step-up-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        if (passkeyMode)
          CupertinoDialogAction(
            key: const ValueKey('step-up-passkey'),
            isDefaultAction: true,
            onPressed: _busy ? null : () => unawaited(_withPasskey()),
            child: const Text('使用 passkey'),
          )
        else if (!_loading)
          CupertinoDialogAction(
            key: const ValueKey('step-up-password-submit'),
            isDefaultAction: true,
            onPressed: _busy || _password.text.isEmpty
                ? null
                : () => unawaited(_withPassword()),
            child: const Text('驗證'),
          ),
        if (!_loading && _hasPasskey)
          CupertinoDialogAction(
            key: const ValueKey('step-up-switch'),
            onPressed: _busy
                ? null
                : () => setState(() {
                    _usePassword = !_usePassword;
                    _error = null;
                  }),
            child: Text(passkeyMode ? '改用密碼' : '改用 passkey'),
          ),
      ],
    );
  }
}

class _PlatformFailed implements Exception {
  const _PlatformFailed();

  String get message => '無法使用 passkey 驗證，請確認這支裝置已設定螢幕鎖定，或改用密碼';
}
