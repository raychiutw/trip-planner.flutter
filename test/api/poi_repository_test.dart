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

  test(
    'autocompletePlaces：POST q/sessionToken/regionCode → 解析 predictions',
    () async {
      dioAdapter.onPost(
        '/places/autocomplete',
        (server) => server.reply(200, {
          'predictions': [
            {
              'placeId': 'ChIJ123',
              'primaryText': '高雄市左營區',
              'secondaryText': 'Kaohsiung City, Taiwan',
            },
          ],
        }),
        data: {'q': '左營', 'sessionToken': 'session-1', 'regionCode': 'TW'},
      );

      final predictions = await poiRepository.autocompletePlaces(
        q: ' 左營 ',
        sessionToken: ' session-1 ',
        regionCode: 'TW',
      );

      expect(predictions.single.placeId, 'ChIJ123');
      expect(predictions.single.primaryText, '高雄市左營區');
    },
  );

  test('autocompletePlaces：regionCode 空白時省略', () async {
    dioAdapter.onPost(
      '/places/autocomplete',
      (server) => server.reply(200, {'predictions': []}),
      data: {'q': '首里', 'sessionToken': 'session-2'},
    );

    await poiRepository.autocompletePlaces(
      q: '首里',
      sessionToken: 'session-2',
      regionCode: ' ',
    );

    final sent = recordedRequests.single;
    expect(
      (sent.data as Map<String, dynamic>).containsKey('regionCode'),
      false,
    );
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

  test('enrichPoi：POST /pois/:id/enrich?tripId=... → 解析 refresh 結果', () async {
    dioAdapter.onPost(
      '/pois/42/enrich',
      (server) => server.reply(200, {
        'poi_id': 42,
        'name': '暖暮拉麵',
        'place_id': 'ChIJ123',
        'status': 'closed',
        'status_reason': '永久歇業',
        'rating': 4.1,
        'refreshed_at': '2026-07-09T10:00:00Z',
      }),
      queryParameters: {'tripId': 'okinawa'},
    );

    final result = await poiRepository.enrichPoi(
      poiId: 42,
      tripId: ' okinawa ',
    );

    expect(result.poiId, 42);
    expect(result.status.name, 'closed');
    expect(result.statusReason, '永久歇業');
    expect(result.rating, 4.1);
  });
}
