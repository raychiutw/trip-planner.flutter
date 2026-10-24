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

  @override
  Future<BiometricKind?> availableKind() async => kind;

  @override
  Future<BiometricOutcome> authenticate({required String reason}) async {
    authenticateCalls++;
    return outcomes.isEmpty ? BiometricOutcome.success : outcomes.removeAt(0);
  }
}
