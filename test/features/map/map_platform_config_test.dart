import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('map SDK and platform floors are locked consistently', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final androidApp = File('android/app/build.gradle.kts').readAsStringSync();
    final androidSettings = File(
      'android/settings.gradle.kts',
    ).readAsStringSync();
    final podfile = File('ios/Podfile').readAsStringSync();
    final xcode = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();

    expect(pubspec, contains('google_navigation_flutter: ^0.10.0'));
    expect(pubspec, isNot(contains('google_maps_flutter:')));
    expect(androidApp, contains('minSdk = 24'));
    expect(androidApp, contains('desugar_jdk_libs_nio:2.1.5'));
    expect(androidSettings, contains('version "2.3.0"'));
    expect(
      androidSettings,
      contains('com.android.application") version "8.13.2"'),
    );
    expect(podfile, contains("platform :ios, '16.0'"));
    expect(xcode, isNot(contains('IPHONEOS_DEPLOYMENT_TARGET = 14.0')));
    expect(xcode, contains('IPHONEOS_DEPLOYMENT_TARGET = 16.0'));
  });

  test('feature code cannot import a Google map plugin', () {
    for (final entity in Directory('lib/features').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (entity.path.endsWith('map_canvas_mobile.dart')) continue;
      expect(
        source,
        isNot(contains('google_navigation_flutter')),
        reason: entity.path,
      );
      expect(
        source,
        isNot(contains('google_maps_flutter')),
        reason: entity.path,
      );
    }
  });

  test('Test Lab Patrol build keeps the Maps signing identity', () {
    final androidApp = File('android/app/build.gradle.kts').readAsStringSync();
    final workflow = File(
      '.github/workflows/mobile-e2e.yml',
    ).readAsStringSync();

    expect(androidApp, contains('ANDROID_SIGN_DEBUG_WITH_RELEASE'));
    expect(workflow, contains('ANDROID_SIGN_DEBUG_WITH_RELEASE: \'true\''));
    expect(workflow, contains('ANDROID_KEYSTORE_BASE64'));
    expect(workflow, contains('E2E_EXPECT_GOOGLE_POI=true'));
  });

  test('iOS Test Lab builds and runs with the same supported Xcode', () {
    final workflow = File(
      '.github/workflows/mobile-e2e.yml',
    ).readAsStringSync();
    final iosJobStart = workflow.indexOf('  ios_test_lab:\n');
    expect(iosJobStart, isNonNegative);
    final iosJob = workflow.substring(iosJobStart);

    expect(
      workflow,
      contains(RegExp(r"^  FIREBASE_XCODE_VERSION: '26\.2'$", multiLine: true)),
    );
    expect(
      iosJob,
      contains(
        RegExp(
          r'^      DEVELOPER_DIR: /Applications/Xcode_26\.2\.app/Contents/Developer$',
          multiLine: true,
        ),
      ),
    );
    expect(
      iosJob,
      contains(
        RegExp(
          r'^            --xcode-version "\$FIREBASE_XCODE_VERSION" \\',
          multiLine: true,
        ),
      ),
    );
    expect(
      iosJob,
      contains(
        RegExp(
          r'^      - name: Verify Test Lab Xcode compatibility$',
          multiLine: true,
        ),
      ),
    );
    expect(
      iosJob,
      contains(
        'gcloud firebase test ios versions describe '
        '"\$FIREBASE_IOS_VERSION"',
      ),
    );
    expect(
      iosJob,
      contains("'.supportedXcodeVersionIds | index(\$xcode) != null'"),
    );
  });

  test('iOS Test Lab runs the app-owned flow before native map state', () {
    final workflow = File(
      '.github/workflows/mobile-e2e.yml',
    ).readAsStringSync();
    final iosJob = workflow.substring(workflow.indexOf('  ios_test_lab:\n'));
    final appOwnedTarget = iosJob.indexOf(
      '--target patrol_test/app_owned_flow_test.dart',
    );
    final nativeMapTarget = iosJob.indexOf(
      '--target patrol_test/native_map_smoke_test.dart',
    );

    expect(appOwnedTarget, isNonNegative);
    expect(nativeMapTarget, isNonNegative);
    expect(appOwnedTarget, lessThan(nativeMapTarget));
  });

  test('Test Lab workflow 自己可被觸發，不依賴發版 workflow 呼叫', () {
    final e2eWorkflow = File(
      '.github/workflows/mobile-e2e.yml',
    ).readAsStringSync();
    final releaseWorkflow = File(
      '.github/workflows/mobile.yml',
    ).readAsStringSync();

    // 發版路徑已與 Test Lab 解耦，mobile.yml 不再呼叫這支 workflow。
    // 因此它必須保有自己的觸發來源，否則就成了永遠不會執行的孤兒。
    expect(
      releaseWorkflow,
      isNot(contains('uses: ./.github/workflows/mobile-e2e.yml')),
    );
    expect(e2eWorkflow, contains('  schedule:'));
    expect(e2eWorkflow, contains(RegExp(r"^    - cron: '", multiLine: true)));
    expect(e2eWorkflow, contains('  workflow_dispatch:'));
    // workflow_call 保留，讓需要時仍可由其他 workflow 重用。
    expect(e2eWorkflow, contains('  workflow_call:'));
  });
}
