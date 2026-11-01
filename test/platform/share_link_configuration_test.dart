import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 旅伴收到的分享連結是 `https://<主站>/s/<token>`；要讓已安裝 App 的人直接
/// 在 App 內開（#454），iOS 與 Android 都要宣告主站網域的 /s/ 路徑。
/// 主站網域要與 `ApiClient` 的 origin 預設值一致。
void main() {
  const host = 'trip-planner-dby.pages.dev';

  for (final file in [
    'ios/Runner/Release.entitlements',
    'ios/Runner/DebugProfile.entitlements',
  ]) {
    test('$file 宣告主站網域的 applinks', () {
      expect(
        File(file).readAsStringSync(),
        contains('<string>applinks:$host</string>'),
      );
    });
  }

  test('Android MainActivity 有 /s/ 的 App Link intent-filter（autoVerify）', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final activity = RegExp(
      r'<activity\s+android:name="\.MainActivity".*?</activity>',
      dotAll: true,
    ).firstMatch(manifest)!.group(0)!;

    expect(activity, contains('android:autoVerify="true"'));
    expect(activity, contains('android:scheme="https"'));
    expect(activity, contains(r'android:host="${shareLinkHost}"'));
    expect(activity, contains('android:pathPrefix="/s/"'));
  });

  test('gradle 的 shareLinkHost 預設為主站網域', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('manifestPlaceholders["shareLinkHost"]'));
    expect(gradle, contains('?: "$host"'));
  });

  test('Dart 端 API origin 預設與分享連結網域一致', () {
    expect(
      File('lib/api/api_client.dart').readAsStringSync(),
      contains("defaultValue: 'https://$host'"),
    );
  });
}
