import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/trip_route.dart';

void main() {
  group('TripRouteResult.fromJson', () {
    test('解析 route polyline tuples 與秒數/公尺欄位', () {
      final route = TripRouteResult.fromJson({
        'polyline': [
          [25.033, 121.5654],
          ['25.034', '121.566'],
        ],
        'duration': 612,
        'distance': '4300',
      });

      expect(route.polyline, hasLength(2));
      expect(route.polyline.first.lat, 25.033);
      expect(route.polyline.first.lng, 121.5654);
      expect(route.polyline.last.lat, 25.034);
      expect(route.durationSeconds, 612);
      expect(route.distanceMeters, 4300);
    });

    test('duration 可為 null, polyline 也接受 lat/lng object', () {
      final route = TripRouteResult.fromJson({
        'polyline': [
          {'lat': 24.1, 'lng': 120.7},
        ],
        'duration': null,
        'distance': 0,
      });

      expect(route.durationSeconds, isNull);
      expect(route.distanceMeters, 0);
      expect(route.polyline.single.lng, 120.7);
    });
  });
}
