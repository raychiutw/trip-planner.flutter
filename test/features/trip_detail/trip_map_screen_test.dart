import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/route_repository.dart';
import 'package:tripline/features/trip_detail/trip_map_screen.dart';
import 'package:tripline/features/trip_detail/trip_providers.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/models/route_result.dart';
import 'package:tripline/theme/app_theme.dart';

/// 記錄 fetchRoute 呼叫的假 repo;預設回 null(無折線、不觸網),供多數測試用。
/// 傳 onFetch 可回傳指定 RouteResult。
class _FakeRouteRepository implements RouteRepository {
  _FakeRouteRepository({this.onFetch});

  final List<String> calls = [];
  final RouteResult? Function(
    double fromLat,
    double fromLng,
    double toLat,
    double toLng,
  )?
  onFetch;

  @override
  ApiClient get client => throw UnimplementedError();

  @override
  Future<RouteResult?> fetchRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    calls.add('$fromLat,$fromLng->$toLat,$toLng');
    return onFetch?.call(fromLat, fromLng, toLat, toLng);
  }
}

// google_maps_flutter 的 GoogleMap 是 platform view,widget test 無法真渲染,
// 也不能靠 marker widget key 斷言(marker 是原生 BitmapDescriptor)。故 pin 萃取
// 與日切換改由「底部 entry card(與可見 pin 一對一)」間接驗證。

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
    // 無座標 entry:不應產生 pin 與 entry card。
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

Widget _buildScreen(List<TripDay> days, {RouteRepository? routeRepository}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const TripMapScreen(tripId: 'trip-1'),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      tripDaysProvider.overrideWith((ref, tripId) => Stream.value(days)),
      // 統一注入假 route repo,避免 _resolveRoutes 打真實網路。
      routeRepositoryProvider.overrideWithValue(
        routeRepository ?? _FakeRouteRepository(),
      ),
    ],
    child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
}

void main() {
  testWidgets('總覽:day tabs + 每個含座標 entry 都有 card(無座標則無)', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_buildScreen([_dayOne, _dayTwo]));
    await tester.pumpAndSettle();

    // day tabs:總覽 + DAY NN
    expect(find.text('總覽'), findsOneWidget);
    expect(find.text('DAY 01'), findsOneWidget);
    expect(find.text('DAY 02'), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(const ValueKey('trip-map-tab-0'))),
      matchesSemantics(
        label: '總覽',
        isSelected: true,
        hasSelectedState: true,
        isButton: true,
        hasTapAction: true,
      ),
    );

    // 每個含座標 entry(11/12/21)都有底部 card;無座標(13)沒有 → 驗證 pin 萃取
    expect(find.byKey(const ValueKey('entry-card-11')), findsOneWidget);
    expect(find.byKey(const ValueKey('entry-card-12')), findsOneWidget);
    expect(find.byKey(const ValueKey('entry-card-21')), findsOneWidget);
    expect(find.byKey(const ValueKey('entry-card-13')), findsNothing);
    expect(find.text('首里城'), findsOneWidget);
    expect(find.textContaining('09:00'), findsOneWidget);
    expect(find.text('自由活動'), findsNothing);
    semantics.dispose();
  });

  testWidgets('切到 DAY 02:只顯示該日 entry cards', (tester) async {
    await tester.pumpWidget(_buildScreen([_dayOne, _dayTwo]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('DAY 02'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('entry-card-21')), findsOneWidget);
    expect(find.byKey(const ValueKey('entry-card-11')), findsNothing);
    expect(find.text('美麗海水族館'), findsOneWidget);
    expect(find.text('首里城'), findsNothing);
  });

  testWidgets('點 entry card:呼叫地圖 move 且不 crash', (tester) async {
    await tester.pumpWidget(_buildScreen([_dayOne, _dayTwo]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('entry-card-12')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('全部 entry 無座標:顯示空狀態、不渲染 GoogleMap', (tester) async {
    final dayWithoutCoordinates = TripDay(
      id: 3,
      dayNum: 1,
      version: 1,
      timeline: [_entry(id: 31, title: '自由活動', startTime: '10:00')],
    );
    await tester.pumpWidget(_buildScreen([dayWithoutCoordinates]));
    await tester.pumpAndSettle();

    expect(find.text('此行程尚無地點座標'), findsOneWidget);
    expect(find.byType(GoogleMap), findsNothing);
  });

  testWidgets('總覽:相鄰同日 pin 對打 /api/route(不跨日、單 pin 日略過)', (tester) async {
    final fake = _FakeRouteRepository(
      onFetch: (fromLat, fromLng, toLat, toLng) => const RouteResult(
        polyline: [(lat: 26.217, lng: 127.719), (lat: 26.214, lng: 127.688)],
        distanceM: 100,
      ),
    );
    await tester.pumpWidget(
      _buildScreen([_dayOne, _dayTwo], routeRepository: fake),
    );
    await tester.pumpAndSettle();

    // day1 有 11→12 一對;day2 單 pin 無對;不接 12→21(不跨日)→ 僅 1 次呼叫。
    expect(fake.calls, ['26.217,127.719->26.214,127.688']);
  });
}
