import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:tripline/api/map_repository.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/features/map/google_maps_external_launcher.dart';
import 'package:tripline/features/map/map_adapter.dart';
import 'package:tripline/features/map/map_location.dart';
import 'package:tripline/features/shell/apple_root_tab_bar.dart';
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

class _RestrictedLocationService implements TripMapLocationService {
  _RestrictedLocationService({
    this.settingsTarget = TripMapLocationSettingsTarget.application,
  });

  final TripMapLocationSettingsTarget settingsTarget;
  int calls = 0;

  @override
  Future<TripMapPoint> currentLocation() async {
    calls++;
    throw TripMapLocationException(
      '定位權限遭拒或受限制，請前往「設定」允許定位',
      settingsTarget: settingsTarget,
    );
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

class _DelayedSecondRouteRepository implements MapRepository {
  final secondRoute = Completer<TripRouteResult>();
  int calls = 0;

  @override
  Future<TripRouteResult> fetchRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    cancelToken,
  }) {
    calls++;
    final result = TripRouteResult(
      polyline: [
        TripRoutePoint(lat: fromLat, lng: fromLng),
        TripRoutePoint(lat: toLat, lng: toLng),
      ],
      durationSeconds: 600,
      distanceMeters: 4200,
    );
    return calls == 1 ? Future.value(result) : secondRoute.future;
  }
}

class _RecordedMove {
  const _RecordedMove(this.point, this.zoom, this.animate);

  final TripMapPoint point;
  final double zoom;
  final bool animate;
}

class _FakeTripMapPlatformController implements TripMapPlatformController {
  final moves = <_RecordedMove>[];

  @override
  Future<void> fitPoints(
    List<TripMapPoint> points, {
    required double padding,
    required bool animate,
    double? maxZoom,
  }) async {}

  @override
  Future<void> move(
    TripMapPoint point,
    double zoom, {
    required bool animate,
  }) async {
    moves.add(_RecordedMove(point, zoom, animate));
  }
}

TimelineEntry _entry({
  required int id,
  required String title,
  String? time,
  String? startTime,
  String? endTime,
  String? category,
  String? type,
  double? lat,
  double? lng,
}) {
  return TimelineEntry(
    id: id,
    sortOrder: 0,
    title: title,
    version: 1,
    time: time,
    startTime: startTime,
    endTime: endTime,
    master: (lat == null || lng == null)
        ? null
        : EntryPoiInfo(
            poiId: id * 10,
            name: title,
            lat: lat,
            lng: lng,
            category: category,
            type: type,
          ),
  );
}

