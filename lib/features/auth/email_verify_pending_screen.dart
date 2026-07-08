/// Email 驗證待確認頁：顯示信箱並允許重寄驗證信。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/providers.dart';
import '../../theme/tokens.dart';

/// `/signup/check-email` shell 外頁面。
class EmailVerifyPendingScreen extends ConsumerStatefulWidget {
  const EmailVerifyPendingScreen({
    super.key,
    required this.email,
    this.invitationError,
  });

  /// 從 query 取得的 email。
  final String? email;

  /// Signup 成功但 invitation accept 失敗時的錯誤碼。
  final String? invitationError;

  @override
  ConsumerState<EmailVerifyPendingScreen> createState() =>
      _EmailVerifyPendingScreenState();
}

class _EmailVerifyPendingScreenState
    extends ConsumerState<EmailVerifyPendingScreen> {
  bool _isResending = false;
  String? _statusMessage;
  bool _statusIsError = false;

  String get _safeEmail => (widget.email ?? '').trim().toLowerCase();

  Future<void> _resend() async {
    if (_safeEmail.isEmpty || _isResending) return;
    setState(() {
      _isResending = true;
      _statusMessage = null;
      _statusIsError = false;
    });
    try {
      await ref.read(authRepositoryProvider).sendVerificationEmail(_safeEmail);
      if (!mounted) return;
      setState(() => _statusMessage = '已重寄。請查看信箱。');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _statusMessage = '重寄失敗，請稍後再試。';
        _statusIsError = true;
      });
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasInvitationError =
        widget.invitationError != null && widget.invitationError!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('查看你的信箱')),
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
                  Icon(
                    Icons.mark_email_unread_outlined,
                    size: 56,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: TpSpacing.s4),
                  Text(
                    '查看你的信箱',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall,
                  ),
                  const SizedBox(height: TpSpacing.s2),
                  Text(
                    _safeEmail.isEmpty ? '（沒有電子郵件）' : _safeEmail,
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: TpSpacing.s4),
                  _InfoPanel(message: '驗證連結 24 小時內有效。記得檢查垃圾信件夾。'),
                  if (hasInvitationError) ...[
                    const SizedBox(height: TpSpacing.s3),
                    _InfoPanel(
                      message: '帳號已建立，但邀請連結暫時無法接受。請登入後請旅伴重新邀請。',
                      isError: true,
                    ),
                  ],
                  if (_statusMessage != null) ...[
                    const SizedBox(height: TpSpacing.s3),
                    _InfoPanel(
                      message: _statusMessage!,
                      isError: _statusIsError,
                    ),
                  ],
                  const SizedBox(height: TpSpacing.s6),
                  FilledButton.icon(
                    key: const ValueKey('verify-pending-resend-button'),
                    onPressed: _isResending || _safeEmail.isEmpty
                        ? null
                        : _resend,
                    icon: _isResending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined),
                    label: Text(_isResending ? '寄送中...' : '重新寄送驗證信'),
                  ),
                  const SizedBox(height: TpSpacing.s3),
                  OutlinedButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('回登入'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(TpSpacing.s4),
      decoration: BoxDecoration(
        color: isError
            ? colorScheme.errorContainer
            : colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(TpRadius.md),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: isError ? colorScheme.error : colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
