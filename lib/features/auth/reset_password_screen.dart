/// 重設密碼頁：token + new password → `/oauth/reset-password`。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_error.dart';
import '../../api/providers.dart';
import '../../theme/tokens.dart';

/// `/auth/password/reset?token=...` shell 外頁面。
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.token});

  /// 從 query string 取得的 reset token。
  final String? token;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isSubmitting = false;
  bool _success = false;
  bool _tokenInvalid = false;
  String? _passwordError;
  String? _bannerError;

  String get _token => (widget.token ?? '').trim();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;
    setState(() {
      _passwordError = null;
      _bannerError = null;
    });
    final newPassword = _passwordController.text;
    if (newPassword != _confirmController.text) {
      setState(() => _passwordError = '兩次輸入的密碼不一致');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .resetPassword(token: _token, password: newPassword);
      if (!mounted) return;
      setState(() => _success = true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (error is ApiError &&
            (error.code == 'RESET_TOKEN_INVALID' ||
                error.code == 'RESET_TOKEN_MISSING')) {
          _tokenInvalid = true;
        } else if (error is ApiError &&
            (error.code == 'RESET_PASSWORD_TOO_SHORT' ||
                error.code == 'RESET_INVALID_PASSWORD' ||
                error.code == 'RESET_PASSWORD_FORMAT')) {
          _passwordError = '密碼格式不符（至少 8 字元，包含字母與數字）';
        } else {
          _bannerError = '暫時無法處理，請稍後再試。';
        }
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_token.isEmpty || _tokenInvalid) return _invalidLink(context);
    if (_success) return _successView(context);

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/login')),
        title: const Text('設定新密碼'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: TpSpacing.s6,
              vertical: TpSpacing.s8,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '設定新密碼',
                      textAlign: TextAlign.center,
                      style: textTheme.headlineSmall,
                    ),
                    const SizedBox(height: TpSpacing.s2),
                    Text(
                      '建立一組新密碼，至少 8 字元。',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: TpSpacing.s6),
                    if (_bannerError != null) ...[
                      _ErrorPanel(message: _bannerError!),
                      const SizedBox(height: TpSpacing.s4),
                    ],
                    TextFormField(
                      key: const ValueKey('reset-password-field'),
                      controller: _passwordController,
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      enabled: !_isSubmitting,
                      decoration: const InputDecoration(
                        labelText: '新密碼',
                        helperText: '至少 8 字元',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return '請輸入密碼';
                        if (value.length < 8) return '密碼至少 8 字元';
                        return null;
                      },
                    ),
                    const SizedBox(height: TpSpacing.s4),
                    TextFormField(
                      key: const ValueKey('reset-confirm-field'),
                      controller: _confirmController,
                      obscureText: true,
                      enabled: !_isSubmitting,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: '再次輸入新密碼',
                        errorText: _passwordError,
                      ),
                    ),
                    const SizedBox(height: TpSpacing.s6),
                    FilledButton(
                      key: const ValueKey('reset-submit-button'),
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('重設密碼'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _invalidLink(BuildContext context) {
    return _ResultScaffold(
      icon: Icons.link_off_outlined,
      title: '這個連結無法使用了',
      message: '重設連結已失效或已被使用過。為了安全，連結只在 1 小時內有效，且只能使用一次。',
      primaryKey: const ValueKey('reset-retry-button'),
      primaryLabel: '重新申請重設密碼',
      primaryPath: '/login/forgot',
      secondaryLabel: '回登入',
      secondaryPath: '/login',
    );
  }

  Widget _successView(BuildContext context) {
    return _ResultScaffold(
      icon: Icons.check_circle_outline,
      title: '密碼已更新',
      message: '為了安全，所有裝置上的登入已自動登出。請用新密碼重新登入。',
      primaryKey: const ValueKey('reset-go-login-button'),
      primaryLabel: '前往登入',
      primaryPath: '/login',
    );
  }
}

class _ResultScaffold extends StatelessWidget {
  const _ResultScaffold({
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryKey,
    required this.primaryLabel,
    required this.primaryPath,
    this.secondaryLabel,
    this.secondaryPath,
  });

  final IconData icon;
  final String title;
  final String message;
  final Key primaryKey;
  final String primaryLabel;
  final String primaryPath;
  final String? secondaryLabel;
  final String? secondaryPath;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
                  Icon(icon, size: 56, color: colorScheme.primary),
                  const SizedBox(height: TpSpacing.s4),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: TpSpacing.s2),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: TpSpacing.s6),
                  FilledButton(
                    key: primaryKey,
                    onPressed: () => context.go(primaryPath),
                    child: Text(primaryLabel),
                  ),
                  if (secondaryLabel != null && secondaryPath != null) ...[
                    const SizedBox(height: TpSpacing.s3),
                    OutlinedButton(
                      onPressed: () => context.go(secondaryPath!),
                      child: Text(secondaryLabel!),
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
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: colorScheme.error),
      ),
    );
  }
}
