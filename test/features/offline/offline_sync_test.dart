import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/cache/cache_keys.dart';
import 'package:tripline/api/cache/cache_store.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/session_store.dart';
import 'package:tripline/features/offline/offline_sync.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late InMemoryCacheStore cache;
  late ProviderContainer container;

  QueuedMutation mut(String id) => QueuedMutation(
    id: id,
    method: 'POST',
    path: '/trips/t/days/1/entries',
    body: const {'title': 'x'},
    type: 'entry.add',
    cacheKey: cacheKeyFor('GET', '/trips/t/days', {'all': '1'}),
    args: const {'dayNum': 1},
    createdAt: 't',
  );

  setUp(() {
    dio = Dio(BaseOptions())..options.validateStatus = (_) => true;
    adapter = DioAdapter(dio: dio);
    cache = InMemoryCacheStore();
    container = ProviderContainer(
      overrides: [
        cacheStoreProvider.overrideWithValue(cache),
        apiClientProvider.overrideWithValue(
          ApiClient(
            sessionStore: InMemorySessionStore(),
            dio: dio,
            cacheStore: cache,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  ConflictRecord conflict(String id) => ConflictRecord(
    id: id,
    type: 'entry.update',
    path: '/trips/t/entries/7',
    body: const {'title': 'B'},
    args: const {'entryId': 7},
    cacheKey: cacheKeyFor('GET', '/trips/t/days', {'all': '1'}),
    ours: const {'title': 'B'},
    theirs: const {'title': 'C'},
    newVersion: 5,
    conflictFields: const ['title'],
    createdAt: 't',
  );

  // offlinePendingCountProvider 是 StreamProvider(反應式),bare container 需有 listener
  // 才會跑 generator;listen + pump microtask 後讀當前值。
  Future<int> currentCount() async {
    container.listen(offlinePendingCountProvider, (_, _) {});
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return container.read(offlinePendingCountProvider).value ?? -1;
  }

  // syncConflictRecordsProvider 同為反應式 StreamProvider:需 listener 驅動 generator。
  Future<List<ConflictRecord>> currentConflicts() async {
    container.listen(syncConflictRecordsProvider, (_, _) {});
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return container.read(syncConflictRecordsProvider).value ?? const [];
  }

  test('sync 成功 → 佇列清空、count 歸零', () async {
    await cache.appendMutation(mut('1'));
    adapter.onPost(
      '/trips/t/days/1/entries',
      (s) => s.reply(200, {'ok': true}),
      data: Matchers.any,
    );
    await container.read(offlineSyncControllerProvider.notifier).sync();
    expect(await currentCount(), 0);
  });

  test('前景由離線恢復連線時自動同步，首次線上事件不重複冷啟動同步', () async {
    await cache.appendMutation(mut('reconnect'));
    adapter.onPost(
      '/trips/t/days/1/entries',
      (server) => server.reply(200, {'ok': true}),
      data: Matchers.any,
    );
    final controller = container.read(offlineSyncControllerProvider.notifier);

    controller.handleNetworkAvailability(true);
    await Future<void>.delayed(Duration.zero);
    expect(await cache.readQueue(), hasLength(1));

    controller.handleNetworkAvailability(false);
    controller.handleNetworkAvailability(true);
    for (var attempt = 0; attempt < 20; attempt++) {
      if ((await cache.readQueue()).isEmpty) break;
      await Future<void>.delayed(Duration.zero);
    }

    expect(await cache.readQueue(), isEmpty);
  });

  // 衝突真相源改為持久化 conflict store(flushQueue/_tryRebase 寫入,api 層測試覆蓋);
  // 此處驗證 syncConflictRecordsProvider 反應式反映 store 內容與變動。
  test('syncConflictRecordsProvider 反映 conflict store 並反應式更新', () async {
    expect(await currentConflicts(), isEmpty);

    await cache.appendConflict(conflict('1'));
    expect((await currentConflicts()).map((c) => c.id), ['1']);

    await cache.removeConflict('1');
    expect(await currentConflicts(), isEmpty);
  });

  test('offlinePendingCountProvider 反映佇列筆數', () async {
    await cache.appendMutation(mut('1'));
    await cache.appendMutation(mut('2'));
    expect(await currentCount(), 2);
  });

  test('入隊後 count 反應式更新(無需手動 invalidate)', () async {
    container.listen(offlinePendingCountProvider, (_, _) {});
    expect(await currentCount(), 0);
    await cache.appendMutation(mut('x')); // 模擬離線寫入入隊
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(container.read(offlinePendingCountProvider).value, 1);
  });
}
