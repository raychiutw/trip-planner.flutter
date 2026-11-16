import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/app/app_lock.dart';

class _MockLocalAuth extends Mock implements LocalAuthentication {}

/// `local_auth` 的結果碼要分成：使用者取消、被系統中斷（可重試）、真正失敗，
/// 並保留原因碼給提示使用。
void main() {
  late _MockLocalAuth auth;
  late LocalAuthBiometricAuthenticator sut;

  setUp(() {
    auth = _MockLocalAuth();
    sut = LocalAuthBiometricAuthenticator(auth);
  });

  void stubThrows(LocalAuthExceptionCode code) {
    when(
      () => auth.authenticate(localizedReason: any(named: 'localizedReason')),
    ).thenThrow(LocalAuthException(code: code));
  }

  test('通過 → success，沒有失敗碼', () async {
    when(
      () => auth.authenticate(localizedReason: any(named: 'localizedReason')),
    ).thenAnswer((_) async => true);
    expect(await sut.authenticate(reason: 'x'), BiometricOutcome.success);
    expect(sut.lastFailureCode, isNull);
  });

  test('使用者取消 → cancelled', () async {
    stubThrows(LocalAuthExceptionCode.userCanceled);
    expect(await sut.authenticate(reason: 'x'), BiometricOutcome.cancelled);
  });

  for (final code in [
    LocalAuthExceptionCode.systemCanceled,
    LocalAuthExceptionCode.uiUnavailable,
    LocalAuthExceptionCode.authInProgress,
  ]) {
    test('${code.name} → interrupted（可重試），保留原因碼', () async {
      stubThrows(code);
      expect(await sut.authenticate(reason: 'x'), BiometricOutcome.interrupted);
      expect(sut.lastFailureCode, code.name);
    });
  }

  test('沒有登錄生物辨識 → failed，保留原因碼', () async {
    stubThrows(LocalAuthExceptionCode.noBiometricsEnrolled);
    expect(await sut.authenticate(reason: 'x'), BiometricOutcome.failed);
    expect(sut.lastFailureCode, 'noBiometricsEnrolled');
  });

  test('回傳 false（驗證不通過）→ failed', () async {
    when(
      () => auth.authenticate(localizedReason: any(named: 'localizedReason')),
    ).thenAnswer((_) async => false);
    expect(await sut.authenticate(reason: 'x'), BiometricOutcome.failed);
    expect(sut.lastFailureCode, 'rejected');
  });

  test('下一次成功會清掉上一次的失敗碼', () async {
    stubThrows(LocalAuthExceptionCode.noBiometricsEnrolled);
    await sut.authenticate(reason: 'x');
    when(
      () => auth.authenticate(localizedReason: any(named: 'localizedReason')),
    ).thenAnswer((_) async => true);
    await sut.authenticate(reason: 'x');
    expect(sut.lastFailureCode, isNull);
  });

  // 生物辨識登入在 Android 只接受 BIOMETRIC_STRONG（ADR-0019）。local_auth_android 以
  // canAuthenticate(BIOMETRIC_WEAK／STRONG) 回 weak／strong；只有 weak（例如 class 2 臉部
  // 解鎖）時金鑰無法建立，不能當成「有生物辨識」提供這個功能。
  group('Android 可用種類', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      when(() => auth.isDeviceSupported()).thenAnswer((_) async => true);
    });
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    void stubTypes(List<BiometricType> types) => when(
      () => auth.getAvailableBiometrics(),
    ).thenAnswer((_) async => types);

    test('有 strong → App 鎖與生物辨識登入都是生物辨識', () async {
      stubTypes([BiometricType.weak, BiometricType.strong]);
      expect(await sut.availableKind(), BiometricKind.biometric);
      expect(await sut.biometricLoginKind(), BiometricKind.biometric);
    });

    test('只有 weak → App 鎖照樣用生物辨識（不受影響）', () async {
      stubTypes([BiometricType.weak]);
      final kind = await sut.availableKind();
      expect(kind, BiometricKind.biometric);
      expect(kind.hasBiometric, isTrue);
    });

    test('只有 weak → 生物辨識登入只算裝置密碼，不提供', () async {
      stubTypes([BiometricType.weak]);
      final kind = await sut.biometricLoginKind();
      expect(kind, BiometricKind.passcode);
      expect(kind.hasBiometric, isFalse);
    });

    test('沒有登記生物特徵 → 都是裝置密碼', () async {
      stubTypes([]);
      expect(await sut.availableKind(), BiometricKind.passcode);
      expect(await sut.biometricLoginKind(), BiometricKind.passcode);
    });
  });

  group('iOS 可用種類（生物辨識登入與 App 鎖相同）', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      when(() => auth.isDeviceSupported()).thenAnswer((_) async => true);
      when(
        () => auth.getAvailableBiometrics(),
      ).thenAnswer((_) async => [BiometricType.face]);
    });
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('Face ID', () async {
      expect(await sut.availableKind(), BiometricKind.faceId);
      expect(await sut.biometricLoginKind(), BiometricKind.faceId);
    });
  });
}
