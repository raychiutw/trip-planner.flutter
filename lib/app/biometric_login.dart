/// 生物辨識登入：用 Face ID／Touch ID／指紋保護本機的登入憑證（ADR-0019／ADR-0020）。
///
/// 開啟後 refresh token 改存成「讀取時要通過生物辨識」的 Keychain／Keystore 項目，
/// 冷啟動讀取時由系統跳出驗證；App 不保管密碼。登出時保留憑證與 DPoP 金鑰、不撤銷，
/// 之後在歡迎頁按「登入」通過生物辨識即可回來（ADR-0020）。
/// 開啟的入口：web 登入頁的生物辨識鈕（callback 帶 `biometric_intent=enable`）或設定頁
/// 開關，都只驗一次生物辨識；關閉改回一般保存，不驗證、不登出。
/// 與 App 鎖（[appLockProvider]）互相獨立。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'
    show AppLifecycleListener, AppLifecycleState, WidgetsBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/oauth/oauth_protocol.dart';
import '../api/oauth/oauth_providers.dart';
import '../api/oauth/oauth_token_store.dart';
import '../api/providers.dart';
import '../models/user.dart';
import 'app_lock.dart';

@immutable
class BiometricLoginState {
  const BiometricLoginState({
    this.enabled = false,
    this.passcodeOnlyNotice = false,
    this.enableFailureMessage,
  });

  /// refresh token 目前受生物辨識保護。
  final bool enabled;

  /// web 要求開啟、但這支手機只有裝置密碼：提示已用一般方式登入。
  final bool passcodeOnlyNotice;

  /// 開啟生物辨識登入沒有成功時給使用者看的一句話（使用者自己取消不顯示）。
  final String? enableFailureMessage;

  BiometricLoginState copyWith({
    bool? enabled,
    bool? passcodeOnlyNotice,
    String? enableFailureMessage,
    bool clearEnableFailureMessage = false,
  }) => BiometricLoginState(
    enabled: enabled ?? this.enabled,
    passcodeOnlyNotice: passcodeOnlyNotice ?? this.passcodeOnlyNotice,
    enableFailureMessage: clearEnableFailureMessage
        ? null
        : enableFailureMessage ?? this.enableFailureMessage,
  );
}

class BiometricLoginController extends Notifier<BiometricLoginState> {
  bool _inFlight = false;

  /// 登入狀態的世代編號：登出（含 refresh 被拒的過期）或換帳號就加一。
  /// 生物辨識驗證回來時世代已變，代表驗證期間登入狀態改變，結果要丟棄（ADR-0019）。
  int _generation = 0;
  String? _userId;

  @override
  BiometricLoginState build() {
    ref.listen(authStateProvider, (_, next) => _onAuth(next));
    return BiometricLoginState(enabled: _storeEnabled);
  }

  bool get _storeEnabled =>
      ref.read(oauthTokenStoreProvider).protection == TokenProtection.biometric;

  void _onAuth(AsyncValue<UserInfo?> next) {
    if (next is! AsyncData<UserInfo?>) return;
    final userId = next.value?.id;
    if (userId == null || userId != _userId) _generation++;
    _userId = userId;
    if (userId == null) {
      // 登出：保護等級已隨憑證一起重置，提示也作廢。
      state = BiometricLoginState(enabled: _storeEnabled);
      return;
    }
    state = state.copyWith(enabled: _storeEnabled);
  }

  /// 瀏覽器登入：授權網址帶按鈕名稱提示；callback 若帶 `biometric_intent=enable`，
  /// 登入完成後直接驗證一次生物辨識（[enable]），取消則維持一般保存、登入照常完成。
  Future<void> signInWithBrowser() async {
    final kind = await ref
        .read(biometricAuthenticatorProvider)
        .biometricLoginKind();
    final enableIntent = await ref
        .read(authStateProvider.notifier)
        .signInWithBrowser(biometricHint: _hintFor(kind));
    if (!enableIntent || !ref.mounted) return;
    if (ref.read(authStateProvider).value == null) return;
    if (!kind.hasBiometric) {
      state = state.copyWith(passcodeOnlyNotice: true);
      return;
    }
    await enable(); // 取消或失敗維持一般保存，不影響登入
  }

  void clearEnableFailureMessage() =>
      state = state.copyWith(clearEnableFailureMessage: true);

  void clearPasscodeOnlyNotice() =>
      state = state.copyWith(passcodeOnlyNotice: false);

  /// 裝置只有密碼或沒有生物辨識時不帶，web 就不顯示專門鈕。
  static String? _hintFor(BiometricKind? kind) => switch (kind) {
    BiometricKind.faceId => OAuthProtocol.hintFaceId,
    BiometricKind.touchId => OAuthProtocol.hintTouchId,
    BiometricKind.biometric => OAuthProtocol.hintGeneric,
    BiometricKind.passcode || null => null,
  };

  /// 開啟：驗證一次生物辨識（不接受改用裝置密碼），通過才把 refresh token 改存成
  /// 受生物辨識保護。驗證期間登入狀態改變（登出、過期、換帳號）就丟棄結果。
  Future<bool> enable() async {
    if (_inFlight) return false;
    _inFlight = true;
    try {
      if (ref.read(authStateProvider).value == null) return false;
      final generation = _generation;
      final auth = ref.read(biometricAuthenticatorProvider);
      final waitForeground = ref.read(foregroundWaiterProvider);
      // 從 web 授權頁回來的當下 App 還沒穩定，先等前景；仍被系統中斷就再等一次重試一次。
      await waitForeground();
      var outcome = await _verify(auth);
      if (outcome == BiometricOutcome.interrupted) {
        await waitForeground();
        outcome = await _verify(auth);
      }
      if (!ref.mounted || generation != _generation) return false;
      if (outcome != BiometricOutcome.success) {
        // 使用者自己取消不打擾；其他失敗要讓人知道，不能開關沒變又沒有任何訊息。
        if (outcome != BiometricOutcome.cancelled) {
          state = state.copyWith(
            enableFailureMessage:
                '生物辨識驗證沒有通過，沒有開啟生物辨識登入'
                '（原因碼：${auth.lastFailureCode ?? 'unknown'}）。',
          );
        }
        return false;
      }
      final stored = await ref
          .read(oauthTokenStoreProvider)
          .setProtection(TokenProtection.biometric);
      if (ref.mounted) state = state.copyWith(enabled: _storeEnabled);
      return stored;
    } finally {
      _inFlight = false;
    }
  }

  static Future<BiometricOutcome> _verify(BiometricAuthenticator auth) =>
      auth.authenticate(reason: '開啟生物辨識登入', biometricOnly: true);

  /// 關閉：refresh token 改回一般保存（裝置密碼保護）。不驗證、不登出（ADR-0019）。
  Future<bool> disable() async {
    if (_inFlight) return false;
    _inFlight = true;
    try {
      final stored = await ref
          .read(oauthTokenStoreProvider)
          .setProtection(TokenProtection.passcode);
      if (ref.mounted) state = state.copyWith(enabled: _storeEnabled);
      return stored;
    } finally {
      _inFlight = false;
    }
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
