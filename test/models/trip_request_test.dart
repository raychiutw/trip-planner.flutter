import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/trip_request.dart';

void main() {
  group('TripRequest.fromJson', () {
    test('解析完整欄位', () {
      final r = TripRequest.fromJson({
        'id': 5,
        'tripId': 'okinawa',
        'message': '把午餐改成沖繩麵',
        'reply': '我改好了',
        'status': 'completed',
        'submittedBy': 'a@b.com',
        'submittedByDisplayName': 'Ray',
        'processedBy': 'api',
        'createdAt': '2026-06-11T00:00:00Z',
        'updatedAt': '2026-06-11T00:01:00Z',
      });
      expect(r.id, 5);
      expect(r.tripId, 'okinawa');
      expect(r.message, '把午餐改成沖繩麵');
      expect(r.reply, '我改好了');
      expect(r.status, RequestStatus.completed);
      expect(r.submittedBy, 'a@b.com');
      expect(r.submittedByDisplayName, 'Ray');
      expect(r.status.isTerminal, isTrue);
    });

    test('status parse + unknown → processing', () {
      expect(parseRequestStatus('open'), RequestStatus.open);
      expect(parseRequestStatus('processing'), RequestStatus.processing);
      expect(parseRequestStatus('failed'), RequestStatus.failed);
      expect(parseRequestStatus('completed'), RequestStatus.completed);
      expect(parseRequestStatus('weird'), RequestStatus.processing);
      expect(parseRequestStatus(null), RequestStatus.processing);
      expect(RequestStatus.processing.isTerminal, isFalse);
      expect(RequestStatus.failed.isTerminal, isTrue);
    });

    test('reply 可 null（未完成）', () {
      final r = TripRequest.fromJson({
        'id': 6,
        'tripId': 't',
        'message': 'hi',
        'status': 'open',
      });
      expect(r.reply, isNull);
      expect(r.status, RequestStatus.open);
      expect(r.status.isTerminal, isFalse);
    });
  });
}
