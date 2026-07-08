import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/chat.dart';

void main() {
  group('TripRequest.fromJson', () {
    test('解析 request row camelCase 欄位與 inflight/completed helper', () {
      final request = TripRequest.fromJson({
        'id': 42,
        'tripId': 'okinawa-trip-2026',
        'message': '幫我安排晚餐',
        'reply': '已幫你補上晚餐候選。',
        'status': 'completed',
        'submittedBy': 'traveler@example.com',
        'submittedByDisplayName': 'Ray',
        'processedBy': 'api',
        'createdAt': '2026-07-08T10:00:00Z',
        'updatedAt': '2026-07-08T10:03:00Z',
      });

      expect(request.id, 42);
      expect(request.tripId, 'okinawa-trip-2026');
      expect(request.isInflight, isFalse);
      expect(request.isCompleted, isTrue);
      expect(request.displayReply, '已幫你補上晚餐候選。');
    });

    test('open request 無 reply 時 displayReply 為 null', () {
      final request = TripRequest.fromJson({
        'id': 43,
        'tripId': 'okinawa-trip-2026',
        'message': '幫我調整第二天',
        'status': 'open',
      });

      expect(request.isInflight, isTrue);
      expect(request.displayReply, isNull);
    });
  });

  group('TripRequestPage.fromJson', () {
    test('解析 paginated response', () {
      final page = TripRequestPage.fromJson({
        'items': [
          {
            'id': 1,
            'tripId': 'trip-1',
            'message': 'hello',
            'status': 'completed',
          },
        ],
        'hasMore': true,
      });

      expect(page.items.single.id, 1);
      expect(page.hasMore, isTrue);
    });
  });
}
