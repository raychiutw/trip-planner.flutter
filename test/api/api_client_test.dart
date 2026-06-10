import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/session_store.dart';

/// 依序回放腳本 response 的假 adapter（http_mock_adapter 無法對同一
/// request 簽章先回 429 再回 200，retry 測試需要序列回應）。
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
    final responseIndex =
        (recordedRequests.length - 1).clamp(0, scriptedResponses.length - 1);
    return scriptedResponses[responseIndex];
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponseBody(int statusCode, Object? body,
    {Map<String, List<String>>? extraHeaders}) {
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
  late DioAdapter dioAdapter;
  late InMemorySessionStore sessionStore;
  late List<RequestOptions> recordedRequests;
  late ApiClient apiClient;

  setUp(() {
    dio = Dio();
    dioAdapter = DioAdapter(dio: dio);
    sessionStore = InMemorySessionStore();
    recordedRequests = [];
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        recordedRequests.add(options);
        handler.next(options);
      },
    ));
    apiClient = ApiClient(sessionStore: sessionStore, dio: dio);
  });

  group('規則 1：Cookie header', () {
    test('store 有 token 時每個 request 帶 Cookie: tripline_session=<token>',
        () async {
      await sessionStore.write('token123');
      dioAdapter.onGet('/my-trips', (server) => server.reply(200, []));

      await apiClient.get('/my-trips');

      expect(
        recordedRequests.single.headers['Cookie'],
        'tripline_session=token123',
      );
    });

    test('store 無 token 時不帶 Cookie header', () async {
      dioAdapter.onGet('/my-trips', (server) => server.reply(200, []));

      await apiClient.get('/my-trips');

      expect(recordedRequests.single.headers.containsKey('Cookie'), isFalse);
    });
  });

  group('規則 2：Origin header', () {
    test('mutating request（POST）帶 Origin', () async {
      dioAdapter.onPost(
        '/oauth/logout',
        (server) => server.reply(200, {'ok': true}),
      );

      await apiClient.post('/oauth/logout');

      expect(recordedRequests.single.headers['Origin'], kTriplineOrigin);
    });

    test('GET 不帶 Origin', () async {
      dioAdapter.onGet('/trips', (server) => server.reply(200, []));

      await apiClient.get('/trips');

      expect(recordedRequests.single.headers.containsKey('Origin'), isFalse);
    });
  });

  group('規則 3：非 2xx 與 429 retry', () {
    test('非 2xx 丟出 ApiError', () async {
      dioAdapter.onGet(
        '/trips/missing',
        (server) => server.reply(404, {
          'error': {'code': 'DATA_NOT_FOUND', 'message': '找不到行程'},
        }),
      );

      await expectLater(
        apiClient.get('/trips/missing'),
        throwsA(isA<ApiError>()
            .having((error) => error.status, 'status', 404)
            .having((error) => error.code, 'code', 'DATA_NOT_FOUND')),
      );
    });

    test('429 GET 讀 Retry-After 後 retry 一次', () async {
      final sequencedAdapter = SequencedResponseAdapter([
        jsonResponseBody(
          429,
          {
            'error': {'code': 'SYS_RATE_LIMIT', 'message': '請稍後再試'},
          },
          extraHeaders: {
            'retry-after': ['0'],
          },
        ),
        jsonResponseBody(200, [
          {'tripId': 'okinawa-trip-2026-Ray', 'name': 'Okinawa'},
        ]),
      ]);
      final sequencedDio = Dio()..httpClientAdapter = sequencedAdapter;
      final retryingClient =
          ApiClient(sessionStore: sessionStore, dio: sequencedDio);

      final responseBody = await retryingClient.get('/my-trips');

      expect(sequencedAdapter.recordedRequests, hasLength(2));
      expect(responseBody, isA<List<dynamic>>());
    });

    test('429 GET retry 後仍 429 → 丟 ApiError（只 retry 一次）', () async {
      final rateLimitedBody = jsonResponseBody(
        429,
        {
          'error': {'code': 'SYS_RATE_LIMIT', 'message': '請稍後再試'},
        },
        extraHeaders: {
          'retry-after': ['0'],
        },
      );
      final sequencedAdapter = SequencedResponseAdapter([
        rateLimitedBody,
        jsonResponseBody(
          429,
          {
            'error': {'code': 'SYS_RATE_LIMIT', 'message': '請稍後再試'},
          },
          extraHeaders: {
            'retry-after': ['0'],
          },
        ),
      ]);
      final sequencedDio = Dio()..httpClientAdapter = sequencedAdapter;
      final retryingClient =
          ApiClient(sessionStore: sessionStore, dio: sequencedDio);

      await expectLater(
        retryingClient.get('/my-trips'),
        throwsA(isA<ApiError>().having((error) => error.status, 'status', 429)),
      );
      expect(sequencedAdapter.recordedRequests, hasLength(2));
    });

    test('429 mutation 不 retry 直接丟 ApiError', () async {
      final sequencedAdapter = SequencedResponseAdapter([
        jsonResponseBody(
          429,
          {
            'error': {'code': 'SYS_RATE_LIMIT', 'message': '請稍後再試'},
          },
          extraHeaders: {
            'retry-after': ['0'],
          },
        ),
        jsonResponseBody(200, {'ok': true}),
      ]);
      final sequencedDio = Dio()..httpClientAdapter = sequencedAdapter;
      final nonRetryingClient =
          ApiClient(sessionStore: sessionStore, dio: sequencedDio);

      await expectLater(
        nonRetryingClient.post('/trips', body: {'id': 't1'}),
        throwsA(isA<ApiError>().having((error) => error.status, 'status', 429)),
      );
      expect(sequencedAdapter.recordedRequests, hasLength(1));
    });

    test('parseRetryAfterSeconds：delta-seconds、cap 30s、HTTP-date、無效值',
        () {
      expect(ApiClient.parseRetryAfterSeconds('5'), 5);
      expect(ApiClient.parseRetryAfterSeconds('0'), 0);
      expect(ApiClient.parseRetryAfterSeconds('120'), 30);
      // 過去的 HTTP-date → 0 秒
      expect(
        ApiClient.parseRetryAfterSeconds('Wed, 21 Oct 2015 07:28:00 GMT'),
        0,
      );
      expect(ApiClient.parseRetryAfterSeconds('not-a-number'), 1);
      expect(ApiClient.parseRetryAfterSeconds(null), 1);
    });
  });

  group('規則 4：204 / 空 body', () {
    test('204 回 null', () async {
      dioAdapter.onDelete(
        '/trips/old-trip',
        (server) => server.reply(204, null),
      );

      expect(await apiClient.delete('/trips/old-trip'), isNull);
    });

    test('200 空字串 body 回 null', () async {
      dioAdapter.onGet(
        '/empty',
        (server) => server.reply(
          200,
          '',
          headers: {
            Headers.contentTypeHeader: ['text/plain'],
          },
        ),
      );

      expect(await apiClient.get('/empty'), isNull);
    });
  });

  group('base URL', () {
    test('base = <origin>/api', () {
      expect(apiClient.dio.options.baseUrl, '$kTriplineOrigin/api');
    });
  });
}
