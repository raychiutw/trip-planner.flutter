import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/error_report.dart';

void main() {
  group('TripErrorReport.toJson', () {
    test('輸出 /reports body 並省略空白 optional 欄位', () {
      final report = TripErrorReport(
        tripId: 'trip-1',
        url: ' /trip/trip-1 ',
        errorCode: ' SYS_INTERNAL ',
        errorMessage: ' Something failed ',
        userAgent: ' ',
        context: '{"severity":"error"}',
        timestamp: '2026-07-09T10:00:00Z',
      );

      expect(report.toJson(), {
        'tripId': 'trip-1',
        'url': '/trip/trip-1',
        'errorCode': 'SYS_INTERNAL',
        'errorMessage': 'Something failed',
        'context': '{"severity":"error"}',
        'timestamp': '2026-07-09T10:00:00Z',
      });
    });
  });
}
