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

  test('iOS deployment target 符合 Google Navigation 外掛最低版本', () {
    final podfile = read('ios/Podfile');
    final project = read('ios/Runner.xcodeproj/project.pbxproj');

    expect(podfile, contains("platform :ios, '16.0'"));
    expect(project, isNot(contains('IPHONEOS_DEPLOYMENT_TARGET = 14.0;')));
    expect(
      'IPHONEOS_DEPLOYMENT_TARGET = 16.0;'.allMatches(project).length,
      greaterThanOrEqualTo(3),
    );
  });

  test('iOS 定位權限包含 Apple 要求的完整用途說明', () {
    final infoPlist = read('ios/Runner/Info.plist');

    expect(infoPlist, contains('NSLocationWhenInUseUsageDescription'));
    expect(infoPlist, contains('NSLocationAlwaysAndWhenInUseUsageDescription'));
    expect(infoPlist, contains('不會在背景持續追蹤'));
  });

  test('iOS 透過 EventChannel 提供 Reduce Transparency current value 與變更事件', () {
    final appDelegate = read('ios/Runner/AppDelegate.swift');

    expect(appDelegate, contains('tripline/accessibility/reduce-transparency'));
    expect(appDelegate, contains('FlutterEventChannel'));
    expect(
      appDelegate,
      contains('UIAccessibility.isReduceTransparencyEnabled'),
    );
    expect(
      appDelegate,
      contains('UIAccessibility.reduceTransparencyStatusDidChangeNotification'),
    );
    expect(appDelegate, contains('NotificationCenter.default.addObserver'));
    expect(appDelegate, contains('guard\n      let registrar ='));
    expect(appDelegate, contains('else { return }'));
    expect(appDelegate, contains('ReduceTransparencyPlugin.register'));
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
    expect(workflow, isNot(contains('secrets.MAPS_API_KEY')));
    expect(workflow, contains('GOOGLE_MAPS_IOS_API_KEY=%s'));
    expect(workflow, contains("wait-for-processing: 'true'"));
    expect(workflow, isNot(contains('uses-non-exempt-encryption')));
    // 發版路徑縮短後，ci 只服務 PR／push；手動 dispatch 直接進 store job，
    // 不再把 ci 當成上傳前置閘門。
    expect(
      workflow,
      contains(r"if: ${{ github.event_name != 'workflow_dispatch' }}"),
    );
    expect(infoPlist, contains('ITSAppUsesNonExemptEncryption'));
  });

  test('商店上傳與外部裝置、人工證據解耦，但保留 master-only 與環境審核', () {
    final workflow = read('.github/workflows/mobile.yml');
    final testflightJob = workflow.substring(
      workflow.indexOf('  testflight:'),
      workflow.indexOf('  android_internal:'),
    );
    final androidJob = workflow.substring(
      workflow.indexOf('  android_internal:'),
    );

    // 解耦：store 上傳不再等待任何前置 job，Test Lab 與人工證據各自獨立驗證。
    // 決策與取捨見 docs/adr/0002-decouple-store-upload-from-evidence-gates.md。
    expect(workflow, isNot(contains('external_device_gate')));
    expect(workflow, isNot(contains('manual_evidence_gate')));
    expect(
      workflow,
      isNot(contains('uses: ./.github/workflows/mobile-e2e.yml')),
    );
    expect(testflightJob, isNot(contains('needs:')));
    expect(androidJob, isNot(contains('needs:')));

    // 解耦掉的是 workflow 層的 needs；把關改由 GitHub Environment 審核與
    // master-only 條件承擔。這兩層若也消失，發版就真的沒有任何前置把關。
    for (final job in [testflightJob, androidJob]) {
      expect(job, contains('environment: mobile-release'));
      expect(job, contains(r"github.ref == 'refs/heads/master'"));
      expect(job, contains(r"github.event_name == 'workflow_dispatch'"));
    }
  });

  test('workflow 手動發布 Android internal testing 且沒有 production 權限', () {
    final workflow = read('.github/workflows/mobile.yml');

    expect(workflow, contains('release_target:'));
    expect(workflow, contains('- android-internal'));
    expect(workflow, contains('android_internal:'));
    expect(workflow, contains(r"inputs.release_target == 'android-internal'"));
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
    // 簽章後的 AAB 直接上傳 Google Play，不再保留公開的 GitHub artifact。
    expect(workflow, isNot(contains('actions/upload-artifact')));
    expect(workflow, contains('tracks: internal'));
    expect(workflow, contains('status: completed'));
    expect(workflow, isNot(contains('track: production')));
    expect(workflow, isNot(contains('tracks: production')));
  });
}
