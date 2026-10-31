/// 生物辨識登入：用 Face ID／Touch ID 保護本機的登入憑證（ADR-0014）。
///
/// 開啟後 refresh token 改存成「讀取時要通過生物辨識」的 Keychain／Keystore 項目，
/// 冷啟動讀取時由系統跳出驗證；App 不保管密碼。關閉會清掉 refresh token 並登出。
/// 與 App 鎖（[appLockProvider]）互相獨立。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/oauth/oauth_providers.dart';
import '../api/oauth/oauth_token_store.dart';
import '../api/providers.dart';
import '../models/user.dart';
import 'app_lock.dart';

const _promptedKey = 'bio_login_prompted';

@immutable
class BiometricLoginState {
  const BiometricLoginState({this.enabled = false, this.promptPending = false});

  /// refresh token 目前受生物辨識保護。
  final bool enabled;

  /// 登入成功後，要詢問是否開啟。
  final bool promptPending;

  BiometricLoginState copyWith({bool? enabled, bool? promptPending}) =>
      BiometricLoginState(
        enabled: enabled ?? this.enabled,
        promptPending: promptPending ?? this.promptPending,
      );
}

class BiometricLoginController extends Notifier<BiometricLoginState> {
  bool _inFlight = false;

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
    unawaited(_maybePrompt());
  }

  /// 登入成功後只問一次；裝置沒有生物辨識或已經開啟就不問。
  Future<void> _maybePrompt() async {
    if (state.enabled) return;
    if (await _read(_promptedKey) == '1') return;
    final kind = await ref.read(biometricAuthenticatorProvider).availableKind();
    // 沒有生物辨識（只有裝置密碼）時不問：裝置密碼保護已是預設。
    if (kind == null || kind == BiometricKind.passcode) return;
    if (ref.mounted) state = state.copyWith(promptPending: true);
  }

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
      final outcome = await ref
          .read(biometricAuthenticatorProvider)
          .authenticate(reason: '開啟生物辨識登入');
      if (outcome != BiometricOutcome.success) return false;
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
      await ref.read(authStateProvider.notifier).logout();
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

final biometricLoginProvider =
    NotifierProvider<BiometricLoginController, BiometricLoginState>(
      BiometricLoginController.new,
    );
