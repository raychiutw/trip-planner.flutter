import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/trip_poi_health.dart';

void main() {
  group('TripPoiHealthReport.fromJson', () {
    test('解析 POI closed/missing 摘要與 snake_case items', () {
      final report = TripPoiHealthReport.fromJson({
        'version': 1,
        'closed': 1,
        'missing': 1,
        'items': [
          {
            'poi_id': 10,
            'poi_name': '閉店餐廳',
            'status': 'closed',
            'reason': 'Google Places: CLOSED_PERMANENTLY',
          },
          {
            'poi_id': '11',
            'poi_name': '失效景點',
            'status': 'missing',
            'reason': '',
          },
        ],
      });

      expect(report.version, 1);
      expect(report.closed, 1);
      expect(report.missing, 1);
      expect(report.hasIssues, isTrue);
      expect(report.items.first.poiId, 10);
      expect(report.items.first.status, TripPoiHealthStatus.closed);
      expect(report.items.first.reason, 'Google Places: CLOSED_PERMANENTLY');
      expect(report.items.last.poiId, 11);
      expect(report.items.last.status, TripPoiHealthStatus.missing);
      expect(report.items.last.reason, isNull);
    });

    test('空 items 代表沒有 POI health issues', () {
      final report = TripPoiHealthReport.fromJson({
        'version': 1,
        'closed': 0,
        'missing': 0,
        'items': const [],
      });

      expect(report.hasIssues, isFalse);
    });
  });

  test('parseTripPoiHealthStatus unknown fallback', () {
    expect(parseTripPoiHealthStatus('closed'), TripPoiHealthStatus.closed);
    expect(parseTripPoiHealthStatus('missing'), TripPoiHealthStatus.missing);
    expect(parseTripPoiHealthStatus('active'), TripPoiHealthStatus.unknown);
  });
}
