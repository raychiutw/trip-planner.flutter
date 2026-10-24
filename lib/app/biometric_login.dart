/// 生物辨識登入：登出後也能用 Face ID／Touch ID 取代手動輸入帳密。
///
/// 純 client、不改後端：密碼登入成功後詢問一次，同意就把 email 與密碼存進
/// Keychain；之後在登入頁通過生物辨識才讀出並走一般的密碼登入。與 App 鎖
/// （[appLockProvider]）互相獨立：登出會關掉 App 鎖，但保留這裡存的帳密。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_error.dart';
import '../api/credential_store.dart';
import '../api/providers.dart';
import '../models/user.dart';
import 'app_lock.dart';

const _promptedKey = 'bio_login_prompted';

@immutable
class BiometricLoginState {
  const BiometricLoginState({
    this.hasSaved = false,
    this.promptPending = false,
  });

  /// Keychain 內有可用的帳密（決定登入頁是否出現生物辨識按鈕）。
  final bool hasSaved;

  /// 密碼登入成功後，要詢問是否開啟。
  final bool promptPending;

  BiometricLoginState copyWith({bool? hasSaved, bool? promptPending}) =>
      BiometricLoginState(
        hasSaved: hasSaved ?? this.hasSaved,
        promptPending: promptPending ?? this.promptPending,
      );
}

class BiometricLoginController extends Notifier<BiometricLoginState> {
  SavedCredentials? _attempt;

  /// 詢問框待答時暫存的帳密，答「開啟」才寫進 Keychain。
  SavedCredentials? _pendingSave;
  bool _attemptFromSaved = false;
  bool _inFlight = false;

  @override
  BiometricLoginState build() {
    ref.listen(authStateProvider, (_, next) => _onAuth(next));
    unawaited(_loadSaved());
    return const BiometricLoginState();
  }

  Future<void> _loadSaved() async {
    try {
      final saved = await ref.read(credentialStoreProvider).read();
      if (ref.mounted) state = state.copyWith(hasSaved: saved != null);
    } catch (_) {
      // Keychain 讀不到就當作沒有，登入頁維持手動輸入。
    }
  }

  /// 登入畫面送出密碼登入前呼叫，登入成功才會用到。
  void rememberAttempt(String email, String password) {
    _attempt = SavedCredentials(email: email, password: password);
    _attemptFromSaved = false;
  }

  void _onAuth(AsyncValue<UserInfo?> next) {
    if (next is AsyncData<UserInfo?> && next.value == null) {
      // 登出：待答的詢問與待存的帳密都作廢（不能存到下一位使用者名下），
      // 並重新對帳 Keychain（帳號被刪除時帳密已被清掉）。
      _pendingSave = null;
      if (state.promptPending) state = state.copyWith(promptPending: false);
      unawaited(_loadSaved());
    }
    final attempt = _attempt;
    if (attempt == null) return;
    if (next is AsyncData<UserInfo?> && next.value != null) {
      _attempt = null;
      if (!_attemptFromSaved) unawaited(_afterPasswordLogin(attempt));
    } else if (next is AsyncError<UserInfo?>) {
      _attempt = null;
      final error = next.error;
      // 存下的密碼已失效（例如在別處改過密碼）：清掉，回到手動登入。
      if (_attemptFromSaved &&
          error is ApiError &&
          error.code == 'LOGIN_INVALID') {
        unawaited(_clear());
      }
    }
  }

  Future<void> _afterPasswordLogin(SavedCredentials attempt) async {
    final store = ref.read(credentialStoreProvider);
    var otherAccount = false;
    if (state.hasSaved) {
      try {
        final saved = await store.read();
        if (saved?.email == attempt.email) {
          // 同一帳號：靜默跟上新密碼。
          if (saved?.password != attempt.password) await store.write(attempt);
          return;
        }
        // 換成別的帳號手動登入：前一位的帳密不留給這一位，重新詢問。
        otherAccount = true;
        await store.clear();
        if (ref.mounted) state = state.copyWith(hasSaved: false);
      } catch (_) {
        return;
      }
    }
    if (!otherAccount && await _read(_promptedKey) == '1') return;
    // 裝置不可用時不問、也不記已問過，等之後可用再問一次。
    if (await ref.read(biometricAuthenticatorProvider).availableKind() ==
        null) {
      return;
    }
    _pendingSave = attempt;
    if (ref.mounted) state = state.copyWith(promptPending: true);
  }

  /// 回答登入後的詢問；不論選哪個都記為已問過。
  Future<void> answerPrompt({required bool enable}) async {
    state = state.copyWith(promptPending: false);
    final toSave = _pendingSave;
    _pendingSave = null;
    await _write(_promptedKey, '1');
    if (!enable || toSave == null) return;
    try {
      await ref.read(credentialStoreProvider).write(toSave);
      if (ref.mounted) state = state.copyWith(hasSaved: true);
    } catch (_) {
      // 存不進 Keychain：維持關閉，下次登入頁仍是手動輸入。
    }
  }

  /// 登入頁的「使用 Face ID 登入」：驗證通過才讀出帳密並走一般密碼登入。
  Future<BiometricOutcome> loginWithBiometric() async {
    if (_inFlight) return BiometricOutcome.cancelled;
    _inFlight = true;
    try {
      final outcome = await ref
          .read(biometricAuthenticatorProvider)
          .authenticate(reason: '登入 Tripline');
      if (outcome != BiometricOutcome.success) return outcome;
      SavedCredentials? saved;
      try {
        saved = await ref.read(credentialStoreProvider).read();
      } catch (_) {
        return BiometricOutcome.failed;
      }
      if (saved == null) {
        state = state.copyWith(hasSaved: false);
        return BiometricOutcome.failed;
      }
      _attempt = saved;
      _attemptFromSaved = true;
      await ref
          .read(authStateProvider.notifier)
          .login(saved.email, saved.password);
      return BiometricOutcome.success;
    } finally {
      _inFlight = false;
    }
  }

  /// 關閉：先驗證身分，通過才清除存下的帳密。
  Future<bool> disable() async {
    final outcome = await ref
        .read(biometricAuthenticatorProvider)
        .authenticate(reason: '驗證身分以關閉生物辨識登入');
    if (outcome != BiometricOutcome.success) return false;
    await _clear();
    return true;
  }

  Future<void> _clear() async {
    try {
      await ref.read(credentialStoreProvider).clear();
    } catch (_) {}
    if (ref.mounted) state = state.copyWith(hasSaved: false);
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
