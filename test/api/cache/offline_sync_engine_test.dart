import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/cache/cache_store.dart';
import 'package:tripline/api/cache/offline_op.dart';
import 'package:tripline/api/cache/offline_sync_engine.dart';

void main() {
  test('離線操作以資源產生與讀取一致的快取鍵', () {
    final op = OfflineOp('entry.add', OfflineResource.tripDays, 't', const {});
    expect(op.cacheKey, 'GET /trips/t/days?all=1');
    expect(
      () => OfflineOp('entry.update', OfflineResource.tripNotes, 't', const {}),
      throwsArgumentError,
    );
  });

  test('讀取與接收新資料時都保留尚未同步的樂觀 patch', () async {
    final store = InMemoryCacheStore();
    final engine = OfflineSyncEngine(
      store: store,
      send: (method, path, {body, query}) async => null,
    );
    const key = 'GET /trips/t/days?all=1';
    final server = [
      {'dayNum': 1, 'timeline': <dynamic>[]},
    ];
    await store.writeResponse(key, server);
    await store.appendMutation(
      const QueuedMutation(
        id: 'pending',
        method: 'POST',
        path: '/trips/t/days/1/entries',
        type: 'entry.add',
        cacheKey: key,
        args: {'dayNum': 1, 'title': '離線停留點', 'tempId': -1},
        createdAt: 't',
      ),
    );

    final stale = await engine.readStale(key);
    final fresh = await engine.reconcileFresh(key, server);
    expect(((stale!.data as List).single['timeline'] as List), hasLength(1));
    expect(((fresh as List).single['timeline'] as List), hasLength(1));
  });

  test('離線寫入入佇列，重連後以同一送出函式依序同步', () async {
    final store = InMemoryCacheStore();
    var online = false;
    final sent = <String>[];
    final engine = OfflineSyncEngine(
      store: store,
      send: (method, path, {body, query}) async {
        if (!online) {
          throw OfflineSendFailure(
            cause: Exception('離線'),
            stackTrace: StackTrace.current,
            isOffline: true,
          );
        }
        sent.add('$method $path');
        return {'ok': true};
      },
    );

    await engine.sendMutation(
      'POST',
      '/trips/t/days/1/entries',
      body: const {'title': '新停留點'},
      optimistic: OfflineOp('entry.add', OfflineResource.tripDays, 't', const {
        'dayNum': 1,
        'title': '新停留點',
      }),
    );
    expect(await store.readQueue(), hasLength(1));

    online = true;
    final result = await engine.flushQueue();
    expect(result.synced, 1);
    expect(await store.readQueue(), isEmpty);
    expect(sent, ['POST /trips/t/days/1/entries']);
  });
}
