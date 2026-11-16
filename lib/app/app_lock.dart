/// App 鎖：本機生物辨識解鎖（純 client，不碰後端與 session）。
///
/// 開啟後，冷啟動與離開前景超過 [appLockAfterBackground] 再回來時要通過
/// Face ID / Touch ID（可退回裝置密碼）。驗證失敗或取消只留在鎖定畫面，
/// 不登出、不清 session、不清離線資料。冷啟動已為讀受保護憑證驗證過就不再上鎖；
/// 只能在設定頁開啟，登入後不主動詢問（ADR-0019）。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../api/providers.dart';
import '../api/settings_store.dart';
import '../models/user.dart';

const _enabledKey = 'app_lock_enabled';

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

  /// 裝置有真正的生物辨識（只有裝置密碼不算）：保留憑證的解鎖入口才成立。
  bool get hasBiometric => this != null && this != BiometricKind.passcode;
}

/// [interrupted]：被系統中斷（App 剛回前景、另一個驗證還在進行、系統取消），
/// 不是使用者取消也不是驗證失敗；呼叫端可等前景後重試一次。
enum BiometricOutcome { success, cancelled, interrupted, failed }

/// 平台生物辨識的最小介面（測試以假的替換）。
abstract interface class BiometricAuthenticator {
  /// 目前可用的解鎖方式；null = 沒有生物辨識也沒有裝置密碼。
  Future<BiometricKind?> availableKind();

  /// [biometricOnly] 為 true 時不接受裝置密碼（用於「必須是生物特徵」的把關）。
  Future<BiometricOutcome> authenticate({
    required String reason,
    bool biometricOnly = false,
  });

  /// 最近一次非成功結果的原因碼（給提示與診斷用）；成功或沒有則為 null。
  String? get lastFailureCode;
}

class LocalAuthBiometricAuthenticator implements BiometricAuthenticator {
  LocalAuthBiometricAuthenticator([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  String? lastFailureCode;

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
      if (defaultTargetPlatform == TargetPlatform.android) {
        // 生物辨識登入只接受 BIOMETRIC_STRONG；只有 weak 時金鑰建不起來，當成只有裝置密碼。
        return types.contains(BiometricType.strong)
            ? BiometricKind.biometric
            : BiometricKind.passcode;
      }
      return types.isEmpty ? BiometricKind.passcode : BiometricKind.biometric;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<BiometricOutcome> authenticate({
    required String reason,
    bool biometricOnly = false,
  }) async {
    lastFailureCode = null;
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: biometricOnly,
      );
      if (ok) return BiometricOutcome.success;
      lastFailureCode = 'rejected';
      return BiometricOutcome.failed;
    } on LocalAuthException catch (e) {
      lastFailureCode = e.code.name;
      return switch (e.code) {
        LocalAuthExceptionCode.userCanceled => BiometricOutcome.cancelled,
        // 被系統中斷：App 剛回前景、另一個驗證還在進行、系統取消。不是使用者的決定。
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.uiUnavailable ||
        LocalAuthExceptionCode.authInProgress => BiometricOutcome.interrupted,
        _ => BiometricOutcome.failed,
      };
    } catch (_) {
      lastFailureCode = 'unexpected';
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
  const AppLockState({required this.enabled, required this.locked});

  final bool enabled;
  final bool locked;

  AppLockState copyWith({bool? enabled, bool? locked}) => AppLockState(
    enabled: enabled ?? this.enabled,
    locked: locked ?? this.locked,
  );
}

class AppLockController extends Notifier<AppLockState> {
  AppLockController({bool? initialEnabled}) : _initialEnabled = initialEnabled;

  final bool? _initialEnabled;
  DateTime? _hiddenAt;
  bool _inFlight = false;

  @override
  AppLockState build() {
    ref.listen(authStateProvider, (_, next) => _onAuth(next));
    // 登入憑證才剛通過系統驗證：同一個人、同一次驗證，不再要求 App 鎖。
    // 事件只由 AuthNotifier 發出（credentialVerifiedProvider），這裡不推斷時序。
    ref.listen(credentialVerifiedProvider, (_, _) {
      if (state.locked) state = state.copyWith(locked: false);
    });
    final enabled = _initialEnabled ?? false;
    if (_initialEnabled == null) unawaited(_loadSaved());
    return AppLockState(
      enabled: enabled,
      locked: enabled && !_verifiedThisLaunch,
    );
  }

  /// listen 只管訂閱之後的事件；憑證若在 App 鎖建立前就已驗證（認證比 App 鎖先解析完），
  /// 建立時與非同步載入設定時都要把這件事算進初始鎖定狀態。
  /// 計數器永不歸零，所以只在這兩個時機讀；登出時 App 鎖會被關掉，不沿用到下一次登入。
  /// `appLockProvider` 目前不會被重建，若日後改成 autoDispose 或 invalidate，這個假設要重新檢查。
  bool get _verifiedThisLaunch => ref.read(credentialVerifiedProvider) > 0;

  Future<void> _loadSaved() async {
    if (await _read(_enabledKey) == '1' && !state.enabled) {
      state = state.copyWith(enabled: true, locked: !_verifiedThisLaunch);
    }
  }

  void _onAuth(AsyncValue<UserInfo?> next) {
    if (next is! AsyncData<UserInfo?>) return;
    if (next.value == null) {
      // 登出：App 鎖是這台裝置上這個登入的設定，不留給下一位使用者。
      // 憑證只是還沒解開（authLocked）不是登出：App 鎖設定要留著，等解鎖後放行。
      // 這裡讀 authLockedProvider 是為了分辨「憑證還沒解開」與「登出」，
      // 否則冷啟動取消 Face ID 會把 App 鎖設定清掉。
      if (!ref.read(authLockedProvider) && (state.enabled || state.locked)) {
        unawaited(_write(_enabledKey, '0'));
        state = state.copyWith(enabled: false, locked: false);
      }
    }
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
