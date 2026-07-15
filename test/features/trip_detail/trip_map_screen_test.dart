import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tripline/api/map_repository.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/features/map/map_adapter.dart';
import 'package:tripline/features/map/map_location.dart';
import 'package:tripline/features/trip_detail/trip_map_screen.dart';
import 'package:tripline/features/trip_detail/trip_providers.dart';
import 'package:tripline/features/trips/trips_list_screen.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/models/trip_route.dart';
import 'package:tripline/theme/app_theme.dart';

import '../../helpers/fake_trip_map.dart';

class _FakeLocationService implements TripMapLocationService {
  int calls = 0;

  @override
  Future<TripMapPoint> currentLocation() async {
    calls++;
    return const TripMapPoint(26.215, 127.72);
  }
}

class _StubMapRepository implements MapRepository {
  int calls = 0;

  @override
  Future<TripRouteResult> fetchRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    cancelToken,
  }) async {
    calls++;
    return TripRouteResult(
      polyline: [
        TripRoutePoint(lat: fromLat, lng: fromLng),
        TripRoutePoint(lat: (fromLat + toLat) / 2, lng: (fromLng + toLng) / 2),
        TripRoutePoint(lat: toLat, lng: toLng),
      ],
      durationSeconds: 600,
      distanceMeters: 4200,
    );
  }
}

TimelineEntry _entry({
  required int id,
  required String title,
  String? startTime,
  double? lat,
  double? lng,
}) {
  return TimelineEntry(
    id: id,
    sortOrder: 0,
    title: title,
    version: 1,
    startTime: startTime,
    master: (lat == null || lng == null)
        ? null
        : EntryPoiInfo(poiId: id * 10, name: title, lat: lat, lng: lng),
  );
}

final _dayOne = TripDay(
  id: 1,
  dayNum: 1,
  date: '2026-04-01',
  version: 1,
  timeline: [
    _entry(id: 11, title: '首里城', startTime: '09:00', lat: 26.217, lng: 127.719),
    _entry(id: 12, title: '國際通', startTime: '11:30', lat: 26.214, lng: 127.688),
    // 無座標 entry：不應產生 pin 與 entry card。
    _entry(id: 13, title: '自由活動', startTime: '14:00'),
  ],
);

final _dayTwo = TripDay(
  id: 2,
  dayNum: 2,
  date: '2026-04-02',
  version: 1,
  timeline: [
    _entry(
      id: 21,
      title: '美麗海水族館',
      startTime: '10:00',
      lat: 26.694,
      lng: 127.878,
    ),
  ],
);

Widget _buildScreen(
  List<TripDay> days, {
  int? initialEntryId,
  TripMapLocationService? locationService,
  MapRepository? mapRepository,
  List<TripSummary> trips = const [
    TripSummary(tripId: 'trip-1', name: 'okinawa', title: '沖繩家族旅行'),
  ],
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => TripMapScreen(
          tripId: 'trip-1',
          initialEntryId: initialEntryId,
          mapBuilder: fakeTripMapBuilder,
          locationService: locationService,
        ),
      ),
      GoRoute(
        path: '/trips/:tripId/map',
        builder: (context, state) => Scaffold(
          body: Text('trip-map-route-${state.pathParameters['tripId']}'),
        ),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      tripDaysProvider.overrideWith((ref, tripId) => Stream.value(days)),
      myTripsProvider.overrideWith((ref) => Stream.value(trips)),
      mapRepositoryProvider.overrideWithValue(
        mapRepository ?? _StubMapRepository(),
      ),
    ],
    child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
}

