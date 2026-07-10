import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/features/map/map_adapter.dart';

class _TransparentTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(TileProvider.transparentImage);
}

void main() {
  test('TripMapPoint 是地圖套件無關的座標值物件', () {
    const point = TripMapPoint(26.217, 127.719);

    expect(point.latitude, 26.217);
    expect(point.longitude, 127.719);
    expect(point, const TripMapPoint(26.217, 127.719));
  });

  test('內建 tile presets 保留路線圖/地形/衛星圖層設定', () {
    expect(
      kTripMapTilePresets.map((preset) => preset.style),
      containsAll([
        TripMapTileStyle.roadmap,
        TripMapTileStyle.terrain,
        TripMapTileStyle.satellite,
      ]),
    );
    expect(
      kTripMapTilePresets
          .firstWhere((preset) => preset.style == TripMapTileStyle.terrain)
          .urlTemplate,
      contains('opentopomap'),
    );
  });

  testWidgets('FlutterMapCanvas 只在 adapter 內轉接 tile、route 與 marker', (
    tester,
  ) async {
    final controller = FlutterTripMapController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 320,
          child: FlutterMapCanvas(
            controller: controller,
            initialFitPoints: const [
              TripMapPoint(26.217, 127.719),
              TripMapPoint(26.214, 127.688),
            ],
            tilePreset: kTripMapTilePresets.firstWhere(
              (preset) => preset.style == TripMapTileStyle.terrain,
            ),
            tileProvider: _TransparentTileProvider(),
            routes: const [
              TripMapRoute(
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
                point: TripMapPoint(26.217, 127.719),
                width: 24,
                height: 24,
                child: Text('1'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    final tileLayer = tester.widget<TileLayer>(
      find.byKey(const ValueKey('trip-map-canvas-tile-layer')),
    );
    expect(tileLayer.urlTemplate, contains('opentopomap'));
    expect(kTripMapUserAgentPackageName, 'com.raychiu.tripline');

    final routeLayer = tester.widget<PolylineLayer<Object>>(
      find.byKey(const ValueKey('trip-map-canvas-routes')),
    );
    expect(routeLayer.polylines.single.points, hasLength(2));
    expect(routeLayer.polylines.single.color, Colors.red);
  });
}
