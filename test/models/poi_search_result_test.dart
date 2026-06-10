import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/poi_search_result.dart';

void main() {
  group('PoiSearchResult.fromJson', () {
    test('完整 snake_case 欄位', () {
      final poi = PoiSearchResult.fromJson({
        'place_id': 'ChIJ_xxx',
        'name': '美麗海水族館',
        'address': '沖繩縣國頭郡',
        'lat': 26.694,
        'lng': 127.878,
        'category': 'aquarium',
        'country': 'JP',
        'country_name': '日本',
        'rating': 4.6,
        'business_status': 'OPERATIONAL',
      });
      expect(poi.placeId, 'ChIJ_xxx');
      expect(poi.name, '美麗海水族館');
      expect(poi.lat, 26.694);
      expect(poi.category, 'aquarium');
      expect(poi.countryName, '日本');
      expect(poi.rating, 4.6);
      expect(poi.businessStatus, PoiBusinessStatus.operational);
    });

    test('nullable 缺漏 + lat/lng 缺省 0 + 未知 business_status → null', () {
      final poi = PoiSearchResult.fromJson({
        'place_id': 'ChIJ_min',
        'name': '某地',
      });
      expect(poi.address, isNull);
      expect(poi.lat, 0);
      expect(poi.lng, 0);
      expect(poi.rating, isNull);
      expect(poi.businessStatus, isNull);
    });
  });
}
