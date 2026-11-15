// 特徵化測試（characterization）：記錄目前 Android 上 passcode 與 biometric 兩種選項
// 傳給 flutter_secure_storage 平台通道的參數。
//
// 原始碼推論（flutter_secure_storage 10.3.1 android）：plugin 以 sharedPreferencesName
// （無 storageNamespace 時）當 key 快取 FlutterSecureStorage 實例
// （FlutterSecureStoragePlugin.java:87-101），且 initialize 在 preferences != null 時
// 直接 return（FlutterSecureStorage.java:146-149），cipher 與 config 以該實例第一次
// 呼叫的選項為準（:151、initializeStorageCipher）。下面證明兩種選項的實例快取 key
// 相同、但 cipher 相關參數不同；若日後替 biometric 指定獨立 storageNamespace，
// 這支測試會紅，屬預期，須連同遷移一起更新。
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

  test('passcode 與 biometric 的實例快取 key 相同，但 cipher 參數不同', () async {
    final vault = FlutterSecureVault();
    await vault.read('k', protection: TokenProtection.passcode);
    await vault.read('k', protection: TokenProtection.biometric);

    final passcode = calls[0];
    final biometric = calls[1];

    // 快取 key 的輸入：兩者都沒指定 storageNamespace／sharedPreferencesName。
    expect(passcode['storageNamespace'], '');
    expect(biometric['storageNamespace'], '');
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
}
