import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/health.dart';

void main() {
  group('TripHealthReport.fromJson', () {
    test('解析 completed report 與 findings action target', () {
      final report = TripHealthReport.fromJson({
        'tripId': 'okinawa-trip-2026',
        'userId': 'user-1',
        'status': 'completed',
        'requestId': 88,
        'findings': [
          {
            'severity': 'high',
            'dimension': 'timing',
            'title': 'Day 2 入住衝突',
            'description': '末站後移動時間不足。',
            'suggestion': '前移末站時間。',
            'actionTarget': {'day': 2, 'entryId': 42},
          },
          {
            'severity': 'low',
            'dimension': 'sights',
            'title': '可加水族館',
            'description': '北上路線順路。',
            'actionTarget': {'day': 5},
          },
        ],
        'createdAt': '2026-07-08T10:00:00Z',
        'completedAt': '2026-07-08T10:05:00Z',
      });

      expect(report.tripId, 'okinawa-trip-2026');
      expect(report.isCompleted, isTrue);
      expect(report.requestId, 88);
      expect(report.findings, hasLength(2));
      expect(report.severityCount('high'), 1);
      expect(report.severityCount('medium'), 0);
      expect(report.severityCount('low'), 1);

      final first = report.findings.first;
      expect(first.severity, 'high');
      expect(first.dimensionLabel, '時間');
      expect(first.actionTarget!.day, 2);
      expect(first.actionTarget!.entryId, 42);
    });

    test('解析 failed report 與 errorMessage', () {
      final report = TripHealthReport.fromJson({
        'tripId': 'trip-1',
        'userId': 'user-1',
        'status': 'failed',
        'requestId': null,
        'findings': [],
        'errorMessage': 'AI 處理失敗',
        'createdAt': '2026-07-08T10:00:00Z',
      });

      expect(report.isFailed, isTrue);
      expect(report.errorMessage, 'AI 處理失敗');
      expect(report.findings, isEmpty);
    });
  });
}
