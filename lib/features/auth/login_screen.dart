/// 登入畫面：email + 密碼 → authStateProvider.login。
/// 登入成功後的跳轉由 router redirect 處理，不在此畫面導航。
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_error.dart';
import '../../api/oauth/oauth_login_service.dart';
import '../../api/oauth/oauth_providers.dart';
import '../../api/providers.dart';
import '../../app/adaptive_content.dart';
import '../../app/error_message.dart';
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
  bool _loginAttempted = false;
  bool _oauthLoading = false;
  String? _oauthError;

  /// 已知錯誤碼的繁中人話 fallback（server message 非繁中時使用）。
  static const _fallbackMessageByCode = <String, String>{
    'LOGIN_RATE_LIMITED': '登入嘗試次數過多，請稍後再試',
    'LOGIN_INVALID': 'Email 或密碼錯誤',
    'AUTH_NO_SESSION_COOKIE': '登入回應異常，請稍後再試',
  };

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_oauthLoading || ref.read(authStateProvider).isLoading) return;
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;
    setState(() => _loginAttempted = true);
    // 失敗訊息由 authStateProvider 的 AsyncError 呈現，不在此 throw
    await ref
        .read(authStateProvider.notifier)
        .login(_emailController.text.trim(), _passwordController.text);
    if (!mounted) return;
    // 登入成功(無 error)→ 結束 autofill 情境,iOS 才會跳出「儲存密碼到 Keychain」提示。
    if (!ref.read(authStateProvider).hasError) {
      TextInput.finishAutofillContext();
    }
  }

  /// OAuth PKCE 登入(系統瀏覽器 + loopback);成功後 invalidate authState → router 跳轉。
  Future<void> _oauthLogin() async {
    if (_oauthLoading || ref.read(authStateProvider).isLoading) return;
    setState(() {
      _oauthLoading = true;
      _oauthError = null;
    });
    try {
      await ref.read(oauthLoginServiceProvider).login();
      if (mounted) ref.invalidate(authStateProvider);
    } on OAuthLoginException catch (e) {
      if (mounted) setState(() => _oauthError = e.message);
    } on Exception {
      if (mounted) setState(() => _oauthError = 'OAuth 登入失敗,請稍後再試');
    } finally {
      if (mounted) setState(() => _oauthLoading = false);
    }
  }

  /// 錯誤訊息：server 回繁中直接用；否則查 code 對照表；再不然通用訊息。
  String _loginErrorMessage(Object error) {
    if (error is ApiError) {
      if (hasCjk(error.message)) return error.message;
      return _fallbackMessageByCode[error.code] ?? '登入失敗，請稍後再試';
    }
    return '登入失敗，請檢查網路後再試';
  }

  void _togglePasswordVisibility() =>
      setState(() => _obscurePassword = !_obscurePassword);

  @override
  Widget build(BuildContext context) => _buildContent(context);

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final successColor = theme.brightness == Brightness.dark
        ? TpSystemColorsDark.success
        : TpSystemColorsLight.success;
    final authState = ref.watch(authStateProvider);
    final isSubmitting = authState.isLoading;
    final isBusy = isSubmitting || _oauthLoading;
    final highContrast = MediaQuery.highContrastOf(context);
    final emailVerified =
        GoRouterState.of(context).uri.queryParameters['verified'] == '1';

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
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Tripline',
                        textAlign: TextAlign.center,
                        style: textTheme.displaySmall?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: TpSpacing.s2),
                      Text(
                        '把每段旅程，安排得剛剛好',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: TpSpacing.s8),
                      if (emailVerified) ...[
                        Semantics(
                          key: const ValueKey('login-verified-banner'),
                          container: true,
                          liveRegion: true,
                          label: '成功：信箱已驗證，請登入繼續。',
                          excludeSemantics: true,
                          child: Container(
                            key: const ValueKey('login-verified-surface'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: TpSpacing.s4,
                              vertical: TpSpacing.s3,
                            ),
                            decoration: BoxDecoration(
                              color: successColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(TpRadius.md),
                              border: highContrast
                                  ? Border.all(color: colorScheme.onSurface)
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  CupertinoIcons.check_mark_circled_solid,
                                  color: successColor,
                                ),
                                const SizedBox(width: TpSpacing.s2),
                                Expanded(
                                  child: Text(
                                    '信箱已驗證，請登入繼續。',
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: TpSpacing.s4),
                      ],
                      if (_loginAttempted && authState.hasError) ...[
                        Semantics(
                          key: const ValueKey('login-error-banner'),
                          container: true,
                          liveRegion: true,
                          child: Container(
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
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.error,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: TpSpacing.s4),
                      ],
                      TextFormField(
                        key: const ValueKey('login-email-field'),
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        autofillHints: const [
                          AutofillHints.username,
                          AutofillHints.email,
                        ],
                        textInputAction: TextInputAction.next,
                        enabled: !isBusy,
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
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        enabled: !isBusy,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: '密碼',
                          suffixIcon: Semantics(
                            key: const ValueKey(
                              'login-password-visibility-toggle',
                            ),
                            button: true,
                            label: _obscurePassword ? '顯示密碼' : '隱藏密碼',
                            onTap: _togglePasswordVisibility,
                            child: Tooltip(
                              message: _obscurePassword ? '顯示密碼' : '隱藏密碼',
                              excludeFromSemantics: true,
                              child: IconButton(
                                onPressed: _togglePasswordVisibility,
                                icon: Icon(
                                  _obscurePassword
                                      ? CupertinoIcons.eye
                                      : CupertinoIcons.eye_slash,
                                ),
                              ),
                            ),
                          ),
                        ),
                        validator: (value) =>
                            (value == null || value.isEmpty) ? '請輸入密碼' : null,
                      ),
                      const SizedBox(height: TpSpacing.s6),
                      FilledButton(
                        key: const ValueKey('login-submit-button'),
                        onPressed: isBusy ? null : _submit,
                        child: isSubmitting
                            ? const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox.square(
                                    dimension: 18,
                                    child: CupertinoActivityIndicator(),
                                  ),
                                  SizedBox(width: TpSpacing.s2),
                                  Text('登入中'),
                                ],
                              )
                            : const Text('登入'),
                      ),
                      if (ref.watch(oauthEnabledProvider)) ...[
                        const SizedBox(height: TpSpacing.s4),
                        if (_oauthError != null) ...[
                          Semantics(
                            container: true,
                            liveRegion: true,
                            child: Text(
                              _oauthError!,
                              textAlign: TextAlign.center,
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.error,
                              ),
                            ),
                          ),
                          const SizedBox(height: TpSpacing.s2),
                        ],
                        OutlinedButton(
                          key: const ValueKey('login-oauth-button'),
                          onPressed: isBusy ? null : _oauthLogin,
                          child: _oauthLoading
                              ? const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox.square(
                                      dimension: 18,
                                      child: CupertinoActivityIndicator(),
                                    ),
                                    SizedBox(width: TpSpacing.s2),
                                    Text('OAuth 登入中'),
                                  ],
                                )
                              : const Text('用 OAuth 登入'),
                        ),
                      ],
                      const SizedBox(height: TpSpacing.s3),
                      TextButton(
                        key: const ValueKey('login-forgot-password-link'),
                        onPressed: isBusy
                            ? null
                            : () => context.go('/login/forgot'),
                        child: const Text('忘記密碼？'),
                      ),
                      TextButton(
                        key: const ValueKey('login-signup-link'),
                        onPressed: isBusy ? null : () => context.go('/signup'),
                        child: const Text('沒有帳號，建立帳號'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
