import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/poi_favorite.dart';

void main() {
  group('PoiFavorite.fromJson', () {
    test('完整欄位 + usages 巢狀', () {
      final favorite = PoiFavorite.fromJson({
        'id': 7,
        'userId': 'u-1',
        'poiId': 501,
        'favoritedAt': '2026-06-01T10:00:00Z',
        'note': '想吃',
        'poiName': '首里城',
        'poiAddress': '那霸市',
        'poiType': 'attraction',
        'poiLat': 26.21,
        'poiLng': 127.71,
        'poiRating': 4.4,
        'usages': [
          {
            'tripId': 'okinawa',
            'tripName': '沖繩',
            'dayNum': 1,
            'dayDate': '2026-06-10',
            'entryId': 101,
          },
        ],
      });
      expect(favorite.id, 7);
      expect(favorite.poiId, 501);
      expect(favorite.poiName, '首里城');
      expect(favorite.poiRating, 4.4);
      expect(favorite.usages.single.tripName, '沖繩');
      expect(favorite.usages.single.dayNum, 1);
    });

    test('nullable 缺漏 + usages 缺省為空 + displayName fallback', () {
      final favorite = PoiFavorite.fromJson({
        'id': 8,
        'userId': 'u-1',
        'poiId': 502,
        'favoritedAt': '2026-06-02T10:00:00Z',
      });
      expect(favorite.note, isNull);
      expect(favorite.poiName, isNull);
      expect(favorite.poiRating, isNull);
      expect(favorite.usages, isEmpty);
      expect(favorite.displayName, '未命名地點');
    });

    test('displayName 用 poiName', () {
      final favorite = PoiFavorite.fromJson({
        'id': 9,
        'userId': 'u-1',
        'poiId': 503,
        'favoritedAt': '2026-06-03T10:00:00Z',
        'poiName': '美麗海水族館',
      });
      expect(favorite.displayName, '美麗海水族館');
    });
  });
}
