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

  // offlinePendingCountProvider 是 StreamProvider(反應式),bare container 需有 listener
  // 才會跑 generator;listen + pump microtask 後讀當前值。
  Future<int> currentCount() async {
    container.listen(offlinePendingCountProvider, (_, _) {});
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return container.read(offlinePendingCountProvider).value ?? -1;
  }

  test('sync 成功 → 佇列清空、count 歸零、無衝突', () async {
    await cache.appendMutation(mut('1'));
    adapter.onPost(
      '/trips/t/days/1/entries',
      (s) => s.reply(200, {'ok': true}),
      data: Matchers.any,
    );
    await container.read(offlineSyncControllerProvider.notifier).sync();
    expect(await currentCount(), 0);
    expect(container.read(syncConflictsProvider), isEmpty);
  });

  test('sync 遇 409 → 衝突進 syncConflictsProvider', () async {
    await cache.appendMutation(mut('1'));
    adapter.onPost(
      '/trips/t/days/1/entries',
      (s) => s.reply(409, {
        'error': {'code': 'STALE_ENTRY'},
      }),
      data: Matchers.any,
    );
    await container.read(offlineSyncControllerProvider.notifier).sync();
    expect(container.read(syncConflictsProvider).map((m) => m.id), ['1']);
    expect(await currentCount(), 0);
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
