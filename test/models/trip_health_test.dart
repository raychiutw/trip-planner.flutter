import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/trip_health.dart';

void main() {
  group('TripHealthReport.fromJson', () {
    test('解析完整 camelCase report 與 finding action target', () {
      final report = TripHealthReport.fromJson({
        'tripId': 'okinawa',
        'userId': 'user-1',
        'status': 'completed',
        'requestId': 42,
        'findings': [
          {
            'severity': 'high',
            'title': 'Day 2 移動太趕',
            'description': '連續兩段移動時間不足。',
            'dimension': 'timing',
            'suggestion': '把午餐延後 30 分鐘。',
            'actionTarget': {'day': 2, 'entryId': 77},
          },
        ],
        'errorMessage': null,
        'createdAt': '2026-07-09T10:00:00Z',
        'completedAt': '2026-07-09T10:01:00Z',
      });

      expect(report.tripId, 'okinawa');
      expect(report.status, TripHealthStatus.completed);
      expect(report.status.isTerminal, isTrue);
      expect(report.requestId, 42);
      expect(report.completedAt, '2026-07-09T10:01:00Z');
      expect(report.findings.single.severity, TripHealthSeverity.high);
      expect(report.findings.single.dimension, TripHealthDimension.timing);
      expect(report.findings.single.suggestion, '把午餐延後 30 分鐘。');
      expect(report.findings.single.actionTarget?.day, 2);
      expect(report.findings.single.actionTarget?.entryId, 77);
    });

    test('接受 snake_case 欄位並忽略非 map finding', () {
      final report = TripHealthReport.fromJson({
        'trip_id': 'legacy-trip',
        'user_id': 'user-2',
        'status': 'failed',
        'request_id': 9,
        'findings': [
          {
            'severity': 'low',
            'title': '缺少早餐',
            'action_target': {'day': 1, 'entry_id': 11},
          },
          'bad-row',
        ],
        'error_message': 'Claude timeout',
        'created_at': '2026-07-09T10:00:00Z',
        'completed_at': '',
      });

      expect(report.tripId, 'legacy-trip');
      expect(report.userId, 'user-2');
      expect(report.status, TripHealthStatus.failed);
      expect(report.status.isTerminal, isTrue);
      expect(report.findings, hasLength(1));
      expect(report.findings.single.description, '');
      expect(report.findings.single.actionTarget?.entryId, 11);
      expect(report.errorMessage, 'Claude timeout');
      expect(report.completedAt, isNull);
    });
  });

  group('trip health parsers', () {
    test('status unknown 保持 pending 以便 UI 繼續輪詢', () {
      expect(parseTripHealthStatus('pending'), TripHealthStatus.pending);
      expect(parseTripHealthStatus('COMPLETED'), TripHealthStatus.completed);
      expect(parseTripHealthStatus('failed'), TripHealthStatus.failed);
      expect(parseTripHealthStatus('weird'), TripHealthStatus.pending);
      expect(TripHealthStatus.pending.isTerminal, isFalse);
    });

    test('severity 與 dimension 對未知值容錯', () {
      expect(parseTripHealthSeverity('high'), TripHealthSeverity.high);
      expect(parseTripHealthSeverity('unknown'), TripHealthSeverity.medium);
      expect(
        parseTripHealthDimension('distance'),
        TripHealthDimension.distance,
      );
      expect(parseTripHealthDimension('unknown'), isNull);
    });
  });
}
