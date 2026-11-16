// Android 兩種選項傳給 flutter_secure_storage 平台通道的參數。
//
// plugin（10.3.1 android）以 storageNamespace（沒有才用 sharedPreferencesName）當 key
// 快取 FlutterSecureStorage 實例（FlutterSecureStoragePlugin.java:87-101），initialize
// 在 preferences != null 時直接 return（FlutterSecureStorage.java:146-149），cipher 以
// 實例第一次呼叫的選項為準。兩種選項若同一個實例，biometric 設定會被 passcode 的第一次
// 呼叫蓋掉；所以 biometric 必須有獨立的 storageNamespace（同時隔離 SharedPreferences、
// 金鑰存放區與 KeyStore alias）。
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/oauth/oauth_token_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <Map<Object?, Object?>>[];

  setUp(() {
    calls.clear();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async {
            final args = call.arguments as Map<Object?, Object?>;
            calls.add(Map<Object?, Object?>.from(args['options'] as Map));
            return null;
          },
        );
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('passcode 與 biometric 的 plugin 實例快取 key 不同，cipher 參數也不同', () async {
    final vault = FlutterSecureVault();
    await vault.read('k', protection: TokenProtection.passcode);
    await vault.read('k', protection: TokenProtection.biometric);

    final passcode = calls[0];
    final biometric = calls[1];

    // 快取 key 的輸入：passcode 維持原預設實例，biometric 有獨立 namespace。
    expect(passcode['storageNamespace'], '');
    expect(biometric['storageNamespace'], 'biometric');
    expect(passcode['sharedPreferencesName'], '');
    expect(biometric['sharedPreferencesName'], '');

    // 但 biometric 要求的是 KeyStore AES 金鑰＋驗證；passcode 是 RSA 包金鑰、不驗證。
    expect(passcode['enforceBiometrics'], 'false');
    expect(biometric['enforceBiometrics'], 'true');
    expect(
      passcode['keyCipherAlgorithm'],
      isNot(biometric['keyCipherAlgorithm']),
    );
    expect(biometric['keyCipherAlgorithm'], 'AES_GCM_NoPadding');
    expect(biometric['biometricType'], 'strongBiometricOnly');
  });

  // 只接受 BIOMETRIC_STRONG 時，外掛的驗證視窗沒有「改用裝置密碼」，一定要有取消鈕
  // （FlutterSecureStorage.java 只在 strongBiometricOnly 時 setNegativeButton）。
  // 外掛預設的副標是「Use biometrics or device credentials」，與只接受生物辨識矛盾。
  test('biometric 驗證視窗：中文取消鈕，文字不提裝置密碼', () async {
    final vault = FlutterSecureVault();
    await vault.read('k', protection: TokenProtection.biometric);

    final biometric = calls.single;
    expect(biometric['biometricPromptNegativeButton'], '取消');
    final subtitle = biometric['biometricPromptSubtitle']! as String;
    expect(subtitle, isNot(contains('credential')));
    expect(subtitle, isNot(contains('密碼')));
    expect(subtitle, contains('生物辨識'));
  });
}
