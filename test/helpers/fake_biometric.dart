import 'dart:async';

import 'package:tripline/app/app_lock.dart';

/// 測試用生物辨識驗證器：可指定裝置種類與每次驗證的結果。
class FakeBiometricAuthenticator implements BiometricAuthenticator {
  FakeBiometricAuthenticator({
    this.kind = BiometricKind.faceId,
    List<BiometricOutcome>? outcomes,
  }) : outcomes = outcomes ?? [];

  /// null = 裝置沒有生物辨識也沒有密碼。
  BiometricKind? kind;

  /// 依序消耗；用完後一律成功。
  final List<BiometricOutcome> outcomes;

  int authenticateCalls = 0;

  /// 每次 authenticate 收到的 biometricOnly。
  final biometricOnlyCalls = <bool>[];

  @override
  String? lastFailureCode;

  /// 每次 authenticate 被呼叫時觸發（測試記錄呼叫順序用）。
  void Function()? onAuthenticate;

  /// 驗證「進行中」要做的事（例如模擬驗證期間登出、換帳號），做完才回傳結果。
  Future<void> Function()? whileAuthenticating;

  /// 生物辨識登入可用的種類；null＝與 [kind] 相同（模擬 Android 只有 weak 時另設）。
  BiometricKind? loginKindOverride;

  @override
  Future<BiometricKind?> availableKind() async => kind;

  @override
  Future<BiometricKind?> biometricLoginKind() async =>
      loginKindOverride ?? kind;

  @override
  Future<BiometricOutcome> authenticate({
    required String reason,
    bool biometricOnly = false,
  }) async {
    authenticateCalls++;
    biometricOnlyCalls.add(biometricOnly);
    onAuthenticate?.call();
    await whileAuthenticating?.call();
    return outcomes.isEmpty ? BiometricOutcome.success : outcomes.removeAt(0);
  }
}
