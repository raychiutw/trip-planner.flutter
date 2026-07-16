import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/features/map/map_adapter.dart';
import 'package:tripline/features/map/map_style.dart';

void main() {
  test('TripMapPoint 與 Google Maps LatLng 雙向轉接', () {
    const point = TripMapPoint(26.217, 127.719);

    expect(point.toGoogleLatLng(), const LatLng(26.217, 127.719));
    expect(TripMapPoint.fromGoogleLatLng(const LatLng(26.217, 127.719)), point);
  });

  test('內建 Google Maps presets 保留路線圖/地形/衛星', () {
    expect(
      kTripMapTilePresets.map((preset) => preset.mapType),
      containsAll([MapType.normal, MapType.terrain, MapType.hybrid]),
    );
  });

  testWidgets('GoogleTripMapCanvas 轉接原生 marker 與 polyline', (tester) async {
    final controller = GoogleTripMapController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: GoogleTripMapCanvas(
          config: TripMapCanvasConfig(
            controller: controller,
            initialFitPoints: const [TripMapPoint(26.217, 127.719)],
            tilePreset: kTripMapTilePresets[1],
            clusterMarkers: true,
            routes: const [
              TripMapRoute(
                id: 'day-1',
                points: [
                  TripMapPoint(26.217, 127.719),
                  TripMapPoint(26.214, 127.688),
                ],
                color: Colors.red,
                strokeWidth: 4,
              ),
            ],
            markers: const [
              TripMapMarker(
                id: 'stop-1',
                point: TripMapPoint(26.217, 127.719),
                color: Colors.blue,
                title: '首里城',
              ),
            ],
          ),
        ),
      ),
    );

    final googleMap = tester.widget<GoogleMap>(find.byType(GoogleMap));
    expect(googleMap.mapType, MapType.terrain);
    expect(googleMap.markers.single.markerId.value, 'stop-1');
    expect(googleMap.markers.single.infoWindow.title, '首里城');
    expect(googleMap.clusterManagers, hasLength(1));
    expect(googleMap.markers.single.clusterManagerId, isNotNull);
    expect(googleMap.polylines.single.polylineId.value, 'day-1');
    expect(googleMap.polylines.single.points, hasLength(2));
  });

  testWidgets('路線虛線與透明度轉接到原生 Polyline', (tester) async {
    final controller = GoogleTripMapController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: GoogleTripMapCanvas(
          config: TripMapCanvasConfig(
            controller: controller,
            initialFitPoints: const [TripMapPoint(26.217, 127.719)],
            tilePreset: kTripMapTilePresets.first,
            routes: const [
              TripMapRoute(
                id: 'solid-day',
                points: [
                  TripMapPoint(26.217, 127.719),
                  TripMapPoint(26.214, 127.688),
                ],
                color: Color(0xFF0EA5E9),
                strokeWidth: 3,
                opacity: 0.6,
              ),
              TripMapRoute(
                id: 'dashed-day',
                points: [
                  TripMapPoint(26.217, 127.719),
                  TripMapPoint(26.214, 127.688),
                ],
                color: Color(0xFF14B8A6),
                strokeWidth: 3,
                opacity: 0.6,
                dashed: true,
              ),
            ],
          ),
        ),
      ),
    );

    final googleMap = tester.widget<GoogleMap>(find.byType(GoogleMap));
    final byId = {
      for (final polyline in googleMap.polylines)
        polyline.polylineId.value: polyline,
    };

    expect(byId['solid-day']!.patterns, isEmpty);
    expect(byId['dashed-day']!.patterns, isNotEmpty);
    // 透明度要進到色彩 alpha，不能只留在樣式物件裡。
    expect(byId['solid-day']!.color.a, closeTo(0.6, 0.01));
    expect(byId['solid-day']!.width, 3);
    // web 沒有白色外框 casing：一段路線只該有一條線。
    expect(googleMap.polylines, hasLength(2));
  });

  testWidgets('renderTripMapChip 產生自繪 bytes 圖（非內建水滴 pin）', (tester) async {
    final style = tripMapMarkerStyle(
      dayColor: const Color(0xFF0EA5E9),
      isFocused: false,
    );

    // 真的算圖 + PNG 編碼，要在 runAsync 放行真實時間才完成。
    late final BitmapDescriptor chip;
    await tester.runAsync(() async {
      chip = await renderTripMapChip('1', style, pixelRatio: 2);
    });

    expect(chip, isA<BytesMapBitmap>());
  });

  group('Reduce Motion 時鏡頭直接切換而非平移', () {
    // 規格(design.md 地圖 C 定稿):「Reduce Motion 時卡片與 camera 直接切換」。
    // 卡片走 TpMotion.resolve 已遵守;鏡頭先前一律 animateCamera —— 而它沒有
    // duration 參數可以歸零,只能改用 moveCamera。鏡頭平移正是最容易誘發動暈的
    // 動作,開這個設定的人多半就是為了避免它。
    setUpAll(() => registerFallbackValue(_FakeCameraUpdate()));

    test('預設(未開啟)→ animateCamera', () async {
      final googleMap = _MockGoogleMapController();
      when(() => googleMap.animateCamera(any())).thenAnswer((_) async {});
      final controller = GoogleTripMapController()..attach(googleMap);

      await controller.move(const TripMapPoint(26.2, 127.7), 16);

      verify(() => googleMap.animateCamera(any())).called(1);
      verifyNever(() => googleMap.moveCamera(any()));
    });

    test('開啟後 move 改用 moveCamera', () async {
      final googleMap = _MockGoogleMapController();
      when(() => googleMap.moveCamera(any())).thenAnswer((_) async {});
      final controller = GoogleTripMapController()
        ..attach(googleMap)
        ..reduceMotion = true;

      await controller.move(const TripMapPoint(26.2, 127.7), 16);

      verify(() => googleMap.moveCamera(any())).called(1);
      verifyNever(() => googleMap.animateCamera(any()));
    });

    test('開啟後 fitPoints(單點)改用 moveCamera', () async {
      final googleMap = _MockGoogleMapController();
      when(() => googleMap.moveCamera(any())).thenAnswer((_) async {});
      final controller = GoogleTripMapController()
        ..attach(googleMap)
        ..reduceMotion = true;

      await controller.fitPoints(const [
        TripMapPoint(26.2, 127.7),
      ], padding: EdgeInsets.zero);

      verify(() => googleMap.moveCamera(any())).called(1);
      verifyNever(() => googleMap.animateCamera(any()));
    });

    test('開啟後 fitPoints(多點 bounds + maxZoom 修正)全程 moveCamera', () async {
      final googleMap = _MockGoogleMapController();
      when(() => googleMap.moveCamera(any())).thenAnswer((_) async {});
      when(() => googleMap.getZoomLevel()).thenAnswer((_) async => 18);
      final controller = GoogleTripMapController()
        ..attach(googleMap)
        ..reduceMotion = true;

      await controller.fitPoints(
        const [TripMapPoint(26.2, 127.7), TripMapPoint(26.3, 127.8)],
        padding: EdgeInsets.zero,
        maxZoom: 16,
      );

      // bounds 一次 + 超過 maxZoom 的回拉一次,兩次都不得是 animateCamera。
      verify(() => googleMap.moveCamera(any())).called(2);
      verifyNever(() => googleMap.animateCamera(any()));
    });
  });
}

class _MockGoogleMapController extends Mock implements GoogleMapController {}

class _FakeCameraUpdate extends Fake implements CameraUpdate {}
