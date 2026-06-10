/// 登入畫面：email + 密碼 → authStateProvider.login。
/// 登入成功後的跳轉由 router redirect 處理，不在此畫面導航。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_error.dart';
import '../../api/providers.dart';
import '../../theme/tokens.dart';

/// 密碼登入畫面（/login，shell 外）。
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  /// 已知錯誤碼的繁中人話 fallback（server message 非繁中時使用）。
  static const _fallbackMessageByCode = <String, String>{
    'LOGIN_RATE_LIMITED': '登入嘗試次數過多，請稍後再試',
    'LOGIN_INVALID': 'Email 或密碼錯誤',
    'AUTH_NO_SESSION_COOKIE': '登入回應異常，請稍後再試',
  };

  static final _cjkPattern = RegExp(r'[一-鿿]');

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;
    // 失敗訊息由 authStateProvider 的 AsyncError 呈現，不在此 throw
    await ref.read(authStateProvider.notifier).login(
          _emailController.text.trim(),
          _passwordController.text,
        );
  }

  /// 錯誤訊息：server 回繁中直接用；否則查 code 對照表；再不然通用訊息。
  String _loginErrorMessage(Object error) {
    if (error is ApiError) {
      if (_cjkPattern.hasMatch(error.message)) return error.message;
      return _fallbackMessageByCode[error.code] ?? '登入失敗，請稍後再試';
    }
    return '登入失敗，請檢查網路後再試';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final authState = ref.watch(authStateProvider);
    final isSubmitting = authState.isLoading;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: TpSpacing.s6,
              vertical: TpSpacing.s10,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 品牌區（奶油底由 scaffold surface 提供）
                    Text(
                      'Tripline',
                      textAlign: TextAlign.center,
                      style: textTheme.displaySmall
                          ?.copyWith(color: colorScheme.primary),
                    ),
                    const SizedBox(height: TpSpacing.s2),
                    Text(
                      '把每段旅程，安排得剛剛好',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyLarge
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: TpSpacing.s8),
                    if (authState.hasError) ...[
                      Container(
                        key: const ValueKey('login-error-banner'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: TpSpacing.s4,
                          vertical: TpSpacing.s3,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(TpRadius.md),
                        ),
                        child: Text(
                          _loginErrorMessage(authState.error!),
                          style: textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.error),
                        ),
                      ),
                      const SizedBox(height: TpSpacing.s4),
                    ],
                    TextFormField(
                      key: const ValueKey('login-email-field'),
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
                      key: const ValueKey('login-password-field'),
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      enabled: !isSubmitting,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: '密碼',
                        suffixIcon: IconButton(
                          key: const ValueKey(
                            'login-password-visibility-toggle',
                          ),
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
                      validator: (value) =>
                          (value == null || value.isEmpty) ? '請輸入密碼' : null,
                    ),
                    const SizedBox(height: TpSpacing.s6),
                    FilledButton(
                      key: const ValueKey('login-submit-button'),
                      onPressed: isSubmitting ? null : _submit,
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('登入'),
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
