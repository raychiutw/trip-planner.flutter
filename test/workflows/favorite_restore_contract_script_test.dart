import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory sandbox;
  late File mockCurl;
  late Map<String, String> baseEnvironment;

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('tripline-contract-test-');
    mockCurl = File('${sandbox.path}/curl')..writeAsStringSync(_mockCurlSource);
    final chmod = Process.runSync('chmod', ['+x', mockCurl.path]);
    if (chmod.exitCode != 0) {
      fail('Could not make mock curl executable: ${chmod.stderr}');
    }
    baseEnvironment = {
      'PATH': '${sandbox.path}:${Platform.environment['PATH']}',
      'MOCK_CURL_STATE': '${sandbox.path}/curl-state',
      'MOCK_MUTATION_LOG': '${sandbox.path}/mutation-log',
      'MOCK_ENVIRONMENT_ID': 'tripline-staging-test',
      'MOCK_MUTATION_GUARD': 'expected-environment-id-v1',
      'STAGING_API_BASE_URL': 'https://staging.tripline.test',
      'STAGING_ORIGIN': 'https://staging-app.tripline.test',
      'STAGING_SESSION_COOKIE': 'session=owner-fixture',
      'STAGING_OTHER_SESSION_COOKIE': 'session=other-fixture',
      'STAGING_FAVORITE_POI_ID': '123',
      'STAGING_CONTRACT_GUARD': 'tripline-staging-favorite-restore-v1',
    };
  });

  tearDown(() => sandbox.deleteSync(recursive: true));

  test('rejects non-HTTPS and uncommitted staging URLs before curl', () async {
    final insecure = await _runContract({
      ...baseEnvironment,
      'STAGING_API_BASE_URL': 'http://staging.tripline.test',
    });
    expect(insecure.exitCode, 2);
    expect(insecure.stderr, contains('exact committed HTTPS origin'));

    final wrongHost = await _runContract({
      ...baseEnvironment,
      'STAGING_API_BASE_URL': 'https://production.tripline.test',
    });
    expect(wrongHost.exitCode, 2);
    expect(
      wrongHost.stderr,
      contains('committed staging environment allowlist'),
    );
    expect(File(baseEnvironment['MOCK_CURL_STATE']!).existsSync(), isFalse);
  });

  test(
    'rejects the known production API host before allowlist lookup',
    () async {
      final result = await _runContract({
        ...baseEnvironment,
        'STAGING_API_BASE_URL': 'https://trip-planner-dby.pages.dev',
      });

      expect(result.exitCode, 2);
      expect(result.stderr, contains('production hostname'));
      expect(File(baseEnvironment['MOCK_CURL_STATE']!).existsSync(), isFalse);
    },
  );

  test('rejects an uncommitted production-like alias', () async {
    final result = await _runContract({
      ...baseEnvironment,
      'STAGING_API_BASE_URL': 'https://production-alias.example',
    });

    expect(result.exitCode, 2);
    expect(result.stderr, contains('committed staging environment allowlist'));
    expect(File(baseEnvironment['MOCK_CURL_STATE']!).existsSync(), isFalse);
  });

  test('rejects an explicit port before curl', () async {
    final result = await _runContract({
      ...baseEnvironment,
      'STAGING_API_BASE_URL': 'https://staging.tripline.test:8443',
    });

    expect(result.exitCode, 2);
    expect(result.stderr, contains('exact committed HTTPS origin'));
    expect(File(baseEnvironment['MOCK_CURL_STATE']!).existsSync(), isFalse);
  });

  test('rejects a mismatched backend identity before mutations', () async {
    final result = await _runContract({
      ...baseEnvironment,
      'MOCK_ENVIRONMENT_ID': 'tripline-production',
    });

    expect(result.exitCode, 2);
    expect(result.stderr, contains('environment identity'));
    expect(File(baseEnvironment['MOCK_CURL_STATE']!).existsSync(), isFalse);
  });

  test('rejects a backend without the environment mutation guard', () async {
    final result = await _runContract({
      ...baseEnvironment,
      'MOCK_MUTATION_GUARD': 'disabled',
    });

    expect(result.exitCode, 2);
    expect(result.stderr, contains('mutation guard'));
    expect(File(baseEnvironment['MOCK_CURL_STATE']!).existsSync(), isFalse);
  });

  test('rejects a route switch after identity without mutating', () async {
    final result = await _runContract({
      ...baseEnvironment,
      'MOCK_MUTATION_ENVIRONMENT_ID': 'tripline-production',
    });

    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('HTTP 412'));
    expect(File(baseEnvironment['MOCK_MUTATION_LOG']!).existsSync(), isFalse);
  });

  test(
    'rejects internal whitespace in a committed environment entry',
    () async {
      final copiedTool = Directory('${sandbox.path}/tool')..createSync();
      final copiedScript = File('${copiedTool.path}/verify.sh');
      File(
        'tool/verify_favorite_restore_contract.sh',
      ).copySync(copiedScript.path);
      File(
        '${copiedTool.path}/staging-release-environments.txt',
      ).writeAsStringSync(
        'https://staging.tripline.test tripline staging test\n',
      );

      final result = await _runContract(
        baseEnvironment,
        scriptPath: copiedScript.path,
      );

      expect(result.exitCode, 2);
      expect(result.stderr, contains('allowlist is invalid'));
      expect(File(baseEnvironment['MOCK_CURL_STATE']!).existsSync(), isFalse);
    },
  );

  test('canonicalizes production hosts and rejects URL userinfo', () async {
    for (final url in <String>[
      'https://TRIP-PLANNER-DBY.PAGES.DEV',
      'https://trip-planner-dby.pages.dev.',
    ]) {
      final result = await _runContract({
        ...baseEnvironment,
        'STAGING_API_BASE_URL': url,
      });
      expect(result.exitCode, 2);
      expect(result.stderr, contains('production hostname'));
    }

    final userInfo = await _runContract({
      ...baseEnvironment,
      'STAGING_API_BASE_URL': 'https://staging-user@trip-planner-dby.pages.dev',
    });
    expect(userInfo.exitCode, 2);
    expect(userInfo.stderr, contains('exact committed HTTPS origin'));
    expect(File(baseEnvironment['MOCK_CURL_STATE']!).existsSync(), isFalse);
  });

  test(
    'verifies owner containment, timestamp preservation, and cleanup',
    () async {
      final result = await _runContract(baseEnvironment);

      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout, contains('contract passed'));
      expect(
        File(baseEnvironment['MOCK_CURL_STATE']!).readAsStringSync().trim(),
        '8',
      );
    },
  );

  test('fails when restore changes the original favorite timestamp', () async {
    final result = await _runContract({
      ...baseEnvironment,
      'MOCK_RESTORE_TIMESTAMP': 'changed',
    });

    expect(result.exitCode, 1);
    expect(result.stderr, contains('did not preserve'));
  });
}

