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
    expect(workflow, contains("uses-non-exempt-encryption: 'false'"));
    expect(infoPlist, contains('ITSAppUsesNonExemptEncryption'));
  });
}
