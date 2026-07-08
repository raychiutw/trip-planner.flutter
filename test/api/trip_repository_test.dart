import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/session_store.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/models/health.dart';
import 'package:tripline/models/notes.dart';
import 'package:tripline/models/poi.dart';
import 'package:tripline/models/trip.dart';

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
          'owner': 'ray@example.com',
          'ownerDisplayName': 'Ray',
          'ownerUserId': 'user-ray',
          'role': 'owner',
          'countries': 'JP',
          'startDate': '2026-10-01',
          'endDate': '2026-10-05',
          'updatedAt': '2026-07-08T10:00:00Z',
          'totalDays': 5,
          'memberCount': 2,
        },
      ]),
    );

    final myTrips = await tripRepository.fetchMyTrips();

    expect(myTrips, hasLength(1));
    expect(myTrips.single.tripId, 'okinawa-trip-2026-Ray');
    expect(myTrips.single.totalDays, 5);
    expect(myTrips.single.role, 'owner');
    expect(myTrips.single.startDate, '2026-10-01');
    expect(myTrips.single.memberCount, 2);
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

  test('fetchTripHealthReport：GET /health-check 解析 wrapper report', () async {
    dioAdapter.onGet(
      '/trips/okinawa-trip-2026-Ray/health-check',
      (server) => server.reply(200, {
        'report': {
          'tripId': 'okinawa-trip-2026-Ray',
          'userId': 'user-1',
          'status': 'completed',
          'requestId': 88,
          'findings': [
            {
              'severity': 'medium',
              'dimension': 'meals',
              'title': '晚餐間隔過長',
              'description': 'Day 2 晚餐安排偏晚。',
              'suggestion': '補一個下午茶。',
              'actionTarget': {'day': 2},
            },
          ],
          'createdAt': '2026-07-08T10:00:00Z',
          'completedAt': '2026-07-08T10:05:00Z',
        },
      }),
    );

    final report = await tripRepository.fetchTripHealthReport(
      'okinawa-trip-2026-Ray',
    );

    expect(report, isA<TripHealthReport>());
    expect(report!.isCompleted, isTrue);
    expect(report.findings.single.dimensionLabel, '餐飲');
  });

  test('fetchTripHealthReport：GET /health-check report null', () async {
    dioAdapter.onGet(
      '/trips/okinawa-trip-2026-Ray/health-check',
      (server) => server.reply(200, {'report': null}),
    );

    final report = await tripRepository.fetchTripHealthReport(
      'okinawa-trip-2026-Ray',
    );

    expect(report, isNull);
  });

  test('startTripHealthCheck：POST /health-check 回 pending report', () async {
    dioAdapter.onPost(
      '/trips/okinawa-trip-2026-Ray/health-check',
      (server) => server.reply(202, {
        'report': {
          'tripId': 'okinawa-trip-2026-Ray',
          'userId': 'user-1',
          'status': 'pending',
          'requestId': 99,
          'findings': [],
          'createdAt': '2026-07-08T10:00:00Z',
        },
      }),
      data: <String, dynamic>{},
    );

    final report = await tripRepository.startTripHealthCheck(
      'okinawa-trip-2026-Ray',
    );

    expect(report.isPending, isTrue);
    expect(report.requestId, 99);
  });

  test('fetchTripRequests：GET /requests 帶 tripId、limit、sort', () async {
    dioAdapter.onGet(
      '/requests',
      (server) => server.reply(200, {
        'items': [
          {
            'id': 42,
            'tripId': 'okinawa-trip-2026',
            'message': '幫我安排晚餐',
            'reply': '已補上晚餐建議。',
            'status': 'completed',
          },
        ],
        'hasMore': false,
      }),
      queryParameters: {
        'tripId': 'okinawa-trip-2026',
        'limit': '5',
        'sort': 'desc',
      },
    );

    final page = await tripRepository.fetchTripRequests(
      tripId: 'okinawa-trip-2026',
      limit: 5,
      sort: 'desc',
    );

    expect(page.items.single.id, 42);
    expect(page.items.single.displayReply, '已補上晚餐建議。');
    expect(page.hasMore, isFalse);
  });

  test('createTripRequest：POST /requests 建立 AI request', () async {
    dioAdapter.onPost(
      '/requests',
      (server) => server.reply(201, {
        'id': 43,
        'tripId': 'okinawa-trip-2026',
        'message': '幫我調整第二天',
        'status': 'open',
      }),
      data: {'tripId': 'okinawa-trip-2026', 'message': '幫我調整第二天'},
    );

    final request = await tripRepository.createTripRequest(
      tripId: 'okinawa-trip-2026',
      message: '幫我調整第二天',
    );

    expect(request.id, 43);
    expect(request.isInflight, isTrue);
  });

  test('fetchTripRequest：GET /requests/:id 取得 request 最新狀態', () async {
    dioAdapter.onGet(
      '/requests/43',
      (server) => server.reply(200, {
        'id': 43,
        'tripId': 'okinawa-trip-2026',
        'message': '幫我調整第二天',
        'reply': '已完成調整。',
        'status': 'completed',
      }),
    );

    final request = await tripRepository.fetchTripRequest(43);

    expect(request.isCompleted, isTrue);
    expect(request.displayReply, '已完成調整。');
  });

  test('fetchTripPermissions：GET /permissions?tripId 解析成員', () async {
    dioAdapter.onGet(
      '/permissions',
      (server) => server.reply(200, [
        {
          'id': 1,
          'email': 'owner@example.com',
          'displayName': 'Owner',
          'tripId': 'okinawa-trip-2026',
          'role': 'owner',
        },
      ]),
      queryParameters: {'tripId': 'okinawa-trip-2026'},
    );

    final permissions = await tripRepository.fetchTripPermissions(
      'okinawa-trip-2026',
    );

    expect(permissions.single.isOwner, isTrue);
    expect(permissions.single.roleLabel, '擁有者');
  });

  test('fetchPendingInvitations：GET /invitations?tripId 解析 wrapper', () async {
    dioAdapter.onGet(
      '/invitations',
      (server) => server.reply(200, {
        'items': [
          {
            'id': 'hash-1',
            'invitedEmail': 'pending@example.com',
            'createdAt': '2026-07-01T00:00:00Z',
            'expiresAt': '2026-07-08T00:00:00Z',
            'daysRemaining': 2,
            'isExpired': false,
          },
        ],
      }),
      queryParameters: {'tripId': 'okinawa-trip-2026'},
    );

    final page = await tripRepository.fetchPendingInvitations(
      'okinawa-trip-2026',
    );

    expect(page.items.single.invitedEmail, 'pending@example.com');
    expect(page.items.single.isExpired, isFalse);
  });

  test('createTripPermissionInvite：POST /permissions 新增邀請', () async {
    dioAdapter.onPost(
      '/permissions',
      (server) => server.reply(201, {
        'ok': true,
        'status': 'invitation_sent',
        'email': 'friend@example.com',
        'expiresAt': '2026-07-15T00:00:00Z',
      }),
      data: {
        'tripId': 'okinawa-trip-2026',
        'email': 'friend@example.com',
        'role': 'viewer',
      },
    );

    final result = await tripRepository.createTripPermissionInvite(
      tripId: 'okinawa-trip-2026',
      email: 'friend@example.com',
      role: 'viewer',
    );

    expect(result.status, 'invitation_sent');
    expect(result.email, 'friend@example.com');
  });

  test('revokeTripInvitation：POST /invitations/revoke', () async {
    dioAdapter.onPost(
      '/invitations/revoke',
      (server) => server.reply(200, {'ok': true, 'revoked': 1}),
      data: {'tripId': 'okinawa-trip-2026', 'email': 'pending@example.com'},
    );

    await tripRepository.revokeTripInvitation(
      tripId: 'okinawa-trip-2026',
      email: 'pending@example.com',
    );
  });

  test('updateTripPermissionRole：PATCH /permissions/:id 更新角色', () async {
    dioAdapter.onPatch(
      '/permissions/2',
      (server) => server.reply(200, {'ok': true, 'role': 'viewer'}),
      data: {'role': 'viewer'},
    );

    final result = await tripRepository.updateTripPermissionRole(
      permissionId: 2,
      role: 'viewer',
    );

    expect(result.role, 'viewer');
    expect(result.unchanged, isFalse);
  });

  test('deleteTripPermission：DELETE /permissions/:id 移除既有成員', () async {
    dioAdapter.onDelete(
      '/permissions/2',
      (server) => server.reply(200, {'ok': true}),
    );

    await tripRepository.deleteTripPermission(2);
  });

  test('fetchInvitation：GET /invitations?token 解析公開邀請預覽', () async {
    dioAdapter.onGet(
      '/invitations',
      (server) => server.reply(200, {
        'tripId': 'okinawa-trip-2026',
        'tripTitle': '沖繩家族旅行',
        'invitedEmail': 'friend@example.com',
        'inviterDisplayName': 'Ray',
        'inviterEmail': 'ray@example.com',
        'expiresAt': '2026-07-15T00:00:00Z',
      }),
      queryParameters: {'token': 'invite-token'},
    );

    final preview = await tripRepository.fetchInvitation('invite-token');

    expect(preview.tripTitle, '沖繩家族旅行');
    expect(preview.inviterLabel, 'Ray');
  });

  test('acceptInvitation：POST /invitations/accept', () async {
    dioAdapter.onPost(
      '/invitations/accept',
      (server) => server.reply(200, {
        'ok': true,
        'tripId': 'okinawa-trip-2026',
        'tripTitle': '沖繩家族旅行',
      }),
      data: {'token': 'invite-token'},
    );

    final result = await tripRepository.acceptInvitation('invite-token');

    expect(result.ok, isTrue);
    expect(result.tripId, 'okinawa-trip-2026');
  });

  test('createTrip：POST /trips 帶基本資料與目的地', () async {
    dioAdapter.onPost(
      '/trips',
      (server) => server.reply(201, {
        'ok': true,
        'tripId': 'okinawa-trip-2026',
        'daysCreated': 3,
      }),
      data: {
        'id': 'okinawa-trip-2026',
        'name': '沖繩',
        'startDate': '2026-10-01',
        'endDate': '2026-10-03',
        'title': '沖繩家族旅行',
        'description': '想放慢步調',
        'countries': 'JP',
        'published': 1,
        'lang': 'zh-TW',
        'data_source': 'manual',
        'destinations': [
          {'name': '那霸', 'lat': 26.2145, 'lng': 127.6812, 'day_quota': 3},
        ],
      },
    );

    final tripId = await tripRepository.createTrip(
      id: 'okinawa-trip-2026',
      name: '沖繩',
      title: '沖繩家族旅行',
      description: '想放慢步調',
      startDate: '2026-10-01',
      endDate: '2026-10-03',
      countries: 'JP',
      published: true,
      lang: 'zh-TW',
      destinations: const [
        TripDestinationInput(
          name: '那霸',
          lat: 26.2145,
          lng: 127.6812,
          dayQuota: 3,
        ),
      ],
    );

    expect(tripId, 'okinawa-trip-2026');
  });

  test('importTripJson：POST /trips/import 送 raw JSON text 並回 tripId', () async {
    const exportedJson = '{"schemaVersion":1,"trip":{"name":"imported"}}';
    dioAdapter.onPost(
      '/trips/import',
      (server) => server.reply(201, {
        'ok': true,
        'tripId': 'imp-okinawa-trip-2026',
        'daysCreated': 3,
      }),
      data: exportedJson,
    );

    final tripId = await tripRepository.importTripJson(exportedJson);

    expect(tripId, 'imp-okinawa-trip-2026');
  });

  test(
    'updateTrip：PUT /trips/:id 帶 scalar 欄位與 destinations full replacement',
    () async {
      dioAdapter.onPut(
        '/trips/okinawa-trip-2026',
        (server) => server.reply(200, {'ok': true}),
        data: {
          'title': '沖繩慢旅行',
          'description': null,
          'published': 0,
          'lang': 'ja',
          'destinations': [
            {'name': '那霸', 'lat': 26.2145, 'lng': 127.6812, 'day_quota': null},
            {'name': '名護', 'lat': null, 'lng': null, 'day_quota': 1},
          ],
        },
      );

      await expectLater(
        tripRepository.updateTrip(
          id: 'okinawa-trip-2026',
          title: '沖繩慢旅行',
          description: null,
          published: false,
          lang: 'ja',
          destinations: const [
            TripDestinationInput(name: '那霸', lat: 26.2145, lng: 127.6812),
            TripDestinationInput(name: '名護', dayQuota: 1),
          ],
        ),
        completes,
      );
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

  test('createTripDay：POST /trips/:id/days 可從結尾新增一天', () async {
    dioAdapter.onPost(
      '/trips/okinawa-trip-2026-Ray/days',
      (server) => server.reply(201, {
        'day': {
          'id': 14,
          'day_num': 4,
          'date': '2026-10-04',
          'day_of_week': '日',
          'label': 'Day 4',
          'title': 'Day 4',
        },
      }),
      data: {'position': 'end'},
    );

    final day = await tripRepository.createTripDay(
      tripId: 'okinawa-trip-2026-Ray',
      position: 'end',
    );

    expect(day.dayNum, 4);
    expect(day.date, '2026-10-04');
    expect(day.dayOfWeek, '日');
  });

  test('createTripDay：insert 位置帶 date 補回缺漏日期', () async {
    dioAdapter.onPost(
      '/trips/okinawa-trip-2026-Ray/days',
      (server) => server.reply(201, {
        'day': {
          'id': 12,
          'day_num': 2,
          'date': '2026-10-02',
          'day_of_week': '五',
          'label': 'Day 2',
          'title': 'Day 2',
        },
      }),
      data: {'position': 'insert', 'date': '2026-10-02'},
    );

    final day = await tripRepository.createTripDay(
      tripId: 'okinawa-trip-2026-Ray',
      position: 'insert',
      date: '2026-10-02',
    );

    expect(day.dayNum, 2);
    expect(day.date, '2026-10-02');
  });

  test(
    'deleteTripDay：DELETE /trips/:id/days/:num 回 removedEntryCount',
    () async {
      dioAdapter.onDelete(
        '/trips/okinawa-trip-2026-Ray/days/2',
        (server) => server.reply(200, {'ok': true, 'removedEntryCount': 3}),
      );

      final result = await tripRepository.deleteTripDay(
        tripId: 'okinawa-trip-2026-Ray',
        dayNum: 2,
      );

      expect(result.ok, isTrue);
      expect(result.removedEntryCount, 3);
    },
  );

  test('shiftTripDays：POST /trips/:id/days/shift 整段平移日期', () async {
    dioAdapter.onPost(
      '/trips/okinawa-trip-2026-Ray/days/shift',
      (server) => server.reply(200, {
        'ok': true,
        'newStartDate': '2026-10-05',
        'newEndDate': '2026-10-07',
        'daysShifted': 3,
      }),
      data: {'startDate': '2026-10-05'},
    );

    final result = await tripRepository.shiftTripDays(
      tripId: 'okinawa-trip-2026-Ray',
      startDate: '2026-10-05',
    );

    expect(result.ok, isTrue);
    expect(result.newStartDate, '2026-10-05');
    expect(result.newEndDate, '2026-10-07');
    expect(result.daysShifted, 3);
  });

  test(
    'fetchTripSegments：GET /trips/:id/segments 解析 snake_case rows',
    () async {
      dioAdapter.onGet(
        '/trips/okinawa-trip-2026-Ray/segments',
        (server) => server.reply(200, [
          {
            'id': 9001,
            'trip_id': 'okinawa-trip-2026-Ray',
            'from_entry_id': 101,
            'to_entry_id': 102,
            'mode': 'driving',
            'min': 18,
            'distance_m': 7400,
            'source': 'google',
            'computed_at': 1783500000000,
            'updated_at': 1783500010000,
            'version': 4,
          },
        ]),
      );

      final segments = await tripRepository.fetchTripSegments(
        'okinawa-trip-2026-Ray',
      );

      expect(segments, hasLength(1));
      expect(segments.single.id, 9001);
      expect(segments.single.tripId, 'okinawa-trip-2026-Ray');
      expect(segments.single.fromEntryId, 101);
      expect(segments.single.toEntryId, 102);
      expect(segments.single.mode, 'driving');
      expect(segments.single.min, 18);
      expect(segments.single.distanceM, 7400);
      expect(segments.single.version, 4);
    },
  );

  test(
    'updateTripSegment：PATCH /segments/:sid 帶 mode/min/expectedVersion',
    () async {
      dioAdapter.onPatch(
        '/trips/okinawa-trip-2026-Ray/segments/9001',
        (server) => server.reply(200, {
          'id': 9001,
          'trip_id': 'okinawa-trip-2026-Ray',
          'from_entry_id': 101,
          'to_entry_id': 102,
          'mode': 'transit',
          'min': 32,
          'distance_m': null,
          'source': 'manual',
          'computed_at': 1783500000000,
          'updated_at': 1783500010000,
          'version': 5,
        }),
        data: {'mode': 'transit', 'min': 32, 'expectedVersion': 4},
      );

      final segment = await tripRepository.updateTripSegment(
        tripId: 'okinawa-trip-2026-Ray',
        segmentId: 9001,
        mode: 'transit',
        min: 32,
        expectedVersion: 4,
      );

      expect(segment.mode, 'transit');
      expect(segment.min, 32);
      expect(segment.source, 'manual');
      expect(segment.version, 5);
    },
  );

  test('updateTripSegment：driving/walking 不送 min', () async {
    dioAdapter.onPatch(
      '/trips/okinawa-trip-2026-Ray/segments/9001',
      (server) => server.reply(200, {
        'id': 9001,
        'trip_id': 'okinawa-trip-2026-Ray',
        'from_entry_id': 101,
        'to_entry_id': 102,
        'mode': 'walking',
        'min': 12,
        'distance_m': 900,
        'source': 'google',
        'computed_at': 1783500000000,
        'updated_at': 1783500010000,
        'version': 5,
      }),
      data: {'mode': 'walking', 'expectedVersion': 4},
    );

    final segment = await tripRepository.updateTripSegment(
      tripId: 'okinawa-trip-2026-Ray',
      segmentId: 9001,
      mode: 'walking',
      expectedVersion: 4,
    );

    expect(segment.mode, 'walking');
    expect(segment.min, 12);
    expect(segment.version, 5);
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

  test('copyEntry：POST /trips/:id/entries/:eid/copy 指定 targetDayId', () async {
    dioAdapter.onPost(
      '/trips/okinawa-trip-2026-Ray/entries/101/copy',
      (server) => server.reply(201, {
        'id': 902,
        'dayId': 12,
        'sortOrder': 2,
        'startTime': '10:00',
        'endTime': '11:30',
        'title': '首里城',
        'description': '世界遺產',
        'version': 1,
      }),
      data: {'targetDayId': 12},
    );

    final copied = await tripRepository.copyEntry(
      tripId: 'okinawa-trip-2026-Ray',
      entryId: 101,
      targetDayId: 12,
    );

    expect(copied.id, 902);
    expect(copied.dayId, 12);
    expect(copied.startTime, '10:00');
  });

  test(
    'moveEntry：PATCH /trips/:id/entries/:eid 帶 day_id 與 expectedVersion',
    () async {
      dioAdapter.onPatch(
        '/trips/okinawa-trip-2026-Ray/entries/101',
        (server) => server.reply(200, {
          'id': 101,
          'dayId': 12,
          'sortOrder': 2,
          'startTime': '10:00',
          'endTime': '11:30',
          'title': '首里城',
          'version': 8,
        }),
        data: {'day_id': 12, 'expectedVersion': 7},
      );

      final moved = await tripRepository.moveEntry(
        tripId: 'okinawa-trip-2026-Ray',
        entryId: 101,
        targetDayId: 12,
        expectedVersion: 7,
      );

      expect(moved.id, 101);
      expect(moved.dayId, 12);
      expect(moved.version, 8);
    },
  );

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

  test(
    'deleteEntryAlternate：DELETE /alternates/:poiId 以 query 帶 entryPoisVersion',
    () async {
      dioAdapter.onDelete(
        '/trips/okinawa-trip-2026-Ray/entries/101/alternates/502?entryPoisVersion=3',
        (server) => server.reply(200, {
          'entryId': 101,
          'poiId': 502,
          'entryPoisVersion': '4',
        }),
      );

      final result = await tripRepository.deleteEntryAlternate(
        tripId: 'okinawa-trip-2026-Ray',
        entryId: 101,
        poiId: 502,
        entryPoisVersion: '3',
      );

      expect(result.entryId, 101);
      expect(result.poiId, 502);
      expect(result.entryPoisVersion, '4');
    },
  );

  test(
    'reorderEntryAlternates：PATCH /alternates/reorder 帶完整 poiId 順序與 OCC',
    () async {
      dioAdapter.onPatch(
        '/trips/okinawa-trip-2026-Ray/entries/101/alternates/reorder',
        (server) => server.reply(200, {
          'entryId': 101,
          'order': [503, 502],
          'entryPoisVersion': '4',
        }),
        data: {
          'order': [503, 502],
          'entryPoisVersion': '3',
        },
      );

      final result = await tripRepository.reorderEntryAlternates(
        tripId: 'okinawa-trip-2026-Ray',
        entryId: 101,
        orderedPoiIds: const [503, 502],
        entryPoisVersion: '3',
      );

      expect(result.entryId, 101);
      expect(result.order, [503, 502]);
      expect(result.entryPoisVersion, '4');
    },
  );

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

  test('createTripFlight：POST /notes/flights 使用 snake_case body', () async {
    dioAdapter.onPost(
      '/trips/okinawa-trip-2026-Ray/notes/flights',
      (server) => server.reply(201, {
        'id': 9,
        'sortOrder': 0,
        'version': 1,
        'airline': '台灣虎航',
        'flightNo': 'IT232',
        'departAirport': 'TPE',
        'arriveAirport': 'OKA',
      }),
      data: {
        'airline': '台灣虎航',
        'flight_no': 'IT232',
        'depart_airport': 'TPE',
        'arrive_airport': 'OKA',
      },
    );

    final flight = await tripRepository.createTripFlight(
      tripId: 'okinawa-trip-2026-Ray',
      airline: '台灣虎航',
      flightNo: 'IT232',
      departAirport: 'TPE',
      arriveAirport: 'OKA',
    );

    expect(flight.id, 9);
    expect(flight.flightNo, 'IT232');
  });

  test('createTripLodging：POST /notes/lodgings 新增住宿', () async {
    dioAdapter.onPost(
      '/trips/okinawa-trip-2026-Ray/notes/lodgings',
      (server) => server.reply(201, {
        'id': 10,
        'sortOrder': 0,
        'version': 1,
        'name': '那霸海濱飯店',
        'address': '沖繩縣那霸市',
      }),
      data: {'name': '那霸海濱飯店', 'address': '沖繩縣那霸市'},
    );

    final lodging = await tripRepository.createTripLodging(
      tripId: 'okinawa-trip-2026-Ray',
      name: '那霸海濱飯店',
      address: '沖繩縣那霸市',
    );

    expect(lodging.id, 10);
    expect(lodging.name, '那霸海濱飯店');
  });

  test(
    'updateTripReservation：PATCH /notes/reservations/:rowId 帶 OCC',
    () async {
      dioAdapter.onPatch(
        '/trips/okinawa-trip-2026-Ray/notes/reservations/21',
        (server) => server.reply(200, {
          'id': 21,
          'sortOrder': 0,
          'version': 8,
          'kind': 'restaurant',
          'title': '燒肉乃我那霸',
          'partySize': 4,
        }),
        data: {
          'kind': 'restaurant',
          'title': '燒肉乃我那霸',
          'party_size': 4,
          'expectedVersion': 7,
        },
      );

      final reservation = await tripRepository.updateTripReservation(
        tripId: 'okinawa-trip-2026-Ray',
        rowId: 21,
        expectedVersion: 7,
        kind: 'restaurant',
        title: '燒肉乃我那霸',
        partySize: 4,
      );

      expect(reservation.version, 8);
      expect(reservation.partySize, 4);
    },
  );

  test('updateTripPretripNote：PATCH /notes/pretrip/:rowId 更新標題內容', () async {
    dioAdapter.onPatch(
      '/trips/okinawa-trip-2026-Ray/notes/pretrip/31',
      (server) => server.reply(200, {
        'id': 31,
        'sortOrder': 0,
        'version': 3,
        'title': '日幣兌換',
        'content': '機場 ATM 通常比臨櫃划算。',
      }),
      data: {
        'title': '日幣兌換',
        'content': '機場 ATM 通常比臨櫃划算。',
        'expectedVersion': 2,
      },
    );

    final note = await tripRepository.updateTripPretripNote(
      tripId: 'okinawa-trip-2026-Ray',
      rowId: 31,
      expectedVersion: 2,
      title: '日幣兌換',
      content: '機場 ATM 通常比臨櫃划算。',
    );

    expect(note.version, 3);
    expect(note.title, '日幣兌換');
  });

  test(
    'updateTripEmergencyContact：PATCH /notes/emergency/:rowId 更新聯絡人',
    () async {
      dioAdapter.onPatch(
        '/trips/okinawa-trip-2026-Ray/notes/emergency/41',
        (server) => server.reply(200, {
          'id': 41,
          'sortOrder': 0,
          'version': 4,
          'name': '日本警察',
          'kind': 'police',
          'phone': '110',
        }),
        data: {
          'name': '日本警察',
          'kind': 'police',
          'phone': '110',
          'expectedVersion': 3,
        },
      );

      final contact = await tripRepository.updateTripEmergencyContact(
        tripId: 'okinawa-trip-2026-Ray',
        rowId: 41,
        expectedVersion: 3,
        name: '日本警察',
        kind: 'police',
        phone: '110',
      );

      expect(contact.version, 4);
      expect(contact.kind, 'police');
    },
  );

  test('deleteTripNoteRow：DELETE /notes/:section/:rowId', () async {
    dioAdapter.onDelete(
      '/trips/okinawa-trip-2026-Ray/notes/emergency/41',
      (server) => server.reply(200, {'ok': true}),
    );

    await tripRepository.deleteTripNoteRow(
      tripId: 'okinawa-trip-2026-Ray',
      section: TripNoteSection.emergency,
      rowId: 41,
    );
  });

  test(
    'generateTripNotes：POST /notes/:docType/generate 解析 request id',
    () async {
      dioAdapter.onPost(
        '/trips/okinawa-trip-2026-Ray/notes/tips/generate',
        (server) => server.reply(202, {
          'jobId': 77,
          'requestId': 9901,
          'status': 'pending',
          'tripId': 'okinawa-trip-2026-Ray',
          'docType': 'tips',
        }),
        data: <String, dynamic>{},
      );

      final job = await tripRepository.generateTripNotes(
        tripId: 'okinawa-trip-2026-Ray',
        docType: 'tips',
      );

      expect(job.jobId, 77);
      expect(job.requestId, 9901);
    },
  );

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

  test('createCustomEntry：POST entries 帶自訂座標、類型與 note', () async {
    dioAdapter.onPost(
      '/trips/okinawa-trip-2026/days/2/entries',
      (server) => server.reply(201, {
        'id': 902,
        'dayId': 11,
        'sortOrder': 3,
        'startTime': '14:30',
        'endTime': '15:30',
        'source': 'custom',
      }),
      data: {
        'name': '巷口咖啡',
        'note': '朋友推薦的甜點店',
        'lat': 26.2145,
        'lng': 127.6812,
        'source': 'custom',
        'time': '14:30-15:30',
        'poi_type': 'restaurant',
      },
    );

    await expectLater(
      tripRepository.createCustomEntry(
        tripId: 'okinawa-trip-2026',
        dayNum: 2,
        name: '巷口咖啡',
        note: '朋友推薦的甜點店',
        lat: 26.2145,
        lng: 127.6812,
        poiType: 'restaurant',
        startTime: '14:30',
        endTime: '15:30',
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
