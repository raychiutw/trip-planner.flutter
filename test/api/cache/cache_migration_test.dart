import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/cache/cache_migration.dart';
import 'package:tripline/api/cache/cache_store.dart';
import 'package:tripline/api/cache/sembast_cache_store.dart';

QueuedMutation _mutation(String id) => QueuedMutation(
  id: id,
  method: 'PATCH',
  path: '/trips/t1/entries/$id',
  body: {'title': id},
  type: 'updateEntry',
  cacheKey: 'GET /trips/t1/days',
  args: {'entryId': id},
  createdAt: '2026-07-16T00:00:00.000Z',
  base: {'title': 'old'},
);

ConflictRecord _conflict(String id) => ConflictRecord(
  id: id,
  type: 'updateEntry',
  path: '/trips/t1/entries/$id',
  body: {'title': 'ours'},
  args: {'entryId': id},
  cacheKey: 'GET /trips/t1/days',
  ours: {'title': 'ours'},
  theirs: {'title': 'theirs'},
  newVersion: 3,
  conflictFields: ['title'],
  createdAt: '2026-07-16T00:00:00.000Z',
);

void main() {
  late Directory tempDir;
  late InMemoryCacheStore target;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tripline_migration_');
    target = InMemoryCacheStore();
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  File dbFile() => File('${tempDir.path}/tripline_cache.db');

  /// 造一個帶資料的舊 sembast DB(模擬既有使用者的裝置)。
  Future<void> seedSembast({
    List<QueuedMutation> queue = const [],
    List<ConflictRecord> conflicts = const [],
    Map<String, Object?> responses = const {},
  }) async {
    final db = await openCacheDatabase(tempDir.path);
    final store = SembastCacheStore(db);
    for (final mutation in queue) {
      await store.appendMutation(mutation);
    }
    for (final conflict in conflicts) {
      await store.appendConflict(conflict);
    }
    for (final entry in responses.entries) {
      await store.writeResponse(entry.key, entry.value);
    }
    await db.close();
  }

  test('沒有舊 DB → 回 0,不崩', () async {
    expect(
      await migrateSembastCacheToDrift(
        directoryPath: tempDir.path,
        target: target,
      ),
      0,
    );
  });

  test('離線佇列整批搬遷並保序(= 重播序)', () async {
    await seedSembast(queue: [_mutation('m1'), _mutation('m2')]);

    final moved = await migrateSembastCacheToDrift(
      directoryPath: tempDir.path,
      target: target,
    );

    expect(moved, 2);
    expect((await target.readQueue()).map((m) => m.id), ['m1', 'm2']);
    // base 是 rebase 三方比對的依據,搬遷不得掉。
    expect((await target.readQueue()).first.base, {'title': 'old'});
  });

  test('衝突區一併搬遷', () async {
    await seedSembast(conflicts: [_conflict('c1')]);

    await migrateSembastCacheToDrift(
      directoryPath: tempDir.path,
      target: target,
    );

    final conflicts = await target.readConflicts();
    expect(conflicts.single.id, 'c1');
    expect(conflicts.single.conflictFields, ['title']);
  });

  test('回應快取刻意不搬(可重抓,搬了只是浪費)', () async {
    await seedSembast(
      queue: [_mutation('m1')],
      responses: {
        'GET /my-trips': [1, 2],
      },
    );

    await migrateSembastCacheToDrift(
      directoryPath: tempDir.path,
      target: target,
    );

    expect(await target.readResponse('GET /my-trips'), isNull);
    expect(await target.readQueue(), hasLength(1));
  });

  test('搬遷成功後刪掉舊 DB 檔(避免下次重搬)', () async {
    await seedSembast(queue: [_mutation('m1')]);
    expect(dbFile().existsSync(), isTrue);

    await migrateSembastCacheToDrift(
      directoryPath: tempDir.path,
      target: target,
    );

    expect(dbFile().existsSync(), isFalse);
  });

  test('重跑不重複搬(依 id 去重)', () async {
    // 若上次搬到一半當掉、檔案沒刪，重跑不得把同一筆 mutation 再排一次 ——
    // 重播兩次會把使用者的編輯套兩遍。
    await seedSembast(queue: [_mutation('m1')]);
    await target.appendMutation(_mutation('m1'));

    final moved = await migrateSembastCacheToDrift(
      directoryPath: tempDir.path,
      target: target,
    );

    expect(moved, 0);
    expect(await target.readQueue(), hasLength(1));
  });
}
