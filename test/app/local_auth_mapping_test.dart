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
}
