import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/add_to_trip.dart';
import 'package:tripline/models/poi_search_result.dart';

void main() {
  group('TripEntryConflict.fromJson', () {
    test('解析 conflictWith', () {
      final c = TripEntryConflict.fromJson({
        'entryId': 5,
        'time': '10:00-11:00',
        'title': '午餐',
        'dayNum': 1,
      });
      expect(c.entryId, 5);
      expect(c.time, '10:00-11:00');
      expect(c.title, '午餐');
      expect(c.dayNum, 1);
    });
    test('time 可為 null', () {
      final c = TripEntryConflict.fromJson({
        'entryId': 6,
        'title': '景點',
        'dayNum': 2,
      });
      expect(c.time, isNull);
    });
  });

  group('AddToTripArgs', () {
    test('favorite / direct 兩型', () {
      final fav = AddToTripFavorite(favoriteId: 7, displayName: '首里城');
      final direct = AddToTripDirect(
        poi: const PoiSearchResult(placeId: 'p1', name: '拉麵'),
      );
      expect(fav.favoriteId, 7);
      expect(direct.poi.name, '拉麵');
      expect(fav, isA<AddToTripArgs>());
      expect(direct, isA<AddToTripArgs>());
    });
  });
}
