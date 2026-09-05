import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/cache/cache_keys.dart';
import 'package:tripline/api/cache/cache_read_policy.dart';
import 'package:tripline/api/cache/cache_store.dart';
import 'package:tripline/api/session_store.dart';

/// 依序回放腳本 response 的假 adapter（retry 測試需要序列回應）。
class SequencedResponseAdapter implements HttpClientAdapter {
  SequencedResponseAdapter(this.scriptedResponses);

  final List<ResponseBody> scriptedResponses;
  final List<RequestOptions> recordedRequests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    recordedRequests.add(options);
    final index = (recordedRequests.length - 1).clamp(
      0,
      scriptedResponses.length - 1,
    );
    return scriptedResponses[index];
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponseBody(
  int statusCode,
  Object? body, {
  Map<String, List<String>>? extraHeaders,
}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
      ...?extraHeaders,
    },
  );
}

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

  test('GET 成功 → write-through 寫入快取', () async {
    adapter.onGet(
      '/my-trips',
      (s) => s.reply(200, [
        {'id': 't1'},
      ]),
    );
    await client.get('/my-trips');
    final entry = await cache.readResponse(cacheKeyFor('GET', '/my-trips'));
    expect(entry!.data, [
      {'id': 't1'},
    ]);
  });

  test('GET 連線失敗 + 有快取 → 回退快取', () async {
    await cache.writeResponse(
      cacheKeyFor('GET', '/trips/t/days', {'all': '1'}),
      [
        {'dayNumber': 1},
      ],
    );
    adapter.onGet(
      '/trips/t/days',
      (s) => s.throws(
        503,
        DioException(
          requestOptions: RequestOptions(path: '/trips/t/days'),
          type: DioExceptionType.connectionError,
        ),
      ),
      queryParameters: {'all': '1'},
    );
    final result = await client.get('/trips/t/days', query: {'all': '1'});
    expect(result, [
      {'dayNumber': 1},
    ]);
  });

  test('GET networkOnly → 有快取也不回退', () async {
    await cache.writeResponse(
      cacheKeyFor('GET', '/invitations', {'token': 'raw-token'}),
      {'tripId': 'stale-trip'},
    );
    adapter.onGet(
      '/invitations',
      (s) => s.throws(
        503,
        DioException(
          requestOptions: RequestOptions(path: '/invitations'),
          type: DioExceptionType.connectionError,
        ),
      ),
      queryParameters: {'token': 'raw-token'},
    );

    await expectLater(
      client.get(
        '/invitations',
        query: {'token': 'raw-token'},
        policy: CacheReadPolicy.networkOnly,
      ),
      throwsA(isA<DioException>()),
    );
  });

  test('GET 連線失敗 + 無快取 → rethrow', () async {
    adapter.onGet(
      '/trips/t/days',
      (s) => s.throws(
        503,
        DioException(
          requestOptions: RequestOptions(path: '/trips/t/days'),
          type: DioExceptionType.connectionError,
        ),
      ),
      queryParameters: {'all': '1'},
    );
    expect(
      () => client.get('/trips/t/days', query: {'all': '1'}),
      throwsA(isA<DioException>()),
    );
  });

  test('GET 4xx(server 有回應)→ 丟 ApiError,不回退快取', () async {
    final key = cacheKeyFor('GET', '/trips/t/days', {'all': '1'});
    await cache.writeResponse(key, [
      {'dayNumber': 99},
    ]);
    adapter.onGet(
      '/trips/t/days',
      (s) => s.reply(404, {
        'error': {'code': 'DATA_NOT_FOUND'},
      }),
      queryParameters: {'all': '1'},
    );
    await expectLater(
      client.get('/trips/t/days', query: {'all': '1'}),
      throwsA(isA<ApiError>().having((e) => e.status, 'status', 404)),
    );
    // 快取未被污染、仍在
    expect((await cache.readResponse(key))!.data, [
      {'dayNumber': 99},
    ]);
  });

  test('429 GET retry 後只把 200 結果寫入快取(不快取 429)', () async {
    final seq = SequencedResponseAdapter([
      jsonResponseBody(
        429,
        {
          'error': {'code': 'SYS_RATE_LIMIT'},
        },
        extraHeaders: {
          'retry-after': ['0'],
        },
      ),
      jsonResponseBody(200, [
        {'id': 't1'},
      ]),
    ]);
    final seqDio = Dio()..httpClientAdapter = seq;
    final c = ApiClient(
      sessionStore: InMemorySessionStore(),
      dio: seqDio,
      cacheStore: cache,
    );
    await c.get('/my-trips');
    expect(seq.recordedRequests, hasLength(2));
    expect((await cache.readResponse(cacheKeyFor('GET', '/my-trips')))!.data, [
      {'id': 't1'},
    ]);
  });

  test('mutation 成功 → 依失效表 evict', () async {
    final daysKey = cacheKeyFor('GET', '/trips/t/days', {'all': '1'});
    await cache.writeResponse(daysKey, [
      {'dayNumber': 1},
    ]);
    adapter.onPatch(
      '/trips/t/entries/5',
      (s) => s.reply(200, {'ok': true}),
      data: {'title': 'x'},
    );
    await client.patch('/trips/t/entries/5', body: {'title': 'x'});
    expect(await cache.readResponse(daysKey), isNull);
  });

  test('mutation 4xx(409)→ 不 evict 快取', () async {
    final daysKey = cacheKeyFor('GET', '/trips/t/days', {'all': '1'});
    await cache.writeResponse(daysKey, [
      {'dayNumber': 1},
    ]);
    adapter.onPatch(
      '/trips/t/entries/5',
      (s) => s.reply(409, {
        'error': {'code': 'STALE_ENTRY'},
      }),
      data: {'title': 'x'},
    );
    await expectLater(
      client.patch('/trips/t/entries/5', body: {'title': 'x'}),
      throwsA(isA<ApiError>()),
    );
    expect(await cache.readResponse(daysKey), isNotNull);
  });

  test('add-to-trip 成功 → evict 目標 trip 的 days(tripId 在 body)', () async {
    final daysKey = cacheKeyFor('GET', '/trips/t/days', {'all': '1'});
    await cache.writeResponse(daysKey, [
      {'dayNumber': 1},
    ]);
    final body = {
      'tripId': 't',
      'dayNum': 1,
      'startTime': '09:00',
      'endTime': '10:00',
    };
    adapter.onPost(
      '/poi-favorites/42/add-to-trip',
      (s) => s.reply(200, {'ok': true}),
      data: body,
    );
    await client.post('/poi-favorites/42/add-to-trip', body: body);
    expect(await cache.readResponse(daysKey), isNull);
  });

  test('accept invitation 成功 → evict my trips 與 invitations 快取', () async {
    final tripsKey = cacheKeyFor('GET', '/my-trips');
    final invitesKey = cacheKeyFor('GET', '/invitations', {'tripId': 'trip-1'});
    await cache.writeResponse(tripsKey, [
      {'id': 'old-trip'},
    ]);
    await cache.writeResponse(invitesKey, {
      'items': [
        {'id': 'invite-1'},
      ],
    });
    adapter.onPost(
      '/invitations/accept',
      (s) => s.reply(200, {'ok': true, 'tripId': 'trip-1'}),
      data: {'token': 'raw-token'},
    );

    await client.post('/invitations/accept', body: {'token': 'raw-token'});

    expect(await cache.readResponse(tripsKey), isNull);
    expect(await cache.readResponse(invitesKey), isNull);
  });

  test('developer app PATCH 成功後 list/detail 不可回退舊快取', () async {
    final listKey = cacheKeyFor('GET', '/dev/apps');
    final detailKey = cacheKeyFor('GET', '/dev/apps/tp_dev');
    await cache.writeResponse(listKey, [
      {'clientId': 'tp_dev', 'appName': 'Old App'},
    ]);
    await cache.writeResponse(detailKey, {
      'clientId': 'tp_dev',
      'appName': 'Old App',
    });
    adapter.onPatch(
      '/dev/apps/tp_dev',
      (server) =>
          server.reply(200, {'clientId': 'tp_dev', 'appName': 'New App'}),
      data: {'appName': 'New App'},
    );
    adapter.onGet(
      '/dev/apps/tp_dev',
      (server) => server.throws(
        503,
        DioException(
          requestOptions: RequestOptions(path: '/dev/apps/tp_dev'),
          type: DioExceptionType.connectionError,
        ),
      ),
    );

    await client.patch('/dev/apps/tp_dev', body: {'appName': 'New App'});

    expect(await cache.readResponse(listKey), isNull);
    expect(await cache.readResponse(detailKey), isNull);
    await expectLater(
      client.get('/dev/apps/tp_dev'),
      throwsA(isA<DioException>()),
    );
  });

  test('session DELETE 成功後不可回退舊清單快取', () async {
    final sessionsKey = cacheKeyFor('GET', '/account/sessions');
    await cache.writeResponse(sessionsKey, [
      {'id': 'session-1'},
    ]);
    adapter.onDelete(
      '/account/sessions/session-1',
      (server) => server.reply(204, null),
    );
    adapter.onGet(
      '/account/sessions',
      (server) => server.throws(
        503,
        DioException(
          requestOptions: RequestOptions(path: '/account/sessions'),
          type: DioExceptionType.connectionError,
        ),
      ),
    );

    await client.delete('/account/sessions/session-1');

    expect(await cache.readResponse(sessionsKey), isNull);
    await expectLater(
      client.get('/account/sessions'),
      throwsA(isA<DioException>()),
    );
  });

  test('connected app DELETE 成功後不可回退舊清單快取', () async {
    final connectedAppsKey = cacheKeyFor('GET', '/account/connected-apps');
    await cache.writeResponse(connectedAppsKey, [
      {'clientId': 'tp_alpha'},
    ]);
    adapter.onDelete(
      '/account/connected-apps/tp_alpha',
      (server) => server.reply(204, null),
    );
    adapter.onGet(
      '/account/connected-apps',
      (server) => server.throws(
        503,
        DioException(
          requestOptions: RequestOptions(path: '/account/connected-apps'),
          type: DioExceptionType.connectionError,
        ),
      ),
    );

    await client.delete('/account/connected-apps/tp_alpha');

    expect(await cache.readResponse(connectedAppsKey), isNull);
    await expectLater(
      client.get('/account/connected-apps'),
      throwsA(isA<DioException>()),
    );
  });

  test('userinfo 離線 → 回退最後快取身分(離線保持登入)', () async {
    final key = cacheKeyFor('GET', '/oauth/userinfo');
    await cache.writeResponse(key, {'id': 'u1', 'email': 'a@b.c'});
    adapter.onGet(
      '/oauth/userinfo',
      (s) => s.throws(
        503,
        DioException(
          requestOptions: RequestOptions(path: '/oauth/userinfo'),
          type: DioExceptionType.connectionError,
        ),
      ),
    );
    final result = await client.get('/oauth/userinfo');
    expect(result, {'id': 'u1', 'email': 'a@b.c'});
  });

  group('高基數 GET 的容量上限', () {
    // /poi-search 與 /route 同病:每個 query 都是新 key、沒有任何 mutation 會
    // evict 它們 → 快取只增不減。先前是整個排除在快取外(止血),快取層遷到
    // drift(sqlite,不全載入記憶體)後改為「照常快取,但給容量上限」。

    test('/poi-search 會寫入快取', () async {
      adapter.onGet(
        '/poi-search',
        (s) => s.reply(200, [
          {'name': 'x'},
        ]),
        queryParameters: {'q': 'tokyo'},
      );
      await client.get('/poi-search', query: {'q': 'tokyo'});
      expect(
        await cache.readResponse(
          cacheKeyFor('GET', '/poi-search', {'q': 'tokyo'}),
        ),
        isNotNull,
      );
    });

    test('/route 會寫入快取', () async {
      adapter.onGet(
        '/route',
        (s) => s.reply(200, {
          'polyline': [
            [35.68, 139.7],
          ],
          'duration': 1315,
          'distance': 6026,
        }),
        queryParameters: {'from': '139.7,35.68', 'to': '139.74,35.66'},
      );
      await client.get(
        '/route',
        query: {'from': '139.7,35.68', 'to': '139.74,35.66'},
      );
      expect(
        await cache.readResponse(
          cacheKeyFor('GET', '/route', {
            'from': '139.7,35.68',
            'to': '139.74,35.66',
          }),
        ),
        isNotNull,
      );
    });

    test('超過上限時丟掉最舊的,總數不超過上限', () async {
      final capped = ApiClient(
        sessionStore: InMemorySessionStore(),
        cacheStore: cache,
        dio: dio,
        cacheCapacityByPathPrefix: const {'/poi-search': 2},
      );
      for (final q in ['a', 'b', 'c']) {
        adapter.onGet(
          '/poi-search',
          (s) => s.reply(200, [
            {'name': q},
          ]),
          queryParameters: {'q': q},
        );
        await capped.get('/poi-search', query: {'q': q});
      }

      // 最舊的 a 被淘汰,b/c 留著。
      expect(
        await cache.readResponse(cacheKeyFor('GET', '/poi-search', {'q': 'a'})),
        isNull,
      );
      expect(
        await cache.readResponse(cacheKeyFor('GET', '/poi-search', {'q': 'b'})),
        isNotNull,
      );
      expect(
        await cache.readResponse(cacheKeyFor('GET', '/poi-search', {'q': 'c'})),
        isNotNull,
      );
    });

    test('上限只約束該前綴,不波及一般快取', () async {
      final capped = ApiClient(
        sessionStore: InMemorySessionStore(),
        cacheStore: cache,
        dio: dio,
        cacheCapacityByPathPrefix: const {'/poi-search': 1},
      );
      await cache.writeResponse(cacheKeyFor('GET', '/my-trips'), [1]);
      for (final q in ['a', 'b']) {
        adapter.onGet(
          '/poi-search',
          (s) => s.reply(200, [
            {'name': q},
          ]),
          queryParameters: {'q': q},
        );
        await capped.get('/poi-search', query: {'q': q});
      }
      expect(
        await cache.readResponse(cacheKeyFor('GET', '/my-trips')),
        isNotNull,
      );
    });
  });

  test('cacheStore=null → 行為不變(GET 成功不報錯)', () async {
    final plain = ApiClient(sessionStore: InMemorySessionStore(), dio: dio);
    adapter.onGet('/trips', (s) => s.reply(200, []));
    expect(await plain.get('/trips'), []);
  });

  group('讀取政策', () {
    test('noStore → GET 成功後快取不被寫入(仍為 null)', () async {
      final key = cacheKeyFor('GET', '/trips/t1');
      adapter.onGet('/trips/t1', (s) => s.reply(200, {'id': 't1'}));

      await client.get('/trips/t1', policy: CacheReadPolicy.noStore);

      expect(await cache.readResponse(key), isNull);
    });

    test('networkOnly → 不讀快取,但成功後仍寫入', () async {
      final key = cacheKeyFor('GET', '/trips/t1');
      adapter.onGet('/trips/t1', (s) => s.reply(200, {'id': 't1'}));

      await client.get('/trips/t1', policy: CacheReadPolicy.networkOnly);

      expect((await cache.readResponse(key))!.data, {'id': 't1'});
    });

    test('預設 cached → GET 成功後快取有新值(回歸保護)', () async {
      final key = cacheKeyFor('GET', '/trips/t1');
      adapter.onGet('/trips/t1', (s) => s.reply(200, {'id': 't1'}));

      await client.get('/trips/t1');

      expect((await cache.readResponse(key))!.data, {'id': 't1'});
    });
  });
}
