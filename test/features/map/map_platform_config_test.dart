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

  test(
    'mobile releases keep reusable Test Lab evidence without gating uploads',
    () {
      final e2eWorkflow = File(
        '.github/workflows/mobile-e2e.yml',
      ).readAsStringSync();
      final releaseWorkflow = File(
        '.github/workflows/mobile.yml',
      ).readAsStringSync();

      expect(e2eWorkflow, contains('workflow_call:'));
      expect(
        releaseWorkflow,
        contains('uses: ./.github/workflows/mobile-e2e.yml'),
      );
      expect(releaseWorkflow, isNot(contains('needs: external_device_gate')));
      expect(
        releaseWorkflow,
        isNot(contains("needs.external_device_gate.result == 'success'")),
      );
    },
  );
}
