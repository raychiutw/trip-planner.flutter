import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/offline_cache.dart';

void main() {
  test('InMemoryOfflineCache 儲存/回讀 JSON 並隔離外部 mutation', () async {
    final cache = InMemoryOfflineCache();

    await cache.writeJson('trip-days:okinawa', [
      {
        'id': 1,
        'dayNum': 1,
        'timeline': [
          {'id': 11, 'title': '首里城'},
        ],
      },
    ]);

    final firstRead = await cache.readJson('trip-days:okinawa') as List;
    (firstRead.first as Map)['dayNum'] = 99;

    final secondRead = await cache.readJson('trip-days:okinawa') as List;
    expect((secondRead.first as Map)['dayNum'], 1);
  });

  test('InMemoryOfflineCache missing key 回 null', () async {
    final cache = InMemoryOfflineCache();

    expect(await cache.readJson('missing'), isNull);
  });
}
