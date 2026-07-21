/// Login-adjacent account flows ported from the web auth pages.
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_error.dart';
import '../../api/providers.dart';
import '../../app/adaptive_content.dart';
import '../../app/external_links.dart';
import '../../theme/tokens.dart';

/// Email/password signup page, including optional invitation token handoff.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key, this.invitationToken});

  final String? invitationToken;

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  bool _submitting = false;
  bool _obscurePassword = true;
  bool _privacyConsent = false;
  String? _emailServerError;
  String? _passwordServerError;
  String? _privacyConsentError;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
      _emailServerError = null;
      _passwordServerError = null;
      _privacyConsentError = null;
    });
    try {
      final email = _emailController.text.trim();
      final result = await ref
          .read(authRepositoryProvider)
          .signup(
            email: email,
            password: _passwordController.text,
            privacyConsent: _privacyConsent,
            displayName: _displayNameController.text,
            invitationToken: widget.invitationToken,
          );
      try {
        await ref
            .read(authRepositoryProvider)
            .sendVerificationEmail(result.email);
      } catch (_) {
        // Verification resend is best-effort, matching the web flow.
      }
      if (!mounted) return;
      ref.invalidate(authStateProvider);
      if (result.joinedTrip != null) {
        context.go(
          '/trips?selected=${Uri.encodeQueryComponent(result.joinedTrip!.id)}',
        );
      } else if (result.requiresVerification) {
        final query = <String, String>{'email': result.email};
        if (result.invitationError != null) {
          query['invitationError'] = result.invitationError!;
        }
        context.go(
          Uri(path: '/signup/check-email', queryParameters: query).toString(),
        );
      } else {
        context.go('/trips');
      }
    } on Exception catch (error) {
      if (!mounted) return;
      if (error is ApiError) {
        switch (error.code) {
          case 'SIGNUP_CONSENT_REQUIRED':
            setState(() => _privacyConsentError = '請先閱讀並同意個資條款');
            return;
          case 'SIGNUP_INVALID_EMAIL':
            setState(() => _emailServerError = '電子郵件格式無效');
            return;
          case 'SIGNUP_INVALID_PASSWORD':
          case 'SIGNUP_PASSWORD_TOO_SHORT':
            setState(() => _passwordServerError = '密碼至少 8 字元');
            return;
          case 'SIGNUP_RATE_LIMITED':
            final seconds = error.retryAfterSeconds;
            setState(
              () => _error = seconds == null
                  ? '註冊請求過多，請幾分鐘後再試'
                  : '註冊請求過多，請在 $seconds 秒後再試',
            );
            return;
        }
      }
      setState(
        () => _error = _authErrorMessage(error, const {
          'SIGNUP_EMAIL_TAKEN': '此電子郵件已註冊，請改用登入或重設密碼',
        }, '註冊失敗，請稍後再試'),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: '建立帳號',
      subtitle: widget.invitationToken == null
          ? '用 Email 加入 Tripline'
          : '建立帳號後加入這趟行程',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              _InlineAuthMessage(
                key: const ValueKey('signup-error-banner'),
                message: _error!,
              ),
              const SizedBox(height: TpSpacing.s4),
            ],
            TextFormField(
              key: const ValueKey('signup-email-field'),
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              enabled: !_submitting,
              forceErrorText: _emailServerError,
              onChanged: (_) {
                if (_emailServerError != null) {
                  setState(() => _emailServerError = null);
                }
              },
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? '請輸入 Email' : null,
            ),
            const SizedBox(height: TpSpacing.s4),
            TextFormField(
              key: const ValueKey('signup-display-name-field'),
              controller: _displayNameController,
              textInputAction: TextInputAction.next,
              enabled: !_submitting,
              decoration: const InputDecoration(labelText: '顯示名稱（選填）'),
            ),
            const SizedBox(height: TpSpacing.s4),
            TextFormField(
              key: const ValueKey('signup-password-field'),
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              enabled: !_submitting,
              forceErrorText: _passwordServerError,
              onChanged: (_) {
                if (_passwordServerError != null) {
                  setState(() => _passwordServerError = null);
                }
              },
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: '密碼',
                helperText: '至少 8 個字元',
                suffixIcon: IconButton(
                  key: const ValueKey('signup-password-visibility-toggle'),
                  tooltip: _obscurePassword ? '顯示密碼' : '隱藏密碼',
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? CupertinoIcons.eye
                        : CupertinoIcons.eye_slash,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return '請輸入密碼';
                if (value.length < 8) return '密碼至少 8 字元';
                return null;
              },
            ),
            const SizedBox(height: TpSpacing.s3),
            FormField<bool>(
              key: const ValueKey('signup-privacy-consent-field'),
              initialValue: false,
              validator: (value) => value == true ? null : '請先閱讀並同意個資條款',
              builder: (field) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckboxListTile(
                    key: const ValueKey('signup-privacy-consent-checkbox'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: field.value ?? false,
                    onChanged: _submitting
                        ? null
                        : (value) {
                            field.didChange(value);
                            setState(() {
                              _privacyConsent = value ?? false;
                              _privacyConsentError = null;
                            });
                          },
                    title: const Text('我已閱讀並同意個資條款'),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      key: const ValueKey('signup-privacy-policy-link'),
                      onPressed: openPrivacyPolicy,
                      child: const Text('查看個資條款'),
                    ),
                  ),
                  if (field.errorText != null || _privacyConsentError != null)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 12),
                      child: Text(
                        field.errorText ?? _privacyConsentError!,
                        key: const ValueKey('signup-privacy-consent-error'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: TpSpacing.s4),
            FilledButton(
              key: const ValueKey('signup-submit-button'),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const _ButtonProgressLabel('建立帳號')
                  : const Text('建立帳號'),
            ),
            const SizedBox(height: TpSpacing.s3),
            TextButton(
              onPressed: _submitting ? null : () => context.go('/login'),
              child: const Text('已有帳號，改用登入'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Post-signup page that tells users to verify email and can resend the email.
class EmailVerifyPendingScreen extends ConsumerStatefulWidget {
  const EmailVerifyPendingScreen({
    super.key,
    required this.email,
    this.invitationError,
  });

  final String email;
  final String? invitationError;

  @override
  ConsumerState<EmailVerifyPendingScreen> createState() =>
      _EmailVerifyPendingScreenState();
}

class _EmailVerifyPendingScreenState
    extends ConsumerState<EmailVerifyPendingScreen> {
  bool _sending = false;
  String? _message;

  Future<void> _resend() async {
    if (widget.email.trim().isEmpty) return;
    setState(() {
      _sending = true;
      _message = null;
    });
    try {
      final message = await ref
          .read(authRepositoryProvider)
          .sendVerificationEmail(widget.email);
      if (mounted) setState(() => _message = message ?? '驗證信已重新寄出');
    } on Exception catch (error) {
      if (mounted) {
        setState(
          () => _message = _authErrorMessage(error, const {
            'VERIFY_EMAIL_RATE_LIMITED': '驗證信請求過多，請稍後再試',
          }, '暫時無法重寄驗證信，請稍後再試'),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: '查看你的信箱',
      subtitle: widget.email.isEmpty ? '註冊已送出，請回信箱確認驗證信' : widget.email,
      child: Column(
        key: const ValueKey('verify-pending-page'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.invitationError != null) ...[
            _InlineAuthMessage(
              message: '帳號已建立，但邀請加入未完成：${widget.invitationError}',
            ),
            const SizedBox(height: TpSpacing.s4),
          ],
          Text(
            '點開信中的連結即可完成驗證。若沒有收到，可重新寄送驗證信。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: TpSpacing.s6),
          OutlinedButton(
            key: const ValueKey('verify-pending-resend-button'),
            onPressed: _sending || widget.email.trim().isEmpty ? null : _resend,
            child: _sending
                ? const _ButtonProgressLabel('重寄驗證信')
                : const Text('重寄驗證信'),
          ),
          if (_message != null) ...[
            const SizedBox(height: TpSpacing.s3),
            Text(_message!, key: const ValueKey('verify-pending-message')),
          ],
          const SizedBox(height: TpSpacing.s3),
          TextButton(
            onPressed: () => context.go('/login'),
            child: const Text('回登入'),
          ),
        ],
      ),
    );
  }
}

/// Password-reset request page.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .requestPasswordReset(_emailController.text);
      if (mounted) setState(() => _submitted = true);
    } on Exception catch (error) {
      if (mounted) {
        setState(
          () => _error = _authErrorMessage(error, const {
            'FORGOT_PASSWORD_RATE_LIMITED': '重設請求過多，請幾分鐘後再試',
          }, '暫時無法處理，請稍後再試'),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return _AuthScaffold(
        title: '查看你的信箱',
        subtitle: '若 ${_emailController.text.trim()} 已註冊，重設連結已寄出',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(key: ValueKey('forgot-password-success'), '連結 1 小時內有效。'),
            const SizedBox(height: TpSpacing.s6),
            FilledButton(
              onPressed: () => context.go('/login'),
              child: const Text('回登入'),
            ),
          ],
        ),
      );
    }
    return _AuthScaffold(
      title: '重設密碼',
      subtitle: '輸入帳號 Email，我們會寄出重設連結',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              _InlineAuthMessage(
                key: const ValueKey('forgot-password-error'),
                message: _error!,
              ),
              const SizedBox(height: TpSpacing.s4),
            ],
            TextFormField(
              key: const ValueKey('forgot-password-email-field'),
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              enabled: !_submitting,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? '請輸入 Email' : null,
            ),
            const SizedBox(height: TpSpacing.s6),
            FilledButton(
              key: const ValueKey('forgot-password-submit-button'),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const _ButtonProgressLabel('寄出重設連結')
                  : const Text('寄出重設連結'),
            ),
            const SizedBox(height: TpSpacing.s3),
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('回登入'),
            ),
          ],
        ),
      ),
    );
  }
}

