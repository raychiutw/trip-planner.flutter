import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/api_error.dart';
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

  test('restoreFavorite：POST /poi-favorites/:id/restore 並解析原收藏', () async {
    dioAdapter.onPost(
      '/poi-favorites/7/restore',
      (server) => server.reply(200, {
        'id': 7,
        'user_id': 'u-1',
        'poi_id': 501,
        'favorited_at': '2026-06-01T10:00:00Z',
        'note': '雨天備案',
        'poi_name': '美麗海水族館',
      }),
      data: <String, dynamic>{},
    );

    final restored = await favoritesRepository.restoreFavorite(7);

    expect(restored.id, 7);
    expect(restored.note, '雨天備案');
  });

  test('addFavorite：POST /poi-favorites camelCase {poiId}', () async {
    dioAdapter.onPost(
      '/poi-favorites',
      (server) => server.reply(201, {
        'id': 9,
        'userId': 'u-1',
        'poiId': 501,
        'favoritedAt': '2026-06-11T00:00:00Z',
      }),
      data: {'poiId': 501},
    );

    await expectLater(favoritesRepository.addFavorite(501), completes);
  });

  test(
    'addFavoriteToTrip：POST /poi-favorites/:id/add-to-trip camelCase（201 成功）',
    () async {
      dioAdapter.onPost(
        '/poi-favorites/7/add-to-trip',
        (server) => server.reply(201, {
          'ok': true,
          'entryId': 11,
          'dayId': 2,
          'sortOrder': 0,
          'startTime': '10:00',
          'endTime': '11:00',
          'note': '...',
        }),
        data: {
          'tripId': 'okinawa',
          'dayNum': 1,
          'startTime': '10:00',
          'endTime': '11:00',
        },
      );

      await expectLater(
        favoritesRepository.addFavoriteToTrip(
          favoriteId: 7,
          tripId: 'okinawa',
          dayNum: 1,
          startTime: '10:00',
          endTime: '11:00',
        ),
        completes,
      );
    },
  );

  test('addFavoriteToTrip：409 → 拋 ApiError 帶 conflictWith payload', () async {
    dioAdapter.onPost(
      '/poi-favorites/7/add-to-trip',
      (server) => server.reply(409, {
        'error': 'CONFLICT',
        'conflictWith': {
          'entryId': 5,
          'time': '10:00-11:00',
          'title': '午餐',
          'dayNum': 1,
        },
      }),
      data: {
        'tripId': 'okinawa',
        'dayNum': 1,
        'startTime': '10:00',
        'endTime': '11:00',
      },
    );

    await expectLater(
      favoritesRepository.addFavoriteToTrip(
        favoriteId: 7,
        tripId: 'okinawa',
        dayNum: 1,
        startTime: '10:00',
        endTime: '11:00',
      ),
      throwsA(
        isA<ApiError>()
            .having((e) => e.status, 'status', 409)
            .having(
              (e) => e.payload?['conflictWith'],
              'conflictWith',
              isA<Map>(),
            ),
      ),
    );
  });
}
