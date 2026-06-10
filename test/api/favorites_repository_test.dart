import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/favorites_repository.dart';
import 'package:tripline/api/session_store.dart';

void main() {
  late Dio dio;
  late DioAdapter dioAdapter;
  late FavoritesRepository favoritesRepository;

  setUp(() {
    dio = Dio();
    dioAdapter = DioAdapter(dio: dio);
    final apiClient = ApiClient(sessionStore: InMemorySessionStore(), dio: dio);
    favoritesRepository = FavoritesRepository(client: apiClient);
  });

  test('fetchFavorites：GET /poi-favorites 解析 PoiFavorite list', () async {
    dioAdapter.onGet(
      '/poi-favorites',
      (server) => server.reply(200, [
        {
          'id': 7,
          'userId': 'u-1',
          'poiId': 501,
          'favoritedAt': '2026-06-01T10:00:00Z',
          'poiName': '首里城',
          'poiType': 'attraction',
          'poiRating': 4.4,
          'usages': [
            {'tripId': 'okinawa', 'tripName': '沖繩', 'dayNum': 1},
          ],
        },
      ]),
    );

    final favorites = await favoritesRepository.fetchFavorites();

    expect(favorites, hasLength(1));
    expect(favorites.single.poiName, '首里城');
    expect(favorites.single.usages.single.tripName, '沖繩');
  });

  test('deleteFavorite：DELETE /poi-favorites/:id（204 視為成功）', () async {
    dioAdapter.onDelete(
      '/poi-favorites/7',
      (server) => server.reply(204, null),
    );

    await expectLater(favoritesRepository.deleteFavorite(7), completes);
  });

  test('addFavorite：POST /poi-favorites camelCase {poiId}', () async {
    dioAdapter.onPost(
      '/poi-favorites',
      (server) => server.reply(201, {'id': 9, 'userId': 'u-1', 'poiId': 501,
          'favoritedAt': '2026-06-11T00:00:00Z'}),
      data: {'poiId': 501},
    );

    await expectLater(favoritesRepository.addFavorite(501), completes);
  });
}
