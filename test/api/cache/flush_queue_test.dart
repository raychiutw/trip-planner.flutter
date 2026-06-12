import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/cache/cache_keys.dart';
import 'package:tripline/api/cache/cache_store.dart';
import 'package:tripline/api/session_store.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late InMemoryCacheStore cache;
  late ApiClient client;

  setUp(() {
    dio = Dio(BaseOptions())..options.validateStatus = (_) => true;
    adapter = DioAdapter(dio: dio);
    cache = InMemoryCacheStore();
    client = ApiClient(
      sessionStore: InMemorySessionStore(),
      dio: dio,
      cacheStore: cache,
    );
  });

  final daysKey = cacheKeyFor('GET', '/trips/t/days', {'all': '1'});

  QueuedMutation addMut(
    String id, {
    String path = '/trips/t/days/1/entries',
    String method = 'POST',
  }) => QueuedMutation(
    id: id,
    method: method,
    path: path,
    body: const {'title': 'x'},
    type: 'entry.add',
    cacheKey: daysKey,
    args: const {'dayNum': 1},
    createdAt: 't',
  );

  DioException offline(String path) => DioException(
    requestOptions: RequestOptions(path: path),
    type: DioExceptionType.connectionError,
  );

  test('依序重播成功 → 全部移除、synced 計數', () async {
    await cache.appendMutation(addMut('1'));
    await cache.appendMutation(addMut('2'));
    adapter.onPost(
      '/trips/t/days/1/entries',
      (s) => s.reply(200, {'ok': true}),
      data: Matchers.any,
    );
    final r = await client.flushQueue();
    expect(r.synced, 2);
    expect(r.conflicts, isEmpty);
    expect(await cache.readQueue(), isEmpty);
  });

  test('成功後 evict 受影響快取(days)', () async {
    await cache.writeResponse(daysKey, [
      {
        'dayNum': 1,
        'timeline': [
          {'id': -1},
        ],
      },
    ]);
    await cache.appendMutation(addMut('1'));
    adapter.onPost(
      '/trips/t/days/1/entries',
      (s) => s.reply(200, {'ok': true}),
      data: Matchers.any,
    );
    await client.flushQueue();
    expect(await cache.readResponse(daysKey), isNull);
  });

  test('遇 409 → 上報衝突 + 移除該筆,續處理其餘', () async {
    await cache.appendMutation(addMut('1', path: '/trips/t/entries/5'));
    await cache.appendMutation(addMut('2'));
    adapter.onPost(
      '/trips/t/entries/5',
      (s) => s.reply(409, {
        'error': {'code': 'STALE_ENTRY', 'message': 'stale'},
      }),
      data: Matchers.any,
    );
    adapter.onPost(
      '/trips/t/days/1/entries',
      (s) => s.reply(200, {'ok': true}),
      data: Matchers.any,
    );
    final r = await client.flushQueue();
    expect(r.conflicts.map((m) => m.id), ['1']);
    expect(r.synced, 1);
    expect(await cache.readQueue(), isEmpty);
  });

  test('中途離線 → 停止、保留未處理佇列', () async {
    await cache.appendMutation(addMut('1'));
    await cache.appendMutation(addMut('2'));
    adapter.onPost(
      '/trips/t/days/1/entries',
      (s) => s.throws(503, offline('/trips/t/days/1/entries')),
      data: Matchers.any,
    );
    final r = await client.flushQueue();
    expect(r.synced, 0);
    expect(await cache.readQueue(), hasLength(2));
  });

  test('空佇列 → synced 0', () async {
    final r = await client.flushQueue();
    expect(r.synced, 0);
    expect(r.conflicts, isEmpty);
  });
}
