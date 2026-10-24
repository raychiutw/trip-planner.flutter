import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// App 鎖用 `local_auth`，兩個平台各有一個漏掉就只會在真機上靜默失敗：
/// iOS 缺 Face ID 說明字串會直接 crash，Android 的 Activity 不是
/// FragmentActivity 或主題不是 AppCompat 則 BiometricPrompt 開不起來。
void main() {
  String read(String path) => File(path).readAsStringSync();

  test('iOS Info.plist 有 Face ID 使用說明', () {
    final plist = read('ios/Runner/Info.plist');
    expect(plist, contains('<key>NSFaceIDUsageDescription</key>'));
  });

  test('Android 宣告 USE_BIOMETRIC 權限', () {
    final manifest = read('android/app/src/main/AndroidManifest.xml');
    expect(
      manifest,
      contains(
        '<uses-permission android:name="android.permission.USE_BIOMETRIC"/>',
      ),
    );
  });

  test('Android MainActivity 繼承 FlutterFragmentActivity', () {
    final activity = read(
      'android/app/src/main/kotlin/com/raychiu/tripline/MainActivity.kt',
    );
    expect(
      activity,
      contains('class MainActivity : FlutterFragmentActivity()'),
    );
    expect(activity, isNot(contains('FlutterActivity()')));
  });

  test('Android app 直接依賴 appcompat（主題資源不會從 local_auth 傳遞進來）', () {
    expect(
      read('android/app/build.gradle.kts'),
      contains('implementation("androidx.appcompat:appcompat:'),
    );
  });

  test('Android 淺色與深色主題都以 AppCompat 為父主題', () {
    for (final path in [
      'android/app/src/main/res/values/styles.xml',
      'android/app/src/main/res/values-night/styles.xml',
    ]) {
      final styles = read(path);
      for (final name in ['LaunchTheme', 'NormalTheme']) {
        expect(
          RegExp(
            '<style name="$name" parent="Theme\\.AppCompat[^"]*"',
          ).hasMatch(styles),
          isTrue,
          reason: '$path 的 $name',
        );
      }
    }
  });
}
