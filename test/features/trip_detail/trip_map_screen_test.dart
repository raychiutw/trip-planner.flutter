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
import 'package:tripline/theme/tokens.dart';
import 'package:tripline/ui/tp_bottom_accessory.dart';

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
  ValueChanged<TripMapCanvasConfig>? onMapConfig,
  TextScaler textScaler = TextScaler.noScaling,
  EdgeInsets viewPadding = EdgeInsets.zero,
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
          mapBuilder: (config) {
            onMapConfig?.call(config);
            return fakeTripMapBuilder(config);
          },
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
    child: MaterialApp.router(
      theme: AppTheme.light(),
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: textScaler,
          padding: viewPadding,
          viewPadding: viewPadding,
        ),
        child: child!,
      ),
    ),
  );
}

void main() {
  testWidgets('總覽：單一 scope 、全部含座標 pins 與 entry cards', (tester) async {
    TripMapCanvasConfig? mapConfig;
    await tester.pumpWidget(
      _buildScreen([
        _dayOne,
        _dayTwo,
      ], onMapConfig: (config) => mapConfig = config),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('trip-section-scope')), findsOneWidget);
    expect(find.text('地圖 · 總覽'), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-map-day-tabs')), findsNothing);
    expect(find.byType(PageView), findsOneWidget);
    final pageView = tester.widget<PageView>(find.byType(PageView));
    expect(pageView.scrollDirection, Axis.horizontal);
    expect(pageView.controller!.viewportFraction, 0.84);
    expect(
      tester.getSize(find.byKey(const ValueKey('trip-map-poi-drawer'))).height,
      TpBottomAccessory.height,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('trip-map-poi-drawer')),
        matching: find.byType(AnimatedContainer),
      ),
      findsNothing,
    );

    // pins：只有 master 座標非 null 的 3 筆
    expect(find.byKey(const ValueKey('map-pin-11')), findsOneWidget);
    expect(find.byKey(const ValueKey('map-pin-12')), findsOneWidget);
    expect(find.byKey(const ValueKey('map-pin-21')), findsOneWidget);
    expect(find.byKey(const ValueKey('map-pin-13')), findsNothing);

    // 底部水平 POI pages（時間 + 標題）。
    expect(find.byKey(const ValueKey('entry-card-11')), findsOneWidget);
    expect(find.byKey(const ValueKey('poi-number-11')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('trip-map-poi-drawer')),
        matching: find.byType(Image),
      ),
      findsNothing,
    );
    expect(find.text('首里城'), findsOneWidget);
    expect(find.textContaining('09:00'), findsOneWidget);

    expect(find.byKey(const ValueKey('fake-trip-map-canvas')), findsOneWidget);
    expect(
      mapConfig?.markers
          .singleWhere((marker) => marker.id == 'map-pin-21')
          .glyph,
      '4',
    );
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

  testWidgets('點目前 entry card：地圖移至該 pin 且不 crash', (tester) async {
    await tester.pumpWidget(_buildScreen([_dayOne, _dayTwo]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('entry-card-11')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('map-pin-11')), findsOneWidget);
  });

  testWidgets('marker 點擊與左右滑卡共用 active POI', (tester) async {
    TripMapCanvasConfig? mapConfig;
    await tester.pumpWidget(
      _buildScreen([
        _dayOne,
        _dayTwo,
      ], onMapConfig: (config) => mapConfig = config),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('map-pin-12')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('active-entry-card-12')), findsOneWidget);
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 1);

    await tester.drag(find.byType(PageView), const Offset(700, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('active-entry-card-11')), findsOneWidget);
    final first = mapConfig!.markers.singleWhere(
      (marker) => marker.id == 'map-pin-11',
    );
    final second = mapConfig!.markers.singleWhere(
      (marker) => marker.id == 'map-pin-12',
    );
    expect(first.zIndex, greaterThan(second.zIndex));
  });

  testWidgets('無座標 POI 仍可透過水平滑動到達', (tester) async {
    await tester.pumpWidget(_buildScreen([_dayOne]));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(-700, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(-700, 0));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('active-entry-card-13')), findsOneWidget);
    expect(find.text('自由活動'), findsOneWidget);
    expect(find.textContaining('尚無位置'), findsOneWidget);
    expect(find.byKey(const ValueKey('map-pin-13')), findsNothing);
  });

  testWidgets('map padding 避讓固定 POI accessory 與 root tab', (tester) async {
    const bottomInset = 34.0;
    TripMapCanvasConfig? mapConfig;
    await tester.pumpWidget(
      _buildScreen(
        [_dayOne],
        viewPadding: const EdgeInsets.only(bottom: bottomInset),
        onMapConfig: (config) => mapConfig = config,
      ),
    );
    await tester.pumpAndSettle();

    final expectedRootClearance = TpRootTabGeometry.expandedHeightFor(
      bottomInset,
    );
    expect(
      mapConfig!.initialPadding.bottom,
      greaterThanOrEqualTo(
        TpBottomAccessory.height + expectedRootClearance + TpSpacing.s3,
      ),
    );
    final drawerRect = tester.getRect(
      find.byKey(const ValueKey('trip-map-poi-drawer')),
    );
    expect(
      tester.view.physicalSize.height / tester.view.devicePixelRatio -
          drawerRect.bottom,
      expectedRootClearance + TpSpacing.s3,
    );
  });

  testWidgets('320×568 與 135% 文字使用 accessibility rail 且 scope 不撞定位鈕', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _buildScreen([_dayOne], textScaler: const TextScaler.linear(1.35)),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const ValueKey('trip-map-poi-drawer'))).height,
      144,
    );
    final scope = tester.getRect(
      find.byKey(const ValueKey('trip-section-scope')),
    );
    final locate = tester.getRect(
      find.byKey(const ValueKey('trip-map-locate-button')),
    );
    expect(scope.right, lessThanOrEqualTo(locate.left));
    expect(tester.takeException(), isNull);
  });

  testWidgets('320×568 與 200% 文字不溢出 POI rail', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _buildScreen([_dayOne], textScaler: const TextScaler.linear(2)),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('active-entry-card-11')), findsOneWidget);
  });

  testWidgets('長行程 page indicator 不會水平溢出', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final manyStops = TripDay(
      id: 9,
      dayNum: 1,
      date: '2026-04-01',
      version: 1,
      timeline: [
        for (var i = 0; i < 40; i++)
          _entry(
            id: 100 + i,
            title: '停留點 ${i + 1}',
            startTime: '09:00',
            lat: 26.2 + i / 1000,
            lng: 127.7 + i / 1000,
          ),
      ],
    );

    await tester.pumpWidget(_buildScreen([manyStops]));
    await tester.pumpAndSettle();

    expect(find.text('1 / 40'), findsOneWidget);
    expect(tester.takeException(), isNull);
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

  testWidgets('全部 entry 無座標：仍渲染地圖與 POI page', (tester) async {
    final dayWithoutCoordinates = TripDay(
      id: 3,
      dayNum: 1,
      version: 1,
      timeline: [_entry(id: 31, title: '自由活動', startTime: '10:00')],
    );
    await tester.pumpWidget(_buildScreen([dayWithoutCoordinates]));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('fake-trip-map-canvas')), findsOneWidget);
    expect(find.byKey(const ValueKey('active-entry-card-31')), findsOneWidget);
    expect(find.text('自由活動'), findsOneWidget);
    expect(find.textContaining('尚無位置'), findsOneWidget);
  });
}