/// New-password form opened from a reset token link.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _submitting = false;
  bool _success = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;

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
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .resetPassword(
            token: widget.token,
            password: _passwordController.text,
          );
      if (mounted) setState(() => _success = true);
    } on Exception catch (error) {
      if (mounted) {
        setState(
          () => _error = _authErrorMessage(error, const {
            'RESET_TOKEN_INVALID': '重設連結無效或已過期',
            'RESET_TOKEN_MISSING': '重設連結缺少 token',
            'RESET_INVALID_PASSWORD': '密碼至少 8 字元',
          }, '暫時無法處理，請稍後再試'),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.token.trim().isEmpty) {
      return _AuthScaffold(
        title: '重設連結無效',
        subtitle: '請重新申請密碼重設信',
        child: FilledButton(
          onPressed: () => context.go('/login/forgot'),
          child: const Text('重新申請'),
        ),
      );
    }
    if (_success) {
      return _AuthScaffold(
        title: '密碼已更新',
        subtitle: '請使用新密碼登入',
        child: FilledButton(
          key: const ValueKey('reset-password-success'),
          onPressed: () => context.go('/login'),
          child: const Text('前往登入'),
        ),
      );
    }
    return _AuthScaffold(
      title: '設定新密碼',
      subtitle: '請輸入至少 8 字元的新密碼',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              _InlineAuthMessage(
                key: const ValueKey('reset-password-error'),
                message: _error!,
              ),
              const SizedBox(height: TpSpacing.s4),
            ],
            TextFormField(
              key: const ValueKey('reset-password-field'),
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              enabled: !_submitting,
              decoration: InputDecoration(
                labelText: '新密碼',
                helperText: '至少 8 個字元',
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? '顯示密碼' : '隱藏密碼',
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? CupertinoIcons.eye
                        : CupertinoIcons.eye_slash,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return '請輸入新密碼';
                if (value.length < 8) return '密碼至少 8 字元';
                return null;
              },
            ),
            const SizedBox(height: TpSpacing.s4),
            TextFormField(
              key: const ValueKey('reset-password-confirm-field'),
              controller: _confirmController,
              obscureText: _obscureConfirm,
              textInputAction: TextInputAction.done,
              enabled: !_submitting,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: '再次輸入新密碼',
                suffixIcon: IconButton(
                  tooltip: _obscureConfirm ? '顯示確認密碼' : '隱藏確認密碼',
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                  icon: Icon(
                    _obscureConfirm
                        ? CupertinoIcons.eye
                        : CupertinoIcons.eye_slash,
                  ),
                ),
              ),
              validator: (value) =>
                  value != _passwordController.text ? '兩次輸入的密碼不一致' : null,
            ),
            const SizedBox(height: TpSpacing.s6),
            FilledButton(
              key: const ValueKey('reset-password-submit-button'),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const _ButtonProgressLabel('更新密碼')
                  : const Text('更新密碼'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Email verification confirmation page opened from a verification token link.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _verifying = false;
  bool _success = false;
  String? _error;

  Future<void> _verify() async {
    if (widget.token.trim().isEmpty) {
      setState(() => _error = '驗證連結缺少 token');
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final ok = await ref
          .read(authRepositoryProvider)
          .verifyEmail(widget.token);
      if (mounted) {
        setState(() {
          _success = ok;
          _error = ok ? null : '驗證失敗，請重新開啟信中的連結';
        });
      }
    } on Exception catch (error) {
      if (mounted) {
        setState(
          () => _error = _authErrorMessage(error, const {
            'VERIFY_TOKEN_INVALID': '驗證連結無效或已過期',
            'VERIFY_TOKEN_MISSING': '驗證連結缺少 token',
          }, '驗證失敗，請稍後再試'),
        );
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: _success ? '信箱已驗證' : '確認信箱驗證',
      subtitle: _success ? '可以回到登入頁繼續使用 Tripline' : '點擊下方按鈕完成驗證',
      child: Column(
        key: const ValueKey('verify-email-page'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            _InlineAuthMessage(
              key: const ValueKey('verify-email-error'),
              message: _error!,
            ),
            const SizedBox(height: TpSpacing.s4),
          ],
          if (_success)
            FilledButton(
              key: const ValueKey('verify-email-success'),
              onPressed: () => context.go('/login?verified=1'),
              child: const Text('前往登入'),
            )
          else
            FilledButton(
              key: const ValueKey('verify-email-confirm-button'),
              onPressed: _verifying ? null : _verify,
              child: _verifying
                  ? const _ButtonProgressLabel('完成驗證')
                  : const Text('完成驗證'),
            ),
        ],
      ),
    );
  }
}

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: TpSpacing.s6,
              vertical: TpSpacing.s10,
            ),
            child: ConstrainedBox(
              key: const ValueKey('auth-card'),
              constraints: const BoxConstraints(
                maxWidth: AppContentWidth.authCard,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Tripline',
                    textAlign: TextAlign.center,
                    style: textTheme.displaySmall?.copyWith(
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: TpSpacing.s6),
                  Text(title, style: textTheme.headlineSmall),
                  const SizedBox(height: TpSpacing.s2),
                  Text(
                    subtitle,
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: TpSpacing.s6),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineAuthMessage extends StatelessWidget {
  const _InlineAuthMessage({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TpSpacing.s4,
        vertical: TpSpacing.s3,
      ),
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

class _ButtonProgressLabel extends StatelessWidget {
  const _ButtonProgressLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: TpSpacing.s2),
        Text(label),
      ],
    );
  }
}

String _authErrorMessage(
  Object error,
  Map<String, String> fallbackByCode,
  String defaultMessage,
) {
  if (error is ApiError) {
    if (_hasCjk(error.message)) return error.message;
    return fallbackByCode[error.code] ?? defaultMessage;
  }
  return '網路連線失敗，請稍後再試';
}

bool _hasCjk(String value) => RegExp(r'[一-鿿]').hasMatch(value);
