import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/cache/cache_keys.dart';
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

  test('/poi-search 不寫入快取(離線非目標、避免無限增長)', () async {
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
      isNull,
    );
  });

  test('cacheStore=null → 行為不變(GET 成功不報錯)', () async {
    final plain = ApiClient(sessionStore: InMemorySessionStore(), dio: dio);
    adapter.onGet('/trips', (s) => s.reply(200, []));
    expect(await plain.get('/trips'), []);
  });

  group('writeCache 開關', () {
    test('writeCache:false → GET 成功後快取不被寫入(仍為 null)', () async {
      final key = cacheKeyFor('GET', '/trips/t1');
      adapter.onGet('/trips/t1', (s) => s.reply(200, {'id': 't1'}));

      await client.get('/trips/t1', writeCache: false);

      expect(await cache.readResponse(key), isNull);
    });

    test('預設 writeCache:true → GET 成功後快取有新值(回歸保護)', () async {
      final key = cacheKeyFor('GET', '/trips/t1');
      adapter.onGet('/trips/t1', (s) => s.reply(200, {'id': 't1'}));

      await client.get('/trips/t1');

      expect((await cache.readResponse(key))!.data, {'id': 't1'});
    });
  });
}
