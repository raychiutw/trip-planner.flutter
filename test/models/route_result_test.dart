import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/route_result.dart';

void main() {
  test('fromJson 解析 polyline(lat/lng)、duration、distance', () {
    final result = RouteResult.fromJson({
      'polyline': [
        [25.0, 121.5],
        [25.1, 121.6],
      ],
      'duration': 300,
      'distance': 1200,
    });
    expect(result.polyline.length, 2);
    expect(result.polyline.first.lat, 25.0);
    expect(result.polyline.first.lng, 121.5);
    expect(result.durationSec, 300);
    expect(result.distanceM, 1200);
  });

  test('duration 可為 null(對齊 /api/route 契約)', () {
    final result = RouteResult.fromJson({
      'polyline': <dynamic>[],
      'duration': null,
      'distance': 0,
    });
    expect(result.durationSec, isNull);
    expect(result.polyline, isEmpty);
  });

  test('polyline 缺漏 → 空清單;distance 缺漏 → 0', () {
    final result = RouteResult.fromJson({'duration': 5});
    expect(result.polyline, isEmpty);
    expect(result.distanceM, 0);
  });

  test('polyline 元素少於兩值 → 跳過(防禦)', () {
    final result = RouteResult.fromJson({
      'polyline': [
        [25.0],
        [25.0, 121.5],
      ],
      'distance': 1,
    });
    expect(result.polyline.length, 1);
  });
}
