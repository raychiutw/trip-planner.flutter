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

  group('TripRequestEvent.fromJson', () {
    test('解析 SSE status event', () {
      final event = TripRequestEvent.fromJson({
        'status': 'completed',
        'processedBy': 'worker',
        'updatedAt': '2026-07-09T01:01:00Z',
      });

      expect(event.status, RequestStatus.completed);
      expect(event.processedBy, 'worker');
      expect(event.updatedAt, '2026-07-09T01:01:00Z');
      expect(event.isTerminal, isTrue);
    });

    test('解析 not_found error event', () {
      final event = TripRequestEvent.fromJson({'error': 'not_found'});

      expect(event.status, isNull);
      expect(event.error, 'not_found');
      expect(event.isTerminal, isTrue);
    });
  });

  group('TerminalReason（後端 ADR-0007：為什麼結束,獨立於 status）', () {
    test('解析四個已知值', () {
      expect(parseTerminalReason('cancelled'), TerminalReason.cancelled);
      expect(parseTerminalReason('timed_out'), TerminalReason.timedOut);
      expect(parseTerminalReason('error'), TerminalReason.error);
      expect(parseTerminalReason('needs_consent'), TerminalReason.needsConsent);
    });

    test('未知值與缺漏都是 null,不得誤判成任何已知值', () {
      expect(parseTerminalReason('brand_new_reason'), isNull);
      expect(parseTerminalReason(null), isNull);
      expect(parseTerminalReason(''), isNull);
    });

    test('TripRequest 解析 terminalReason;缺漏是 null', () {
      final cancelled = TripRequest.fromJson(const {
        'id': 1,
        'tripId': 't',
        'message': 'm',
        'status': 'failed',
        'terminalReason': 'cancelled',
      });
      expect(cancelled.terminalReason, TerminalReason.cancelled);
      // status 維持既有四值,不因為新欄位而擴充。
      expect(cancelled.status, RequestStatus.failed);

      final plain = TripRequest.fromJson(const {
        'id': 2,
        'tripId': 't',
        'message': 'm',
        'status': 'completed',
      });
      expect(plain.terminalReason, isNull);
    });
  });
}
