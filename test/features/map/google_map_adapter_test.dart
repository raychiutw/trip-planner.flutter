import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tripline/features/map/google_map_adapter.dart';

void main() {
  group('tripMapBounds', () {
    test('多點涵蓋 min/max lat/lng', () {
      final bounds = tripMapBounds(const [
        TripMapPoint(25.0, 121.5),
        TripMapPoint(24.0, 122.0),
        TripMapPoint(26.0, 121.0),
      ]);
      expect(bounds.southwest, const LatLng(24.0, 121.0));
      expect(bounds.northeast, const LatLng(26.0, 122.0));
    });

    test('單點 southwest == northeast', () {
      final bounds = tripMapBounds(const [TripMapPoint(25.0, 121.5)]);
      expect(bounds.southwest, bounds.northeast);
      expect(bounds.southwest, const LatLng(25.0, 121.5));
    });
  });

  test('controller 初始未 ready(尚未 attach GoogleMapController)', () {
    expect(GoogleTripMapController().isReady, isFalse);
  });
}
