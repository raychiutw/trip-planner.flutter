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

  test('cacheStore=null → 行為不變(GET 成功不報錯)', () async {
    final plain = ApiClient(sessionStore: InMemorySessionStore(), dio: dio);
    adapter.onGet('/trips', (s) => s.reply(200, []));
    expect(await plain.get('/trips'), []);
  });
}
