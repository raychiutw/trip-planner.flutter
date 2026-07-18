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
      'CI': 'true',
      'MOCK_CURL_STATE': '${sandbox.path}/curl-state',
      'STAGING_API_BASE_URL': 'https://staging.tripline.test',
      'STAGING_ALLOWED_HOST': 'staging.tripline.test',
      'STAGING_ORIGIN': 'https://staging-app.tripline.test',
      'STAGING_SESSION_COOKIE': 'session=owner-fixture',
      'STAGING_OTHER_SESSION_COOKIE': 'session=other-fixture',
      'STAGING_FAVORITE_POI_ID': '123',
      'STAGING_CONTRACT_GUARD': 'tripline-staging-favorite-restore-v1',
    };
  });

  tearDown(() => sandbox.deleteSync(recursive: true));

  test(
    'rejects non-HTTPS and non-allowlisted staging URLs before curl',
    () async {
      final insecure = await _runContract({
        ...baseEnvironment,
        'STAGING_API_BASE_URL': 'http://staging.tripline.test',
      });
      expect(insecure.exitCode, 2);
      expect(insecure.stderr, contains('must use HTTPS'));

      final wrongHost = await _runContract({
        ...baseEnvironment,
        'STAGING_API_BASE_URL': 'https://production.tripline.test/staging',
      });
      expect(wrongHost.exitCode, 2);
      expect(wrongHost.stderr, contains('not allowlisted'));
      expect(File(baseEnvironment['MOCK_CURL_STATE']!).existsSync(), isFalse);
    },
  );

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

Future<ProcessResult> _runContract(Map<String, String> environment) =>
    Process.run(
      'bash',
      ['tool/verify_favorite_restore_contract.sh'],
      workingDirectory: Directory.current.path,
      environment: environment,
    );

const _mockCurlSource = r'''#!/usr/bin/env bash
set -euo pipefail

state_file=${MOCK_CURL_STATE:?}
count=0
if [[ -f "$state_file" ]]; then count=$(cat "$state_file"); fi
count=$((count + 1))
printf '%s' "$count" > "$state_file"

output=''
body=''
while (($#)); do
  case "$1" in
    --output) output=$2; shift 2 ;;
    --data) body=$2; shift 2 ;;
    --request|--write-out|--header|--connect-timeout|--max-time) shift 2 ;;
    --silent|--show-error) shift ;;
    *) shift ;;
  esac
done

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
