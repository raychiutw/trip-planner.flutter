import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'posix_test_support.dart';

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
  final appOwnedSmoke = File(
    'patrol_test/app_owned_flow_test.dart',
  ).readAsStringSync();
  final appFlowFixture = File(
    'integration_test/support/app_flow_fixture.dart',
  ).readAsStringSync();
  final androidBuild = File('android/app/build.gradle.kts').readAsStringSync();
  final standardIntegrationRunner = File(
    'android/app/src/standardIntegrationAndroidTest/java/'
    'com/raychiu/tripline/MainActivityTest.java',
  ).readAsStringSync();
  final springBoardGuard = File(
    'patrol_test/support/ios_system_alerts.dart',
  ).readAsStringSync();
  final setupGuide = File('docs/mobile-e2e.md').readAsStringSync();
  final evidenceSanitizer = File(
    'tool/sanitize_test_lab_evidence.sh',
  ).readAsStringSync();
  final manualEvidenceValidator = File(
    'tool/validate_manual_evidence.sh',
  ).readAsStringSync();
  final testLabSigning = File(
    'ios/Flutter/TestLabSigning.xcconfig',
  ).readAsStringSync();
  final nativeGestureBridge = File(
    'ios/RunnerUITests/RunnerUITests.m',
  ).readAsStringSync();
  final androidNativeGestureBridge = File(
    'android/app/src/androidTest/java/com/raychiu/tripline/MainActivityTest.java',
  ).readAsStringSync();

  group('external mobile integration evidence', () {
    test('Patrol suites run on Firebase Test Lab for Android and iOS', () {
      expect(e2eWorkflow, contains('patrol_test/native_map_smoke_test.dart'));
      expect(e2eWorkflow, contains('patrol_test/app_owned_flow_test.dart'));
      expect(e2eWorkflow, contains('gcloud firebase test android run'));
      expect(e2eWorkflow, contains('gcloud firebase test ios run'));
    });

    test('standard Flutter integration runs before Android Patrol', () {
      final integration = e2eWorkflow.indexOf(
        '- name: Run Flutter integration matrix',
      );
      final patrol = e2eWorkflow.indexOf('- name: Run Android matrix');

      expect(e2eWorkflow, contains('integration_test/app_smoke_test.dart'));
      expect(e2eWorkflow, contains('./gradlew app:assembleAndroidTest'));
      expect(
        RegExp(
          r'-PstandardIntegrationTest=true',
        ).allMatches(e2eWorkflow).length,
        2,
      );
      expect(
        e2eWorkflow,
        contains('build/integration-test/app-debug-androidTest.apk'),
      );
      expect(e2eWorkflow, contains('INTEGRATION_TEST_RESULTS_DIR'));
      expect(e2eWorkflow, contains('test-lab-android-integration.log'));
      expect(integration, isNonNegative);
      expect(integration, lessThan(patrol));
      expect(setupGuide, contains('integration_test/app_smoke_test.dart'));
      expect(
        androidBuild,
        contains('"androidx.test.runner.AndroidJUnitRunner"'),
      );
      expect(androidBuild, contains('"pl.leancode.patrol.PatrolJUnitRunner"'));
      expect(
        androidBuild,
        contains('"src/standardIntegrationAndroidTest/java"'),
      );
      expect(
        standardIntegrationRunner,
        contains('@RunWith(FlutterTestRunner.class)'),
      );
      expect(standardIntegrationRunner, isNot(contains('PatrolJUnitRunner')));
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
      expect(
        e2eWorkflow,
        contains('test-lab-results/android/integration \\\n'),
      );
      expect(e2eWorkflow, contains('test-lab-results/android/patrol'));
      expect(e2eWorkflow, contains('test-lab-results/ios'));
      expect(setupGuide, contains('FIREBASE_TEST_RESULTS_BUCKET'));
      expect(setupGuide, contains('.github/test-lab-results-lifecycle.json'));
    });

    test('deterministic product-state screenshots are always uploaded', () {
      expect(releaseWorkflow, contains('build/test-artifacts'));
      expect(releaseWorkflow, contains('if: \${{ always() }}'));
      expect(releaseWorkflow, contains('tripline-ui-evidence-'));
      expect(
        releaseWorkflow,
        contains(
          '          path: build/test-artifacts\n'
          '          if-no-files-found: error',
        ),
      );
    });

    test('release target selects its matching external device platform', () {
      expect(
        releaseWorkflow,
        contains("inputs.release_target == 'both' && 'all' ||"),
      );
      expect(
        releaseWorkflow,
        isNot(contains('with:\n      platform: android')),
      );
    });

    test('one dispatch can release both stores with the same build number', () {
      expect(
        releaseWorkflow,
        contains(
          '      release_target:\n'
          '        description: Mobile release destination\n'
          '        required: true\n'
          '        default: both',
        ),
      );
      expect(releaseWorkflow, contains('          - both'));
      expect(
        RegExp(
          r"inputs\.release_target == 'both'",
        ).allMatches(releaseWorkflow).length,
        greaterThanOrEqualTo(3),
      );
      expect(
        RegExp(
          r'GITHUB_RUN_NUMBER \* 100 \+ GITHUB_RUN_ATTEMPT',
        ).allMatches(releaseWorkflow).length,
        2,
      );
    });

    test('release evidence fails closed unless BLOCKED is waived', () {
      expect(releaseWorkflow, isNot(contains('run_optional_evidence')));
      expect(releaseWorkflow, contains('manual_evidence_sha:'));
      expect(releaseWorkflow, contains('manual_evidence_url:'));
      expect(releaseWorkflow, contains('manual_evidence_result:'));
      expect(releaseWorkflow, contains('manual_evidence_waiver:'));
      expect(releaseWorkflow, contains('manual_evidence_waiver_reason:'));
      expect(releaseWorkflow, contains('manual_evidence_gate:'));
      expect(
        RegExp(
          r'needs: \[ci, external_device_gate, manual_evidence_gate\]',
        ).allMatches(releaseWorkflow).length,
        2,
      );
      expect(releaseWorkflow, contains('EVIDENCE_RESULT'));
      expect(releaseWorkflow, contains('EVIDENCE_SHA'));
      expect(releaseWorkflow, contains('EVIDENCE_WAIVER'));
      expect(releaseWorkflow, contains('EVIDENCE_WAIVER_REASON'));
      expect(releaseWorkflow, contains('RELEASE_SHA'));
      expect(manualEvidenceValidator, contains('https://'));
      expect(releaseWorkflow, contains('          - FAIL'));
      expect(releaseWorkflow, contains('case "\$EVIDENCE_RESULT" in'));
      expect(releaseWorkflow, contains('            PASS)'));
      expect(releaseWorkflow, contains('            BLOCKED)'));
      expect(
        releaseWorkflow,
        contains('if [[ "\$EVIDENCE_WAIVER" != "true" ]]'),
      );
      expect(
        releaseWorkflow,
        contains('Release waiver reason must not be empty'),
      );
      expect(
        releaseWorkflow,
        contains('Release waiver record must be a valid HTTPS URL with a host'),
      );
      expect(
        releaseWorkflow,
        contains('summary_result="BLOCKED (release waiver)"'),
      );
      expect(
        releaseWorkflow,
        contains(
          'Manual accessibility evidence must be PASS, or BLOCKED with an explicit release waiver',
        ),
      );
      expect(
        releaseWorkflow,
        contains(
          'bash tool/validate_manual_evidence.sh '
          '"\$EVIDENCE_URL" "\$RELEASE_SHA"',
        ),
      );
      expect(manualEvidenceValidator, contains('curl \\'));
      expect(manualEvidenceValidator, contains('--fail'));
      expect(manualEvidenceValidator, contains("--proto '=https'"));
      expect(manualEvidenceValidator, contains('--connect-timeout 10'));
      expect(manualEvidenceValidator, contains('--max-time 30'));
      expect(manualEvidenceValidator, contains('--max-filesize'));
      expect(manualEvidenceValidator, contains('report_bytes'));
      expect(manualEvidenceValidator, contains('jq -e'));
      expect(
        releaseWorkflow.indexOf('if [[ "\$EVIDENCE_SHA" != "\$RELEASE_SHA" ]]'),
        lessThan(releaseWorkflow.indexOf('case "\$EVIDENCE_RESULT" in')),
      );
    });

    test('release CI enforces format, analyzer and one full test suite', () {
      expect(
        releaseWorkflow,
        contains('dart format --output=none --set-exit-if-changed .'),
      );
      expect(releaseWorkflow, contains('flutter analyze --no-fatal-infos'));
      expect(releaseWorkflow, contains('flutter test'));
      expect(
        releaseWorkflow,
        isNot(
          contains('flutter test test/flows/app_owned_release_flow_test.dart'),
        ),
      );
      expect(
        releaseWorkflow,
        isNot(contains("github.event_name != 'workflow_dispatch'")),
      );
      expect(releaseWorkflow, contains('needs: ci'));
    });

    test('manual accessibility evidence uses a traceable case schema', () {
      expect(setupGuide, contains('## 發布證據格式'));
      expect(setupGuide, contains('manual_evidence_sha'));
      expect(setupGuide, contains('manual_evidence_url'));
      expect(setupGuide, contains('manual_evidence_result'));
      expect(setupGuide, contains('A11Y-VOICEOVER'));
      expect(setupGuide, contains('A11Y-BOLD-TEXT'));
      expect(setupGuide, contains('A11Y-REDUCE-TRANSPARENCY'));
      expect(setupGuide, contains('LAYOUT-SAFE-AREA'));
      expect(setupGuide, contains('NAV-EDGE-BACK'));
      expect(setupGuide, contains('PASS | FAIL | BLOCKED'));
      for (final field in [
        'version',
        'build',
        'install_source',
        'viewport',
        'setting_or_assistive_technology',
        'flow',
        'expected',
        'observation',
        'blocker',
        'remediation',
      ]) {
        expect(setupGuide, contains('`$field`'));
      }
      expect(setupGuide, contains('`FAIL` 或 `BLOCKED`'));
      expect(setupGuide, contains('缺少必要欄位'));
      expect(setupGuide, contains('"schema_version": 1'));
      expect(setupGuide, contains('"cases": [...]'));
    });

    test('manual evidence validator fails closed', () {
      const releaseSha = '0123456789abcdef0123456789abcdef01234567';
      const requiredCaseIds = [
        'A11Y-VOICEOVER',
        'A11Y-VOICE-CONTROL',
        'A11Y-SWITCH-CONTROL',
        'A11Y-FULL-KEYBOARD',
        'A11Y-POINTER',
        'A11Y-BUTTON-SHAPES',
        'A11Y-BOLD-TEXT',
        'A11Y-DIFFERENTIATE-WITHOUT-COLOR',
        'APPEARANCE-LIGHT-DARK',
        'A11Y-INCREASE-CONTRAST',
        'A11Y-REDUCE-TRANSPARENCY',
        'A11Y-REDUCE-MOTION',
        'LAYOUT-SAFE-AREA',
        'LAYOUT-KEYBOARD',
        'NAV-EDGE-BACK',
      ];
      for (final caseId in requiredCaseIds) {
        expect(manualEvidenceValidator, contains('"$caseId"'));
        expect(setupGuide, contains('`$caseId`'));
      }
      final root = Directory.systemTemp.createTempSync(
        'tripline-manual-evidence-',
      );
      addTearDown(() => root.deleteSync(recursive: true));
      final fakeBin = Directory('${root.path}/bin')..createSync();
      File('${fakeBin.path}/curl').writeAsStringSync(r'''#!/usr/bin/env bash
set -euo pipefail
if [[ "${FAKE_CURL_EXIT_CODE:-0}" != "0" ]]; then
  exit "$FAKE_CURL_EXIT_CODE"
fi
output=""
while (($#)); do
  case "$1" in
    --output)
      output="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
[[ -n "$output" ]]
cp "$FAKE_CURL_RESPONSE" "$output"
''');
      final response = File('${root.path}/response.json');

      Map<String, Object?> validReport() => {
        'schema_version': 1,
        'cases': [
          for (final caseId in requiredCaseIds)
            {
              'case_id': caseId,
              'result': 'PASS',
              'source_sha': releaseSha,
              'version': '1.0.0',
              'build': '100',
              'install_source': 'TestFlight',
              'tester': 'Release QA',
              'device': 'iPhone 16 Pro',
              'os_version': 'iOS 26.0',
              'viewport': 'compact portrait',
              'setting_or_assistive_technology': caseId,
              'flow': 'Open the required flow and exercise every control.',
              'expected': 'The flow remains operable and unobstructed.',
              'observation': 'Observed the expected behavior.',
              'blocker': 'N/A',
              'remediation': 'N/A',
              'started_at': '2026-07-24T12:00:00+08:00',
              'evidence': 'https://evidence.example/$caseId',
            },
        ],
      };

      Map<String, Object?> copyReport(Map<String, Object?> report) =>
          jsonDecode(jsonEncode(report)) as Map<String, Object?>;

      List<Map<String, Object?>> cases(Map<String, Object?> report) =>
          (report['cases']! as List<Object?>).cast<Map<String, Object?>>();

      ProcessResult validate(
        Object report, {
        int curlExitCode = 0,
        String evidenceUrl = 'https://evidence.example/report.json',
      }) {
        response.writeAsStringSync(
          report is String ? report : jsonEncode(report),
        );
        return Process.runSync(testBashExecutable, [
          '-lc',
          r'''
chmod +x "$1/curl"
export PATH="$1:$PATH"
export FAKE_CURL_RESPONSE="$2"
export FAKE_CURL_EXIT_CODE="$3"
exec bash tool/validate_manual_evidence.sh "$4" "$5"
''',
          'manual-evidence-test',
          bashPath(fakeBin.path),
          bashPath(response.path),
          '$curlExitCode',
          evidenceUrl,
          releaseSha,
        ]);
      }

      final valid = validReport();
      final pass = validate(valid);
      expect(pass.exitCode, 0, reason: '${pass.stderr}');

      final missingField = copyReport(valid);
      cases(missingField).first.remove('observation');
      final failedCase = copyReport(valid);
      cases(failedCase).first['result'] = 'FAIL';
      final blockedCase = copyReport(valid);
      cases(blockedCase).first['result'] = 'BLOCKED';
      final wrongSha = copyReport(valid);
      cases(wrongSha).first['source_sha'] =
          'ffffffffffffffffffffffffffffffffffffffff';
      final missingCase = copyReport(valid);
      cases(
        missingCase,
      ).removeWhere((item) => item['case_id'] == 'A11Y-BOLD-TEXT');
      final duplicateCase = copyReport(valid);
      cases(duplicateCase).add(Map.of(cases(duplicateCase).first));
      final inconsistentVersionAndBuild = copyReport(valid);
      cases(inconsistentVersionAndBuild).last
        ..['version'] = '1.0.1'
        ..['build'] = '101';
      final insecureEvidence = copyReport(valid);
      cases(insecureEvidence).first['evidence'] =
          'http://evidence.example/case';
      final hostlessEvidence = copyReport(valid);
      cases(hostlessEvidence).first['evidence'] = 'https:///case';
      final whitespaceField = copyReport(valid);
      cases(whitespaceField).first['observation'] = '   ';

      final failures = <String, ProcessResult>{
        'legacy report': validate({'result': 'PASS', 'source_sha': releaseSha}),
        '404 response': validate(valid, curlExitCode: 22),
        'invalid JSON': validate('not-json'),
        'missing field': validate(missingField),
        'FAIL result': validate(failedCase),
        'BLOCKED result': validate(blockedCase),
        'wrong SHA': validate(wrongSha),
        'missing case': validate(missingCase),
        'duplicate case': validate(duplicateCase),
        'inconsistent version/build': validate(inconsistentVersionAndBuild),
        'insecure evidence URL': validate(insecureEvidence),
        'hostless evidence URL': validate(hostlessEvidence),
        'hostless report URL': validate(valid, evidenceUrl: 'https:///report'),
        'whitespace-only field': validate(whitespaceField),
      };
      for (final MapEntry(key: scenario, value: result) in failures.entries) {
        expect(
          result.exitCode,
          isNot(0),
          reason: '$scenario unexpectedly passed',
        );
      }
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

    test('iOS Test Lab manually signs each target with its own profile', () {
      expect(
        e2eWorkflow,
        contains(
          'IOS_TEST_RUNNER_BUNDLE_ID: '
          'com.raychiu.tripline.RunnerUITests.xctrunner',
        ),
      );
      expect(
        e2eWorkflow,
        contains('bundle-id: \${{ env.IOS_TEST_RUNNER_BUNDLE_ID }}'),
      );
      expect(
        setupGuide,
        contains('com.raychiu.tripline.RunnerUITests.xctrunner'),
      );
      expect(testLabSigning, contains('CODE_SIGN_STYLE = Manual'));
      expect(
        testLabSigning,
        contains(
          'CODE_SIGN_IDENTITY = '
          'Apple Development: Created via API (XSY38R3689)',
        ),
      );
      expect(
        testLabSigning,
        contains(
          'TRIPLINE_TESTLAB_PROFILE_Runner = '
          'Tripline App Development CI 2026-07-19',
        ),
      );
      expect(
        testLabSigning,
        contains(
          'TRIPLINE_TESTLAB_PROFILE_RunnerUITests = '
          'Tripline XCTest Runner Development CI 2026-07-19',
        ),
      );
      expect(
        testLabSigning,
        contains(
          'PROVISIONING_PROFILE_SPECIFIER = '
          '\$(TRIPLINE_TESTLAB_PROFILE_\$(TARGET_NAME))',
        ),
      );
    });

    test('repository build scripts cannot read the App Store signing key', () {
      final validation = e2eWorkflow.indexOf(
        '- name: Validate Test Lab and Apple signing configuration',
      );
      final authentication = e2eWorkflow.indexOf(
        '- name: Authenticate to Google Cloud with OIDC',
        validation,
      );
      final prepare = e2eWorkflow.indexOf(
        '- name: Prepare iOS build dependencies',
      );
      final build = e2eWorkflow.indexOf(
        '- name: Build and package signed Patrol XCTest',
      );
      final matrix = e2eWorkflow.indexOf('- name: Run iOS matrix');

      expect(validation, greaterThan(-1));
      expect(validation, lessThan(authentication));
      expect(authentication, lessThan(prepare));
      expect(prepare, lessThan(build));
      expect(build, lessThan(matrix));
      expect(
        e2eWorkflow.substring(validation, authentication),
        allOf(
          contains('APPSTORE_API_PRIVATE_KEY_CONFIGURED'),
          isNot(
            contains(
              'APPSTORE_API_PRIVATE_KEY: '
              '\${{ secrets.APPSTORE_API_PRIVATE_KEY }}',
            ),
          ),
        ),
      );
      expect(
        e2eWorkflow.substring(prepare, build),
        contains('dart pub global activate patrol_cli'),
      );
      expect(
        e2eWorkflow.substring(build, matrix),
        allOf(
          contains(
            'XCODE_XCCONFIG_FILE: '
            '\${{ github.workspace }}/ios/Flutter/TestLabSigning.xcconfig',
          ),
          contains('patrol build ios'),
          contains('--verbose'),
        ),
      );
      expect(
        e2eWorkflow.substring(build, matrix),
        isNot(
          anyOf(
            contains('APPSTORE_API_PRIVATE_KEY'),
            contains('APPSTORE_API_KEY_PATH'),
            contains('authenticationKeyPath'),
            contains('xcodebuild-wrapper'),
          ),
        ),
      );
      expect(e2eWorkflow, isNot(contains('"\$GITHUB_PATH"')));
      expect(
        File('tool/xcodebuild_authenticated_wrapper.sh').existsSync(),
        isFalse,
      );
    });

    test('release 不再包含收藏 restore contract 與 feature flag', () {
      expect(
        releaseWorkflow,
        isNot(
          anyOf(
            contains('Verify staging favorite restore'),
            contains('FAVORITE_RESTORE_ENABLED'),
            contains('STAGING_FAVORITE_POI_ID'),
            contains('favorite_restore_contract'),
            contains('favorite-restore-contract-'),
          ),
        ),
      );
      expect(
        File('tool/verify_favorite_restore_contract.sh').existsSync(),
        isFalse,
      );
      expect(
        File(
          'test/workflows/favorite_restore_contract_script_test.dart',
        ).existsSync(),
        isFalse,
      );
      expect(
        File('tool/staging-release-environments.txt').existsSync(),
        isFalse,
      );
    });

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

      final result = Process.runSync(testBashExecutable, [
        '-l',
        'tool/sanitize_test_lab_evidence.sh',
        bashPath(root.path),
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

      final result = Process.runSync(testBashExecutable, [
        '-l',
        'tool/sanitize_test_lab_evidence.sh',
        bashPath(root.path),
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
        expect(nativeMapSmoke, isNot(contains('.platform.mobile.doubleTap(')));
        expect(nativeMapSmoke, isNot(contains('.startGesture(')));
        expect(nativeMapSmoke, contains('ensureSemantics'));
        expect(nativeMapSmoke, contains('.waitUntilExists('));
        for (final requestLabel in [
          'Tripline native map pinch request',
          'Tripline native map rotate request',
          'Tripline native map double tap request',
        ]) {
          expect(nativeMapSmoke, contains(requestLabel));
          expect(nativeGestureBridge, contains(requestLabel));
          expect(androidNativeGestureBridge, contains(requestLabel));
        }
        for (final source in [
          nativeMapSmoke,
          nativeGestureBridge,
          androidNativeGestureBridge,
        ]) {
          expect(source, contains('native Google Map renders'));
        }
        expect(nativeGestureBridge, contains('pinchWithScale:'));
        expect(nativeGestureBridge, contains('rotate:'));
        expect(nativeGestureBridge, contains('[target doubleTap]'));
        expect(androidNativeGestureBridge, contains('.pinchOut('));
        expect(
          androidNativeGestureBridge,
          contains('.performTwoPointerGesture('),
        );
        expect(
          androidNativeGestureBridge,
          contains('!request.equals(activeRequest)'),
        );
        expect(
          androidNativeGestureBridge,
          contains('dartTestName.contains(NATIVE_MAP_TEST_NAME)'),
        );
        expect(androidNativeGestureBridge, contains('gestureBridge.join('));
        expect(
          androidNativeGestureBridge,
          contains('setUncaughtExceptionHandler'),
        );
        expect(androidNativeGestureBridge, contains('addSuppressed'));
        expect(
          androidNativeGestureBridge,
          contains('device.click(centerX, centerY)'),
        );
        expect(
          androidNativeGestureBridge,
          contains('SystemClock.sleep(DOUBLE_TAP_INTERVAL_MS)'),
        );
        expect(
          nativeGestureBridge,
          contains('containsString:@"native Google Map renders"'),
        );
        expect(nativeMapSmoke, contains('_poiTapOffsets'));
        expect(nativeMapSmoke, contains('#toggleMapLifecycle'));
        expect(nativeMapSmoke, contains('#nativeMapRemounted'));
        expect(nativeMapSmoke, contains('#nativeMapRemountCameraObserved'));
        expect(nativeMapSmoke, isNot(contains('Duration(seconds: 1)')));
        expect(nativeMapSmoke, isNot(contains('Duration(seconds: 2)')));
        expect(nativeMapSmoke, isNot(contains('_requestedZoom12')));
      },
    );

    test('both iOS targets dismiss a stale SpringBoard tutorial', () {
      final appDismissal = appOwnedSmoke.indexOf(
        'dismissStaleSpringBoardTutorial',
      );
      final mapDismissal = nativeMapSmoke.indexOf(
        'dismissStaleSpringBoardTutorial',
      );
      final flow = appOwnedSmoke.indexOf('runAppOwnedReleaseFlow');
      final map = nativeMapSmoke.indexOf('pumpWidgetAndSettle');

      expect(appDismissal, isNonNegative);
      expect(mapDismissal, isNonNegative);
      expect(appDismissal, lessThan(flow));
      expect(mapDismissal, lessThan(map));
      expect(springBoardGuard, contains("text: 'Edit Home Screen'"));
      expect(springBoardGuard, contains('IOSElementType.button'));
      expect(springBoardGuard, contains("label: 'Dismiss'"));
      expect(springBoardGuard, contains('getNativeViews'));
      expect(springBoardGuard, contains('.tap('));
      expect(springBoardGuard, isNot(contains('tapAt')));
      expect(springBoardGuard, isNot(contains('PatrolActionException')));
    });

    test('login failures retain visible screen diagnostics', () {
      expect(appFlowFixture, contains('final visibleText ='));
      expect(appFlowFixture, contains('reason: visibleText'));
    });

    test('iOS Patrol flow uses release-device-safe text entry', () {
      expect(
        RegExp(
          r'enterText:\s*\(finder, text\)\s*=>\s*\$\.enterText\('
          r'\s*finder,\s*text,\s*hideKeyboard:\s*false,?\s*\)',
        ).hasMatch(appOwnedSmoke),
        isTrue,
      );
      expect(
        RegExp(r'tester\.enterText\b').allMatches(appFlowFixture).length,
        1,
        reason: 'shared flow steps must use the injected text-entry driver',
      );
    });

    test('release root tab navigation targets the app-owned key contract', () {
      final helper = RegExp(
        r'Finder _rootTab\(String label\) \{(?<body>[\s\S]*?)\n\}',
      ).firstMatch(appFlowFixture)?.namedGroup('body');

      expect(helper, isNotNull);
      expect(helper, contains("ValueKey('root-tab-\$label')"));
      expect(
        helper,
        isNot(anyOf(contains('bySemanticsLabel'), contains('GestureDetector'))),
        reason: 'release tests cannot use debug semantics or package internals',
      );
    });
  });
}
