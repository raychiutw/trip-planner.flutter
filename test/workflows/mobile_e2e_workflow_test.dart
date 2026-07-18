import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final e2eWorkflow = File(
    '.github/workflows/mobile-e2e.yml',
  ).readAsStringSync();
  final releaseWorkflow = File(
    '.github/workflows/mobile.yml',
  ).readAsStringSync();
  final nativeMapSmoke = File(
    'patrol_test/native_map_smoke_test.dart',
  ).readAsStringSync();
  final setupGuide = File('docs/mobile-e2e.md').readAsStringSync();
  final restoreContract = File(
    'tool/verify_favorite_restore_contract.sh',
  ).readAsStringSync();
  final evidenceSanitizer = File(
    'tool/sanitize_test_lab_evidence.sh',
  ).readAsStringSync();

  group('external mobile integration test gate', () {
    test('Patrol suites run on Firebase Test Lab for Android and iOS', () {
      expect(e2eWorkflow, contains('patrol_test/native_map_smoke_test.dart'));
      expect(e2eWorkflow, contains('patrol_test/app_owned_flow_test.dart'));
      expect(e2eWorkflow, contains('gcloud firebase test android run'));
      expect(e2eWorkflow, contains('gcloud firebase test ios run'));
    });

    test('scheduled Android matrix runs on Taipei weekdays', () {
      expect(
        e2eWorkflow,
        contains("cron: '30 18 * * 0-4'"),
        reason: '18:30 UTC Sunday-Thursday is 02:30 Monday-Friday in Taipei',
      );
    });

    test('raw Test Lab evidence is copied into GitHub artifacts', () {
      expect(e2eWorkflow, contains('FIREBASE_TEST_RESULTS_BUCKET'));
      expect(e2eWorkflow, contains('--results-bucket'));
      expect(e2eWorkflow, contains('gcloud storage cp --recursive'));
      expect(e2eWorkflow, contains('test-lab-results/android'));
      expect(e2eWorkflow, contains('test-lab-results/ios'));
      expect(setupGuide, contains('FIREBASE_TEST_RESULTS_BUCKET'));
      expect(setupGuide, contains('.github/test-lab-results-lifecycle.json'));
    });

    test('deterministic product-state screenshots are always uploaded', () {
      expect(releaseWorkflow, contains('build/test-artifacts'));
      expect(releaseWorkflow, contains('if: \${{ always() }}'));
      expect(releaseWorkflow, contains('tripline-ui-evidence-'));
    });

    test('release target selects its matching external device platform', () {
      expect(
        releaseWorkflow,
        contains(
          "platform: \${{ inputs.release_target == 'testflight' && 'ios' || 'android' }}",
        ),
      );
      expect(
        releaseWorkflow,
        isNot(contains('with:\n      platform: android')),
      );
    });

    test('manual releases are master-only and use a protected environment', () {
      expect(releaseWorkflow, contains("github.ref == 'refs/heads/master'"));
      expect(releaseWorkflow, contains('environment: mobile-release'));
      expect(releaseWorkflow, isNot(contains('secrets: inherit')));
      expect(
        releaseWorkflow,
        isNot(contains('permissions:\n  contents: read\n  id-token: write')),
      );
      expect(releaseWorkflow, contains('raven-actions/actionlint@'));
      expect(releaseWorkflow, contains('version: 1.7.12'));
    });

    test(
      'direct Test Lab dispatch is master-only and environment protected',
      () {
        expect(
          RegExp(
            "github.ref == 'refs/heads/master'",
          ).allMatches(e2eWorkflow).length,
          greaterThanOrEqualTo(2),
        );
        expect(
          RegExp(r'environment: mobile-e2e').allMatches(e2eWorkflow).length,
          greaterThanOrEqualTo(2),
        );
      },
    );

    test(
      'release fails closed on the real staging favorite restore contract',
      () {
        expect(releaseWorkflow, contains('Verify staging favorite restore'));
        expect(releaseWorkflow, contains('STAGING_API_BASE_URL'));
        expect(releaseWorkflow, isNot(contains('STAGING_ALLOWED_HOST')));
        expect(releaseWorkflow, contains('STAGING_SESSION_COOKIE'));
        expect(releaseWorkflow, contains('STAGING_OTHER_SESSION_COOKIE'));
        expect(
          releaseWorkflow,
          contains('--dart-define=FAVORITE_RESTORE_ENABLED=true'),
        );
        expect(e2eWorkflow, isNot(contains('favorite_restore_enabled')));
        expect(restoreContract, contains('/api/poi-favorites/'));
        expect(restoreContract, contains('/restore'));
        expect(restoreContract, contains('STAGING_CONTRACT_GUARD'));
        expect(restoreContract, contains('staging-release-environments.txt'));
        expect(restoreContract, contains('/api/environment-identity'));
        expect(restoreContract, contains('X-Expected-Environment-ID'));
        expect(restoreContract, contains('expected-environment-id-v1'));
        expect(restoreContract, contains('--connect-timeout'));
        expect(restoreContract, contains('--max-time'));
        expect(releaseWorkflow, contains('favorite-restore-contract-'));
        expect(
          releaseWorkflow,
          contains(
            'external_device_gate:\n'
            '    name: External device release gate\n'
            '    needs: favorite_restore_contract',
          ),
        );
        expect(
          'needs: external_device_gate'.allMatches(releaseWorkflow).length,
          2,
        );
        expect(
          "needs.external_device_gate.result == 'success'"
              .allMatches(releaseWorkflow)
              .length,
          2,
        );
      },
    );

    test('public GitHub artifacts exclude signed device test binaries', () {
      expect(
        'tool/sanitize_test_lab_evidence.sh'.allMatches(e2eWorkflow).length,
        2,
      );
      expect(
        e2eWorkflow,
        contains(
          "if: \${{ always() && steps.sanitize_android_evidence.outcome == 'success' }}",
        ),
      );
      expect(
        e2eWorkflow,
        contains(
          "if: \${{ always() && steps.sanitize_ios_evidence.outcome == 'success' }}",
        ),
      );
      expect(
        e2eWorkflow,
        isNot(
          contains(
            'path: |\n            build/app/outputs/apk/debug/app-debug.apk',
          ),
        ),
      );
      expect(
        e2eWorkflow,
        isNot(
          contains(
            'path: |\n            build/ios_integ/Build/Products/ios_tests.zip',
          ),
        ),
      );
      expect(evidenceSanitizer, contains("-iname '*.apk'"));
      expect(evidenceSanitizer, contains("-iname '*.ipa'"));
      expect(evidenceSanitizer, contains("-iname '*.zip'"));
    });

    test('Test Lab evidence sanitizer keeps diagnostics only', () {
      final root = Directory.systemTemp.createTempSync(
        'tripline-test-lab-evidence-',
      );
      addTearDown(() => root.deleteSync(recursive: true));
      File('${root.path}/.tripline-test-lab-evidence-root').createSync();

      final resultXml = File('${root.path}/result/test_result.xml')
        ..createSync(recursive: true)
        ..writeAsStringSync('<testsuite/>');
      final video = File('${root.path}/result/video.mp4')
        ..writeAsBytesSync(const [0, 1, 2]);
      final app = File('${root.path}/result/app-debug.apk')
        ..writeAsBytesSync(const [3, 4, 5]);
      final testBundle = File('${root.path}/result/ios_tests.zip')
        ..writeAsBytesSync(const [6, 7, 8]);
      final executable = File('${root.path}/result/Runner.app/Runner')
        ..createSync(recursive: true)
        ..writeAsBytesSync(const [9, 10, 11]);

      final result = Process.runSync('bash', [
        'tool/sanitize_test_lab_evidence.sh',
        root.path,
      ]);

      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(resultXml.existsSync(), isTrue);
      expect(video.existsSync(), isTrue);
      expect(app.existsSync(), isFalse);
      expect(testBundle.existsSync(), isFalse);
      expect(executable.existsSync(), isFalse);
    });

    test('Test Lab evidence sanitizer refuses an unmarked directory', () {
      final root = Directory.systemTemp.createTempSync(
        'tripline-unmarked-evidence-',
      );
      addTearDown(() => root.deleteSync(recursive: true));
      final binary = File('${root.path}/must-not-delete.apk')
        ..writeAsBytesSync(const [1, 2, 3]);

      final result = Process.runSync('bash', [
        'tool/sanitize_test_lab_evidence.sh',
        root.path,
      ]);

      expect(result.exitCode, 64);
      expect(binary.existsSync(), isTrue);
    });

    test(
      'native map assertions observe platform callbacks and permissions',
      () {
        expect(nativeMapSmoke, contains('onCameraIdle'));
        expect(nativeMapSmoke, contains('onMapStyleApplied'));
        expect(nativeMapSmoke, contains('grantPermissionWhenInUse'));
        expect(nativeMapSmoke, contains('.swipe('));
        expect(nativeMapSmoke, contains('.waitUntilExists('));
        expect(nativeMapSmoke, contains('_poiTapOffsets'));
        expect(nativeMapSmoke, isNot(contains('Duration(seconds: 1)')));
        expect(nativeMapSmoke, isNot(contains('Duration(seconds: 2)')));
        expect(nativeMapSmoke, isNot(contains('_requestedZoom12')));
      },
    );
  });
}
