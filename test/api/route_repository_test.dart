import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/route_repository.dart';
import 'package:tripline/api/session_store.dart';

void main() {
  late Dio dio;
  late DioAdapter dioAdapter;
  late RouteRepository routeRepository;

  setUp(() {
    dio = Dio();
    dioAdapter = DioAdapter(dio: dio);
    routeRepository = RouteRepository(
      client: ApiClient(sessionStore: InMemorySessionStore(), dio: dio),
    );
  });

  test('fetchRoute:組 from/to(lng,lat)query 並解析 polyline', () async {
    dioAdapter.onGet(
      '/route',
      (server) => server.reply(200, {
        'polyline': [
          [25.0, 121.5],
          [25.1, 121.6],
        ],
        'duration': 300,
        'distance': 1200,
      }),
      queryParameters: {'from': '121.5,25.0', 'to': '121.6,25.1'},
    );

    final result = await routeRepository.fetchRoute(
      fromLat: 25.0,
      fromLng: 121.5,
      toLat: 25.1,
      toLng: 121.6,
    );

    expect(result, isNotNull);
    expect(result!.polyline.length, 2);
    expect(result.polyline.first.lat, 25.0);
    expect(result.distanceM, 1200);
  });

  test('fetchRoute:502 MAPS_UPSTREAM_FAILED → null(隱藏折線,不 fallback 直線)', () async {
    dioAdapter.onGet(
      '/route',
      (server) => server.reply(502, {'error': 'MAPS_UPSTREAM_FAILED'}),
      queryParameters: {'from': '121.5,25.0', 'to': '121.6,25.1'},
    );

    final result = await routeRepository.fetchRoute(
      fromLat: 25.0,
      fromLng: 121.5,
      toLat: 25.1,
      toLng: 121.6,
    );

    expect(result, isNull);
  });
}
