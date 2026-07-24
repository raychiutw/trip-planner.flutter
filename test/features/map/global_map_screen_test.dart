import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/cache/cache_store.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/features/map/global_map_screen.dart';
import 'package:tripline/features/map/map_adapter.dart';
import 'package:tripline/features/map/map_location.dart';
import 'package:tripline/features/trip_detail/trip_providers.dart';
import 'package:tripline/features/trips/current_trip_provider.dart';
import 'package:tripline/features/trips/trips_list_screen.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/models/trip.dart';
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

const _trips = [
  TripSummary(tripId: 'okinawa', name: 'okinawa', title: '沖繩旅行'),
  TripSummary(tripId: 'tokyo', name: 'tokyo', title: '東京週末'),
];

final _day = TripDay(
  id: 1,
  dayNum: 1,
  version: 1,
  timeline: const [
    TimelineEntry(
      id: 11,
      sortOrder: 0,
      title: '首里城',
      version: 1,
      master: EntryPoiInfo(poiId: 110, name: '首里城', lat: 26.217, lng: 127.719),
    ),
  ],
);

final _dayTwo = TripDay(
  id: 2,
  dayNum: 2,
  version: 1,
  timeline: const [
    TimelineEntry(
      id: 22,
      sortOrder: 0,
      title: '淺草寺',
      version: 1,
      master: EntryPoiInfo(
        poiId: 220,
        name: '淺草寺',
        lat: 35.7148,
        lng: 139.7967,
      ),
    ),
  ],
);

