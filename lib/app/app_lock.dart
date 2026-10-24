/// App 鎖：本機生物辨識解鎖（純 client，不碰後端與 session）。
///
/// 開啟後，冷啟動與離開前景超過 [appLockAfterBackground] 再回來時要通過
/// Face ID / Touch ID（可退回裝置密碼）。驗證失敗或取消只留在鎖定畫面，
/// 不登出、不清 session、不清離線資料。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../api/providers.dart';
import '../api/settings_store.dart';
import '../models/user.dart';

const _enabledKey = 'app_lock_enabled';
const _promptedKey = 'app_lock_prompted';

/// 離開前景超過這段時間再回來才鎖；短暫切 App 不打擾。
const appLockAfterBackground = Duration(minutes: 1);

/// 裝置目前可用來解鎖的方式（決定 UI 用語）。
enum BiometricKind {
  faceId('Face ID'),
  touchId('Touch ID'),
  biometric('生物辨識'),

  /// 沒有生物辨識，但有裝置密碼可用。
  passcode('裝置密碼');

  const BiometricKind(this.label);
  final String label;
}

extension BiometricKindLabel on BiometricKind? {
  /// 尚未查到裝置種類（或不可用）時的通用說法。
  String get lockLabel => this?.label ?? '生物辨識';
}

enum BiometricOutcome { success, cancelled, failed }

/// 平台生物辨識的最小介面（測試以假的替換）。
abstract interface class BiometricAuthenticator {
  /// 目前可用的解鎖方式；null = 沒有生物辨識也沒有裝置密碼。
  Future<BiometricKind?> availableKind();

  Future<BiometricOutcome> authenticate({required String reason});
}

