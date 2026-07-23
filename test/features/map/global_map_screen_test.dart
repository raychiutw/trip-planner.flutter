import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/cache/cache_store.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/features/map/global_map_screen.dart';
import 'package:tripline/features/map/map_adapter.dart';
import 'package:tripline/features/map/map_location.dart';
import 'package:tripline/features/trip_detail/trip_providers.dart';
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

void main() {
  Widget buildApp({
    List<TripSummary> trips = _trips,
    List<TripDay>? days,
    InMemoryCacheStore? cacheStore,
    TripMapLocationService? locationService,
    ValueChanged<TripMapCanvasConfig>? onMapConfig,
  }) {
    return ProviderScope(
      overrides: [
        cacheStoreProvider.overrideWithValue(
          cacheStore ?? InMemoryCacheStore(),
        ),
        myTripsProvider.overrideWith((ref) => Stream.value(trips)),
        tripDaysProvider.overrideWith(
          (ref, tripId) => Stream.value(days ?? [_day]),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: GlobalMapScreen(
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

  testWidgets('從持久 cache 恢復上次查看的行程', (tester) async {
    final store = InMemoryCacheStore();
    await store.writeResponse('ui:last-map-trip', 'tokyo');

    await tester.pumpWidget(buildApp(cacheStore: store));
    await tester.pumpAndSettle();

    expect(find.text('東京週末'), findsOneWidget);
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

    expect(find.text('先建立行程'), findsOneWidget);
    expect(find.byKey(const ValueKey('account-avatar-button')), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '新增行程'), findsOneWidget);
    expect(find.byKey(const ValueKey('fake-trip-map-canvas')), findsNothing);
  });
}
