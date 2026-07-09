import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/poi_repository.dart';
import 'package:tripline/api/session_store.dart';

void main() {
  late Dio dio;
  late DioAdapter dioAdapter;
  late List<RequestOptions> recordedRequests;
  late PoiRepository poiRepository;

  setUp(() {
    dio = Dio();
    dioAdapter = DioAdapter(dio: dio);
    recordedRequests = [];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          recordedRequests.add(options);
          handler.next(options);
        },
      ),
    );
    poiRepository = PoiRepository(
      client: ApiClient(sessionStore: InMemorySessionStore(), dio: dio),
    );
  });

  test('searchPois：組 query（q/limit/region）+ 解析 results', () async {
    dioAdapter.onGet(
      '/poi-search',
      (server) => server.reply(200, {
        'results': [
          {
            'place_id': 'p1',
            'name': '首里城',
            'category': 'tourist_attraction',
            'rating': 4.4,
          },
        ],
      }),
      queryParameters: {'q': '首里城', 'limit': '20', 'region': '沖繩'},
    );

    final results = await poiRepository.searchPois(q: '首里城', region: '沖繩');

    expect(results.single.placeId, 'p1');
    expect(results.single.name, '首里城');
  });

  test('searchPois：region 為 null → query 不含 region', () async {
    dioAdapter.onGet(
      '/poi-search',
      (server) => server.reply(200, {'results': []}),
      queryParameters: {'q': '拉麵', 'limit': '20'},
    );

    await poiRepository.searchPois(q: '拉麵');

    final sent = recordedRequests.single;
    expect(sent.queryParameters.containsKey('region'), isFalse);
  });

  test('findOrCreatePoi：POST snake_case body → 回 poiId', () async {
    dioAdapter.onPost(
      '/pois/find-or-create',
      (server) => server.reply(200, {'id': 501}),
      data: {
        'name': '暖暮拉麵',
        'type': 'restaurant',
        'lat': 26.21,
        'lng': 127.68,
        'address': '那霸市',
        'category': 'ramen_restaurant',
        'source': 'user-explore',
        'place_id': 'p2',
      },
    );

    final poiId = await poiRepository.findOrCreatePoi(
      name: '暖暮拉麵',
      type: 'restaurant',
      lat: 26.21,
      lng: 127.68,
      address: '那霸市',
      category: 'ramen_restaurant',
      placeId: 'p2',
    );

    expect(poiId, 501);
  });

  test('resolvePlace：GET /places/resolve?placeId=... → 解析 details', () async {
    dioAdapter.onGet(
      '/places/resolve',
      (server) => server.reply(200, {
        'placeId': 'p1',
        'name': '美麗海水族館',
        'address': '沖繩縣本部町石川424',
        'lat': 26.694,
        'lng': 127.878,
        'hours': '星期一: 09:00-18:00',
        'priceLevel': 'PRICE_LEVEL_MODERATE',
      }),
      queryParameters: {'placeId': 'p1'},
    );

    final details = await poiRepository.resolvePlace('p1');

    expect(details.placeId, 'p1');
    expect(details.hours, '星期一: 09:00-18:00');
    expect(details.priceLevel, 'PRICE_LEVEL_MODERATE');
  });
}
