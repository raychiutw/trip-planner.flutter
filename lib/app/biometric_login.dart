/// 生物辨識登入：用 Face ID／Touch ID 保護本機的登入憑證（ADR-0014）。
///
/// 開啟後 refresh token 改存成「讀取時要通過生物辨識」的 Keychain／Keystore 項目，
/// 冷啟動讀取時由系統跳出驗證；App 不保管密碼。關閉會清掉 refresh token 並登出。
/// 與 App 鎖（[appLockProvider]）互相獨立。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'
    show AppLifecycleListener, AppLifecycleState, WidgetsBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/oauth/oauth_login_service.dart';
import '../api/oauth/oauth_protocol.dart';
import '../api/oauth/oauth_providers.dart';
import '../api/oauth/oauth_token_store.dart';
import '../api/providers.dart';
import '../models/user.dart';
import 'app_lock.dart';

const _promptedKey = 'bio_login_prompted';

@immutable
class BiometricLoginState {
  const BiometricLoginState({
    this.enabled = false,
    this.promptPending = false,
    this.passcodeOnlyNotice = false,
    this.reauthBusy = false,
    this.reauthNotice,
  });

  /// refresh token 目前受生物辨識保護。
  final bool enabled;

  /// 登入成功後，要詢問是否開啟。
  final bool promptPending;

  /// web 要求開啟、但這支手機只有裝置密碼：提示已用一般方式登入。
  final bool passcodeOnlyNotice;

  /// 設定頁的重新驗證流程進行中：開關要禁用，避免重複觸發。
  final bool reauthBusy;

  /// 重新驗證被拒絕時給使用者看的一句話（例如帳號不同）。
  final String? reauthNotice;

  BiometricLoginState copyWith({
    bool? enabled,
    bool? promptPending,
    bool? passcodeOnlyNotice,
    bool? reauthBusy,
    String? reauthNotice,
    bool clearReauthNotice = false,
  }) => BiometricLoginState(
    enabled: enabled ?? this.enabled,
    promptPending: promptPending ?? this.promptPending,
    passcodeOnlyNotice: passcodeOnlyNotice ?? this.passcodeOnlyNotice,
    reauthBusy: reauthBusy ?? this.reauthBusy,
    reauthNotice: clearReauthNotice ? null : reauthNotice ?? this.reauthNotice,
  );
}

class BiometricLoginController extends Notifier<BiometricLoginState> {
  bool _inFlight = false;

  /// 瀏覽器登入進行中：登入完成的詢問交給 [signInWithBrowser] 依旗標決定。
  /// 保留理由：authState 在 login() 回傳「是否開啟」之前就先變成已登入，
  /// [_onAuth] 若不略過會在旗標處理前先排出詢問。
  bool _signingIn = false;

  @override
  BiometricLoginState build() {
    ref.listen(authStateProvider, (_, next) => _onAuth(next));
    return BiometricLoginState(enabled: _storeEnabled);
  }

  bool get _storeEnabled =>
      ref.read(oauthTokenStoreProvider).protection == TokenProtection.biometric;

  void _onAuth(AsyncValue<UserInfo?> next) {
    if (next is! AsyncData<UserInfo?>) return;
    if (next.value == null) {
      // 登出：待答的詢問作廢，保護等級已隨憑證一起重置。
      state = BiometricLoginState(enabled: _storeEnabled);
      return;
    }
    state = state.copyWith(enabled: _storeEnabled);
    if (!_signingIn) unawaited(_maybePrompt());
  }

  /// 登入成功後只問一次；裝置沒有生物辨識或已經開啟就不問。
  Future<void> _maybePrompt() async {
    if (state.enabled) return;
    if (await _read(_promptedKey) == '1') return;
    final kind = await ref.read(biometricAuthenticatorProvider).availableKind();
    // 沒有生物辨識（只有裝置密碼）時不問：裝置密碼保護已是預設。
    if (!kind.hasBiometric) return;
    if (ref.mounted) state = state.copyWith(promptPending: true);
  }

  /// 瀏覽器登入：授權網址帶按鈕名稱提示；callback 若帶 `biometric_intent=enable`，
  /// 登入完成後走 [enable]（先過生物辨識才改保護），並視為已問過、不再詢問。
  /// 沒有旗標時與以往相同（[_onAuth] 照常排詢問）。
  Future<void> signInWithBrowser() async {
    final kind = await ref.read(biometricAuthenticatorProvider).availableKind();
    _signingIn = true;
    final bool enableIntent;
    try {
      enableIntent = await ref
          .read(authStateProvider.notifier)
          .signInWithBrowser(biometricHint: _hintFor(kind));
    } finally {
      _signingIn = false;
    }
    if (!ref.mounted || ref.read(authStateProvider).value == null) return;
    if (!enableIntent) return unawaited(_maybePrompt());
    await _write(_promptedKey, '1');
    if (!kind.hasBiometric) {
      if (ref.mounted) state = state.copyWith(passcodeOnlyNotice: true);
      return;
    }
    await enable(); // 取消或失敗維持原狀，不報錯
  }

