import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/cache/cache_keys.dart';
import 'package:tripline/api/cache/cache_store.dart';
import 'package:tripline/api/session_store.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/models/destination_input.dart';
import 'package:tripline/models/note_section.dart';
import 'package:tripline/models/oauth.dart';
import 'package:tripline/models/poi_search_result.dart';
import 'package:tripline/models/segment.dart';
import 'package:tripline/models/user.dart';

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

  test('fetchPublicTripShare：GET /share/:token 解析公開分享 payload', () async {
    dioAdapter.onGet(
      '/share/share-token',
      (server) => server.reply(200, {
        'meta': {
          'name': 'okinawa-trip',
          'title': '沖繩家族旅行',
          'sharedBy': 'Ray',
          'destinations': [
            {'name': '那霸'},
          ],
        },
        'days': const [],
        'notes': const {},
      }),
    );

    final share = await tripRepository.fetchPublicTripShare('share-token');

    expect(share.displayTitle, '沖繩家族旅行');
    expect(share.sharedBy, 'Ray');
    expect(share.destinationsLabel, '那霸');
  });

  test('clonePublicTripShare：POST /share/:token/clone 回傳新 tripId', () async {
    dioAdapter.onPost(
      '/share/share-token/clone',
      (server) => server.reply(200, {'tripId': 'cloned-trip'}),
      data: <String, dynamic>{},
    );

    final tripId = await tripRepository.clonePublicTripShare('share-token');

    expect(tripId, 'cloned-trip');
  });

  test('importTripJson：POST /trips/import raw JSON 回傳新 tripId', () async {
    const jsonText = '{"schemaVersion":1,"meta":{"name":"A"}}';
    dioAdapter.onPost(
      '/trips/import',
      (server) => server.reply(200, {'tripId': 'imported-trip'}),
      data: jsonText,
    );

    final tripId = await tripRepository.importTripJson(jsonText);

    expect(tripId, 'imported-trip');
  });

  test(
    'exportTripJson：輸出 schemaVersion 1 JSON 與 entry segment index',
    () async {
      dioAdapter.onGet(
        '/trips/okinawa-trip-2026-Ray',
        (server) => server.reply(200, {
          'id': 'okinawa-trip-2026-Ray',
          'name': 'Okinawa',
          'title': '沖繩',
        }),
      );
      dioAdapter.onGet(
        '/trips/okinawa-trip-2026-Ray/days',
        (server) => server.reply(200, [
          {
            'id': 1,
            'dayNum': 1,
            'timeline': [
              {'id': 11, 'title': 'A'},
              {'id': 12, 'title': 'B'},
            ],
          },
        ]),
        queryParameters: {'all': '1'},
      );
      dioAdapter.onGet(
        '/trips/okinawa-trip-2026-Ray/segments',
        (server) => server.reply(200, [
          {
            'fromEntryId': 11,
            'toEntryId': 12,
            'mode': 'drive',
            'min': 20,
            'distanceM': 1200,
            'source': 'manual',
          },
        ]),
      );
      dioAdapter.onGet(
        '/trips/okinawa-trip-2026-Ray/notes',
        (server) =>
            server.reply(200, {'flights': const [], 'lodgings': const []}),
      );

      final export = await tripRepository.exportTripJson(
        'okinawa-trip-2026-Ray',
        now: DateTime(2026, 7, 8),
      );
      final decoded = jsonDecode(export.content) as Map<String, dynamic>;
      final days = decoded['days'] as List<dynamic>;
      final timeline =
          (days.single as Map<String, dynamic>)['timeline'] as List;
      final segments = decoded['segments'] as List<dynamic>;

      expect(export.fileName, 'Okinawa-2026-07-08.json');
      expect(decoded['schemaVersion'], 1);
      expect((timeline.first as Map<String, dynamic>)['entryPosition'], 0);
      expect((timeline.last as Map<String, dynamic>)['entryPosition'], 1);
      expect((segments.single as Map<String, dynamic>)['fromEntryIdx'], 0);
      expect((segments.single as Map<String, dynamic>)['toEntryIdx'], 1);
    },
  );

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

  test('fetchAccountSessions：GET /account/sessions 解析登入裝置', () async {
    dioAdapter.onGet(
      '/account/sessions',
      (server) => server.reply(200, {
        'current_sid': 'sid-current',
        'sessions': [
          {
            'sid': 'sid-current',
            'ua_summary': 'Chrome on Windows',
            'ip_hash_prefix': 'a1b2c3',
            'created_at': '2026-07-01T10:00:00Z',
            'last_seen_at': '2026-07-08T09:30:00Z',
            'is_current': true,
          },
          {
            'sid': 'sid-phone',
            'ua_summary': 'Safari on iPhone',
            'created_at': '2026-07-02T10:00:00Z',
            'last_seen_at': '2026-07-08T08:00:00Z',
            'is_current': false,
          },
        ],
      }),
    );

    final page = await tripRepository.fetchAccountSessions();

    expect(page, isA<AccountSessionsPage>());
    expect(page.currentSid, 'sid-current');
    expect(page.sessions, hasLength(2));
    expect(page.sessions.first.sid, 'sid-current');
    expect(page.sessions.first.uaSummary, 'Chrome on Windows');
    expect(page.sessions.first.ipHashPrefix, 'a1b2c3');
    expect(page.sessions.first.isCurrent, isTrue);
    expect(page.sessions.last.isCurrent, isFalse);
  });

  test(
    'revokeOtherAccountSessions：DELETE /account/sessions 回 revoked 數量',
    () async {
      dioAdapter.onDelete(
        '/account/sessions',
        (server) => server.reply(200, {'ok': true, 'revoked': 2}),
      );

      final revoked = await tripRepository.revokeOtherAccountSessions();

      expect(revoked, 2);
    },
  );

  test('revokeAccountSession：DELETE /account/sessions/:sid', () async {
    dioAdapter.onDelete(
      '/account/sessions/sid-phone',
      (server) => server.reply(200, {'ok': true, 'revoked_sid': 'sid-phone'}),
    );

    await expectLater(
      tripRepository.revokeAccountSession('sid-phone'),
      completes,
    );
  });

  test(
    'fetchConnectedApps：GET /account/connected-apps 解析 apps wrapper',
    () async {
      dioAdapter.onGet(
        '/account/connected-apps',
        (server) => server.reply(200, {
          'apps': [
            {
              'client_id': 'tp_alpha',
              'app_name': 'Alpha App',
              'app_description': '同步工具',
              'homepage_url': 'https://alpha.example.com',
              'status': 'active',
              'scopes': ['openid', 'email'],
              'granted_at': 1783500000000,
            },
          ],
        }),
      );

      final apps = await tripRepository.fetchConnectedApps();

      expect(apps.single.clientId, 'tp_alpha');
      expect(apps.single.appName, 'Alpha App');
      expect(apps.single.scopes, ['openid', 'email']);
    },
  );

  test(
    'fetchAccountNotificationPreferences：GET /account/notifications',
    () async {
      dioAdapter.onGet(
        '/account/notifications',
        (server) => server.reply(200, {
          'preferences': {
            'tripUpdates': true,
            'invitations': false,
            'system': true,
            'updatedAt': '2026-07-09T00:00:00Z',
          },
        }),
      );

      final prefs = await tripRepository.fetchAccountNotificationPreferences();

      expect(prefs.tripUpdates, isTrue);
      expect(prefs.invitations, isFalse);
      expect(prefs.system, isTrue);
      expect(prefs.updatedAt, '2026-07-09T00:00:00Z');
    },
  );

  test(
    'updateAccountNotificationPreferences：PATCH /account/notifications',
    () async {
      dioAdapter.onPatch(
        '/account/notifications',
        (server) => server.reply(200, {
          'preferences': {
            'tripUpdates': true,
            'invitations': false,
            'system': false,
            'updatedAt': '2026-07-09T01:00:00Z',
          },
        }),
        data: {'invitations': false, 'system': false},
      );

      final prefs = await tripRepository.updateAccountNotificationPreferences(
        invitations: false,
        system: false,
      );

      expect(prefs.invitations, isFalse);
      expect(prefs.system, isFalse);
      expect(prefs.updatedAt, '2026-07-09T01:00:00Z');
    },
  );

  test('updateAccountNotificationPreferences：空 patch 不打 API', () async {
    await expectLater(
      tripRepository.updateAccountNotificationPreferences(),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('revokeConnectedApp：DELETE /account/connected-apps/:clientId', () async {
    dioAdapter.onDelete(
      '/account/connected-apps/tp_alpha',
      (server) =>
          server.reply(200, {'ok': true, 'revoked_client_id': 'tp_alpha'}),
    );

    await expectLater(tripRepository.revokeConnectedApp('tp_alpha'), completes);
  });

  test('fetchDeveloperApps：GET /dev/apps 解析 developer apps wrapper', () async {
    dioAdapter.onGet(
      '/dev/apps',
      (server) => server.reply(200, {
        'apps': [
          {
            'client_id': 'tp_dev',
            'client_type': 'public',
            'app_name': 'Dev App',
            'app_description': null,
            'homepage_url': 'https://dev.example.com',
            'redirect_uris': ['https://dev.example.com/callback'],
            'allowed_scopes': ['openid', 'profile'],
            'status': 'pending_review',
            'created_at': '2026-07-08T10:00:00Z',
            'updated_at': '2026-07-08T10:00:00Z',
          },
        ],
      }),
    );

    final apps = await tripRepository.fetchDeveloperApps();

    expect(apps.single, isA<DeveloperApp>());
    expect(apps.single.clientId, 'tp_dev');
    expect(apps.single.statusLabel, '待審核');
  });

  test('createDeveloperApp：POST /dev/apps 建立 OAuth app', () async {
    dioAdapter.onPost(
      '/dev/apps',
      (server) => server.reply(201, {
        'client_id': 'tp_new',
        'client_secret': null,
        'app_name': 'New App',
        'client_type': 'public',
        'status': 'pending_review',
        'redirect_uris': ['https://new.example.com/callback'],
        'allowed_scopes': ['openid', 'email'],
      }),
      data: {
        'app_name': 'New App',
        'client_type': 'public',
        'redirect_uris': ['https://new.example.com/callback'],
        'allowed_scopes': ['openid', 'email'],
        'app_description': null,
        'homepage_url': null,
      },
    );

    final created = await tripRepository.createDeveloperApp(
      appName: ' New App ',
      clientType: 'public',
      redirectUris: const ['https://new.example.com/callback'],
      allowedScopes: const ['openid', 'email'],
    );

    expect(created.clientId, 'tp_new');
    expect(created.clientSecret, isNull);
  });

  test(
    'addEntryToDay：POST /trips/:id/days/:num/entries snake_case body',
    () async {
      dioAdapter.onPost(
        '/trips/okinawa/days/1/entries',
        (server) => server.reply(201, {'id': 99}),
        data: {
          'title': '美麗海水族館',
          'description': '海景第一排',
          'poi_type': 'attraction',
          'lat': 26.69,
          'lng': 127.87,
          'start_time': '10:00',
          'end_time': '11:00',
          'source': 'user-explore',
        },
      );

      await expectLater(
        tripRepository.addEntryToDay(
          tripId: 'okinawa',
          dayNum: 1,
          title: '美麗海水族館',
          description: '海景第一排',
          poiType: 'attraction',
          lat: 26.69,
          lng: 127.87,
          startTime: '10:00',
          endTime: '11:00',
        ),
        completes,
      );
    },
  );

  test(
    'updateEntry：PATCH /trips/:id/entries/:eid snake_case + expectedVersion',
    () async {
      dioAdapter.onPatch(
        '/trips/okinawa/entries/11',
        (server) => server.reply(200, {'id': 11, 'version': 3, 'title': '新標題'}),
        data: {
          'title': '新標題',
          'description': '改描述',
          'start_time': '09:30',
          'end_time': '10:30',
          'expectedVersion': 2,
        },
      );

      await expectLater(
        tripRepository.updateEntry(
          tripId: 'okinawa',
          entryId: 11,
          expectedVersion: 2,
          title: '新標題',
          description: '改描述',
          startTime: '09:30',
          endTime: '10:30',
        ),
        completes,
      );
    },
  );

  test('updateEntry：409 STALE_ENTRY → 拋 ApiError(409)', () async {
    dioAdapter.onPatch(
      '/trips/okinawa/entries/11',
      (server) => server.reply(409, {
        'error': {
          'code': 'STALE_ENTRY',
          'message': 'expected version 2, current 3',
        },
      }),
      data: {
        'title': '標題',
        'description': null,
        'start_time': null,
        'end_time': null,
        'expectedVersion': 2,
      },
    );

    await expectLater(
      tripRepository.updateEntry(
        tripId: 'okinawa',
        entryId: 11,
        expectedVersion: 2,
        title: '標題',
      ),
      throwsA(
        isA<ApiError>()
            .having((e) => e.status, 'status', 409)
            .having((e) => e.code, 'code', 'STALE_ENTRY'),
      ),
    );
  });

  test('deleteEntry：DELETE /trips/:id/entries/:eid（200 {ok:true}）', () async {
    dioAdapter.onDelete(
      '/trips/okinawa/entries/11',
      (server) => server.reply(200, {'ok': true}),
    );

    await expectLater(
      tripRepository.deleteEntry(tripId: 'okinawa', entryId: 11),
      completes,
    );
  });

  test('reorderEntries：PATCH /entries/batch snake_case updates', () async {
    dioAdapter.onPatch(
      '/trips/okinawa/entries/batch',
      (server) => server.reply(200, {'ok': true, 'updated': 2}),
      data: {
        'updates': [
          {'id': 11, 'sort_order': 0},
          {'id': 12, 'sort_order': 1, 'day_id': 2},
        ],
      },
    );

    await expectLater(
      tripRepository.reorderEntries(
        tripId: 'okinawa',
        updates: [
          (id: 11, sortOrder: 0, dayId: null),
          (id: 12, sortOrder: 1, dayId: 2),
        ],
      ),
      completes,
    );
  });

  test('recomputeTravel：POST /recompute-travel?day=all', () async {
    dioAdapter.onPost(
      '/trips/okinawa/recompute-travel',
      (server) => server.reply(200, {'ok': true}),
      queryParameters: {'day': 'all'},
    );

    await expectLater(
      tripRepository.recomputeTravel(tripId: 'okinawa'),
      completes,
    );
  });

  test('fetchSegments：GET /segments 解析 TripSegment list', () async {
    dioAdapter.onGet(
      '/trips/okinawa/segments',
      (server) => server.reply(200, [
        {
          'id': 5,
          'fromEntryId': 11,
          'toEntryId': 12,
          'mode': 'transit',
          'min': 20,
          'version': 3,
        },
      ]),
    );

    final segs = await tripRepository.fetchSegments(tripId: 'okinawa');
    expect(segs.single.id, 5);
    expect(segs.single.version, 3);
    expect(segs.single, isA<TripSegment>());
  });

  test('updateSegment：PATCH /segments/:sid 回 TripSegment', () async {
    dioAdapter.onPatch(
      '/trips/okinawa/segments/5',
      (server) => server.reply(200, {'id': 5, 'mode': 'transit', 'version': 4}),
      data: {'mode': 'transit', 'min': 20, 'expectedVersion': 1},
    );

    final seg = await tripRepository.updateSegment(
      tripId: 'okinawa',
      segmentId: 5,
      mode: 'transit',
      min: 20,
      expectedVersion: 1,
    );
    expect(seg.version, 4);
  });

  test('updateSegment：409 → 拋 ApiError(409)', () async {
    dioAdapter.onPatch(
      '/trips/okinawa/segments/5',
      (server) => server.reply(409, {
        'error': {'code': 'STALE_ENTRY', 'message': 'stale'},
      }),
      data: {'mode': 'driving', 'expectedVersion': 1},
    );

    await expectLater(
      tripRepository.updateSegment(
        tripId: 'okinawa',
        segmentId: 5,
        mode: 'driving',
        expectedVersion: 1,
      ),
      throwsA(isA<ApiError>().having((e) => e.status, 'status', 409)),
    );
  });

  test(
    'fetchEntry：GET /entries/:eid 解析 master/alternates/entryPoisVersion',
    () async {
      dioAdapter.onGet(
        '/trips/okinawa/entries/11',
        (server) => server.reply(200, {
          'id': 11,
          'sortOrder': 0,
          'title': '首里城',
          'version': 2,
          'entryPoisVersion': '4',
          'master': {'poiId': 501, 'name': '首里城公園'},
          'alternates': [
            {'poiId': 502, 'name': '玉陵', 'sortOrder': 2},
          ],
        }),
      );

      final entry = await tripRepository.fetchEntry(
        tripId: 'okinawa',
        entryId: 11,
      );
      expect(entry.master?.poiId, 501);
      expect(entry.entryPoisVersion, '4');
      expect(entry.alternates.single.poiId, 502);
    },
  );

  test(
    'setEntryMaster：PATCH /entries/:eid/master camelCase + entryPoisVersion',
    () async {
      dioAdapter.onPatch(
        '/trips/okinawa/entries/11/master',
        (server) => server.reply(200, {'entryId': 11, 'masterPoiId': 502}),
        data: {'poiId': 502, 'entryPoisVersion': '4'},
      );

      await expectLater(
        tripRepository.setEntryMaster(
          tripId: 'okinawa',
          entryId: 11,
          poiId: 502,
          entryPoisVersion: '4',
        ),
        completes,
      );
    },
  );

  test('addEntryAlternate：POST /alternates find-or-create（type 映射）', () async {
    dioAdapter.onPost(
      '/trips/okinawa/entries/11/alternates',
      (server) => server.reply(201, {'entryId': 11, 'poiId': 999}),
      data: {
        'name': '通堂拉麵',
        'lat': 26.2,
        'lng': 127.6,
        'type': 'restaurant',
        'category': 'ramen_restaurant',
        'address': '那霸市',
        'rating': 4.1,
        'source': 'search',
        'entryPoisVersion': '4',
      },
    );

    await expectLater(
      tripRepository.addEntryAlternate(
        tripId: 'okinawa',
        entryId: 11,
        poi: const PoiSearchResult(
          placeId: 'p1',
          name: '通堂拉麵',
          address: '那霸市',
          category: 'ramen_restaurant',
          lat: 26.2,
          lng: 127.6,
          rating: 4.1,
        ),
        entryPoisVersion: '4',
      ),
      completes,
    );
  });

  test(
    'removeEntryAlternate：DELETE /alternates/:poiId?entryPoisVersion',
    () async {
      dioAdapter.onDelete(
        '/trips/okinawa/entries/11/alternates/502',
        (server) => server.reply(200, {'entryId': 11, 'poiId': 502}),
        queryParameters: {'entryPoisVersion': '4'},
      );

      await expectLater(
        tripRepository.removeEntryAlternate(
          tripId: 'okinawa',
          entryId: 11,
          poiId: 502,
          entryPoisVersion: '4',
        ),
        completes,
      );
    },
  );

  test(
    'reorderEntryAlternates：PATCH /alternates/reorder order=poiId[]',
    () async {
      dioAdapter.onPatch(
        '/trips/okinawa/entries/11/alternates/reorder',
        (server) => server.reply(200, {
          'entryId': 11,
          'order': [503, 502],
        }),
        data: {
          'order': [503, 502],
          'entryPoisVersion': '4',
        },
      );

      await expectLater(
        tripRepository.reorderEntryAlternates(
          tripId: 'okinawa',
          entryId: 11,
          order: [503, 502],
          entryPoisVersion: '4',
        ),
        completes,
      );
    },
  );

  test('updateEntryPoi：PATCH /pois/:poiId 只送有值欄位（無 OCC）', () async {
    dioAdapter.onPatch(
      '/trips/okinawa/entries/11/pois/501',
      (server) => server.reply(200, {'entryId': 11, 'poiId': 501}),
      data: {'note': '記得訂位', 'poi_type': 'restaurant'},
    );

    await expectLater(
      tripRepository.updateEntryPoi(
        tripId: 'okinawa',
        entryId: 11,
        poiId: 501,
        note: '記得訂位',
        poiType: 'restaurant',
      ),
      completes,
    );
  });

  test('createNote：POST /notes/{section} snake_case body', () async {
    dioAdapter.onPost(
      '/trips/okinawa/notes/flights',
      (server) => server.reply(201, {'id': 1, 'version': 0}),
      data: {'airline': 'IT', 'flight_no': 'IT232'},
    );
    await expectLater(
      tripRepository.createNote(
        NoteSection.flights,
        tripId: 'okinawa',
        fields: {'airline': 'IT', 'flight_no': 'IT232'},
      ),
      completes,
    );
  });

  test('updateNote：PATCH /notes/{section}/:id + expectedVersion', () async {
    dioAdapter.onPatch(
      '/trips/okinawa/notes/reservations/5',
      (server) => server.reply(200, {'id': 5, 'version': 3}),
      data: {'title': '晚餐', 'expectedVersion': 2},
    );
    await expectLater(
      tripRepository.updateNote(
        NoteSection.reservations,
        tripId: 'okinawa',
        rowId: 5,
        fields: {'title': '晚餐'},
        expectedVersion: 2,
      ),
      completes,
    );
  });

  test('updateNote：409 STALE_ENTRY → ApiError(409)', () async {
    dioAdapter.onPatch(
      '/trips/okinawa/notes/reservations/5',
      (server) => server.reply(409, {
        'error': {'code': 'STALE_ENTRY', 'message': 'stale'},
      }),
      data: {'title': '晚餐', 'expectedVersion': 2},
    );
    await expectLater(
      tripRepository.updateNote(
        NoteSection.reservations,
        tripId: 'okinawa',
        rowId: 5,
        fields: {'title': '晚餐'},
        expectedVersion: 2,
      ),
      throwsA(
        isA<ApiError>()
            .having((e) => e.status, 'status', 409)
            .having((e) => e.code, 'code', 'STALE_ENTRY'),
      ),
    );
  });

  test('deleteNote：DELETE /notes/{section}/:id（200 {ok:true}）', () async {
    dioAdapter.onDelete(
      '/trips/okinawa/notes/emergency/7',
      (server) => server.reply(200, {'ok': true}),
    );
    await expectLater(
      tripRepository.deleteNote(
        NoteSection.emergency,
        tripId: 'okinawa',
        rowId: 7,
      ),
      completes,
    );
  });

  test('reorderNotes：PATCH /notes/{section}/reorder items camelCase', () async {
    dioAdapter.onPatch(
      '/trips/okinawa/notes/flights/reorder',
      (server) => server.reply(200, {'ok': true, 'updated': 2}),
      data: {
        'items': [
          {'id': 11, 'sortOrder': 0},
          {'id': 12, 'sortOrder': 1},
        ],
      },
    );
    await expectLater(
      tripRepository.reorderNotes(
        NoteSection.flights,
        tripId: 'okinawa',
        items: [(id: 11, sortOrder: 0), (id: 12, sortOrder: 1)],
      ),
      completes,
    );
  });

  test('createTrip：POST /trips 衍生欄位 + snake_case destinations', () async {
    dioAdapter.onPost(
      '/trips',
      (server) => server.reply(201, {
        'ok': true,
        'tripId': 'tokyo-abcd',
        'daysCreated': 5,
        'destinationsCreated': 1,
      }),
      data: {
        'id': 'tokyo-abcd',
        'name': '東京',
        'startDate': '2026-07-01',
        'endDate': '2026-07-05',
        'countries': 'JP',
        'published': 1,
        'data_source': 'manual',
        'lang': 'zh-TW',
        'destinations': [
          {'name': '東京', 'lat': 35.68, 'lng': 139.76},
        ],
      },
    );

    final r = await tripRepository.createTrip(
      id: 'tokyo-abcd',
      name: '東京',
      startDate: '2026-07-01',
      endDate: '2026-07-05',
      destinations: const [
        DestinationInput(name: '東京', lat: 35.68, lng: 139.76, country: 'JP'),
      ],
    );
    expect(r.tripId, 'tokyo-abcd');
    expect(r.daysCreated, 5);
    expect(r.destinationsCreated, 1);
  });

  test('updateTrip：diff-only PUT（只送 title,無 expectedVersion）', () async {
    dioAdapter.onPut(
      '/trips/tokyo',
      (server) => server.reply(200, {'ok': true}),
      data: {'title': '新標題'},
    );
    await expectLater(
      tripRepository.updateTrip('tokyo', title: '新標題'),
      completes,
    );
  });

  test('updateTrip：destinations 全量替換 + countries', () async {
    dioAdapter.onPut(
      '/trips/tokyo',
      (server) => server.reply(200, {'ok': true}),
      data: {
        'countries': 'JP,KR',
        'destinations': [
          {'name': 'A'},
          {'name': 'B'},
        ],
      },
    );
    await expectLater(
      tripRepository.updateTrip(
        'tokyo',
        countries: 'JP,KR',
        destinations: const [
          DestinationInput(name: 'A'),
          DestinationInput(name: 'B'),
        ],
      ),
      completes,
    );
  });

  // watchX(SWR stream)— 上線讀取實際走這些;直接測解析路徑(尤其 watchEntry/watchSegments)。
  group('watchX SWR streams', () {
    test('watchMyTrips:無快取 → 單一 emission 解析 TripSummary list', () async {
      dioAdapter.onGet(
        '/my-trips',
        (server) => server.reply(200, [
          {'tripId': 't1', 'name': 'N', 'totalDays': 3},
        ]),
      );
      final emissions = await tripRepository.watchMyTrips().toList();
      expect(emissions, hasLength(1));
      expect(emissions.single.single.tripId, 't1');
    });

    test('watchTrip:無快取 → 解析 Trip', () async {
      dioAdapter.onGet(
        '/trips/okinawa',
        (server) => server.reply(200, {'id': 'okinawa', 'name': 'Okinawa'}),
      );
      final trip = await tripRepository.watchTrip('okinawa').first;
      expect(trip.id, 'okinawa');
    });

    test('watchDays:無快取 → 解析巢狀 timeline', () async {
      dioAdapter.onGet(
        '/trips/okinawa/days',
        (server) => server.reply(200, [
          {
            'id': 11,
            'dayNum': 1,
            'title': '抵達那霸',
            'timeline': [
              {'id': 101, 'sortOrder': 0, 'title': '首里城', 'alternates': []},
            ],
          },
        ]),
        queryParameters: {'all': '1'},
      );
      final days = await tripRepository.watchDays('okinawa').first;
      expect(days.single.timeline.single.title, '首里城');
    });

    test('watchNotes:無快取 → 解析 5 區', () async {
      dioAdapter.onGet(
        '/trips/okinawa/notes',
        (server) => server.reply(200, {
          'flights': [
            {'id': 1, 'sortOrder': 0, 'version': 1, 'flightNo': 'IT232'},
          ],
          'lodgings': [],
          'reservations': [],
          'pretripNotes': [],
          'emergencyContacts': [],
        }),
      );
      final notes = await tripRepository.watchNotes('okinawa').first;
      expect(notes.flights.single.flightNo, 'IT232');
    });

    test('watchSegments:無快取 → 解析 TripSegment list', () async {
      dioAdapter.onGet(
        '/trips/okinawa/segments',
        (server) => server.reply(200, [
          {'id': 5, 'mode': 'transit', 'min': 20, 'version': 3},
        ]),
      );
      final segs = await tripRepository.watchSegments(tripId: 'okinawa').first;
      expect(segs.single.id, 5);
      expect(segs.single.version, 3);
    });

    test('watchEntry:無快取 → 解析 master/alternates/entryPoisVersion', () async {
      dioAdapter.onGet(
        '/trips/okinawa/entries/11',
        (server) => server.reply(200, {
          'id': 11,
          'sortOrder': 0,
          'title': '首里城',
          'version': 2,
          'entryPoisVersion': '4',
          'master': {'poiId': 501, 'name': '首里城公園'},
          'alternates': [
            {'poiId': 502, 'name': '玉陵', 'sortOrder': 2},
          ],
        }),
      );
      final entry = await tripRepository
          .watchEntry(tripId: 'okinawa', entryId: 11)
          .first;
      expect(entry.master?.poiId, 501);
      expect(entry.entryPoisVersion, '4');
      expect(entry.alternates.single.poiId, 502);
    });

    test('watchDays:有快取 → 先 stale 後 fresh(SWR 兩次 emission)', () async {
      final cache = InMemoryCacheStore();
      final swrDio = Dio();
      final swrAdapter = DioAdapter(dio: swrDio);
      final swrRepo = TripRepository(
        client: ApiClient(
          sessionStore: InMemorySessionStore(),
          dio: swrDio,
          cacheStore: cache,
        ),
      );
      await cache.writeResponse(
        cacheKeyFor('GET', '/trips/okinawa/days', {'all': '1'}),
        [
          {'id': 11, 'dayNum': 1, 'title': 'stale', 'timeline': []},
        ],
      );
      swrAdapter.onGet(
        '/trips/okinawa/days',
        (server) => server.reply(200, [
          {'id': 11, 'dayNum': 1, 'title': 'fresh', 'timeline': []},
        ]),
        queryParameters: {'all': '1'},
      );
      final emissions = await swrRepo.watchDays('okinawa').toList();
      expect(emissions, hasLength(2));
      expect(emissions.first.single.displayTitle, 'stale');
      expect(emissions.last.single.displayTitle, 'fresh');
    });
  });

  // entry 離線寫:證明 repo 建出正確 OfflineOp(type + daysKey),防 cache key mismatch。
  group('離線 entry 寫入(樂觀入佇列 + patch days 快取)', () {
    late InMemoryCacheStore cache;
    late TripRepository repo;
    setUp(() {
      cache = InMemoryCacheStore();
      repo = TripRepository(
        client: ApiClient(
          sessionStore: InMemorySessionStore(),
          dio: dio,
          cacheStore: cache,
        ),
      );
    });
    final daysKey = cacheKeyFor('GET', '/trips/okinawa/days', {'all': '1'});

    test('addEntryToDay 離線 → 入佇列(entry.add)+ days 快取末端插入', () async {
      await cache.writeResponse(daysKey, [
        {'dayNum': 1, 'timeline': <dynamic>[]},
      ]);
      dioAdapter.onPost(
        '/trips/okinawa/days/1/entries',
        (server) => server.throws(
          503,
          DioException(
            requestOptions: RequestOptions(
              path: '/trips/okinawa/days/1/entries',
            ),
            type: DioExceptionType.connectionError,
          ),
        ),
        data: Matchers.any,
      );

      await repo.addEntryToDay(tripId: 'okinawa', dayNum: 1, title: '新景點');

      final q = await cache.readQueue();
      expect(q.single.type, 'entry.add');
      expect(q.single.cacheKey, daysKey);
      final days = (await cache.readResponse(daysKey))!.data as List;
      final timeline = (days.first as Map)['timeline'] as List;
      expect(timeline, hasLength(1));
      expect((timeline.first as Map)['title'], '新景點');
    });

    test('deleteEntry 離線 → 入佇列(entry.delete)+ days 快取移除', () async {
      await cache.writeResponse(daysKey, [
        {
          'dayNum': 1,
          'timeline': [
            {'id': 77, 'title': '要刪的'},
          ],
        },
      ]);
      dioAdapter.onDelete(
        '/trips/okinawa/entries/77',
        (server) => server.throws(
          503,
          DioException(
            requestOptions: RequestOptions(path: '/trips/okinawa/entries/77'),
            type: DioExceptionType.connectionError,
          ),
        ),
      );

      await repo.deleteEntry(tripId: 'okinawa', entryId: 77);

      final q = await cache.readQueue();
      expect(q.single.type, 'entry.delete');
      final days = (await cache.readResponse(daysKey))!.data as List;
      expect((days.first as Map)['timeline'] as List, isEmpty);
    });

    test('createNote(pretrip)離線 → 入佇列 + patch 對到 pretripNotes 段', () async {
      final notesKey = cacheKeyFor('GET', '/trips/okinawa/notes');
      await cache.writeResponse(notesKey, {
        'flights': <dynamic>[],
        'pretripNotes': <dynamic>[],
      });
      dioAdapter.onPost(
        '/trips/okinawa/notes/pretrip',
        (server) => server.throws(
          503,
          DioException(
            requestOptions: RequestOptions(
              path: '/trips/okinawa/notes/pretrip',
            ),
            type: DioExceptionType.connectionError,
          ),
        ),
        data: Matchers.any,
      );

      await repo.createNote(
        NoteSection.pretrip,
        tripId: 'okinawa',
        fields: {'content': '記得帶護照'},
      );

      final q = await cache.readQueue();
      expect(q.single.type, 'note.create');
      final notes = (await cache.readResponse(notesKey))!.data as Map;
      // section 段名 gotcha:pretrip → pretripNotes(非 'pretrip')
      expect(notes['pretripNotes'] as List, hasLength(1));
    });
  });

  // T7:入佇列時擷取 base(rebase 三方比對的「離線當下值」)。
  group('離線 updateEntry/updateNote → 佇列項帶 base', () {
    late InMemoryCacheStore cache;
    late TripRepository repo;
    final daysKey = cacheKeyFor('GET', '/trips/okinawa/days', {'all': '1'});
    final notesKey = cacheKeyFor('GET', '/trips/okinawa/notes');

    setUp(() {
      cache = InMemoryCacheStore();
      repo = TripRepository(
        client: ApiClient(
          sessionStore: InMemorySessionStore(),
          dio: dio,
          cacheStore: cache,
        ),
      );
    });

    test('離線 updateEntry → 佇列項帶 base(快取當下值)', () async {
      // 預先寫入含 entry id=7 的 days 快取
      await cache.writeResponse(daysKey, [
        {
          'dayNum': 1,
          'timeline': [
            {
              'id': 7,
              'title': '舊標題',
              'description': '舊描述',
              'startTime': '09:00',
              'endTime': '10:00',
              'version': 3,
            },
          ],
        },
      ]);
      dioAdapter.onPatch(
        '/trips/okinawa/entries/7',
        (server) => server.throws(
          503,
          DioException(
            requestOptions: RequestOptions(path: '/trips/okinawa/entries/7'),
            type: DioExceptionType.connectionError,
          ),
        ),
        data: Matchers.any,
      );

      await repo.updateEntry(
        tripId: 'okinawa',
        entryId: 7,
        expectedVersion: 3,
        title: '新標題',
        description: '新描述',
        startTime: '10:00',
        endTime: '11:00',
      );

      final q = await cache.readQueue();
      expect(q.single.type, 'entry.update');
      final base = q.single.base;
      expect(base, isNotNull);
      // base 應含快取中 entry 的原始值(camelCase)+ version
      expect(base!['title'], '舊標題');
      expect(base['description'], '舊描述');
      expect(base['startTime'], '09:00');
      expect(base['endTime'], '10:00');
      expect(base['version'], 3);
    });

    test('離線 updateNote → 佇列項帶 base(快取當下值)', () async {
      // 預先寫入含 reservations row id=5 的 notes 快取
      await cache.writeResponse(notesKey, {
        'reservations': [
          {'id': 5, 'title': '舊餐廳', 'date': '2026-05-01', 'version': 2},
        ],
        'flights': <dynamic>[],
      });
      dioAdapter.onPatch(
        '/trips/okinawa/notes/reservations/5',
        (server) => server.throws(
          503,
          DioException(
            requestOptions: RequestOptions(
              path: '/trips/okinawa/notes/reservations/5',
            ),
            type: DioExceptionType.connectionError,
          ),
        ),
        data: Matchers.any,
      );

      await repo.updateNote(
        NoteSection.reservations,
        tripId: 'okinawa',
        rowId: 5,
        fields: {'title': '新餐廳'},
        expectedVersion: 2,
      );

      final q = await cache.readQueue();
      expect(q.single.type, 'note.update');
      final base = q.single.base;
      expect(base, isNotNull);
      // base 應含 note row 對應 camelCase 欄位 + version
      expect(base!['title'], '舊餐廳');
      expect(base['version'], 2);
    });
  });
}
