import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/session_store.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/models/poi.dart';

void main() {
  late Dio dio;
  late DioAdapter dioAdapter;
  late TripRepository tripRepository;

  setUp(() {
    dio = Dio();
    dioAdapter = DioAdapter(dio: dio);
    final apiClient = ApiClient(sessionStore: InMemorySessionStore(), dio: dio);
    tripRepository = TripRepository(client: apiClient);
  });

  test('fetchMyTrips：GET /my-trips 解析 TripSummary list', () async {
    dioAdapter.onGet(
      '/my-trips',
      (server) => server.reply(200, [
        {
          'tripId': 'okinawa-trip-2026-Ray',
          'name': 'Okinawa',
          'title': '沖繩自駕',
          'totalDays': 5,
        },
      ]),
    );

    final myTrips = await tripRepository.fetchMyTrips();

    expect(myTrips, hasLength(1));
    expect(myTrips.single.tripId, 'okinawa-trip-2026-Ray');
    expect(myTrips.single.totalDays, 5);
  });

  test('fetchTrips：GET /trips 解析 Trip list', () async {
    dioAdapter.onGet(
      '/trips',
      (server) => server.reply(200, [
        {
          'tripId': 'okinawa-trip-2026-Ray',
          'name': 'Okinawa',
          'owner': 'Ray',
          'published': 1,
          'dayCount': 5,
        },
      ]),
    );

    final publishedTrips = await tripRepository.fetchTrips();

    expect(publishedTrips.single.id, 'okinawa-trip-2026-Ray');
    expect(publishedTrips.single.published, isTrue);
  });

  test('fetchTrip：GET /trips/:id 解析 Trip detail（含 destinations）', () async {
    dioAdapter.onGet(
      '/trips/okinawa-trip-2026-Ray',
      (server) => server.reply(200, {
        'id': 'okinawa-trip-2026-Ray',
        'name': 'Okinawa',
        'published': 0,
        'destinations': [
          {'destOrder': 1, 'name': '那霸', 'lat': 26.21, 'lng': 127.68},
        ],
      }),
    );

    final tripDetail = await tripRepository.fetchTrip('okinawa-trip-2026-Ray');

    expect(tripDetail.id, 'okinawa-trip-2026-Ray');
    expect(tripDetail.destinations.single.name, '那霸');
  });

  test('fetchDays：GET /trips/:id/days?all=1 解析巢狀 timeline', () async {
    dioAdapter.onGet(
      '/trips/okinawa-trip-2026-Ray/days',
      (server) => server.reply(200, [
        {
          'id': 11,
          'dayNum': 1,
          'date': '2026-04-23',
          'dayOfWeek': '四',
          'label': 'Day 1',
          'title': '抵達那霸',
          'version': 2,
          'hotel': {
            'id': 99,
            'name': '那霸海濱飯店',
            'checkout': '11:00',
            'note': null,
            'location': {'name': '那霸', 'lat': 26.21, 'lng': 127.68},
          },
          'timeline': [
            {
              'id': 101,
              'dayId': 11,
              'sortOrder': 0,
              'time': '10:00',
              'startTime': '10:00',
              'endTime': '11:30',
              'title': '首里城',
              'description': '世界遺產',
              'note': null,
              'version': 1,
              'travel': {
                'type': 'drive',
                'desc': '開車 20 分',
                'min': 20,
                'distanceM': 8000,
                'source': 'google',
              },
              'master': {
                'poiId': 501,
                'name': '首里城公園',
                'lat': 26.217,
                'lng': 127.719,
                'type': 'attraction',
                'category': '歷史',
                'hours': '08:30-18:00',
                'rating': 4.4,
                'price': null,
                'note': null,
                'sortOrder': 0,
              },
              'alternates': [
                {
                  'poiId': 502,
                  'name': '玉陵',
                  'lat': 26.218,
                  'lng': 127.717,
                  'type': 'attraction',
                  'rating': 4.2,
                },
              ],
            },
            {
              'id': 102,
              'dayId': 11,
              'sortOrder': 1,
              'title': '國際通',
              'version': 1,
              'travel': null,
              'master': null,
              'alternates': [],
            },
          ],
        },
      ]),
      queryParameters: {'all': '1'},
    );

    final tripDays = await tripRepository.fetchDays('okinawa-trip-2026-Ray');

    expect(tripDays, hasLength(1));
    final firstDay = tripDays.single;
    expect(firstDay.dayNum, 1);
    expect(firstDay.displayTitle, '抵達那霸');
    expect(firstDay.hotel!.name, '那霸海濱飯店');
    expect(firstDay.hotel!.location!.lat, 26.21);
    expect(firstDay.timeline, hasLength(2));

    final shuriCastleEntry = firstDay.timeline.first;
    expect(shuriCastleEntry.title, '首里城');
    expect(shuriCastleEntry.travel!.min, 20);
    expect(shuriCastleEntry.master!.poiId, 501);
    expect(shuriCastleEntry.master!.rating, 4.4);
    expect(shuriCastleEntry.alternates.single.poiId, 502);

    final kokusaiStreetEntry = firstDay.timeline.last;
    expect(kokusaiStreetEntry.master, isNull);
    expect(kokusaiStreetEntry.alternates, isEmpty);
  });

  test(
    'fetchEntry：GET /trips/:id/entries/:eid 解析單一 entry 與 POI OCC token',
    () async {
      dioAdapter.onGet(
        '/trips/okinawa-trip-2026-Ray/entries/101',
        (server) => server.reply(200, {
          'id': 101,
          'dayId': 11,
          'sortOrder': 0,
          'startTime': '10:00',
          'endTime': '11:30',
          'title': '首里城',
          'description': '世界遺產',
          'source': 'google',
          'version': 7,
          'entryPoisVersion': '3',
          'master': {
            'poiId': 501,
            'name': '首里城公園',
            'type': 'attraction',
            'note': '黃昏時段去',
          },
          'alternates': [
            {'poiId': 502, 'name': '玉陵', 'type': 'attraction'},
          ],
        }),
      );

      final entry = await tripRepository.fetchEntry(
        'okinawa-trip-2026-Ray',
        101,
      );

      expect(entry.id, 101);
      expect(entry.version, 7);
      expect(entry.entryPoisVersion, '3');
      expect(entry.source, 'google');
      expect(entry.master!.note, '黃昏時段去');
      expect(entry.alternates.single.name, '玉陵');
    },
  );

  test('updateEntry：PATCH /trips/:id/entries/:eid 帶 expectedVersion', () async {
    dioAdapter.onPatch(
      '/trips/okinawa-trip-2026-Ray/entries/101',
      (server) => server.reply(200, {
        'id': 101,
        'dayId': 11,
        'sortOrder': 0,
        'startTime': '10:30',
        'endTime': '12:00',
        'title': '首里城',
        'description': '改成上午晚點去',
        'version': 8,
      }),
      data: {
        'start_time': '10:30',
        'end_time': '12:00',
        'description': '改成上午晚點去',
        'expectedVersion': 7,
      },
    );

    final updated = await tripRepository.updateEntry(
      'okinawa-trip-2026-Ray',
      101,
      expectedVersion: 7,
      startTime: '10:30',
      endTime: '12:00',
      description: '改成上午晚點去',
    );

    expect(updated.startTime, '10:30');
    expect(updated.endTime, '12:00');
    expect(updated.description, '改成上午晚點去');
    expect(updated.version, 8);
  });

  test('deleteEntry：DELETE /trips/:id/entries/:eid', () async {
    dioAdapter.onDelete(
      '/trips/okinawa-trip-2026-Ray/entries/101',
      (server) => server.reply(200, {'ok': true}),
    );

    await expectLater(
      tripRepository.deleteEntry('okinawa-trip-2026-Ray', 101),
      completes,
    );
  });

  test(
    'replaceEntryMasterPoiFromSearchResult：PUT /poi-id 帶 entryPoisVersion',
    () async {
      const searchResult = PoiSearchResult(
        placeId: 'ChIJ-shuri',
        name: '首里城',
        address: '沖繩縣那霸市首里金城町',
        lat: 26.217,
        lng: 127.719,
        category: 'tourist_attraction',
        country: 'JP',
        rating: 4.4,
      );
      dioAdapter.onPut(
        '/trips/okinawa-trip-2026-Ray/entries/101/poi-id',
        (server) => server.reply(200, {'ok': true, 'poiId': 501}),
        data: {
          'name': '首里城',
          'type': 'attraction',
          'lat': 26.217,
          'lng': 127.719,
          'address': '沖繩縣那霸市首里金城町',
          'category': 'tourist_attraction',
          'source': 'google',
          'country': 'JP',
          'place_id': 'ChIJ-shuri',
          'entryPoisVersion': '3',
          'rating': 4.4,
        },
      );

      await expectLater(
        tripRepository.replaceEntryMasterPoiFromSearchResult(
          tripId: 'okinawa-trip-2026-Ray',
          entryId: 101,
          poi: searchResult,
          entryPoisVersion: '3',
        ),
        completes,
      );
    },
  );

  test('replaceEntryMasterPoiWithPoiId：PUT /poi-id 可用既有 POI id', () async {
    dioAdapter.onPut(
      '/trips/okinawa-trip-2026-Ray/entries/101/poi-id',
      (server) => server.reply(200, {'ok': true, 'poiId': 501}),
      data: {'poiId': 501, 'entryPoisVersion': '3'},
    );

    await expectLater(
      tripRepository.replaceEntryMasterPoiWithPoiId(
        tripId: 'okinawa-trip-2026-Ray',
        entryId: 101,
        poiId: 501,
        entryPoisVersion: '3',
      ),
      completes,
    );
  });

  test(
    'addEntryAlternateFromSearchResult：POST /alternates 回新 POI OCC token',
    () async {
      const searchResult = PoiSearchResult(
        placeId: 'ChIJ-tamaudun',
        name: '玉陵',
        address: '沖繩縣那霸市',
        lat: 26.219,
        lng: 127.716,
        category: 'tourist_attraction',
        rating: 4.2,
      );
      dioAdapter.onPost(
        '/trips/okinawa-trip-2026-Ray/entries/101/alternates',
        (server) => server.reply(201, {
          'entryId': 101,
          'poiId': 502,
          'sortOrder': 2,
          'entryPoisVersion': '4',
        }),
        data: {
          'name': '玉陵',
          'type': 'attraction',
          'lat': 26.219,
          'lng': 127.716,
          'address': '沖繩縣那霸市',
          'category': 'tourist_attraction',
          'source': 'google',
          'place_id': 'ChIJ-tamaudun',
          'entryPoisVersion': '3',
          'rating': 4.2,
        },
      );

      final result = await tripRepository.addEntryAlternateFromSearchResult(
        tripId: 'okinawa-trip-2026-Ray',
        entryId: 101,
        poi: searchResult,
        entryPoisVersion: '3',
      );

      expect(result.entryId, 101);
      expect(result.poiId, 502);
      expect(result.sortOrder, 2);
      expect(result.entryPoisVersion, '4');
    },
  );

  test('addEntryAlternateWithPoiId：POST /alternates 可用收藏 POI id', () async {
    dioAdapter.onPost(
      '/trips/okinawa-trip-2026-Ray/entries/101/alternates',
      (server) => server.reply(201, {
        'entryId': 101,
        'poiId': 502,
        'sortOrder': 2,
        'entryPoisVersion': '4',
      }),
      data: {'poiId': 502, 'entryPoisVersion': '3'},
    );

    final result = await tripRepository.addEntryAlternateWithPoiId(
      tripId: 'okinawa-trip-2026-Ray',
      entryId: 101,
      poiId: 502,
      entryPoisVersion: '3',
    );

    expect(result.entryPoisVersion, '4');
    expect(result.poiId, 502);
  });

  test('fetchNotes：GET /trips/:id/notes 解析 5 區聚合', () async {
    dioAdapter.onGet(
      '/trips/okinawa-trip-2026-Ray/notes',
      (server) => server.reply(200, {
        'flights': [
          {
            'id': 1,
            'sortOrder': 0,
            'version': 1,
            'airline': '台灣虎航',
            'flightNo': 'IT232',
          },
        ],
        'lodgings': [],
        'reservations': [],
        'pretripNotes': [],
        'emergencyContacts': [],
      }),
    );

    final tripNotes = await tripRepository.fetchNotes('okinawa-trip-2026-Ray');

    expect(tripNotes.flights.single.flightNo, 'IT232');
    expect(tripNotes.lodgings, isEmpty);
  });

  test('deleteTrip：DELETE /trips/:id（204 視為成功）', () async {
    dioAdapter.onDelete('/trips/old-trip', (server) => server.reply(204, null));

    await expectLater(tripRepository.deleteTrip('old-trip'), completes);
  });

  test('fetchStats：GET /account/stats', () async {
    dioAdapter.onGet(
      '/account/stats',
      (server) => server.reply(200, {
        'tripCount': 2,
        'totalDays': 10,
        'collaboratorCount': 1,
      }),
    );

    final accountStats = await tripRepository.fetchStats();

    expect(accountStats.tripCount, 2);
    expect(accountStats.totalDays, 10);
  });

  test('updateProfile：PATCH /account/profile 回 UserInfo', () async {
    dioAdapter.onPatch(
      '/account/profile',
      (server) => server.reply(200, {
        'id': 'u1hex',
        'email': 'ray@example.com',
        'emailVerified': 1,
        'displayName': '新名字',
        'avatarUrl': null,
        'createdAt': '2026-01-01T00:00:00Z',
      }),
      data: {'displayName': '新名字'},
    );

    final updatedUser = await tripRepository.updateProfile(displayName: '新名字');

    expect(updatedUser.displayName, '新名字');
  });

  test('fetchPoiFavorites：GET /poi-favorites 解析收藏清單', () async {
    dioAdapter.onGet(
      '/poi-favorites',
      (server) => server.reply(200, [
        {
          'id': 77,
          'userId': 'user-1',
          'poiId': 501,
          'favoritedAt': '2026-07-08T10:00:00Z',
          'note': '黃昏時段去',
          'poiName': '首里城公園',
          'poiAddress': '沖繩縣那霸市',
          'poiLat': 26.217,
          'poiLng': 127.719,
          'poiType': 'attraction',
          'poiRating': 4.4,
          'usages': [
            {
              'tripId': 'okinawa-trip-2026',
              'tripName': 'Okinawa',
              'dayNum': 2,
              'dayDate': '2026-04-24',
              'entryId': 101,
            },
          ],
        },
      ]),
    );

    final favorites = await tripRepository.fetchPoiFavorites();

    expect(favorites, hasLength(1));
    expect(favorites.single.poiName, '首里城公園');
    expect(favorites.single.usages.single.dayNum, 2);
  });

  test('searchPois：GET /poi-search 解析 results wrapper 與 query', () async {
    dioAdapter.onGet(
      '/poi-search',
      (server) => server.reply(200, {
        'results': [
          {
            'place_id': 'ChIJ-shuri',
            'name': '首里城',
            'address': '沖繩縣那霸市首里金城町',
            'lat': 26.217,
            'lng': 127.719,
            'category': 'tourist_attraction',
            'country': 'JP',
            'country_name': '日本',
            'rating': 4.4,
            'business_status': 'OPERATIONAL',
          },
        ],
      }),
      queryParameters: {'q': '首里城', 'region': '沖繩', 'limit': '20'},
    );

    final results = await tripRepository.searchPois(query: '首里城', region: '沖繩');

    expect(results.single.placeId, 'ChIJ-shuri');
    expect(results.single.countryName, '日本');
    expect(results.single.rating, 4.4);
  });

  test('findOrCreatePoi：POST /pois/find-or-create 映射 type 後回 POI id', () async {
    const searchResult = PoiSearchResult(
      placeId: 'ChIJ-shuri',
      name: '首里城',
      address: '沖繩縣那霸市首里金城町',
      lat: 26.217,
      lng: 127.719,
      category: 'tourist_attraction',
      country: 'JP',
      rating: 4.4,
    );
    dioAdapter.onPost(
      '/pois/find-or-create',
      (server) => server.reply(200, {'id': 501}),
      data: {
        'name': '首里城',
        'type': 'attraction',
        'lat': 26.217,
        'lng': 127.719,
        'address': '沖繩縣那霸市首里金城町',
        'category': 'tourist_attraction',
        'source': 'user-explore',
        'country': 'JP',
        'place_id': 'ChIJ-shuri',
      },
    );

    final poiId = await tripRepository.findOrCreatePoi(searchResult);

    expect(poiId, 501);
  });

  test('createPoiFavorite：POST /poi-favorites 回新增收藏', () async {
    dioAdapter.onPost(
      '/poi-favorites',
      (server) => server.reply(201, {
        'id': 88,
        'userId': 'user-1',
        'poiId': 501,
        'favoritedAt': '2026-07-08T12:00:00Z',
        'note': '想排進下午',
      }),
      data: {'poiId': 501, 'note': '想排進下午'},
    );

    final favorite = await tripRepository.createPoiFavorite(
      poiId: 501,
      note: '想排進下午',
    );

    expect(favorite.id, 88);
    expect(favorite.note, '想排進下午');
  });

  test('deletePoiFavorite：DELETE /poi-favorites/:id（204 視為成功）', () async {
    dioAdapter.onDelete(
      '/poi-favorites/88',
      (server) => server.reply(204, null),
    );

    await expectLater(tripRepository.deletePoiFavorite(88), completes);
  });

  test('addPoiFavoriteToTrip：POST /poi-favorites/:id/add-to-trip', () async {
    dioAdapter.onPost(
      '/poi-favorites/88/add-to-trip',
      (server) => server.reply(201, {
        'ok': true,
        'entryId': 901,
        'dayId': 11,
        'sortOrder': 2,
        'startTime': '09:00',
        'endTime': '10:00',
        'note': 'trip_segments 將由背景 /recompute-travel 計算填入',
      }),
      data: {
        'tripId': 'okinawa-trip-2026',
        'dayNum': 2,
        'startTime': '09:00',
        'endTime': '10:00',
      },
    );

    final result = await tripRepository.addPoiFavoriteToTrip(
      88,
      tripId: 'okinawa-trip-2026',
      dayNum: 2,
      startTime: '09:00',
      endTime: '10:00',
    );

    expect(result.entryId, 901);
    expect(result.sortOrder, 2);
  });

  test('createEntryFromPoiSearchResult：direct-mode POST entries', () async {
    const searchResult = PoiSearchResult(
      placeId: 'ChIJ-shuri',
      name: '首里城',
      address: '沖繩縣那霸市首里金城町',
      lat: 26.217,
      lng: 127.719,
      category: 'tourist_attraction',
      country: 'JP',
    );
    dioAdapter.onPost(
      '/trips/okinawa-trip-2026/days/2/entries',
      (server) => server.reply(201, {
        'id': 901,
        'dayId': 11,
        'sortOrder': 2,
        'startTime': '09:00',
        'endTime': '10:00',
        'source': 'google',
      }),
      data: {
        'name': '首里城',
        'note': '沖繩縣那霸市首里金城町',
        'lat': 26.217,
        'lng': 127.719,
        'source': 'google',
        'time': '09:00-10:00',
        'poi_type': 'attraction',
      },
    );

    await expectLater(
      tripRepository.createEntryFromPoiSearchResult(
        tripId: 'okinawa-trip-2026',
        dayNum: 2,
        poi: searchResult,
        startTime: '09:00',
        endTime: '10:00',
      ),
      completes,
    );
  });

  test('recomputeTravel：POST /trips/:id/recompute-travel?day=N', () async {
    dioAdapter.onPost(
      '/trips/okinawa-trip-2026/recompute-travel',
      (server) => server.reply(202, {'ok': true}),
      queryParameters: {'day': '2'},
    );

    await expectLater(
      tripRepository.recomputeTravel('okinawa-trip-2026', dayNum: 2),
      completes,
    );
  });
}
