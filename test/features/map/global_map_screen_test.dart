import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/features/favorites/favorites_providers.dart';
import 'package:tripline/features/map/global_map_screen.dart';
import 'package:tripline/features/map/map_adapter.dart';
import 'package:tripline/features/map/map_location.dart';
import 'package:tripline/models/poi_favorite.dart';
import 'package:tripline/theme/app_theme.dart';

class _TransparentTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(TileProvider.transparentImage);
}

class _FakeLocationService implements TripMapLocationService {
  int calls = 0;

  @override
  Future<TripMapPoint> currentLocation() async {
    calls++;
    return const TripMapPoint(26.215, 127.72);
  }
}

const _withCoords = PoiFavorite(
  id: 1,
  userId: 'u',
  poiId: 10,
  favoritedAt: '2026-01-01',
  poiName: '首里城',
  poiLat: 26.2,
  poiLng: 127.7,
  poiType: 'attraction',
  poiRating: 4.5,
  usages: [PoiFavoriteUsage(tripId: 'okinawa', tripName: '沖繩')],
);
const _noCoords = PoiFavorite(
  id: 2,
  userId: 'u',
  poiId: 11,
  favoritedAt: '2026-01-01',
  poiName: '無座標',
);

void main() {
  Widget buildApp(
    List<PoiFavorite> favs, {
    TripMapLocationService? locationService,
  }) {
    return ProviderScope(
      overrides: [favoritesProvider.overrideWith((ref) => Stream.value(favs))],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: GlobalMapScreen(
          tileProvider: _TransparentTileProvider(),
          locationService: locationService,
        ),
      ),
    );
  }

  String? tileUrl(WidgetTester tester) {
    return tester
        .widget<TileLayer>(
          find.byKey(const ValueKey('trip-map-canvas-tile-layer')),
        )
        .urlTemplate;
  }

  testWidgets('載入中保留地圖輪廓並提供讀屏狀態', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          favoritesProvider.overrideWith(
            (ref) => const Stream<List<PoiFavorite>>.empty(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const GlobalMapScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('map-loading-skeleton')), findsOneWidget);
    expect(find.bySemanticsLabel('正在載入地圖'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('有座標的收藏 → 顯示 marker(無座標者跳過)', (tester) async {
    await tester.pumpWidget(buildApp(const [_withCoords, _noCoords]));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('map-fav-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('map-fav-2')), findsNothing);
  });

  testWidgets('點 marker → 顯示選中卡(名稱 + 所屬行程)', (tester) async {
    await tester.pumpWidget(buildApp(const [_withCoords]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('map-fav-1')));
    await tester.pumpAndSettle();

    expect(find.text('首里城'), findsOneWidget);
    expect(find.textContaining('沖繩'), findsOneWidget);
  });

  testWidgets('圖層選單：可從路線圖切換為衛星圖', (tester) async {
    await tester.pumpWidget(buildApp(const [_withCoords]));
    await tester.pumpAndSettle();

    expect(tileUrl(tester), kTripMapTilePresets.first.urlTemplate);

    await tester.tap(find.byKey(const ValueKey('global-map-layer-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('global-map-layer-satellite')));
    await tester.pumpAndSettle();

    expect(tileUrl(tester), kTripMapTilePresets[2].urlTemplate);
    expect(find.text('衛星'), findsOneWidget);
  });

  testWidgets('定位按鈕：取得目前位置後顯示 user marker', (tester) async {
    final locationService = _FakeLocationService();
    await tester.pumpWidget(
      buildApp(const [_withCoords], locationService: locationService),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('global-map-locate-button')));
    await tester.pumpAndSettle();

    expect(locationService.calls, 1);
    expect(
      find.byKey(const ValueKey('global-map-user-location')),
      findsOneWidget,
    );
  });

  testWidgets('無可顯示座標 → 提示', (tester) async {
    await tester.pumpWidget(buildApp(const [_noCoords]));
    await tester.pumpAndSettle();

    expect(find.text('還沒有地點可顯示'), findsOneWidget);
    expect(find.byType(FlutterMap), findsNothing);
  });
}