  /// 設定頁開啟（[turnOn] 為 true）或關閉生物辨識登入（ADR-0018）：先重新驗證授權
  /// （web 頁重新輸入密碼、且必須是目前帳號），回來再通過一次生物辨識才套用。
  /// 取消、帳號不同、任何失敗都維持原狀；重新驗證本身不改變目前的登入。
  Future<void> reauthenticate({required bool turnOn}) async {
    if (state.reauthBusy) return;
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    state = state.copyWith(reauthBusy: true, clearReauthNotice: true);
    try {
      final kind = await ref
          .read(biometricAuthenticatorProvider)
          .availableKind();
      // 沒有生物辨識（只有裝置密碼）時沒東西可開；關閉不受裝置能力限制。
      if (turnOn && !kind.hasBiometric) return;
      try {
        await ref
            .read(oauthLoginServiceProvider)
            .reauthenticate(
              intent: turnOn
                  ? OAuthProtocol.intentEnable
                  : OAuthProtocol.intentDisable,
              expectedAccount: user.id,
              biometricHint: _hintFor(kind),
            );
      } on OAuthLoginException catch (e) {
        if (!e.cancelled && ref.mounted) {
          state = state.copyWith(reauthNotice: e.userMessage);
        }
        return;
      }
      if (!ref.mounted) return;
      if (turnOn) {
        await enable();
      } else {
        await disable();
      }
    } finally {
      if (ref.mounted) state = state.copyWith(reauthBusy: false);
    }
  }

  void clearReauthNotice() => state = state.copyWith(clearReauthNotice: true);

  void clearPasscodeOnlyNotice() =>
      state = state.copyWith(passcodeOnlyNotice: false);

  /// 裝置只有密碼或沒有生物辨識時不帶，web 就不顯示專門鈕。
  static String? _hintFor(BiometricKind? kind) => switch (kind) {
    BiometricKind.faceId => OAuthProtocol.hintFaceId,
    BiometricKind.touchId => OAuthProtocol.hintTouchId,
    BiometricKind.biometric => OAuthProtocol.hintGeneric,
    BiometricKind.passcode || null => null,
  };

  /// 回答登入後的詢問；不論選哪個都記為已問過。
  Future<void> answerPrompt({required bool enable}) async {
    state = state.copyWith(promptPending: false);
    await _write(_promptedKey, '1');
    if (enable) await this.enable();
  }

  /// 開啟：先驗證身分，通過才把 refresh token 改存成受生物辨識保護。
  Future<bool> enable() async {
    if (_inFlight) return false;
    _inFlight = true;
    try {
      final auth = ref.read(biometricAuthenticatorProvider);
      final waitForeground = ref.read(foregroundWaiterProvider);
      // 從 web 授權頁回來的當下 App 還沒穩定，先等前景；仍被系統中斷就再等一次重試一次。
      await waitForeground();
      var outcome = await auth.authenticate(reason: '開啟生物辨識登入');
      if (outcome == BiometricOutcome.interrupted) {
        await waitForeground();
        outcome = await auth.authenticate(reason: '開啟生物辨識登入');
      }
      if (outcome != BiometricOutcome.success) {
        // 使用者自己取消不打擾；其他失敗要讓人知道，不能開關沒變又沒有任何訊息。
        if (outcome != BiometricOutcome.cancelled && ref.mounted) {
          state = state.copyWith(
            reauthNotice:
                '生物辨識驗證沒有通過，沒有開啟生物辨識登入'
                '（原因碼：${auth.lastFailureCode ?? 'unknown'}）。',
          );
        }
        return false;
      }
      final stored = await ref
          .read(oauthTokenStoreProvider)
          .setProtection(TokenProtection.biometric);
      if (ref.mounted) state = state.copyWith(enabled: stored);
      return stored;
    } finally {
      _inFlight = false;
    }
  }

  /// 關閉：先驗證身分，通過才清掉 refresh token 並登出。
  Future<bool> disable() async {
    if (_inFlight) return false;
    _inFlight = true;
    try {
      final outcome = await ref
          .read(biometricAuthenticatorProvider)
          .authenticate(reason: '驗證身分以關閉生物辨識登入');
      if (outcome != BiometricOutcome.success) return false;
      await ref.read(authStateProvider.notifier).logout(clear: true);
      return true;
    } finally {
      _inFlight = false;
    }
  }

  Future<String?> _read(String key) async {
    try {
      return await ref.read(settingsStoreProvider).read(key);
    } catch (_) {
      return null;
    }
  }

  Future<void> _write(String key, String value) async {
    try {
      await ref.read(settingsStoreProvider).write(key, value);
    } catch (_) {}
  }
}

/// 開啟流程要驗證指紋前，等 App 回到前景（從 web 授權頁回來的當下 Activity 還在切換）。
final foregroundWaiterProvider = Provider<Future<void> Function()>(
  (ref) => waitUntilForeground,
);

/// 等 App 回到前景（回來後再多等一小段穩定時間）；一直沒回來就逾時放行（不能永遠卡住）。
/// 從 Chrome 授權分頁回來的當下，Activity 的生命週期還在抖動，這時叫指紋驗證
/// 會被系統中斷（local_auth 回 systemCanceled／uiUnavailable）。
Future<void> waitUntilForeground() async {
  const settle = Duration(milliseconds: 250);
  const timeout = Duration(seconds: 5);
  final binding = WidgetsBinding.instance;
  final state = binding.lifecycleState;
  // 已在前景就不用等；只有真的等過背景，才多給一小段穩定時間。
  if (state == null || state == AppLifecycleState.resumed) return;
  final resumed = Completer<void>();
  final listener = AppLifecycleListener(
    onResume: () {
      if (!resumed.isCompleted) resumed.complete();
    },
  );
  try {
    await resumed.future.timeout(timeout, onTimeout: () {});
  } finally {
    listener.dispose();
  }
  await Future<void>.delayed(settle);
}

final biometricLoginProvider =
    NotifierProvider<BiometricLoginController, BiometricLoginState>(
      BiometricLoginController.new,
    );
