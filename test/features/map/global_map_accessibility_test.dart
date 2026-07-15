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

class _SequencedLocationService implements TripMapLocationService {
  int calls = 0;

  @override
  Future<TripMapPoint> currentLocation() async {
    calls++;
    if (calls == 1) {
      throw const TripMapLocationException('請開啟定位權限');
    }
    return const TripMapPoint(26.215, 127.72);
  }
}

const _trip = TripSummary(tripId: 'okinawa', name: 'okinawa', title: '沖繩旅行');

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

Widget _buildApp({TripMapLocationService? locationService}) {
  return ProviderScope(
    overrides: [
      cacheStoreProvider.overrideWithValue(InMemoryCacheStore()),
      myTripsProvider.overrideWith((ref) => Stream.value(const [_trip])),
      tripDaysProvider.overrideWith((ref, tripId) => Stream.value([_day])),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: GlobalMapScreen(
        mapBuilder: fakeTripMapBuilder,
        locationService: locationService,
      ),
    ),
  );
}

void main() {
  testWidgets('地圖 marker 提供 44pt 點擊區與名稱語意', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    final marker = find.byKey(const ValueKey('map-pin-11'));
    expect(tester.getSize(marker), const Size(44, 44));
    expect(find.bySemanticsLabel('1. 首里城，DAY 1'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('定位失敗持續顯示且可直接重試', (tester) async {
    final location = _SequencedLocationService();
    await tester.pumpWidget(_buildApp(locationService: location));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('trip-map-locate-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-error-banner')), findsOneWidget);
    expect(find.text('請開啟定位權限'), findsOneWidget);

    await tester.pump(const Duration(seconds: 10));
    expect(find.text('請開啟定位權限'), findsOneWidget);

    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();

    expect(location.calls, 2);
    expect(find.byKey(const ValueKey('app-error-banner')), findsNothing);
    expect(
      find.byKey(const ValueKey('trip-map-user-location')),
      findsOneWidget,
    );
  });
}