void main() {
  testWidgets('總覽：單一 scope 、全部含座標 pins 與 entry cards', (tester) async {
    await tester.pumpWidget(_buildScreen([_dayOne, _dayTwo]));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('trip-section-scope')), findsOneWidget);
    expect(find.text('地圖 · 總覽'), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-map-day-tabs')), findsNothing);

    // pins：只有 master 座標非 null 的 3 筆
    expect(find.byKey(const ValueKey('map-pin-11')), findsOneWidget);
    expect(find.byKey(const ValueKey('map-pin-12')), findsOneWidget);
    expect(find.byKey(const ValueKey('map-pin-21')), findsOneWidget);
    expect(find.byKey(const ValueKey('map-pin-13')), findsNothing);

    // 底部 entry cards（時間 + 標題）；無座標 entry 不出卡片
    expect(find.byKey(const ValueKey('entry-card-11')), findsOneWidget);
    expect(find.text('首里城'), findsOneWidget);
    expect(find.textContaining('09:00'), findsOneWidget);
    expect(find.text('自由活動'), findsNothing);

    expect(find.byKey(const ValueKey('fake-trip-map-canvas')), findsOneWidget);
  });

  testWidgets('切到 DAY 02：只顯示該日 pins 與 entry cards', (tester) async {
    await tester.pumpWidget(_buildScreen([_dayOne, _dayTwo]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('trip-section-scope')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('trip-section-day-2')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('map-pin-21')), findsOneWidget);
    expect(find.byKey(const ValueKey('map-pin-11')), findsNothing);
    expect(find.text('美麗海水族館'), findsOneWidget);
    expect(find.text('首里城'), findsNothing);
  });

  testWidgets('相鄰景點使用 /route 幾何繪製 Google polyline', (tester) async {
    final repository = _StubMapRepository();
    await tester.pumpWidget(_buildScreen([_dayOne], mapRepository: repository));
    await tester.pumpAndSettle();

    expect(repository.calls, 1);
    expect(find.byKey(const ValueKey('map-route-day-route-0')), findsOneWidget);
  });

  testWidgets('指定 initialEntryId：初始顯示該停留點所在天', (tester) async {
    await tester.pumpWidget(
      _buildScreen([_dayOne, _dayTwo], initialEntryId: 21),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('map-pin-21')), findsOneWidget);
    expect(find.byKey(const ValueKey('map-pin-11')), findsNothing);
    expect(find.byKey(const ValueKey('map-pin-12')), findsNothing);
    expect(find.text('美麗海水族館'), findsOneWidget);
    expect(find.text('首里城'), findsNothing);
  });

  testWidgets('點 entry card：地圖移至該 pin 且不 crash', (tester) async {
    await tester.pumpWidget(_buildScreen([_dayOne, _dayTwo]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('entry-card-12')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('map-pin-12')), findsOneWidget);
  });

  testWidgets('地圖維持單一路線圖，不顯示舊圖層選單', (tester) async {
    await tester.pumpWidget(_buildScreen([_dayOne, _dayTwo]));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('map-style-roadmap')), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-map-layer-menu')), findsNothing);
  });

  testWidgets('定位按鈕：取得目前位置後顯示 user marker', (tester) async {
    final locationService = _FakeLocationService();
    await tester.pumpWidget(
      _buildScreen([_dayOne, _dayTwo], locationService: locationService),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('trip-map-locate-button')));
    await tester.pumpAndSettle();

    expect(locationService.calls, 1);
    expect(
      find.byKey(const ValueKey('trip-map-user-location')),
      findsOneWidget,
    );
  });

  testWidgets('行程切換選單：可從地圖切到另一個行程', (tester) async {
    await tester.pumpWidget(
      _buildScreen(
        [_dayOne, _dayTwo],
        trips: const [
          TripSummary(tripId: 'trip-1', name: 'okinawa', title: '沖繩家族旅行'),
          TripSummary(tripId: 'trip-2', name: 'tokyo', title: '東京週末'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('trip-map-trip-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('trip-map-trip-pick-trip-2')));
    await tester.pumpAndSettle();

    expect(find.text('trip-map-route-trip-2'), findsOneWidget);
  });

  testWidgets('全部 entry 無座標：顯示空狀態、不渲染地圖', (tester) async {
    final dayWithoutCoordinates = TripDay(
      id: 3,
      dayNum: 1,
      version: 1,
      timeline: [_entry(id: 31, title: '自由活動', startTime: '10:00')],
    );
    await tester.pumpWidget(_buildScreen([dayWithoutCoordinates]));
    await tester.pumpAndSettle();

    expect(find.text('此行程尚無地點座標'), findsOneWidget);
    expect(find.byKey(const ValueKey('fake-trip-map-canvas')), findsNothing);
  });
}
