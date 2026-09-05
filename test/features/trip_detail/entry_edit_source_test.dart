import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/features/trip_detail/trip_providers.dart';
import 'package:tripline/models/entry.dart';

TimelineEntry _v(int version) =>
    TimelineEntry(id: 11, sortOrder: 0, title: 'a', version: version);

void main() {
  test('較新的 detail 才採用;SWR 先吐的舊快取不能把 version 倒退', () async {
    final detail = StreamController<TimelineEntry>();
    final c = ProviderContainer(
      overrides: [
        entryDetailProvider.overrideWith((ref, key) => detail.stream),
      ],
    );
    addTearDown(c.dispose);
    final key = (tripId: 't', entryId: 11, seedVersion: 3);
    final sub = c.listen(entryEditSourceProvider(key), (_, _) {});

    detail.add(_v(2));
    await Future<void>.delayed(Duration.zero);
    expect(sub.read().fresher, isNull, reason: 'v2 < 種子 v3');

    detail.add(_v(3));
    await Future<void>.delayed(Duration.zero);
    expect(sub.read().fresher?.version, 3);

    detail.add(_v(5));
    await Future<void>.delayed(Duration.zero);
    expect(sub.read().fresher?.version, 5);
    expect(sub.read().deleted, isFalse);
  });

  test('404 → 已刪除;其他錯誤只是載入失敗', () async {
    final c = ProviderContainer(
      overrides: [
        entryDetailProvider.overrideWith(
          (ref, key) => Stream<TimelineEntry>.error(
            const ApiError(status: 404, code: 'NOT_FOUND', message: 'gone'),
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    final key = (tripId: 't', entryId: 11, seedVersion: 1);
    final sub = c.listen(entryEditSourceProvider(key), (_, _) {});
    await Future<void>.delayed(Duration.zero);
    expect(sub.read().deleted, isTrue);
    expect(sub.read().error, isNotNull);
  });
}
