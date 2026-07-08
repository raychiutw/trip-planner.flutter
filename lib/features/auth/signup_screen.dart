/// 註冊畫面：email/password/displayName → `/oauth/signup`。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_error.dart';
import '../../api/providers.dart';
import '../../theme/tokens.dart';

/// `/signup` shell 外註冊頁。
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key, this.invitationToken});

  /// 若從共編邀請進入，帶給 signup API 讓後端 best-effort accept。
  final String? invitationToken;

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  bool _obscurePassword = true;

  static final _cjkPattern = RegExp(r'[一-鿿]');
  static const _fallbackMessageByCode = <String, String>{
    'SIGNUP_INVALID_EMAIL': '電子郵件格式無效',
    'SIGNUP_PASSWORD_TOO_SHORT': '密碼至少 8 字元，並包含字母與數字',
    'SIGNUP_INVALID_PASSWORD': '密碼至少 8 字元，並包含字母與數字',
    'SIGNUP_PASSWORD_FORMAT': '密碼至少 8 字元，並包含字母與數字',
    'SIGNUP_EMAIL_TAKEN': '此 Email 已註冊，請改用登入或忘記密碼。',
    'SIGNUP_RATE_LIMITED': '註冊請求過多，請稍後再試',
    'AUTH_NO_SESSION_COOKIE': '註冊回應異常，請稍後再試',
  };

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

    final result = await ref
        .read(authStateProvider.notifier)
        .signup(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _displayNameController.text.trim(),
          invitationToken: widget.invitationToken,
        );
    if (!mounted || result == null) return;

    try {
      await ref
          .read(authRepositoryProvider)
          .sendVerificationEmail(result.email);
    } catch (_) {
      // best-effort；失敗仍讓使用者進 check-email 頁手動重寄。
    }
    if (!mounted) return;

    final joinedTrip = result.joinedTrip;
    if (joinedTrip != null && joinedTrip.id.isNotEmpty) {
      context.go('/trips/${Uri.encodeComponent(joinedTrip.id)}');
      return;
    }

    final query = <String, String>{'email': result.email};
    final invitationError = result.invitationError;
    if (invitationError != null && invitationError.isNotEmpty) {
      query['invitationError'] = invitationError;
    }
    context.go(
      Uri(path: '/signup/check-email', queryParameters: query).toString(),
    );
  }

  String _errorMessage(Object error) {
    if (error is ApiError) {
      if (_cjkPattern.hasMatch(error.message)) return error.message;
      return _fallbackMessageByCode[error.code] ?? '註冊失敗，請稍後再試';
    }
    return '註冊失敗，請檢查網路後再試';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final authState = ref.watch(authStateProvider);
    final isSubmitting = authState.isLoading;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/login')),
        title: const Text('建立帳號'),
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
                      'Tripline',
                      textAlign: TextAlign.center,
                      style: textTheme.displaySmall?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: TpSpacing.s2),
                    Text(
                      '建立帳號，開始同步你的旅行計畫',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: TpSpacing.s6),
                    if (authState.hasError) ...[
                      _AuthBanner(
                        key: const ValueKey('signup-error-banner'),
                        message: _errorMessage(authState.error!),
                        isError: true,
                      ),
                      const SizedBox(height: TpSpacing.s4),
                    ],
                    TextFormField(
                      key: const ValueKey('signup-email-field'),
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      enabled: !isSubmitting,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? '請輸入 Email'
                          : null,
                    ),
                    const SizedBox(height: TpSpacing.s4),
                    TextFormField(
                      key: const ValueKey('signup-password-field'),
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      enabled: !isSubmitting,
                      decoration: InputDecoration(
                        labelText: '密碼',
                        helperText: '至少 8 字元',
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword ? '顯示密碼' : '隱藏密碼',
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return '請輸入密碼';
                        if (value.length < 8) return '密碼至少 8 字元';
                        return null;
                      },
                    ),
                    const SizedBox(height: TpSpacing.s4),
                    TextFormField(
                      key: const ValueKey('signup-display-name-field'),
                      controller: _displayNameController,
                      textInputAction: TextInputAction.done,
                      enabled: !isSubmitting,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        labelText: '名稱',
                        helperText: '選填',
                      ),
                    ),
                    const SizedBox(height: TpSpacing.s6),
                    FilledButton(
                      key: const ValueKey('signup-submit-button'),
                      onPressed: isSubmitting ? null : _submit,
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('建立帳號'),
                    ),
                    const SizedBox(height: TpSpacing.s3),
                    TextButton(
                      onPressed: isSubmitting
                          ? null
                          : () => context.go('/login'),
                      child: const Text('已有帳號？直接登入'),
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
}

class _AuthBanner extends StatelessWidget {
  const _AuthBanner({super.key, required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TpSpacing.s4,
        vertical: TpSpacing.s3,
      ),
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
