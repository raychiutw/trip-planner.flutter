import 'package:tripline/app/passkey_platform.dart';

/// 測試用 passkey 平台：指定下一次建立的結果，並記錄呼叫次數與收到的選項。
class FakePasskeyPlatform implements PasskeyPlatform {
  FakePasskeyPlatform([this.outcome = const PasskeyCancelled()]);

  PasskeyCreateOutcome outcome;
  int createCalls = 0;
  Map<String, dynamic>? lastOptions;

  @override
  Future<PasskeyCreateOutcome> create(Map<String, dynamic> options) async {
    createCalls++;
    lastOptions = options;
    return outcome;
  }
}

const fakeCredential = <String, dynamic>{
  'id': 'cred-new',
  'rawId': 'cred-new',
  'type': 'public-key',
  'response': {'clientDataJSON': 'cd', 'attestationObject': 'ao'},
};
