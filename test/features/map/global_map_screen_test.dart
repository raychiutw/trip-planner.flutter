import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/map/global_map_screen.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/theme/app_theme.dart';

class _MockTripRepository extends Mock implements TripRepository {}

class _TransparentTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(TileProvider.transparentImage);
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

final _okinawaDay = TripDay(
  id: 1,
  dayNum: 1,
  date: '2026-04-01',
  version: 1,
  timeline: [
    _entry(id: 11, title: '首里城', startTime: '09:00', lat: 26.217, lng: 127.719),
  ],
);

final _tokyoDay = TripDay(
  id: 2,
  dayNum: 1,
  date: '2026-05-01',
  version: 1,
  timeline: [
    _entry(
      id: 21,
      title: '東京塔',
      startTime: '10:00',
      lat: 35.6586,
      lng: 139.7454,
    ),
  ],
);

const _okinawaTrip = TripSummary(
  tripId: 'okinawa-trip-2026',
  name: 'okinawa-trip-2026',
  title: '沖繩家族旅行',
  totalDays: 3,
);

const _tokyoTrip = TripSummary(
  tripId: 'tokyo-trip-2026',
  name: 'tokyo-trip-2026',
  title: '東京快閃',
  totalDays: 1,
);

Widget _buildApp(_MockTripRepository repository) {
  return ProviderScope(
    overrides: [tripRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: GlobalMapScreen(tileProvider: _TransparentTileProvider()),
    ),
  );
}

void main() {
  late _MockTripRepository repository;

  setUp(() {
    repository = _MockTripRepository();
  });

  testWidgets('沒有行程時顯示 empty state 與新增行程 CTA', (tester) async {
    when(repository.fetchMyTrips).thenAnswer((_) async => const []);

    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    expect(find.text('還沒有行程可以看'), findsOneWidget);
    expect(find.byKey(const ValueKey('global-map-new-trip')), findsOneWidget);
    expect(find.byType(FlutterMap), findsNothing);
  });

  testWidgets('載入第一個行程地圖，並可切換其他行程', (tester) async {
    when(
      repository.fetchMyTrips,
    ).thenAnswer((_) async => const [_okinawaTrip, _tokyoTrip]);
    when(
      () => repository.fetchDays('okinawa-trip-2026'),
    ).thenAnswer((_) async => [_okinawaDay]);
    when(
      () => repository.fetchDays('tokyo-trip-2026'),
    ).thenAnswer((_) async => [_tokyoDay]);

    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('global-map-trip-picker')),
      findsOneWidget,
    );
    expect(find.text('沖繩家族旅行'), findsOneWidget);
    expect(find.byKey(const ValueKey('map-pin-11')), findsOneWidget);
    expect(find.text('首里城'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('global-map-trip-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('東京快閃').last);
    await tester.pumpAndSettle();

    expect(find.text('東京快閃'), findsOneWidget);
    expect(find.byKey(const ValueKey('map-pin-21')), findsOneWidget);
    expect(find.text('東京塔'), findsOneWidget);
    expect(find.text('首里城'), findsNothing);
  });
}