class LocalAuthBiometricAuthenticator implements BiometricAuthenticator {
  LocalAuthBiometricAuthenticator([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<BiometricKind?> availableKind() async {
    try {
      if (!await _auth.isDeviceSupported()) return null;
      final types = await _auth.getAvailableBiometrics();
      if (types.contains(BiometricType.face)) return BiometricKind.faceId;
      if (types.contains(BiometricType.fingerprint) &&
          defaultTargetPlatform == TargetPlatform.iOS) {
        return BiometricKind.touchId;
      }
      return types.isEmpty ? BiometricKind.passcode : BiometricKind.biometric;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<BiometricOutcome> authenticate({required String reason}) async {
    try {
      final ok = await _auth.authenticate(localizedReason: reason);
      return ok ? BiometricOutcome.success : BiometricOutcome.failed;
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled => BiometricOutcome.cancelled,
        _ => BiometricOutcome.failed,
      };
    } catch (_) {
      return BiometricOutcome.failed;
    }
  }
}

final biometricAuthenticatorProvider = Provider<BiometricAuthenticator>(
  (ref) => LocalAuthBiometricAuthenticator(),
);

/// 判斷「離開前景多久」用的時鐘；測試可注入。
final appLockClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final appLockKindProvider = FutureProvider.autoDispose<BiometricKind?>(
  (ref) => ref.watch(biometricAuthenticatorProvider).availableKind(),
);

/// 在建立 App 前讀回是否開啟，冷啟動第一幀就能鎖住。
Future<bool> loadInitialAppLockEnabled(SettingsStore store) async {
  try {
    return await store.read(_enabledKey) == '1';
  } catch (_) {
    return false;
  }
}

@immutable
class AppLockState {
  const AppLockState({
    required this.enabled,
    required this.locked,
    this.promptPending = false,
  });

  final bool enabled;
  final bool locked;

  /// 新登入後要主動詢問是否開啟。
  final bool promptPending;

  AppLockState copyWith({bool? enabled, bool? locked, bool? promptPending}) =>
      AppLockState(
        enabled: enabled ?? this.enabled,
        locked: locked ?? this.locked,
        promptPending: promptPending ?? this.promptPending,
      );
}

class AppLockController extends Notifier<AppLockState> {
  AppLockController({bool? initialEnabled}) : _initialEnabled = initialEnabled;

  final bool? _initialEnabled;
  DateTime? _hiddenAt;
  bool _inFlight = false;

  /// 看過「已登出」才算之後的登入是新登入；冷啟動還原 session 是 loading → user。
  bool _signedOutSeen = false;

  @override
  AppLockState build() {
    ref.listen(authStateProvider, (_, next) => _onAuth(next));
    final enabled = _initialEnabled ?? false;
    if (_initialEnabled == null) unawaited(_loadSaved());
    return AppLockState(enabled: enabled, locked: enabled);
  }

  Future<void> _loadSaved() async {
    if (await _read(_enabledKey) == '1' && !state.enabled) {
      state = state.copyWith(enabled: true, locked: true);
    }
  }

  void _onAuth(AsyncValue<UserInfo?> next) {
    if (next is! AsyncData<UserInfo?>) return;
    if (next.value == null) {
      _signedOutSeen = true;
      // 登出：App 鎖是這台裝置上這個登入的設定，不留給下一位使用者。
      if (state.enabled || state.locked) {
        unawaited(_write(_enabledKey, '0'));
        state = state.copyWith(enabled: false, locked: false);
      }
    } else if (_signedOutSeen) {
      _signedOutSeen = false;
      unawaited(_maybePrompt());
    }
  }

  Future<void> _maybePrompt() async {
    if (await _read(_promptedKey) == '1') return;
    // 裝置不可用時不問、也不記已問過，等之後可用再問一次。
    if (await ref.read(biometricAuthenticatorProvider).availableKind() ==
        null) {
      return;
    }
    state = state.copyWith(promptPending: true);
  }

  /// 回答登入後的詢問；不論選哪個都記為已問過。
  Future<void> answerPrompt({required bool enable}) async {
    state = state.copyWith(promptPending: false);
    await _write(_promptedKey, '1');
    if (enable) await setEnabled(true);
  }

  /// 開啟與關閉都要先通過一次驗證；未通過回 false、狀態不變。
  Future<bool> setEnabled(bool value) async {
    if (value == state.enabled) return true;
    final outcome = await _authenticate('驗證身分以變更 App 鎖');
    if (outcome != BiometricOutcome.success) return false;
    await _write(_enabledKey, value ? '1' : '0');
    state = state.copyWith(enabled: value, locked: false);
    return true;
  }

  Future<BiometricOutcome> unlock() async {
    if (!state.locked) return BiometricOutcome.success;
    final outcome = await _authenticate('解鎖 Tripline');
    if (outcome == BiometricOutcome.success) {
      state = state.copyWith(locked: false);
    }
    return outcome;
  }

  /// 離開前景（hidden）。驗證進行中的系統畫面不算。
  void onHidden(DateTime now) {
    if (!_inFlight) _hiddenAt = now;
  }

  /// 回到前景與冷啟動時呼叫；回 true 表示因裝置已不可用而自動關閉。
  Future<bool> onResumed(DateTime now) async {
    final hiddenAt = _hiddenAt;
    _hiddenAt = null;
    if (!state.enabled || _inFlight) return false;
    // 先同步上鎖，再查裝置狀態：不能讓內容在 await 期間露出一格。
    if (hiddenAt != null && now.difference(hiddenAt) > appLockAfterBackground) {
      state = state.copyWith(locked: true);
    }
    final kind = await ref.read(biometricAuthenticatorProvider).availableKind();
    if (!state.enabled) return false;
    if (kind == null) {
      // 使用者在系統設定移除了生物辨識與密碼：關閉而不是把人鎖在外面。
      await _write(_enabledKey, '0');
      state = state.copyWith(enabled: false, locked: false);
      return true;
    }
    return false;
  }

  Future<BiometricOutcome> _authenticate(String reason) async {
    if (_inFlight) return BiometricOutcome.cancelled;
    _inFlight = true;
    try {
      return await ref
          .read(biometricAuthenticatorProvider)
          .authenticate(reason: reason);
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
    } catch (_) {
      // 寫入失敗只影響下次啟動的預設值，不擋當下流程。
    }
  }
}

final appLockProvider = NotifierProvider<AppLockController, AppLockState>(
  AppLockController.new,
);
