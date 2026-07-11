import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/route_repository.dart';
import 'package:tripline/features/map/global_map_screen.dart';
import 'package:tripline/features/trip_detail/trip_providers.dart';
import 'package:tripline/features/trips/trips_list_screen.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/models/route_result.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/theme/app_theme.dart';

// /map 改為「行程總覽」:trip picker 切換行程 → 顯示該行程每天景點與路線
// (共用 TripDayMapView)。GoogleMap 為 platform view,widget test 不真渲染,
// 故以「底部 entry card(與可見 pin 一對一)」與 picker 標題間接驗證。

/// 折線查詢固定回 null,避免打真實網路。
class _NullRouteRepository implements RouteRepository {
  @override
  ApiClient get client => throw UnimplementedError();

  @override
  Future<RouteResult?> fetchRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async => null;
}

TimelineEntry _entry({
  required int id,
  required String title,
  double? lat,
  double? lng,
}) {
  return TimelineEntry(
    id: id,
    sortOrder: 0,
    title: title,
    version: 1,
    master: (lat == null || lng == null)
        ? null
        : EntryPoiInfo(poiId: id * 10, name: title, lat: lat, lng: lng),
  );
}

final _tripADays = [
  TripDay(
    id: 1,
    dayNum: 1,
    version: 1,
    timeline: [_entry(id: 101, title: 'A-景點', lat: 25.0, lng: 121.5)],
  ),
];
final _tripBDays = [
  TripDay(
    id: 2,
    dayNum: 1,
    version: 1,
    timeline: [_entry(id: 201, title: 'B-景點', lat: 26.0, lng: 127.7)],
  ),
];

const _tripA = TripSummary(tripId: 'trip-a', name: '東京五日');
const _tripB = TripSummary(tripId: 'trip-b', name: '沖繩三日');

Widget _buildScreen({
  required List<TripSummary> trips,
  Map<String, List<TripDay>> daysByTrip = const {},
}) {
  return ProviderScope(
    overrides: [
      myTripsProvider.overrideWith((ref) => Stream.value(trips)),
      tripDaysProvider.overrideWith(
        (ref, tripId) => Stream.value(daysByTrip[tripId] ?? const []),
      ),
      routeRepositoryProvider.overrideWithValue(_NullRouteRepository()),
    ],
    child: MaterialApp(theme: AppTheme.light(), home: const GlobalMapScreen()),
  );
}

void main() {
  testWidgets('有行程:預設顯示第一個行程名與其 entry cards', (tester) async {
    await tester.pumpWidget(
      _buildScreen(
        trips: [_tripA, _tripB],
        daysByTrip: {'trip-a': _tripADays, 'trip-b': _tripBDays},
      ),
    );
    await tester.pumpAndSettle();

    // picker 標題顯示第一個行程名;body 顯示其 entry card(101),非第二個(201)。
    expect(find.text('東京五日'), findsOneWidget);
    expect(find.byKey(const ValueKey('entry-card-101')), findsOneWidget);
    expect(find.byKey(const ValueKey('entry-card-201')), findsNothing);
  });

  testWidgets('切換行程:picker 選第二個 → 改顯示其 entry cards', (tester) async {
    await tester.pumpWidget(
      _buildScreen(
        trips: [_tripA, _tripB],
        daysByTrip: {'trip-a': _tripADays, 'trip-b': _tripBDays},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('trip-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('picker-trip-trip-b')));
    await tester.pumpAndSettle();

    expect(find.text('沖繩三日'), findsOneWidget);
    expect(find.byKey(const ValueKey('entry-card-201')), findsOneWidget);
    expect(find.byKey(const ValueKey('entry-card-101')), findsNothing);
  });

  testWidgets('無行程:顯示提示', (tester) async {
    await tester.pumpWidget(_buildScreen(trips: []));
    await tester.pumpAndSettle();

    expect(find.text('還沒有行程'), findsOneWidget);
  });
}
