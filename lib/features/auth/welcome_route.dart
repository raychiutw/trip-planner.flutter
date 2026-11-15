/// 歡迎頁的登入邏輯（歡迎頁是唯一登入入口，ADR-0014／ADR-0017）。
///
/// - 有保留憑證（登出後保留）或憑證被鎖，且裝置有生物辨識：登入鈕＝解鎖一次，
///   成功由 router redirect 進 App；取消留在原頁；憑證失效顯示訊息。
/// - 其餘：開系統瀏覽器登入，失敗在本頁顯示錯誤。
/// - 冷啟動讀憑證時系統本身會跳一次驗證；取消就停在這裡，等使用者按登入鈕。
library;

import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/oauth/oauth_login_service.dart';
import '../../api/providers.dart';
import '../../app/app_feedback.dart';
import '../../app/app_lock.dart';
import '../../app/biometric_login.dart';
import '../../app/forget_this_phone.dart';
import 'welcome_screen.dart';

class WelcomeRoute extends ConsumerStatefulWidget {
  const WelcomeRoute({super.key, this.emailVerified = false});

  final bool emailVerified;

  @override
  ConsumerState<WelcomeRoute> createState() => _WelcomeRouteState();
}

class _WelcomeRouteState extends ConsumerState<WelcomeRoute> {
  /// 登入／解鎖進行中（含成功後、router 換頁前）：以進度畫面蓋住歡迎頁內容。
  bool _busy = false;

  /// 執行登入／解鎖並維持進度畫面。成功（已登入）時不撤掉：router 會換頁，
  /// 提早撤掉會在轉址前多露出一格歡迎頁。取消、失敗、例外都要復原。
  Future<void> _guarded(Future<void> Function() action) async {
    if (mounted) setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) showAppError(context, _message(error));
    } finally {
      if (mounted && ref.read(authStateProvider).value == null) {
        setState(() => _busy = false);
      }
    }
  }

  /// 有保留憑證或憑證被鎖，而且裝置有生物辨識：登入鈕走解鎖。
  Future<bool> _canUnlock() async {
    final kept = await ref.read(keptBiometricAccountProvider.future);
    if (kept == null && !ref.read(authLockedProvider)) return false;
    return (await ref.read(appLockKindProvider.future)).hasBiometric;
  }

  Future<void> _login() async {
    if (_busy || ref.read(authStateProvider).isLoading) return;
    await _guarded(() async {
      if (await _canUnlock()) {
        if (mounted) await _unlock();
      } else if (mounted) {
        await _browserLogin();
      }
    });
  }

  Future<void> _unlock() async {
    await ref.read(authStateProvider.notifier).unlock();
    if (!mounted) return;
    // 取消不是錯誤（unlock 回到未登入、沒有 error）；憑證失效才要說明。
    final error = ref.read(authStateProvider).error;
    if (error != null) showAppError(context, _message(error));
  }

  Future<void> _browserLogin() async {
    await ref.read(biometricLoginProvider.notifier).signInWithBrowser();
    if (!mounted) return;
    final error = ref.read(authStateProvider).error;
    if (error != null) showAppError(context, _message(error));
  }

  String _message(Object error) => switch (error) {
    OAuthLoginException() => error.userMessage,
    KeptCredentialInvalid() => error.userMessage,
    _ => 'Tripline 登入失敗，請稍後再試',
  };

  @override
  Widget build(BuildContext context) {
    final kept = ref.watch(keptBiometricAccountProvider).value;
    // 只有裝置密碼的手機沒有解鎖入口，不標示帳號也不提供忘記這支手機。
    final showKept =
        kept != null && (ref.watch(appLockKindProvider).value).hasBiometric;
    return Stack(
      children: [
        Positioned.fill(
          child: WelcomeScreen(
            onLogin: _login,
            onSignup: () => context.go('/signup'),
            emailVerified: widget.emailVerified,
            keptAccount: showKept ? kept : null,
            onForgetPhone: showKept
                ? () => confirmAndForgetThisPhone(context, ref)
                : null,
          ),
        ),
        if (_busy) const Positioned.fill(child: _LoginProgress()),
      ],
    );
  }
}

/// 不透明的登入進度畫面（蓋住歡迎頁內容、吃掉點擊）。
class _LoginProgress extends StatelessWidget {
  const _LoginProgress();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      key: const ValueKey('welcome-login-progress'),
      container: true,
      liveRegion: true,
      label: '登入中',
      child: ColoredBox(
        color: theme.colorScheme.surface,
        child: const Center(child: CupertinoActivityIndicator()),
      ),
    );
  }
}