void main() {
  Widget buildApp({
    List<TripSummary> trips = _trips,
    Stream<List<TripSummary>>? tripsStream,
    List<TripDay>? days,
    Map<String, List<TripDay>>? daysByTrip,
    InMemoryCacheStore? cacheStore,
    TripMapLocationService? locationService,
    ValueChanged<TripMapCanvasConfig>? onMapConfig,
    String? initialTripId,
  }) {
    return ProviderScope(
      overrides: [
        cacheStoreProvider.overrideWithValue(
          cacheStore ?? InMemoryCacheStore(),
        ),
        myTripsProvider.overrideWith(
          (ref) => tripsStream ?? Stream.value(trips),
        ),
        tripDaysProvider.overrideWith(
          (ref, tripId) => Stream.value(daysByTrip?[tripId] ?? days ?? [_day]),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: GlobalMapScreen(
          initialTripId: initialTripId,
          mapBuilder: (config) {
            onMapConfig?.call(config);
            return fakeTripMapBuilder(config);
          },
          locationService: locationService,
        ),
      ),
    );
  }

  testWidgets('根地圖預設顯示第一個行程，而非跨收藏地圖', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tp-root-glass-header')), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-title-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('tp-app-bar-back')), findsNothing);
    expect(find.byKey(const ValueKey('tp-app-bar-close')), findsNothing);
    expect(find.text('沖繩旅行'), findsOneWidget);
    expect(find.byKey(const ValueKey('account-avatar-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('map-pin-11')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('global-trip-map-okinawa')),
      findsOneWidget,
    );
  });

  testWidgets('根地圖的原生 Google POI 使用同一個底部 accessory', (tester) async {
    TripMapCanvasConfig? mapConfig;
    await tester.pumpWidget(
      buildApp(onMapConfig: (config) => mapConfig = config),
    );
    await tester.pumpAndSettle();

    mapConfig!.onGooglePoiSelected!(
      const GoogleMapPoiSelection(
        placeId: 'ChIJ-test',
        name: '清水寺',
        point: TripMapPoint(34.9948, 135.785),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('google-poi-accessory')), findsOneWidget);
    expect(find.byKey(const ValueKey('tp-bottom-accessory')), findsOneWidget);
  });

  testWidgets('切換行程會留在根地圖並更新目前行程', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('trip-map-trip-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('trip-picker-item-tokyo')));
    await tester.pumpAndSettle();

    expect(find.text('東京週末'), findsOneWidget);
    expect(find.byKey(const ValueKey('global-trip-map-tokyo')), findsOneWidget);
  });

  testWidgets('切換行程保留目標也存在的 DAY', (tester) async {
    await tester.pumpWidget(
      buildApp(
        daysByTrip: {
          'okinawa': [_day, _dayTwo],
          'tokyo': [_day, _dayTwo],
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('trip-map-day-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('trip-map-trip-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('trip-picker-item-tokyo')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('map-pin-22')), findsOneWidget);
    expect(find.byKey(const ValueKey('map-pin-11')), findsNothing);
  });

  testWidgets('切換行程缺少原 DAY 時回 Day 1 並清除舊 POI', (tester) async {
    TripMapCanvasConfig? mapConfig;
    await tester.pumpWidget(
      buildApp(
        daysByTrip: {
          'okinawa': [_day, _dayTwo],
          'tokyo': [_day],
        },
        onMapConfig: (config) => mapConfig = config,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('trip-map-day-2')));
    await tester.pumpAndSettle();
    mapConfig!.onGooglePoiSelected!(
      const GoogleMapPoiSelection(
        placeId: 'old-trip-poi',
        name: '舊行程景點',
        point: TripMapPoint(35.7, 139.8),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('google-poi-accessory')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('trip-map-trip-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('trip-picker-item-tokyo')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('map-pin-11')), findsOneWidget);
    expect(find.byKey(const ValueKey('google-poi-accessory')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('trip-map-trip-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('trip-picker-item-okinawa')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('map-pin-11')), findsOneWidget);
    expect(find.byKey(const ValueKey('map-pin-22')), findsNothing);
  });

  testWidgets('從持久 cache 恢復上次查看的行程', (tester) async {
    final store = InMemoryCacheStore();
    await store.writeResponse('ui:last-map-trip', 'tokyo');

    await tester.pumpWidget(buildApp(cacheStore: store));
    await tester.pumpAndSettle();

    expect(find.text('東京週末'), findsOneWidget);
    expect(find.byKey(const ValueKey('global-trip-map-tokyo')), findsOneWidget);
  });

  testWidgets('cache 行程失效時先顯示第一筆且保留選擇等待 fresh list', (tester) async {
    final store = InMemoryCacheStore();
    await store.writeResponse('ui:last-map-trip', 'deleted-trip');

    await tester.pumpWidget(buildApp(cacheStore: store));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('global-trip-map-okinawa')),
      findsOneWidget,
    );
    expect(
      (await store.readResponse('ui:last-map-trip'))?.data,
      'deleted-trip',
    );
  });

  testWidgets('stale list 缺少深連結行程時 fresh list 仍恢復正確行程', (tester) async {
    final tripsStream = StreamController<List<TripSummary>>();
    addTearDown(tripsStream.close);
    tripsStream.add([_trips.first]);

    await tester.pumpWidget(
      buildApp(tripsStream: tripsStream.stream, initialTripId: 'tokyo'),
    );
    await tester.pumpAndSettle();
    tripsStream.add(_trips);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('global-trip-map-tokyo')), findsOneWidget);
  });

  testWidgets('offstage 時延後套用共享行程，回到地圖才重建', (tester) async {
    final store = InMemoryCacheStore();
    await store.writeResponse('ui:last-map-trip', 'okinawa');
    final tripsStream = StreamController<List<TripSummary>>();
    addTearDown(tripsStream.close);
    tripsStream.add(_trips);
    final container = ProviderContainer(
      overrides: [
        cacheStoreProvider.overrideWithValue(store),
        myTripsProvider.overrideWith((ref) => tripsStream.stream),
        tripDaysProvider.overrideWith((ref, tripId) => Stream.value([_day])),
      ],
    );
    addTearDown(container.dispose);
    await container.read(currentTripIdProvider.future);

    Widget app({required bool active}) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: TickerMode(
          enabled: active,
          child: GlobalMapScreen(mapBuilder: fakeTripMapBuilder),
        ),
      ),
    );

    await tester.pumpWidget(app(active: true));
    await tester.pumpAndSettle();
    await tester.pumpWidget(app(active: false));
    await tester.pumpAndSettle();
    await container.read(currentTripIdProvider.notifier).select('tokyo');
    tripsStream.add(List.of(_trips));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('global-trip-map-okinawa')),
      findsOneWidget,
    );

    await tester.pumpWidget(app(active: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('global-trip-map-tokyo')), findsOneWidget);
  });

  testWidgets('定位按鈕取得目前位置後顯示 Google Maps user marker', (tester) async {
    final locationService = _FakeLocationService();
    await tester.pumpWidget(buildApp(locationService: locationService));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('trip-map-locate-button')));
    await tester.pumpAndSettle();

    expect(locationService.calls, 1);
    expect(
      find.byKey(const ValueKey('trip-map-user-location')),
      findsOneWidget,
    );
  });

  testWidgets('沒有行程時顯示單一新增行程動作', (tester) async {
    await tester.pumpWidget(buildApp(trips: const []));
    await tester.pumpAndSettle();

    expect(find.text('尚無行程'), findsNWidgets(2));
    expect(find.byKey(const ValueKey('account-avatar-button')), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '新增行程'), findsOneWidget);
    expect(find.byKey(const ValueKey('fake-trip-map-canvas')), findsNothing);
  });
}
