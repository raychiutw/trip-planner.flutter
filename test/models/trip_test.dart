import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/trip.dart';

void main() {
  group('TripSummary.fromJson', () {
    test('解析完整欄位', () {
      final summary = TripSummary.fromJson({
        'tripId': 'okinawa-trip-2026-Ray',
        'name': '沖繩之旅',
        'title': '沖繩家族旅行',
        'owner': 'ray@example.com',
        'ownerDisplayName': 'Ray',
        'ownerUserId': 'user-ray',
        'role': 'owner',
        'countries': 'JP',
        'startDate': '2026-10-01',
        'endDate': '2026-10-05',
        'updatedAt': '2026-07-08T10:00:00Z',
        'totalDays': 5,
        'memberCount': 3,
        'archivedAt': null,
      });

      expect(summary.tripId, 'okinawa-trip-2026-Ray');
      expect(summary.name, '沖繩之旅');
      expect(summary.title, '沖繩家族旅行');
      expect(summary.owner, 'ray@example.com');
      expect(summary.ownerDisplayName, 'Ray');
      expect(summary.ownerUserId, 'user-ray');
      expect(summary.role, 'owner');
      expect(summary.countries, 'JP');
      expect(summary.startDate, '2026-10-01');
      expect(summary.endDate, '2026-10-05');
      expect(summary.updatedAt, '2026-07-08T10:00:00Z');
      expect(summary.totalDays, 5);
      expect(summary.memberCount, 3);
      expect(summary.archivedAt, isNull);
    });

    test('nullable 欄位缺漏時為 null', () {
      final summary = TripSummary.fromJson({
        'tripId': 'kyoto-trip',
        'name': '京都',
      });

      expect(summary.title, isNull);
      expect(summary.totalDays, isNull);
      expect(summary.owner, isNull);
      expect(summary.role, isNull);
      expect(summary.countries, isNull);
      expect(summary.startDate, isNull);
      expect(summary.endDate, isNull);
      expect(summary.updatedAt, isNull);
      expect(summary.memberCount, isNull);
      expect(summary.archivedAt, isNull);
    });
  });

  group('TripDestination.fromJson', () {
    test('解析完整欄位，lat/lng int 也轉 double', () {
      final destination = TripDestination.fromJson({
        'destOrder': 1,
        'name': '那霸',
        'lat': 26,
        'lng': 127.68,
      });

      expect(destination.destOrder, 1);
      expect(destination.name, '那霸');
      expect(destination.lat, 26.0);
      expect(destination.lng, 127.68);
    });

    test('nullable 欄位缺漏時為 null', () {
      final destination = TripDestination.fromJson({'name': '美麗海'});

      expect(destination.destOrder, isNull);
      expect(destination.lat, isNull);
      expect(destination.lng, isNull);
    });
  });

  group('Trip.fromJson', () {
    test('優先讀 tripId，fallback 讀 id', () {
      final tripWithTripId = Trip.fromJson({
        'tripId': 'okinawa-trip-2026-Ray',
        'id': 'should-not-use',
        'name': '沖繩',
      });
      final tripWithIdOnly = Trip.fromJson({'id': 'kyoto-trip', 'name': '京都'});

      expect(tripWithTripId.id, 'okinawa-trip-2026-Ray');
      expect(tripWithIdOnly.id, 'kyoto-trip');
    });

    test('published 0/1/true 解析為 bool', () {
      expect(
        Trip.fromJson({'id': 't', 'name': 'n', 'published': 1}).published,
        isTrue,
      );
      expect(
        Trip.fromJson({'id': 't', 'name': 'n', 'published': 0}).published,
        isFalse,
      );
      expect(
        Trip.fromJson({'id': 't', 'name': 'n', 'published': true}).published,
        isTrue,
      );
      expect(Trip.fromJson({'id': 't', 'name': 'n'}).published, isFalse);
    });

    test('解析完整欄位含 destinations 巢狀清單', () {
      final trip = Trip.fromJson({
        'tripId': 'okinawa-trip-2026-Ray',
        'name': '沖繩之旅',
        'owner': 'Ray',
        'ownerDisplayName': 'Ray Chiu',
        'title': '沖繩家族旅行',
        'description': '五天四夜自駕',
        'countries': 'JP',
        'published': 1,
        'lang': 'zh-TW',
        'dayCount': 5,
        'startDate': '2026-04-23',
        'endDate': '2026-04-27',
        'memberCount': 4,
        'destinations': [
          {'destOrder': 1, 'name': '那霸', 'lat': 26.21, 'lng': 127.68},
          {'destOrder': 2, 'name': '恩納', 'lat': 26.49, 'lng': 127.85},
        ],
      });

      expect(trip.id, 'okinawa-trip-2026-Ray');
      expect(trip.owner, 'Ray');
      expect(trip.ownerDisplayName, 'Ray Chiu');
      expect(trip.description, '五天四夜自駕');
      expect(trip.countries, 'JP');
      expect(trip.lang, 'zh-TW');
      expect(trip.dayCount, 5);
      expect(trip.startDate, '2026-04-23');
      expect(trip.endDate, '2026-04-27');
      expect(trip.memberCount, 4);
      expect(trip.destinations, hasLength(2));
      expect(trip.destinations[1].name, '恩納');
    });

    test('destinations 缺漏時預設空清單，其餘 nullable 為 null', () {
      final trip = Trip.fromJson({'id': 'bare-trip', 'name': '最小行程'});

      expect(trip.destinations, isEmpty);
      expect(trip.owner, isNull);
      expect(trip.ownerDisplayName, isNull);
      expect(trip.title, isNull);
      expect(trip.description, isNull);
      expect(trip.countries, isNull);
      expect(trip.lang, isNull);
      expect(trip.dayCount, isNull);
      expect(trip.startDate, isNull);
      expect(trip.endDate, isNull);
      expect(trip.memberCount, isNull);
    });
  });
}
