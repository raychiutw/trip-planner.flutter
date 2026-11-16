// iOS 選項傳給 flutter_secure_storage 平台通道的參數（ADR-0019：只接受生物辨識）。
//
// flutter_secure_storage_darwin 0.3.2 的對應（FlutterSecureStorage.swift）：
// - accessibility `passcode` → kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly（僅限這台裝置）
// - accessControlFlags 逐一 insert 進 SecAccessControlCreateFlags；只有 biometryCurrentSet
//   時不能改用裝置密碼，新增或刪除生物特徵後項目失效。加上 `or`＋`devicePasscode`
//   或改用 `userPresence` 都會讓裝置密碼也能讀。
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/oauth/oauth_token_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <(String, Map<Object?, Object?>)>[];

  setUp(() {
    calls.clear();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async {
            final args = call.arguments as Map<Object?, Object?>;
            calls.add((
              call.method,
              Map<Object?, Object?>.from(args['options'] as Map),
            ));
            return null;
          },
        );
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('biometric 讀寫只接受目前登記的生物特徵，且僅限這台裝置', () async {
    final vault = FlutterSecureVault(platform: TargetPlatform.iOS);
    await vault.read('k', protection: TokenProtection.biometric);
    await vault.write('k', 'v', protection: TokenProtection.biometric);

    expect(calls.map((c) => c.$1), ['read', 'write']);
    for (final (_, options) in calls) {
      expect(options['accessibility'], 'passcode', reason: 'ThisDeviceOnly');
      expect(options['accessControlFlags'], '[biometryCurrentSet]');
      expect(options['synchronizable'], isNot('true'));
      expect(options['useSecureEnclave'], isNot('true'));
    }
  });

  test('passcode 等級不帶 access control（讀取不跳生物辨識）', () async {
    final vault = FlutterSecureVault(platform: TargetPlatform.iOS);
    await vault.read('k', protection: TokenProtection.passcode);

    final options = calls.single.$2;
    expect(options['accessibility'], 'passcode');
    expect(options.containsKey('accessControlFlags'), isFalse);
  });
}
