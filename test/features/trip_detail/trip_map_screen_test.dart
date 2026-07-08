import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tripline/features/trip_detail/trip_map_screen.dart';
import 'package:tripline/features/trip_detail/trip_providers.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/theme/app_theme.dart';

/// 測試用 tile provider：回傳套件內建透明圖，避免 widget test 對 OSM 發網路請求。
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
  String initialLocation = '/trips/trip-1/map',
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/trips/:tripId/map',
        builder: (context, state) => TripMapScreen(
          tripId: state.pathParameters['tripId']!,
          tileProvider: _TransparentTileProvider(),
        ),
      ),
      GoRoute(
        path: '/trips/:tripId/stop/:entryId/map',
        builder: (context, state) => TripMapScreen(
          tripId: state.pathParameters['tripId']!,
          focusEntryId: int.tryParse(state.pathParameters['entryId'] ?? ''),
          tileProvider: _TransparentTileProvider(),
        ),
      ),
    ],
  );
  return ProviderScope(
    overrides: [tripDaysProvider.overrideWith((ref, tripId) async => days)],
    child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
}

BoxDecoration _pinDecoration(WidgetTester tester, int entryId) {
  final pinDot = tester.widget<Container>(
    find.byKey(ValueKey('map-pin-dot-$entryId')),
  );
  return pinDot.decoration! as BoxDecoration;
}

BorderSide _cardBorderSide(WidgetTester tester, int entryId) {
  final card = tester.widget<Card>(
    find.byKey(ValueKey('entry-card-shell-$entryId')),
  );
  final shape = card.shape! as RoundedRectangleBorder;
  return shape.side;
}

List<Polyline<Object>> _routePolylines(WidgetTester tester) {
  final layer = tester.widget<PolylineLayer<Object>>(
    find.byKey(const ValueKey('trip-map-polylines')),
  );
  return layer.polylines;
}

void main() {
  testWidgets('總覽：渲染 day tabs、全部含座標 pins 與 entry cards、OSM attribution', (
    tester,
  ) async {
    await tester.pumpWidget(_buildScreen([_dayOne, _dayTwo]));
    await tester.pumpAndSettle();

    // day tabs：總覽 + DAY NN
    expect(find.text('總覽'), findsOneWidget);
    expect(find.text('DAY 01'), findsOneWidget);
    expect(find.text('DAY 02'), findsOneWidget);

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

    // OSM attribution 必須顯示
    expect(find.byType(RichAttributionWidget), findsOneWidget);
  });

  testWidgets('總覽：依 day 渲染路線 polyline', (tester) async {
    await tester.pumpWidget(_buildScreen([_dayOne, _dayTwo]));
    await tester.pumpAndSettle();

    final polylines = _routePolylines(tester);
    expect(polylines, hasLength(1));
    expect(polylines.single.points, hasLength(2));
    expect(polylines.single.color, kDayPinPalette.first);
  });

  testWidgets('切到 DAY 02：只顯示該日 pins 與 entry cards', (tester) async {
    await tester.pumpWidget(_buildScreen([_dayOne, _dayTwo]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('DAY 02'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('map-pin-21')), findsOneWidget);
    expect(find.byKey(const ValueKey('map-pin-11')), findsNothing);
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

  testWidgets('點 entry card 會同步選取對應 pin 與 card', (tester) async {
    await tester.pumpWidget(_buildScreen([_dayOne, _dayTwo]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('entry-card-12')));
    await tester.pumpAndSettle();

    final selectedPinBorder = _pinDecoration(tester, 12).border! as Border;
    expect(selectedPinBorder.top.width, 4);
    expect(_cardBorderSide(tester, 12).width, 2);
  });

  testWidgets('點 pin 會同步選取對應 card', (tester) async {
    await tester.pumpWidget(_buildScreen([_dayOne, _dayTwo]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('map-pin-12')));
    await tester.pumpAndSettle();

    expect(_cardBorderSide(tester, 12).width, 2);
  });

  testWidgets('總覽點 pin 會切到該 entry 所在 day', (tester) async {
    await tester.pumpWidget(_buildScreen([_dayOne, _dayTwo]));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('map-pin-11')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('map-pin-21')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('map-pin-21')), findsOneWidget);
    expect(find.byKey(const ValueKey('entry-card-21')), findsOneWidget);
    expect(find.text('美麗海水族館'), findsOneWidget);
    expect(find.byKey(const ValueKey('map-pin-11')), findsNothing);
    expect(find.text('首里城'), findsNothing);
  });

  testWidgets('focus route 初載切到 entry 所在日並只顯示該日 pins/cards', (tester) async {
    await tester.pumpWidget(
      _buildScreen([
        _dayOne,
        _dayTwo,
      ], initialLocation: '/trips/trip-1/stop/21/map'),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('map-pin-21')), findsOneWidget);
    expect(find.byKey(const ValueKey('entry-card-21')), findsOneWidget);
    expect(find.text('美麗海水族館'), findsOneWidget);
    expect(find.byKey(const ValueKey('map-pin-11')), findsNothing);
    expect(find.text('首里城'), findsNothing);
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
    expect(find.byType(FlutterMap), findsNothing);
  });
}
