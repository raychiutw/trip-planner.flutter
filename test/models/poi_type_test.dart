import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/poi_type.dart';

void main() {
  group('mapGooglePrimaryTypeToPoiType', () {
    test('whitelist 值原樣 passthrough', () {
      for (final t in [
        'hotel',
        'restaurant',
        'shopping',
        'parking',
        'attraction',
        'transport',
        'activity',
        'other',
      ]) {
        expect(mapGooglePrimaryTypeToPoiType(t), t);
      }
    });

    test('null / 空 → attraction', () {
      expect(mapGooglePrimaryTypeToPoiType(null), 'attraction');
      expect(mapGooglePrimaryTypeToPoiType(''), 'attraction');
      expect(mapGooglePrimaryTypeToPoiType('   '), 'attraction');
    });

    test('關鍵字映射（順序敏感）', () {
      expect(mapGooglePrimaryTypeToPoiType('lodging'), 'hotel');
      expect(mapGooglePrimaryTypeToPoiType('guest_house'), 'hotel');
      expect(mapGooglePrimaryTypeToPoiType('parking_lot'), 'parking');
      expect(mapGooglePrimaryTypeToPoiType('subway_station'), 'transport');
      expect(mapGooglePrimaryTypeToPoiType('amusement_park'), 'activity');
      expect(mapGooglePrimaryTypeToPoiType('aquarium'), 'activity');
      expect(mapGooglePrimaryTypeToPoiType('ramen_restaurant'), 'restaurant');
      expect(mapGooglePrimaryTypeToPoiType('wine_bar'), 'restaurant');
      expect(mapGooglePrimaryTypeToPoiType('ice_cream_shop'), 'restaurant');
      expect(mapGooglePrimaryTypeToPoiType('shopping_mall'), 'shopping');
      expect(mapGooglePrimaryTypeToPoiType('barber_shop'), 'shopping');
      expect(mapGooglePrimaryTypeToPoiType('museum'), 'attraction');
      expect(mapGooglePrimaryTypeToPoiType('tourist_attraction'), 'attraction');
    });

    test('未知 → attraction fallback', () {
      expect(mapGooglePrimaryTypeToPoiType('xyz_unknown'), 'attraction');
    });
  });

  group('kPoiTypeLabels', () {
    test('8 類中文標籤', () {
      expect(kPoiTypeLabels['restaurant'], '餐廳');
      expect(kPoiTypeLabels['attraction'], '景點');
      expect(kPoiTypeLabels['hotel'], '飯店');
      expect(kPoiTypeLabels['other'], '其他');
      expect(kPoiTypeLabels.length, 8);
    });
  });
}
