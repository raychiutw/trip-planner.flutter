import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/cache/cache_keys.dart';
import 'package:tripline/api/cache/cache_store.dart';
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

  test('無快取線上 → 只 emit fresh', () async {
    adapter.onGet(
      '/my-trips',
      (s) => s.reply(200, [
        {'id': 't1'},
      ]),
    );
    final values = await client.getStream('/my-trips').toList();
    expect(values, [
      [
        {'id': 't1'},
      ],
    ]);
  });

  test('有快取線上 → emit stale 再 fresh', () async {
    await cache.writeResponse(cacheKeyFor('GET', '/my-trips'), [
      {'id': 'old'},
    ]);
    adapter.onGet(
      '/my-trips',
      (s) => s.reply(200, [
        {'id': 'new'},
      ]),
    );
    final values = await client.getStream('/my-trips').toList();
    expect(values, [
      [
        {'id': 'old'},
      ],
      [
        {'id': 'new'},
      ],
    ]);
  });

  test('無快取離線 → emit error', () async {
    adapter.onGet('/my-trips', (s) => s.throws(503, _offline('/my-trips')));
    await expectLater(
      client.getStream('/my-trips'),
      emitsError(isA<DioException>()),
    );
  });

  test('有快取離線 → 先 emit stale 且不報錯', () async {
    await cache.writeResponse(cacheKeyFor('GET', '/my-trips'), [
      {'id': 'old'},
    ]);
    adapter.onGet('/my-trips', (s) => s.throws(503, _offline('/my-trips')));
    final values = await client.getStream('/my-trips').toList();
    expect(values.first, [
      {'id': 'old'},
    ]);
    expect(
      values,
      everyElement(
        equals([
          {'id': 'old'},
        ]),
      ),
    );
  });
}
