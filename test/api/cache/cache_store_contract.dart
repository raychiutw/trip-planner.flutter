/// CacheStore 的共用行為契約（不是測試檔本身，故無 `_test` 後綴）。
///
/// 每個 CacheStore 實作都必須通過同一份契約 —— 這是「drop-in 替換」唯一的證明。
/// 先前測試綁死 InMemoryCacheStore，換實作時沒有東西抓得到行為差異。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/cache/cache_store.dart';

QueuedMutation _mutation(String id, {Map<String, dynamic>? base}) =>
    QueuedMutation(
      id: id,
      method: 'PATCH',
      path: '/trips/t1/entries/$id',
      body: {'title': 'x'},
      type: 'updateEntry',
      cacheKey: 'GET /trips/t1/days',
      args: {'entryId': id},
      createdAt: '2026-07-16T00:00:00.000Z',
      base: base,
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
  newVersion: 7,
  conflictFields: ['title'],
  createdAt: '2026-07-16T00:00:00.000Z',
);

/// 對 [create] 產生的實作跑完整 CacheStore 契約。
///
/// [dispose] 供需要關檔的實作（如 drift/sqlite）收尾。
void cacheStoreContract(
  String name,
  CacheStore Function() create, {
  Future<void> Function(CacheStore store)? dispose,
}) {
  group('$name — CacheStore 契約', () {
    late CacheStore store;

    setUp(() => store = create());
    tearDown(() async => dispose == null ? null : await dispose(store));

    group('回應快取', () {
      test('write 後 read 回 data + cachedAt', () async {
        final at = DateTime.utc(2026, 7, 16, 8, 30);
        await store.writeResponse('GET /x', {'a': 1}, cachedAt: at);
        final entry = await store.readResponse('GET /x');
        expect(entry!.data, {'a': 1});
        // cachedAt 必須原樣存回 —— TTL 判斷靠它，被實作改寫就會誤判新鮮度。
        expect(entry.cachedAt.toUtc(), at);
      });

      test('miss 回 null', () async {
        expect(await store.readResponse('GET /none'), isNull);
      });

      test('同 key 重寫覆蓋而非累積', () async {
        await store.writeResponse('GET /x', {'v': 1});
        await store.writeResponse('GET /x', {'v': 2});
        expect((await store.readResponse('GET /x'))!.data, {'v': 2});
      });

      test('list 與純量 data 都能 round-trip', () async {
        await store.writeResponse('GET /list', [1, 'two', null]);
        await store.writeResponse('GET /scalar', 42);
        expect((await store.readResponse('GET /list'))!.data, [1, 'two', null]);
        expect((await store.readResponse('GET /scalar'))!.data, 42);
      });

      test('evictByPrefix 只刪命中,不誤刪 id 前綴相同者', () async {
        await store.writeResponse('GET /trips/abc/days?all=1', [1]);
        await store.writeResponse('GET /trips/abc/notes', {'n': 1});
        await store.writeResponse('GET /trips/abcdef/days', [2]);
        await store.evictByPrefix('GET /trips/abc/days');
        expect(await store.readResponse('GET /trips/abc/days?all=1'), isNull);
        expect(await store.readResponse('GET /trips/abc/notes'), isNotNull);
        expect(await store.readResponse('GET /trips/abcdef/days'), isNotNull);
      });

      test('evictByPrefix 完全相等也刪', () async {
        await store.writeResponse('GET /my-trips', [1]);
        await store.evictByPrefix('GET /my-trips');
        expect(await store.readResponse('GET /my-trips'), isNull);
      });

      test('evictByPrefix 對含 % 與 _ 的 key 不得當成萬用字元', () async {
        // tripId 走 Uri.encodeComponent → key 內會出現 `%XX`。SQL 實作若用
        // `LIKE prefix || '?%'`，prefix 自己的 `%`/`_` 會被當萬用字元，靜默誤刪
        // 別的 trip。Dart 的 startsWith 沒這問題，只有 SQL 版會在此變紅。
        //
        // 受害者一定要帶 `?`/`/` 後綴 —— 不帶後綴的 key 是走精確比對刪的，
        // pattern 根本不會被考驗到（這測試最初就是這樣假綠燈的）。
        await store.writeResponse('GET /trips/a%20b/days?all=1', [1]);
        await store.writeResponse('GET /trips/aQQ20b/days?all=1', [2]);
        await store.writeResponse('GET /trips/a_b/days?all=1', [3]);
        await store.writeResponse('GET /trips/aZb/days?all=1', [4]);

        await store.evictByPrefix('GET /trips/a%20b/days');
        expect(await store.readResponse('GET /trips/a%20b/days?all=1'), isNull);
        // pattern `…a%20b/days?%` 裡的 `%` 若是萬用字元，會吃掉 `aQQ20b`
        // （`a` + `QQ` + `20b/days?` + `all=1`）。
        expect(
          await store.readResponse('GET /trips/aQQ20b/days?all=1'),
          isNotNull,
        );

        await store.evictByPrefix('GET /trips/a_b/days');
        expect(await store.readResponse('GET /trips/a_b/days?all=1'), isNull);
        // `_` 是 LIKE 的單字元萬用字元 → 會吃掉 `aZb`。
        expect(
          await store.readResponse('GET /trips/aZb/days?all=1'),
          isNotNull,
        );
      });
    });

    group('容量上限', () {
      Future<void> writeAt(String key, int minute) => store.writeResponse(key, {
        'm': minute,
      }, cachedAt: DateTime.utc(2026, 7, 16, 0, minute));

      test('未超過上限 → 全部保留', () async {
        await writeAt('GET /route?a=1', 1);
        await writeAt('GET /route?a=2', 2);
        await store.enforceCapacity('GET /route', 5);
        expect(await store.readResponse('GET /route?a=1'), isNotNull);
        expect(await store.readResponse('GET /route?a=2'), isNotNull);
      });

      test('超過上限 → 依 cachedAt 只留最新的 N 筆', () async {
        await writeAt('GET /route?a=old', 1);
        await writeAt('GET /route?a=mid', 2);
        await writeAt('GET /route?a=new', 3);

        await store.enforceCapacity('GET /route', 2);

        expect(await store.readResponse('GET /route?a=old'), isNull);
        expect(await store.readResponse('GET /route?a=mid'), isNotNull);
        expect(await store.readResponse('GET /route?a=new'), isNotNull);
      });

      test('寫入順序與時間順序不一致時,仍以 cachedAt 為準', () async {
        // 後寫入的不一定比較新（例如補寫舊資料）。實作若用插入序（rowid）
        // 當新舊，這條會紅。
        await writeAt('GET /route?a=new', 9);
        await writeAt('GET /route?a=old', 1);

        await store.enforceCapacity('GET /route', 1);

        expect(await store.readResponse('GET /route?a=new'), isNotNull);
        expect(await store.readResponse('GET /route?a=old'), isNull);
      });

      test('只影響同前綴,不動別的前綴', () async {
        await writeAt('GET /route?a=1', 1);
        await writeAt('GET /route?a=2', 2);
        await writeAt('GET /poi-search?q=a', 1);
        await writeAt('GET /my-trips', 1);

        await store.enforceCapacity('GET /route', 1);

        expect(await store.readResponse('GET /poi-search?q=a'), isNotNull);
        expect(await store.readResponse('GET /my-trips'), isNotNull);
      });

      test('前綴比對語意與 evictByPrefix 一致,不誤傷 id 前綴相同者', () async {
        await writeAt('GET /trips/abc/days?p=1', 1);
        await writeAt('GET /trips/abc/days?p=2', 2);
        await writeAt('GET /trips/abcdef/days?p=1', 1);

        await store.enforceCapacity('GET /trips/abc/days', 1);

        // abcdef 不屬於 abc 的前綴 → 不佔額度、也不該被刪。
        expect(
          await store.readResponse('GET /trips/abcdef/days?p=1'),
          isNotNull,
        );
        expect(await store.readResponse('GET /trips/abc/days?p=2'), isNotNull);
        expect(await store.readResponse('GET /trips/abc/days?p=1'), isNull);
      });

      test('上限 0 → 該前綴全清', () async {
        await writeAt('GET /route?a=1', 1);
        await store.enforceCapacity('GET /route', 0);
        expect(await store.readResponse('GET /route?a=1'), isNull);
      });
    });

    group('離線寫入佇列', () {
      test('append 依插入序讀回(= 重播序)', () async {
        await store.appendMutation(_mutation('m1'));
        await store.appendMutation(_mutation('m2'));
        await store.appendMutation(_mutation('m3'));
        final queue = await store.readQueue();
        expect(queue.map((m) => m.id), ['m1', 'm2', 'm3']);
      });

      test('remove 只刪指定 id 並保序', () async {
        await store.appendMutation(_mutation('m1'));
        await store.appendMutation(_mutation('m2'));
        await store.appendMutation(_mutation('m3'));
        await store.removeMutation('m2');
        expect((await store.readQueue()).map((m) => m.id), ['m1', 'm3']);
      });

      test('round-trip 保留 base(rebase 三方比對靠它)', () async {
        await store.appendMutation(_mutation('m1', base: {'title': 'old'}));
        expect((await store.readQueue()).single.base, {'title': 'old'});
      });

      test('base 為 null 時 round-trip 仍是 null(降級不崩)', () async {
        await store.appendMutation(_mutation('m1'));
        expect((await store.readQueue()).single.base, isNull);
      });

      test('空佇列回空 list', () async {
        expect(await store.readQueue(), isEmpty);
      });
    });

    group('衝突區', () {
      test('append → read 回該筆;remove 後消失', () async {
        await store.appendConflict(_conflict('c1'));
        final conflicts = await store.readConflicts();
        expect(conflicts.single.id, 'c1');
        expect(conflicts.single.conflictFields, ['title']);
        expect(conflicts.single.newVersion, 7);
        await store.removeConflict('c1');
        expect(await store.readConflicts(), isEmpty);
      });
    });

    group('changes 事件流', () {
      test('append/remove mutation 各觸發一次', () async {
        final seen = <void>[];
        final sub = store.changes.listen(seen.add);
        await store.appendMutation(_mutation('m1'));
        await store.removeMutation('m1');
        await pumpEventQueue();
        expect(seen, hasLength(2));
        await sub.cancel();
      });

      test('append conflict 與 clear 也觸發', () async {
        final seen = <void>[];
        final sub = store.changes.listen(seen.add);
        await store.appendConflict(_conflict('c1'));
        await store.clear();
        await pumpEventQueue();
        expect(seen, hasLength(2));
        await sub.cancel();
      });
    });

    test('clear 一併清回應快取 / 佇列 / 衝突區', () async {
      await store.writeResponse('GET /x', 1);
      await store.appendMutation(_mutation('m1'));
      await store.appendConflict(_conflict('c1'));

      await store.clear();

      expect(await store.readResponse('GET /x'), isNull);
      expect(await store.readQueue(), isEmpty);
      expect(await store.readConflicts(), isEmpty);
    });
  });
}
