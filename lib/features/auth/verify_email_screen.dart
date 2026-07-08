/// Email 驗證 landing page；使用者按鈕後才 POST token。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_error.dart';
import '../../api/providers.dart';
import '../../theme/tokens.dart';

enum _VerifyStatus { idle, verifying, success, error }

/// `/auth/verify-email?token=...` shell 外頁面。
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, required this.token});

  /// 從 query string 取得的 email verification token。
  final String? token;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  late _VerifyStatus _status;
  late String? _errorCode;

  String get _token => (widget.token ?? '').trim();

  static const _errorMessages = <String, String>{
    'missing_token': '驗證連結缺少 token 參數，可能是連結被截斷。',
    'expired': '驗證連結已過期，請重新申請驗證信。',
    'used': '此驗證連結已經使用過了，可直接登入。',
    'server_error': '系統暫時無法驗證，請稍後再試。',
    'network': '網路連線錯誤，請檢查網路後再試。',
  };

  @override
  void initState() {
    super.initState();
    _status = _token.isEmpty ? _VerifyStatus.error : _VerifyStatus.idle;
    _errorCode = _token.isEmpty ? 'missing_token' : null;
  }

  Future<void> _verify() async {
    if (_token.isEmpty) return;
    setState(() {
      _status = _VerifyStatus.verifying;
      _errorCode = null;
    });
    try {
      await ref.read(authRepositoryProvider).verifyEmail(_token);
      if (!mounted) return;
      setState(() => _status = _VerifyStatus.success);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _status = _VerifyStatus.error;
        _errorCode = _errorCodeFrom(error);
      });
    }
  }

  String _errorCodeFrom(Object error) {
    if (error is ApiError) {
      return switch (error.code) {
        'missing_token' || 'VERIFY_TOKEN_MISSING' => 'missing_token',
        'expired' || 'VERIFY_TOKEN_EXPIRED' => 'expired',
        'used' || 'VERIFY_TOKEN_USED' => 'used',
        'server_error' || 'VERIFY_EMAIL_FAILED' => 'server_error',
        _ => 'server_error',
      };
    }
    return 'network';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: TpSpacing.s6,
              vertical: TpSpacing.s8,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Email 驗證',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall,
                  ),
                  const SizedBox(height: TpSpacing.s5),
                  if (_status == _VerifyStatus.idle) ...[
                    Text(
                      '點下方按鈕完成 Email 驗證。',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: TpSpacing.s6),
                    FilledButton(
                      key: const ValueKey('verify-email-confirm-button'),
                      onPressed: _verify,
                      child: const Text('點此完成驗證'),
                    ),
                  ] else if (_status == _VerifyStatus.verifying) ...[
                    const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: TpSpacing.s4),
                    const Text('驗證中...', textAlign: TextAlign.center),
                  ] else if (_status == _VerifyStatus.success) ...[
                    Icon(
                      Icons.check_circle_outline,
                      color: colorScheme.primary,
                      size: 56,
                    ),
                    const SizedBox(height: TpSpacing.s4),
                    Text(
                      'Email 驗證成功',
                      textAlign: TextAlign.center,
                      style: textTheme.titleLarge,
                    ),
                    const SizedBox(height: TpSpacing.s6),
                    FilledButton(
                      onPressed: () => context.go('/login?verified=1'),
                      child: const Text('前往登入'),
                    ),
                  ] else ...[
                    _ErrorPanel(
                      message:
                          _errorMessages[_errorCode] ??
                          _errorMessages['server_error']!,
                    ),
                    const SizedBox(height: TpSpacing.s6),
                    if (_errorCode == 'network' ||
                        _errorCode == 'server_error') ...[
                      FilledButton(onPressed: _verify, child: const Text('重試')),
                      const SizedBox(height: TpSpacing.s3),
                    ],
                    OutlinedButton(
                      onPressed: () => context.go('/login'),
                      child: Text(_errorCode == 'used' ? '前往登入' : '回登入'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(TpSpacing.s4),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(TpRadius.md),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: colorScheme.error),
      ),
    );
  }
}