final _dayOne = TripDay(
  id: 1,
  dayNum: 1,
  date: '2026-04-01',
  version: 1,
  timeline: [
    _entry(
      id: 11,
      title: '首里城',
      startTime: '09:00',
      endTime: '10:30',
      category: '景點',
      lat: 26.217,
      lng: 127.719,
    ),
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

const _googlePoi = GoogleMapPoiSelection(
  placeId: 'ChIJ-test',
  name: '清水寺',
  point: TripMapPoint(34.9948, 135.785),
);

Widget _buildScreen(
  List<TripDay> days, {
  int? initialEntryId,
  int? initialDayNum,
  TripMapLocationService? locationService,
  Future<bool> Function(TripMapLocationSettingsTarget)? locationSettingsOpener,
  MapRepository? mapRepository,
  ValueChanged<TripMapCanvasConfig>? onMapConfig,
  TextScaler textScaler = TextScaler.noScaling,
  EdgeInsets viewPadding = EdgeInsets.zero,
  List<TripSummary> trips = const [
    TripSummary(tripId: 'trip-1', name: 'okinawa', title: '沖繩家族旅行'),
  ],
  bool withRootTab = false,
  ThemeData? theme,
  GoogleMapsExternalLauncher externalLauncher =
      const GoogleMapsExternalLauncher(),
  bool renderSelectedTripMap = false,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => TripMapScreen(
          tripId: 'trip-1',
          initialEntryId: initialEntryId,
          initialDayNum: initialDayNum,
          mapBuilder: (config) {
            onMapConfig?.call(config);
            return fakeTripMapBuilder(config);
          },
          locationService: locationService,
          locationSettingsOpener: locationSettingsOpener,
          externalLauncher: externalLauncher,
        ),
      ),
      GoRoute(
        path: '/trips/:tripId/map',
        builder: (context, state) {
          final selectedTripId = state.pathParameters['tripId']!;
          if (!renderSelectedTripMap) {
            return Scaffold(body: Text('trip-map-route-$selectedTripId'));
          }
          return TripMapScreen(
            tripId: selectedTripId,
            mapBuilder: (config) {
              onMapConfig?.call(config);
              return fakeTripMapBuilder(config);
            },
            locationService: locationService,
            locationSettingsOpener: locationSettingsOpener,
            externalLauncher: externalLauncher,
          );
        },
      ),
      GoRoute(
        path: '/trips/:tripId',
        builder: (context, state) => Scaffold(
          body: Text(
            'trip-timeline-route-${state.pathParameters['tripId']}-${state.uri.queryParameters['day']}',
          ),
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
      theme: theme ?? AppTheme.light(),
      routerConfig: router,
      builder: (context, child) {
        Widget content = child!;
        if (withRootTab) {
          content = Scaffold(
            extendBody: true,
            body: content,
            bottomNavigationBar: AppleRootTabBar(
              selectedIndex: 2,
              onSelected: (_) {},
            ),
          );
        }
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: textScaler,
            padding: viewPadding,
            viewPadding: viewPadding,
          ),
          child: content,
        );
      },
    ),
  );
}