Future<ProcessResult> _runContract(
  Map<String, String> environment, {
  String scriptPath = 'tool/verify_favorite_restore_contract.sh',
}) => Process.run(
  'bash',
  [scriptPath],
  workingDirectory: Directory.current.path,
  environment: environment,
);

const _mockCurlSource = r'''#!/usr/bin/env bash
set -euo pipefail

state_file=${MOCK_CURL_STATE:?}
output=''
body=''
url=''
method=''
expected_environment_header=''
while (($#)); do
  case "$1" in
    --output) output=$2; shift 2 ;;
    --data) body=$2; shift 2 ;;
    --header)
      if [[ "$2" == 'X-Expected-Environment-ID: '* ]]; then
        expected_environment_header=${2#X-Expected-Environment-ID: }
      fi
      shift 2
      ;;
    --request) method=$2; shift 2 ;;
    --write-out|--connect-timeout|--max-time) shift 2 ;;
    --silent|--show-error) shift ;;
    *) url=$1; shift ;;
  esac
done

if [[ "$url" == */api/environment-identity ]]; then
  jq -nc \
    --arg environmentId "${MOCK_ENVIRONMENT_ID:-tripline-staging-test}" \
    --arg mutationGuard "${MOCK_MUTATION_GUARD:-expected-environment-id-v1}" \
    '{environmentId:$environmentId,mutationGuard:$mutationGuard}' > "$output"
  printf '200'
  exit 0
fi

mutation_environment_id=${MOCK_MUTATION_ENVIRONMENT_ID:-${MOCK_ENVIRONMENT_ID:-tripline-staging-test}}
if [[ "$method" != GET && "$expected_environment_header" != "$mutation_environment_id" ]]; then
  printf '{"code":"ENVIRONMENT_MISMATCH"}' > "$output"
  printf '412'
  exit 0
fi
if [[ "$method" != GET ]]; then
  printf '%s\n' "$method" >> "${MOCK_MUTATION_LOG:?}"
fi

count=0
if [[ -f "$state_file" ]]; then count=$(cat "$state_file"); fi
count=$((count + 1))
printf '%s' "$count" > "$state_file"

note_file="${state_file}.note"
timestamp='2026-07-18T12:00:00Z'
case "$count" in
  1) status=200; payload='{"favorites":[]}' ;;
  2)
    status=201
    note=$(jq -r '.note' <<<"$body")
    printf '%s' "$note" > "$note_file"
    payload=$(jq -nc --arg note "$note" --arg ts "$timestamp" \
      '{id:7,poi_id:123,note:$note,favorited_at:$ts,deleted_at:null}')
    ;;
  3) status=204; payload='' ;;
  4) status=200; payload='{"favorites":[]}' ;;
  5) status=404; payload='{"code":"DATA_NOT_FOUND"}' ;;
  6)
    status=200
    note=$(cat "$note_file")
    restore_timestamp=$timestamp
    if [[ "${MOCK_RESTORE_TIMESTAMP:-}" == changed ]]; then
      restore_timestamp='2026-07-18T12:05:00Z'
    fi
    payload=$(jq -nc --arg note "$note" --arg ts "$restore_timestamp" \
      '{id:7,poi_id:123,note:$note,favorited_at:$ts,deleted_at:null}')
    ;;
  7)
    if [[ "${MOCK_RESTORE_TIMESTAMP:-}" == changed ]]; then
      status=204
      payload=''
    else
      status=200
      note=$(cat "$note_file")
      payload=$(jq -nc --arg note "$note" --arg ts "$timestamp" \
        '{favorites:[{id:7,poi_id:123,note:$note,favorited_at:$ts,deleted_at:null}]}')
    fi
    ;;
  8) status=204; payload='' ;;
  *) status=500; payload='{"error":"unexpected mock call"}' ;;
esac

printf '%s' "$payload" > "$output"
printf '%s' "$status"
''';
