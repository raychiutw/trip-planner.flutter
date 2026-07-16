import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/map_repository.dart';
import 'package:tripline/api/session_store.dart';

void main() {
  late Dio dio;
  late DioAdapter dioAdapter;
  late MapRepository mapRepository;

  setUp(() {
    dio = Dio();
    dioAdapter = DioAdapter(dio: dio);
    mapRepository = MapRepository(
      client: ApiClient(sessionStore: InMemorySessionStore(), dio: dio),
    );
  });

  test('fetchRoute：用 lng,lat query 呼叫 /route 並解析結果', () async {
    dioAdapter.onGet(
      '/route',
      (server) => server.reply(200, {
        'polyline': [
          [25.033, 121.5654],
          [25.034, 121.566],
        ],
        'duration': 612,
        'distance': 4300,
      }),
      queryParameters: {'from': '121.5654,25.033', 'to': '121.566,25.034'},
    );

    final route = await mapRepository.fetchRoute(
      fromLat: 25.033,
      fromLng: 121.5654,
      toLat: 25.034,
      toLng: 121.566,
    );

    expect(route.polyline, hasLength(2));
    expect(route.polyline.first.lat, 25.033);
    expect(route.durationSeconds, 612);
    expect(route.distanceMeters, 4300);
  });

  test('fetchRoute：回應非 JSON 物件時丟 ApiError（不是 TypeError）', () async {
    // 空 body → ApiClient 回 null。裸 `as Map<String, dynamic>` 會丟 TypeError，
    // 那是 Error 不是 Exception，呼叫端的 catch 攔不到。
    dioAdapter.onGet(
      '/route',
      (server) => server.reply(200, null),
      queryParameters: {'from': '121.5654,25.033', 'to': '121.566,25.034'},
    );

    await expectLater(
      mapRepository.fetchRoute(
        fromLat: 25.033,
        fromLng: 121.5654,
        toLat: 25.034,
        toLng: 121.566,
      ),
      throwsA(isA<ApiError>()),
    );
  });
}