void main() {
  testWidgets('Google POI 關閉後還原 Day、卡片索引與 marker 聚焦', (tester) async {
    TripMapCanvasConfig? mapConfig;
    await tester.pumpWidget(
      _buildScreen([
        _dayOne,
        _dayTwo,
      ], onMapConfig: (config) => mapConfig = config),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('trip-map-day-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('entry-card-21')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('active-entry-card-21')), findsOneWidget);

    expect(find.byType(PageView), findsOneWidget);
    mapConfig!.onGooglePoiSelected!(_googlePoi);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('google-poi-accessory')), findsOneWidget);
    expect(find.text('在 Google 地圖開啟'), findsOneWidget);
    expect(find.byType(PageView), findsNothing);

    await tester.tap(find.byKey(const ValueKey('google-poi-close')));
    await tester.pumpAndSettle();

    expect(find.byType(PageView), findsOneWidget);
    expect(find.byKey(const ValueKey('active-entry-card-21')), findsOneWidget);
    expect(find.byKey(const ValueKey('map-pin-21')), findsOneWidget);
    expect(find.byKey(const ValueKey('map-pin-11')), findsNothing);
    expect(
      mapConfig!.markers
          .singleWhere((marker) => marker.id == 'map-pin-21')
          .zIndex,
      1000,
    );
  });

  testWidgets('空白地圖與 Tripline marker 還原原頁且 marker 維持 zoom 13', (tester) async {
    final nativeController = _FakeTripMapPlatformController();
    TripMapCanvasConfig? mapConfig;
    var attached = false;
    await tester.pumpWidget(
      _buildScreen(
        [_dayOne],
        initialEntryId: 13,
        onMapConfig: (config) {
          mapConfig = config;
          if (!attached) {
            attached = true;
            config.controller.attach(nativeController);
          }
        },
      ),
    );
    await tester.pumpAndSettle();

    mapConfig!.onGooglePoiSelected!(_googlePoi);
    await tester.pump();
    mapConfig!.onTap!(const TripMapPoint(35, 135));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('active-entry-card-13')), findsOneWidget);

    mapConfig!.onGooglePoiSelected!(_googlePoi);
    await tester.pump();
    nativeController.moves.clear();
    mapConfig!.markers
        .singleWhere((marker) => marker.id == 'map-pin-12')
        .onTap!();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('active-entry-card-12')), findsOneWidget);
    expect(nativeController.moves, isNotEmpty);
    expect(nativeController.moves.last.zoom, 13);
  });

  testWidgets('選取 Google POI 不移動鏡頭，外開失敗保留卡片並顯示錯誤', (tester) async {
    final nativeController = _FakeTripMapPlatformController();
    TripMapCanvasConfig? mapConfig;
    var attached = false;
    await tester.pumpWidget(
      _buildScreen(
        [_dayOne],
        externalLauncher: GoogleMapsExternalLauncher(
          launch: (_, {required mode}) async => false,
        ),
        onMapConfig: (config) {
          mapConfig = config;
          if (!attached) {
            attached = true;
            config.controller.attach(nativeController);
          }
        },
      ),
    );
    await tester.pumpAndSettle();
    nativeController.moves.clear();

    mapConfig!.onGooglePoiSelected!(_googlePoi);
    await tester.pumpAndSettle();
    expect(nativeController.moves, isEmpty);

    await tester.tap(find.byKey(const ValueKey('google-poi-open')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('google-poi-accessory')), findsOneWidget);
    expect(find.byKey(const ValueKey('app-error-banner')), findsOneWidget);
    expect(find.text('無法開啟 Google 地圖，請稍後再試'), findsOneWidget);
  });

  testWidgets('白天地圖固定使用深色 status bar 圖示', (tester) async {
    await tester.pumpWidget(_buildScreen([_dayOne, _dayTwo]));
    await tester.pumpAndSettle();

    final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byKey(const ValueKey('trip-map-status-style')),
    );
    expect(region.value.statusBarIconBrightness, Brightness.dark);
    expect(region.value.statusBarBrightness, Brightness.light);
  });

  testWidgets('深色地圖固定使用淺色 status bar 圖示', (tester) async {
    await tester.pumpWidget(
      _buildScreen([_dayOne, _dayTwo], theme: AppTheme.dark()),
    );
    await tester.pumpAndSettle();

    final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byKey(const ValueKey('trip-map-status-style')),
    );
    expect(region.value.statusBarIconBrightness, Brightness.light);
    expect(region.value.statusBarBrightness, Brightness.dark);
  });

  testWidgets('DAY 1：Header 行程切換、全部/DAY selector 與當日 POI', (tester) async {
    TripMapCanvasConfig? mapConfig;
    await tester.pumpWidget(
      _buildScreen([
        _dayOne,
        _dayTwo,
      ], onMapConfig: (config) => mapConfig = config),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tp-root-glass-header')), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-title-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('tp-app-bar-back')), findsNothing);
    expect(find.byKey(const ValueKey('tp-app-bar-close')), findsNothing);

    final daySelector = find.byKey(const ValueKey('trip-map-day-selector'));
    expect(daySelector, findsOneWidget);
    expect(find.byKey(const ValueKey('trip-section-scope')), findsNothing);
    expect(find.byKey(const ValueKey('trip-map-itinerary')), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-map-more-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-map-notes-button')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('tp-root-glass-header')),
        matching: find.byKey(const ValueKey('trip-map-itinerary')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: daySelector,
        matching: find.byKey(const ValueKey('trip-map-itinerary')),
      ),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('trip-map-day-overview')), findsNothing);
    expect(find.text('全部'), findsOneWidget);
    expect(find.text('總覽'), findsNothing);
    expect(find.byType(SearchBar), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.byKey(const ValueKey('trip-map-day-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-map-day-2')), findsOneWidget);
    final selectedDay = tester
        .getSemantics(find.byKey(const ValueKey('trip-map-day-1')))
        .getSemanticsData();
    expect(selectedDay.label, '第 1 天，共 2 天');
    expect(selectedDay.flagsCollection.isSelected, Tristate.isTrue);
    expect(
      find.descendant(of: daySelector, matching: find.byType(GlassContainer)),
      findsOneWidget,
    );
    expect(find.byType(PageView), findsOneWidget);
    final pageView = tester.widget<PageView>(find.byType(PageView));
    expect(pageView.scrollDirection, Axis.horizontal);
    expect(pageView.controller!.viewportFraction, 0.74);
    expect(pageView.pageSnapping, isFalse);
    final headerRect = tester.getRect(
      find.byKey(const ValueKey('tp-root-glass-header')),
    );
    final selectorRect = tester.getRect(daySelector);
    expect(selectorRect.top - headerRect.bottom, closeTo(TpSpacing.s2, 1));
    expect(
      tester.getSize(find.byKey(const ValueKey('trip-map-poi-drawer'))).height,
      TpBottomAccessory.height,
    );
    expect(mapConfig?.initialMaxZoom, isNull);
    expect(mapConfig?.initialZoom, 13);
    expect(mapConfig?.initialFitPoints, isEmpty);
    expect(mapConfig?.initialCenter?.latitude, closeTo(26.2155, 0.00001));
    expect(mapConfig?.initialCenter?.longitude, closeTo(127.7035, 0.00001));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('trip-map-poi-drawer')),
        matching: find.byType(AnimatedContainer),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('trip-map-poi-drawer')),
        matching: find.byType(GlassContainer),
      ),
      findsOneWidget,
    );

    // pins：只顯示 DAY 1 且 master 座標非 null 的 2 筆
    expect(find.byKey(const ValueKey('map-pin-11')), findsOneWidget);
    expect(find.byKey(const ValueKey('map-pin-12')), findsOneWidget);
    expect(find.byKey(const ValueKey('map-pin-21')), findsNothing);
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
          .singleWhere((marker) => marker.id == 'map-pin-12')
          .glyph,
      '2',
    );
  });

  testWidgets('縮短 POI 卡並露出相鄰卡，提示可左右滑動', (tester) async {
    await tester.pumpWidget(_buildScreen([_dayOne, _dayTwo]));
    await tester.pumpAndSettle();

    final drawer = tester.getRect(
      find.byKey(const ValueKey('trip-map-poi-drawer')),
    );
    final neighbor = find.byKey(const ValueKey('entry-card-12'));
    expect(neighbor, findsOneWidget);
    final currentRect = tester.getRect(
      find.byKey(const ValueKey('entry-card-11')),
    );
    final neighborRect = tester.getRect(neighbor);
    expect(neighborRect.left, lessThan(drawer.right));
    expect(neighborRect.right, greaterThan(drawer.right));
    final visibleNeighborRatio =
        (drawer.right - neighborRect.left) / currentRect.width;
    expect(visibleNeighborRatio, greaterThan(0.30));
    expect(visibleNeighborRatio, lessThan(0.40));

    expect(
      find.descendant(of: neighbor, matching: find.byType(BackdropFilter)),
      findsNothing,
    );
  });

  testWidgets('POI 卡片與玻璃膠囊保留水平 8pt、垂直 4pt 空白', (tester) async {
    await tester.pumpWidget(_buildScreen([_dayOne, _dayTwo]));
    await tester.pumpAndSettle();

    final padding = tester.widget<Padding>(
      find.byKey(const ValueKey('trip-map-poi-card-padding-11')),
    );
    expect(
      padding.padding,
      const EdgeInsets.symmetric(
        horizontal: TpSpacing.s2,
        vertical: TpSpacing.s1,
      ),
    );
  });

  testWidgets('無座標日期維持城市 zoom，不以全行程座標縮成全日本', (tester) async {
    final coordinateLessDay = TripDay(
      id: 2,
      dayNum: 2,
      date: '2026-04-02',
      version: 1,
      timeline: [_entry(id: 21, title: '待確認景點', startTime: '10:00')],
    );
    final distantDay = TripDay(
      id: 3,
      dayNum: 3,
      date: '2026-04-03',
      version: 1,
      timeline: [
        _entry(
          id: 31,
          title: '東京車站',
          startTime: '09:00',
          lat: 35.681,
          lng: 139.767,
        ),
      ],
    );
    TripMapCanvasConfig? mapConfig;

    await tester.pumpWidget(
      _buildScreen(
        [_dayOne, coordinateLessDay, distantDay],
        initialDayNum: 2,
        onMapConfig: (config) => mapConfig = config,
      ),
    );
    await tester.pumpAndSettle();

    expect(mapConfig?.initialZoom, 13);
    expect(mapConfig?.initialFitPoints, isEmpty);
    expect(mapConfig?.initialCenter?.latitude, 26.217);
    expect(mapConfig?.initialCenter?.longitude, 127.719);
  });

  testWidgets('切到 DAY 02：只顯示該日內容且鏡頭維持 zoom 13', (tester) async {
    final nativeController = _FakeTripMapPlatformController();
    TripMapCanvasConfig? mapConfig;
    var attached = false;
    await tester.pumpWidget(
      _buildScreen(
        [_dayOne, _dayTwo],
        onMapConfig: (config) {
          mapConfig = config;
          if (attached) return;
          attached = true;
          config.controller.attach(nativeController);
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('entry-card-11')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('active-entry-card-11')), findsOneWidget);
    nativeController.moves.clear();

    await tester.tap(find.byKey(const ValueKey('trip-map-day-2')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('active-entry-card-11')), findsNothing);
    expect(find.byKey(const ValueKey('active-entry-card-21')), findsNothing);
    expect(find.byKey(const ValueKey('preview-entry-card-21')), findsOneWidget);
    expect(find.byKey(const ValueKey('map-pin-21')), findsOneWidget);
    expect(find.byKey(const ValueKey('map-pin-11')), findsNothing);
    expect(find.text('美麗海水族館'), findsOneWidget);
    expect(find.text('首里城'), findsNothing);
    expect(mapConfig?.initialZoom, 13);
    expect(mapConfig?.initialCenter?.latitude, 26.694);
    expect(mapConfig?.initialCenter?.longitude, 127.878);
    expect(nativeController.moves, isNotEmpty);
    expect(nativeController.moves.last.zoom, 13);
    expect(nativeController.moves.last.point.latitude, 26.694);
    expect(nativeController.moves.last.point.longitude, 127.878);
  });

  testWidgets('全部顯示所有日期的 POI', (tester) async {
    await tester.pumpWidget(_buildScreen([_dayOne, _dayTwo]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('全部'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('map-pin-11')), findsOneWidget);
    expect(find.byKey(const ValueKey('map-pin-21')), findsOneWidget);
  });

  testWidgets('地圖 Header 的行程按鈕切回同一天 timeline', (tester) async {
    await tester.pumpWidget(_buildScreen([_dayOne, _dayTwo]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('trip-map-day-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('trip-map-itinerary')));
    await tester.pumpAndSettle();

    expect(find.text('trip-timeline-route-trip-1-2'), findsOneWidget);
  });

  testWidgets('相鄰景點使用 /route 幾何繪製 Google polyline', (tester) async {
    final repository = _StubMapRepository();
    await tester.pumpWidget(_buildScreen([_dayOne], mapRepository: repository));
    await tester.pumpAndSettle();

    expect(repository.calls, 1);
    expect(find.byKey(const ValueKey('map-route-day-route-0')), findsOneWidget);
  });

  testWidgets('切換 Day 時立即移除前一日 route，再等待新 route', (tester) async {
    final repository = _DelayedSecondRouteRepository();
    final secondDay = TripDay(
      id: 2,
      dayNum: 2,
      version: 1,
      timeline: [
        _entry(id: 21, title: '首里城', lat: 26.217, lng: 127.719),
        _entry(id: 22, title: '國際通', lat: 26.214, lng: 127.688),
      ],
    );
    await tester.pumpWidget(
      _buildScreen([_dayOne, secondDay], mapRepository: repository),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('map-route-day-route-0')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('trip-map-day-2')));
    await tester.pump();

    expect(repository.calls, 2);
    expect(find.byKey(const ValueKey('map-route-day-route-0')), findsNothing);

    repository.secondRoute.complete(
      TripRouteResult(
        polyline: const [
          TripRoutePoint(lat: 26.217, lng: 127.719),
          TripRoutePoint(lat: 26.214, lng: 127.688),
        ],
        durationSeconds: 600,
        distanceMeters: 4200,
      ),
    );
    await tester.pumpAndSettle();

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

  testWidgets('點選 POI 後鏡頭維持城市 zoom 13', (tester) async {
    final nativeController = _FakeTripMapPlatformController();
    var attached = false;

    await tester.pumpWidget(
      _buildScreen(
        [_dayOne, _dayTwo],
        onMapConfig: (config) {
          if (attached) return;
          attached = true;
          config.controller.attach(nativeController);
        },
      ),
    );
    await tester.pumpAndSettle();
    nativeController.moves.clear();

    await tester.tap(find.byKey(const ValueKey('entry-card-11')));
    await tester.pumpAndSettle();

    expect(nativeController.moves.single.zoom, 13);
  });

  testWidgets('POI 卡顯示起訖時間與獨立分類，不顯示停留進度與箭頭', (tester) async {
    await tester.pumpWidget(_buildScreen([_dayOne]));
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey('entry-card-11'));
    expect(
      find.descendant(of: card, matching: find.text('09:00–10:30')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('景點')),
      findsOneWidget,
    );
    expect(find.textContaining('停留 1 /'), findsNothing);
    expect(
      find.descendant(
        of: card,
        matching: find.byIcon(CupertinoIcons.arrow_right),
      ),
      findsNothing,
    );
  });

  testWidgets('POI 卡將原始分類本地化，缺少時間時顯示明確狀態', (tester) async {
    final day = TripDay(
      id: 4,
      dayNum: 1,
      version: 1,
      timeline: [
        _entry(
          id: 41,
          title: '海上活動',
          category: 'sports_activity',
          lat: 26.2,
          lng: 127.7,
        ),
        _entry(
          id: 42,
          title: '空白分類餐廳',
          category: ' ',
          type: 'restaurant',
          lat: 26.21,
          lng: 127.71,
        ),
      ],
    );

    await tester.pumpWidget(_buildScreen([day]));
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey('entry-card-41'));
    expect(
      find.descendant(of: card, matching: find.text('時間未設定')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('運動活動')),
      findsOneWidget,
    );
    expect(find.text('sports_activity'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('entry-card-42')),
        matching: find.text('餐廳'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('POI 卡相容 legacy time，缺少結束時間時不製造假區間', (tester) async {
    final day = TripDay(
      id: 5,
      dayNum: 1,
      version: 1,
      timeline: [
        _entry(id: 51, title: '舊格式時間', time: '07:45', lat: 26.2, lng: 127.7),
        _entry(
          id: 52,
          title: '尚未排定結束',
          startTime: '08:00',
          endTime: ' ',
          lat: 26.21,
          lng: 127.71,
        ),
      ],
    );

    await tester.pumpWidget(_buildScreen([day]));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('entry-card-51')),
        matching: find.text('07:45'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('entry-card-52')),
        matching: find.text('08:00'),
      ),
      findsOneWidget,
    );
    expect(find.text('時間未設定'), findsNothing);
  });

  testWidgets('marker 點擊與左右滑卡會雙向同步地圖聚焦', (tester) async {
    TripMapCanvasConfig? mapConfig;
    final nativeController = _FakeTripMapPlatformController();
    var attached = false;
    await tester.pumpWidget(
      _buildScreen(
        [_dayOne, _dayTwo],
        onMapConfig: (config) {
          mapConfig = config;
          if (attached) return;
          attached = true;
          config.controller.attach(nativeController);
        },
      ),
    );
    await tester.pumpAndSettle();
    nativeController.moves.clear();

    await tester.tap(find.byKey(const ValueKey('map-pin-12')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('active-entry-card-12')), findsOneWidget);
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 1);
    expect(nativeController.moves, hasLength(1));
    nativeController.moves.clear();

    await tester.drag(find.byType(PageView), const Offset(700, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('active-entry-card-11')), findsOneWidget);
    expect(nativeController.moves, hasLength(1));
    expect(nativeController.moves.single.zoom, 13);
    expect(nativeController.moves.single.point.latitude, 26.217);
    expect(nativeController.moves.single.point.longitude, 127.719);
    final first = mapConfig!.markers.singleWhere(
      (marker) => marker.id == 'map-pin-11',
    );
    final second = mapConfig!.markers.singleWhere(
      (marker) => marker.id == 'map-pin-12',
    );
    expect(first.zIndex, greaterThan(second.zIndex));
  });

  testWidgets('Day 沒有 POI 時隱藏底部配件並顯示地圖內空狀態', (tester) async {
    TripMapCanvasConfig? mapConfig;
    final emptyDay = TripDay(id: 7, dayNum: 1, version: 1, timeline: const []);

    await tester.pumpWidget(
      _buildScreen([emptyDay], onMapConfig: (config) => mapConfig = config),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('trip-map-poi-drawer')), findsNothing);
    expect(find.byType(PageView), findsNothing);
    expect(find.text('此範圍尚無地點座標'), findsOneWidget);
    expect(
      mapConfig!.initialPadding.bottom,
      TpRootTabGeometry.expandedHeightFor(0) + TpSpacing.s6,
    );
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
        TpBottomAccessory.height + expectedRootClearance + TpSpacing.s1,
      ),
    );
    final drawerRect = tester.getRect(
      find.byKey(const ValueKey('trip-map-poi-drawer')),
    );
    expect(
      tester.view.physicalSize.height / tester.view.devicePixelRatio -
          drawerRect.bottom,
      expectedRootClearance + TpSpacing.s1,
    );
  });

  testWidgets('真實浮動 root tab 下 POI accessory 保留 4pt 間距', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _buildScreen(
        [_dayOne],
        viewPadding: const EdgeInsets.only(bottom: 34),
        withRootTab: true,
      ),
    );
    await tester.pumpAndSettle();

    final poi = tester.getRect(
      find.byKey(const ValueKey('trip-map-poi-drawer')),
    );
    final rootTab = tester.getRect(
      find.byKey(const ValueKey('apple-root-tab-bar')),
    );
    final accessoryContext = tester.element(find.byType(TpBottomAccessory));
    expect(MediaQuery.paddingOf(accessoryContext).bottom, rootTab.height);
    expect(poi.bottom, lessThanOrEqualTo(rootTab.top - TpSpacing.s1));
  });

  testWidgets('320×568 與 135% 文字使用 accessibility rail 且 selector 不撞定位鈕', (
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
      closeTo(112.5, 0.01),
    );
    final selector = tester.getRect(
      find.byKey(const ValueKey('trip-map-day-selector')),
    );
    final locate = tester.getRect(
      find.byKey(const ValueKey('trip-map-locate-button')),
    );
    expect(selector.bottom, lessThanOrEqualTo(locate.top));
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
    expect(find.byKey(const ValueKey('preview-entry-card-11')), findsOneWidget);
  });

  testWidgets('最大 Accessibility Size 不溢出 POI rail', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _buildScreen([_dayOne], textScaler: const TextScaler.linear(3)),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('preview-entry-card-11')), findsOneWidget);
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

  testWidgets('定位受限制時只在點擊後顯示可理解的設定入口', (tester) async {
    final locationService = _RestrictedLocationService();
    final settingsTargets = <TripMapLocationSettingsTarget>[];
    var settingsCalls = 0;
    await tester.pumpWidget(
      _buildScreen(
        [_dayOne],
        locationService: locationService,
        locationSettingsOpener: (target) async {
          settingsTargets.add(target);
          settingsCalls++;
          if (settingsCalls == 1) return false;
          throw StateError('platform failure');
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(locationService.calls, 0);
    expect(find.text('開啟設定'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('trip-map-locate-button')));
    await tester.pumpAndSettle();

    expect(locationService.calls, 1);
    expect(find.text('定位權限遭拒或受限制，請前往「設定」允許定位'), findsOneWidget);
    expect(find.text('開啟設定'), findsOneWidget);

    await tester.tap(find.text('開啟設定'));
    await tester.pumpAndSettle();

    expect(settingsTargets, [TripMapLocationSettingsTarget.application]);
    expect(find.text('無法自動開啟設定，請手動前往系統「設定」允許定位'), findsOneWidget);

    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();

    expect(settingsCalls, 2);
    expect(tester.takeException(), isNull);
    expect(find.text('無法自動開啟設定，請手動前往系統「設定」允許定位'), findsOneWidget);
  });

  testWidgets('定位服務未開啟時導向定位服務設定', (tester) async {
    final targets = <TripMapLocationSettingsTarget>[];
    await tester.pumpWidget(
      _buildScreen(
        [_dayOne],
        locationService: _RestrictedLocationService(
          settingsTarget: TripMapLocationSettingsTarget.locationService,
        ),
        locationSettingsOpener: (target) async {
          targets.add(target);
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('trip-map-locate-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('開啟設定'));
    await tester.pumpAndSettle();

    expect(targets, [TripMapLocationSettingsTarget.locationService]);
    expect(find.byKey(const ValueKey('app-error-banner')), findsNothing);
  });

  testWidgets('行程切換選單：可從地圖切到另一個行程', (tester) async {
    final nativeController = _FakeTripMapPlatformController();
    TripMapController? attachedController;
    await tester.pumpWidget(
      _buildScreen(
        [_dayOne, _dayTwo],
        renderSelectedTripMap: true,
        onMapConfig: (config) {
          if (identical(attachedController, config.controller)) return;
          attachedController = config.controller;
          config.controller.attach(nativeController);
        },
        trips: const [
          TripSummary(tripId: 'trip-1', name: 'okinawa', title: '沖繩家族旅行'),
          TripSummary(tripId: 'trip-2', name: 'tokyo', title: '東京週末'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('trip-map-trip-picker')));
    await tester.pumpAndSettle();
    final sheet = tester.widget<GlassModalSheetScaffold>(
      find.byType(GlassModalSheetScaffold),
    );
    expect(find.text('切換行程'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('完成'), findsNothing);
    expect(find.byType(TabBar), findsNothing);
    expect(sheet.initialState, GlassSheetState.full);
    expect(sheet.halfSize, 0.93);
    expect(sheet.fullSize, 0.93);
    expect(sheet.showDragIndicator, isFalse);

    nativeController.moves.clear();
    await tester.tap(find.byKey(const ValueKey('trip-picker-item-trip-2')));
    await tester.pumpAndSettle();

    expect(find.text('東京週末'), findsOneWidget);
    expect(nativeController.moves, isNotEmpty);
    expect(nativeController.moves.last.zoom, 13);
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
    expect(find.byKey(const ValueKey('preview-entry-card-31')), findsOneWidget);
    expect(find.text('自由活動'), findsOneWidget);
    expect(find.textContaining('尚無位置'), findsOneWidget);
  });
}
