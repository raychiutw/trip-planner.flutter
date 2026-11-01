/// 登入畫面：用系統瀏覽器登入（OAuth PKCE），不在 App 內輸入密碼（ADR-0014）。
/// 登入成功後的跳轉由 router redirect 處理，不在此畫面導航。
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/oauth/oauth_login_service.dart';
import '../../api/providers.dart';
import '../../app/adaptive_content.dart';
import '../../app/app_lock.dart';
import '../../theme/tokens.dart';

/// 登入畫面（/login，shell 外）。
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _attempted = false;

  Future<void> _browserLogin() async {
    if (ref.read(authStateProvider).isLoading) return;
    setState(() => _attempted = true);
    // 失敗訊息由 authStateProvider 的 AsyncError 呈現；使用者取消則維持未登入。
    await ref.read(authStateProvider.notifier).signInWithBrowser();
  }

  /// 受保護的登入憑證解鎖（跳出 Face ID／Touch ID）。
  Future<void> _unlock() async {
    if (ref.read(authStateProvider).isLoading) return;
    setState(() => _attempted = true);
    await ref.read(authStateProvider.notifier).unlock();
  }

  String _errorMessage(Object error) =>
      error is OAuthLoginException ? error.userMessage : 'Tripline 登入失敗，請稍後再試';

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
    final isBusy = authState.isLoading;
    final locked = ref.watch(authLockedProvider);
    final biometricKind = ref.watch(appLockKindProvider).value;
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'Tripline',
                      textAlign: TextAlign.center,
                      style: textTheme.displaySmall?.copyWith(
                        color: colorScheme.onSurface,
                      ),
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
                  // 從首頁直接登入失敗時沒有按過本頁的按鈕，登入失敗的錯誤仍要顯示。
                  if (authState.hasError &&
                      (_attempted ||
                          authState.error is OAuthLoginException)) ...[
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
                          _errorMessage(authState.error!),
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: TpSpacing.s4),
                  ],
                  if (locked) ...[
                    FilledButton.icon(
                      key: const ValueKey('login-unlock-button'),
                      onPressed: isBusy ? null : _unlock,
                      icon: Icon(
                        biometricKind == BiometricKind.faceId
                            ? CupertinoIcons.person_crop_square
                            : CupertinoIcons.lock_shield,
                      ),
                      label: Text('使用 ${biometricKind.lockLabel} 解鎖'),
                    ),
                    const SizedBox(height: TpSpacing.s3),
                  ],
                  (locked
                      ? OutlinedButton(
                          key: const ValueKey('login-browser-button'),
                          onPressed: isBusy ? null : _browserLogin,
                          child: const Text('改用瀏覽器登入'),
                        )
                      : FilledButton(
                          key: const ValueKey('login-browser-button'),
                          onPressed: isBusy ? null : _browserLogin,
                          child: isBusy
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
                              : const Text('使用瀏覽器登入'),
                        )),
                  const SizedBox(height: TpSpacing.s3),
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
    );
  }
}
