import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/cache/flush_policy.dart';

void main() {
  ApiError err(int status, [String code = 'X']) =>
      ApiError(status: status, code: code, message: 'm');

  test(
    'classifyFlushError:STALE 且可 rebase → rebase;不可 rebase 的 STALE → drop',
    () {
      expect(
        classifyFlushError(err(409, 'STALE_ENTRY'), rebasable: true),
        FlushErrorAction.rebase,
      );
      expect(
        classifyFlushError(err(409, 'STALE_ENTRY'), rebasable: false),
        FlushErrorAction.drop,
      );
    },
  );

  test('classifyFlushError:5xx / 401 / 403 → retryLater;其他 4xx → drop', () {
    for (final status in [500, 502, 503, 401, 403]) {
      expect(
        classifyFlushError(err(status), rebasable: true),
        FlushErrorAction.retryLater,
        reason: '$status',
      );
    }
    for (final status in [400, 404, 409, 422]) {
      expect(
        classifyFlushError(err(status), rebasable: true),
        FlushErrorAction.drop,
        reason: '$status',
      );
    }
  });

  test('rebasedBody:只送 dirty 欄位 + 換新 expectedVersion;base 缺 → 全送', () {
    final body = {
      'title': 'new',
      'description': 'same',
      'start_time': null,
      'expectedVersion': 3,
    };
    expect(
      rebasedBody(
        {'title': 'old', 'description': 'same', 'startTime': null},
        {'title': 'new', 'description': 'same', 'startTime': null},
        body,
        7,
      ),
      {'title': 'new', 'expectedVersion': 7},
    );
    expect(rebasedBody(null, {'title': 'new'}, body, 7), {
      ...body,
      'expectedVersion': 7,
    });
    expect(rebasedBody(null, {}, 'raw', 7), 'raw');
  });

  test("lib 內 days 的 all 參數只有 '1' 一種拼法", () {
    final offenders = <String>[];
    for (final entity in Directory('lib/api').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (RegExp(r"'all':\s*1\b").hasMatch(source)) offenders.add(entity.path);
    }
    expect(
      offenders,
      isEmpty,
      reason: "cache key 由 OfflineResource 統一產生,all 一律是字串 '1'",
    );
  });
}
