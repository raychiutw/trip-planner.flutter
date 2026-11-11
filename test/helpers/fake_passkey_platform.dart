import 'package:tripline/app/passkey_assertion.dart';
import 'package:tripline/app/passkey_platform.dart';

/// 測試用 passkey 平台：指定下一次建立的結果，並記錄呼叫次數與收到的選項。
class FakePasskeyPlatform implements PasskeyPlatform {
  FakePasskeyPlatform([this.outcome = const PasskeyCancelled()]);

  PasskeyCreateOutcome outcome;
  int createCalls = 0;
  Map<String, dynamic>? lastOptions;

  /// 登入用（assertion）：平台是否支援、下一次的結果與呼叫記錄。
  bool supported = true;
  PasskeyAssertion assertion = const PasskeyAssertCancelled();
  int authenticateCalls = 0;
  Map<String, dynamic>? lastAuthenticateOptions;

  @override
  Future<PasskeyCreateOutcome> create(Map<String, dynamic> options) async {
    createCalls++;
    lastOptions = options;
    return outcome;
  }

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<PasskeyAssertion> authenticate(Map<String, dynamic> options) async {
    authenticateCalls++;
    lastAuthenticateOptions = options;
    return assertion;
  }
}

const fakeCredential = <String, dynamic>{
  'id': 'cred-new',
  'rawId': 'cred-new',
  'type': 'public-key',
  'response': {'clientDataJSON': 'cd', 'attestationObject': 'ao'},
};

const fakeAssertionCredential = <String, dynamic>{
  'id': 'cred-1',
  'rawId': 'cred-1',
  'type': 'public-key',
  'response': {
    'clientDataJSON': 'cd',
    'authenticatorData': 'ad',
    'signature': 'sig',
    'userHandle': 'uh',
  },
};
