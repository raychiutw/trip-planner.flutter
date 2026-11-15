import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/oauth/oauth_protocol.dart';

/// 與 api（trip-planner-api）約定的協定字串。這裡刻意寫死字面值：
/// api 那邊改了任何一個值，Flutter 必須在這裡先失敗，而不是悄悄對不上。
void main() {
  test('授權網址參數名', () {
    expect(OAuthProtocol.biometricHintParam, 'biometric_hint');
    expect(OAuthProtocol.promptParam, 'prompt');
    expect(OAuthProtocol.biometricIntentParam, 'biometric_intent');
    expect(OAuthProtocol.expectedAccountParam, 'expected_account');
  });

  test('參數值', () {
    expect(OAuthProtocol.promptLogin, 'login');
    expect(OAuthProtocol.hintFaceId, 'faceid');
    expect(OAuthProtocol.hintTouchId, 'touchid');
    expect(OAuthProtocol.hintGeneric, 'generic');
    expect(OAuthProtocol.intentEnable, 'enable');
    expect(OAuthProtocol.intentDisable, 'disable');
  });

  test('callback 的 error 值', () {
    expect(OAuthProtocol.errorReauthAccountMismatch, 'reauth_account_mismatch');
    expect(OAuthProtocol.errorAccessDenied, 'access_denied');
  });
}
