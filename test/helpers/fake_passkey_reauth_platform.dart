import 'package:tripline/app/passkey_reauth_platform.dart';

/// 測試用 passkey 簽署平台：指定下一次簽署的結果，並記錄呼叫次數與收到的選項。
class FakePasskeyReauthPlatform implements PasskeyReauthPlatform {
  FakePasskeyReauthPlatform([this.outcome = const PasskeyAssertCancelled()]);

  PasskeyAssertOutcome outcome;
  int authenticateCalls = 0;
  Map<String, dynamic>? lastOptions;

  @override
  Future<PasskeyAssertOutcome> authenticate(
    Map<String, dynamic> options,
  ) async {
    authenticateCalls++;
    lastOptions = options;
    return outcome;
  }
}

const fakeAssertion = <String, dynamic>{
  'id': 'cred-1',
  'rawId': 'cred-1',
  'type': 'public-key',
  'response': {
    'clientDataJSON': 'cd',
    'authenticatorData': 'ad',
    'signature': 'sig',
  },
};
