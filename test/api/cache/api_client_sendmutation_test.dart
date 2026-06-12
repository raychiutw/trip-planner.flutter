import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/cache/cache_keys.dart';
import 'package:tripline/api/cache/cache_store.dart';
import 'package:tripline/api/cache/offline_op.dart';
import 'package:tripline/api/session_store.dart';

DioException _offline(String path) => DioException(
  requestOptions: RequestOptions(path: path),
  type: DioExceptionType.connectionError,
);

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
  OfflineOp addOp() => OfflineOp('entry.add', daysKey, {
    'dayNum': 1,
    'title': 'New',
    'tempId': -1,
  });

  test('sendMutation 線上成功 → 不入佇列、回 server 回應', () async {
    adapter.onPost(
      '/trips/t/days/1/entries',
      (s) => s.reply(200, {'ok': true}),
      data: {'title': 'New'},
    );
    final r = await client.sendMutation(
      'POST',
      '/trips/t/days/1/entries',
      body: {'title': 'New'},
      optimistic: addOp(),
    );
    expect(r, {'ok': true});
    expect(await cache.readQueue(), isEmpty);
  });

  test('sendMutation 離線 + optimistic → 入佇列 + 樂觀 patch 快取 + 回 null', () async {
    await cache.writeResponse(daysKey, [
      {'dayNum': 1, 'timeline': <dynamic>[]},
    ]);
    adapter.onPost(
      '/trips/t/days/1/entries',
      (s) => s.throws(503, _offline('/trips/t/days/1/entries')),
      data: {'title': 'New'},
    );
    final r = await client.sendMutation(
      'POST',
      '/trips/t/days/1/entries',
      body: {'title': 'New'},
      optimistic: addOp(),
    );
    expect(r, isNull);
    final queue = await cache.readQueue();
    expect(queue, hasLength(1));
    expect(queue.single.type, 'entry.add');
    expect(queue.single.cacheKey, daysKey);
    final patched = (await cache.readResponse(daysKey))!.data as List;
    expect((patched.first as Map)['timeline'] as List, hasLength(1));
  });

  test('sendMutation 離線 + optimistic=null → rethrow', () async {
    adapter.onPost('/x', (s) => s.throws(503, _offline('/x')));
    expect(
      () => client.sendMutation('POST', '/x', body: const {}),
      throwsA(isA<DioException>()),
    );
  });

  test('getStream:fresh 到達後仍套用佇列 pending patch(不變式)', () async {
    await cache.appendMutation(
      QueuedMutation(
        id: '1',
        method: 'POST',
        path: '/trips/t/days/1/entries',
        type: 'entry.add',
        cacheKey: daysKey,
        args: const {'dayNum': 1, 'title': 'Pending', 'tempId': -1},
        createdAt: 't',
      ),
    );
    adapter.onGet(
      '/trips/t/days',
      (s) => s.reply(200, [
        {'dayNum': 1, 'timeline': <dynamic>[]},
      ]),
      queryParameters: {'all': '1'},
    );
    final emissions = await client
        .getStream('/trips/t/days', query: {'all': '1'})
        .toList();
    final last = emissions.last as List;
    final timeline = (last.first as Map)['timeline'] as List;
    expect(timeline, hasLength(1));
    expect((timeline.first as Map)['title'], 'Pending');
  });

  test('getStream:離線時對「已 patch 的快取」不重複套 pending(無雙重套用)', () async {
    // 離線新增一筆 → 快取被 patch、佇列有 1
    await cache.writeResponse(daysKey, [
      {'dayNum': 1, 'timeline': <dynamic>[]},
    ]);
    adapter.onPost(
      '/trips/t/days/1/entries',
      (s) => s.throws(503, _offline('/trips/t/days/1/entries')),
      data: {'title': 'New'},
    );
    await client.sendMutation(
      'POST',
      '/trips/t/days/1/entries',
      body: {'title': 'New'},
      optimistic: addOp(),
    );
    // 離線重讀:仍離線
    adapter.onGet(
      '/trips/t/days',
      (s) => s.throws(503, _offline('/trips/t/days')),
      queryParameters: {'all': '1'},
    );
    final emissions = await client
        .getStream('/trips/t/days', query: {'all': '1'})
        .toList();
    // 只應有 1 筆(stale=已 patch 的快取),不因 fallback 再套一次變 2 筆
    final last = emissions.last as List;
    expect((last.first as Map)['timeline'] as List, hasLength(1));
  });

  test('離線新增臨時 id:冪等(重播=入佇列)且連續新增不碰撞', () async {
    await cache.writeResponse(daysKey, [
      {'dayNum': 1, 'timeline': <dynamic>[]},
    ]);
    // production 路徑:OfflineOp 不帶 tempId,由 sendMutation 入佇列時產生並存進 args。
    OfflineOp prodAdd(String title) =>
        OfflineOp('entry.add', daysKey, {'dayNum': 1, 'title': title});
    adapter.onPost(
      '/trips/t/days/1/entries',
      (s) => s.throws(503, _offline('/trips/t/days/1/entries')),
      data: Matchers.any,
    );

    await client.sendMutation(
      'POST',
      '/trips/t/days/1/entries',
      body: {'title': 'One'},
      optimistic: prodAdd('One'),
    );
    await client.sendMutation(
      'POST',
      '/trips/t/days/1/entries',
      body: {'title': 'Two'},
      optimistic: prodAdd('Two'),
    );

    final queue = await cache.readQueue();
    expect(queue, hasLength(2));
    final id1 = queue[0].args['tempId'];
    final id2 = queue[1].args['tempId'];
    expect(id1, isNotNull);
    expect(id1, isNot(id2)); // 不碰撞

    // getStream 重播:fresh(空)→ 套兩筆 pending → entry id 與 queued tempId 相同、順序穩定
    adapter.onGet(
      '/trips/t/days',
      (s) => s.reply(200, [
        {'dayNum': 1, 'timeline': <dynamic>[]},
      ]),
      queryParameters: {'all': '1'},
    );
    final emissions = await client
        .getStream('/trips/t/days', query: {'all': '1'})
        .toList();
    final timeline =
        ((emissions.last as List).first as Map)['timeline'] as List;
    final replayIds = timeline.map((e) => (e as Map)['id']).toList();
    expect(replayIds, [id1, id2]); // 冪等
  });
}
