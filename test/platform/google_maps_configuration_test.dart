import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('iOS 從 ignored xcconfig 注入獨立 Google Maps key', () {
    final appDelegate = read('ios/Runner/AppDelegate.swift');
    final infoPlist = read('ios/Runner/Info.plist');
    final debugConfig = read('ios/Flutter/Debug.xcconfig');
    final releaseConfig = read('ios/Flutter/Release.xcconfig');
    final example = read('ios/Flutter/Secrets.xcconfig.example');

    expect(appDelegate, contains('import GoogleMaps'));
    expect(appDelegate, contains('GMSServices.provideAPIKey'));
    expect(appDelegate, contains('GMSApiKey'));
    expect(infoPlist, contains(r'$(GOOGLE_MAPS_IOS_API_KEY)'));
    expect(debugConfig, contains('Secrets.xcconfig'));
    expect(releaseConfig, contains('Secrets.xcconfig'));
    expect(example, contains('GOOGLE_MAPS_IOS_API_KEY='));
  });

  test('iOS deployment target 符合 Google Maps 外掛最低版本', () {
    final podfile = read('ios/Podfile');
    final project = read('ios/Runner.xcodeproj/project.pbxproj');

    expect(podfile, contains("platform :ios, '14.0'"));
    expect(project, isNot(contains('IPHONEOS_DEPLOYMENT_TARGET = 13.0;')));
    expect(
      'IPHONEOS_DEPLOYMENT_TARGET = 14.0;'.allMatches(project).length,
      greaterThanOrEqualTo(3),
    );
  });

  test('Android manifest placeholder 從 ignored properties 或環境變數注入', () {
    final manifest = read('android/app/src/main/AndroidManifest.xml');
    final gradle = read('android/app/build.gradle.kts');
    final example = read('android/maps.properties.example');

    expect(manifest, contains('com.google.android.geo.API_KEY'));
    expect(manifest, contains(r'${googleMapsApiKey}'));
    expect(gradle, contains('GOOGLE_MAPS_ANDROID_API_KEY'));
    expect(gradle, contains('maps.properties'));
    expect(example.trim(), 'GOOGLE_MAPS_ANDROID_API_KEY=');
  });

  test('Android release 不得使用 debug signing key', () {
    final gradle = read('android/app/build.gradle.kts');
    final example = read('android/key.properties.example');
    final gitignore = read('.gitignore');

    expect(gradle, contains('ANDROID_KEYSTORE_PATH'));
    expect(gradle, contains('ANDROID_KEY_ALIAS'));
    expect(gradle, isNot(contains('signingConfigs.getByName("debug")')));
    expect(example, contains('storeFile='));
    expect(gitignore, contains('android/key.properties'));
    expect(gitignore, contains('android/upload-keystore.jks'));
  });

  test('workflow 使用 iOS/Android scoped secrets，不再使用泛用 key', () {
    final workflow = read('.github/workflows/mobile.yml');
    final infoPlist = read('ios/Runner/Info.plist');

    expect(workflow, contains('GOOGLE_MAPS_IOS_API_KEY'));
    expect(workflow, contains('secrets.GOOGLE_MAPS_ANDROID_API_KEY'));
    expect(workflow, contains('flutter build apk --debug'));
    expect(workflow, isNot(contains('secrets.MAPS_API_KEY')));
    expect(workflow, contains('GOOGLE_MAPS_IOS_API_KEY=%s'));
    expect(workflow, contains("wait-for-processing: 'true'"));
    expect(workflow, isNot(contains('uses-non-exempt-encryption')));
    expect(workflow, contains('runner:'));
    expect(workflow, contains('tripline-release'));
    expect(workflow, contains(r'runs-on: ${{ inputs.runner }}'));
    expect(
      workflow,
      contains(r"if: ${{ github.event_name != 'workflow_dispatch' }}"),
    );
    expect('flutter test'.allMatches(workflow).length, greaterThanOrEqualTo(2));
    expect(infoPlist, contains('ITSAppUsesNonExemptEncryption'));
  });

  test('workflow 手動發布 Android closed testing 且沒有 production 權限', () {
    final workflow = read('.github/workflows/mobile.yml');

    expect(workflow, contains('release_target:'));
    expect(workflow, contains('- android-closed'));
    expect(workflow, contains('android_closed:'));
    expect(workflow, contains(r"inputs.release_target == 'android-closed'"));
    expect(workflow, contains('secrets.ANDROID_KEYSTORE_BASE64'));
    expect(workflow, contains('secrets.ANDROID_KEYSTORE_PASSWORD'));
    expect(workflow, contains('secrets.ANDROID_KEY_ALIAS'));
    expect(workflow, contains('secrets.ANDROID_KEY_PASSWORD'));
    expect(workflow, contains('secrets.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON'));
    expect(workflow, contains('flutter build appbundle'));
    expect(workflow, contains('GITHUB_RUN_NUMBER * 100 + GITHUB_RUN_ATTEMPT'));
    expect(workflow, contains('GITHUB_RUN_ATTEMPT >= 100'));
    expect(workflow, contains('2100000000'));
    expect(
      workflow,
      contains(
        'r0adkll/upload-google-play@'
        'e738b9dd8f2476ea806d921b64aacd24f34515a5',
      ),
    );
    expect(
      workflow,
      contains(
        'actions/upload-artifact@'
        'ea165f8d65b6e75b540449e92b4886f43607fa02',
      ),
    );
    expect(workflow, contains('tripline-android-closed-'));
    expect(workflow, contains('tracks: alpha'));
    expect(workflow, contains('status: completed'));
    expect(workflow, isNot(contains('track: production')));
    expect(workflow, isNot(contains('tracks: production')));
  });
}
