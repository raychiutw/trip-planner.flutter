import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/poi.dart';

void main() {
  group('PoiFavorite', () {
    test('fromJson 解析收藏 JOIN POI 與 usages', () {
      final favorite = PoiFavorite.fromJson({
        'id': 77,
        'userId': 'user-1',
        'poiId': 501,
        'favoritedAt': '2026-07-08T10:00:00Z',
        'note': '黃昏時段去',
        'poiName': '首里城公園',
        'poiAddress': '沖繩縣那霸市',
        'poiLat': 26,
        'poiLng': 127.719,
        'poiType': 'attraction',
        'poiRating': 4,
        'usages': [
          {
            'tripId': 'okinawa-trip-2026',
            'tripName': 'Okinawa',
            'dayNum': 2,
            'dayDate': '2026-04-24',
            'entryId': 101,
          },
        ],
      });

      expect(favorite.id, 77);
      expect(favorite.poiId, 501);
      expect(favorite.poiName, '首里城公園');
      expect(favorite.poiLat, 26.0);
      expect(favorite.poiRating, 4.0);
      expect(favorite.usages.single.tripId, 'okinawa-trip-2026');
      expect(favorite.usages.single.entryId, 101);
    });

    test('fromJson 缺少 optional 欄位時 usages 預設空陣列', () {
      final favorite = PoiFavorite.fromJson({
        'id': 78,
        'userId': 'user-1',
        'poiId': 502,
        'favoritedAt': '2026-07-08T11:00:00Z',
      });

      expect(favorite.note, isNull);
      expect(favorite.poiName, isNull);
      expect(favorite.usages, isEmpty);
    });
  });

  group('PoiSearchResult', () {
    test('fromJson 解析 poi-search snake_case 欄位', () {
      final result = PoiSearchResult.fromJson({
        'place_id': 'ChIJ-shuri',
        'name': '首里城',
        'address': '沖繩縣那霸市首里金城町',
        'lat': 26.217,
        'lng': 127,
        'category': 'tourist_attraction',
        'country': 'JP',
        'country_name': '日本',
        'rating': 4,
        'business_status': 'OPERATIONAL',
      });

      expect(result.placeId, 'ChIJ-shuri');
      expect(result.lng, 127.0);
      expect(result.countryName, '日本');
      expect(result.rating, 4.0);
      expect(result.businessStatus, 'OPERATIONAL');
    });

    test('mapPoiCategoryToType 將 Google primaryType 映射到後端白名單', () {
      expect(mapPoiCategoryToType('restaurant'), 'restaurant');
      expect(mapPoiCategoryToType('tourist_attraction'), 'attraction');
      expect(mapPoiCategoryToType('shopping_mall'), 'shopping');
      expect(mapPoiCategoryToType('train_station'), 'transport');
      expect(mapPoiCategoryToType(null), 'attraction');
    });
  });
}
