import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tripline/features/map/map_adapter.dart';

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
    GoogleMap? googleMap;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            googleMap =
                GoogleTripMapCanvas(
                      config: TripMapCanvasConfig(
                        controller: controller,
                        initialFitPoints: const [TripMapPoint(26.217, 127.719)],
                        tilePreset: kTripMapTilePresets[1],
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
                    ).build(context)
                    as GoogleMap;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(googleMap, isNotNull);
    expect(googleMap!.mapType, MapType.terrain);
    expect(googleMap!.markers.single.markerId.value, 'stop-1');
    expect(googleMap!.markers.single.infoWindow.title, '首里城');
    expect(googleMap!.polylines.single.polylineId.value, 'day-1');
    expect(googleMap!.polylines.single.points, hasLength(2));
  });
}
