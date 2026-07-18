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
      expect(mapGooglePrimaryTypeToPoiType('bed_and_breakfast'), 'hotel');
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

  group('poiCategoryLabel', () {
    test('空值 → null，caller 可自行 fallback', () {
      expect(poiCategoryLabel(null), isNull);
      expect(poiCategoryLabel(''), isNull);
      expect(poiCategoryLabel('   '), isNull);
    });

    test('已收錄 Google primaryType → 細類中文 label', () {
      expect(poiCategoryLabel('tourist_attraction'), '景點');
      expect(poiCategoryLabel('fast_food_restaurant'), '速食');
      expect(poiCategoryLabel('ramen_restaurant'), '拉麵店');
      expect(poiCategoryLabel('shinto_shrine'), '神社');
      expect(poiCategoryLabel('lodging'), '飯店');
      expect(poiCategoryLabel('department_store'), '百貨公司');
      expect(poiCategoryLabel('subway_station'), '地鐵站');
      expect(poiCategoryLabel('restaurant'), '餐廳');
      expect(poiCategoryLabel('other'), '其他');
    });

    test('未收錄的合法 snake_case → 可讀英文，方便補 mapping', () {
      expect(poiCategoryLabel('hindu_temple_annex'), 'Hindu Temple Annex');
    });

    test('純 CJK / 假名 curated label → 原樣顯示', () {
      expect(poiCategoryLabel('拉麵'), '拉麵');
      expect(poiCategoryLabel('浮潛'), '浮潛');
      expect(poiCategoryLabel('當地特色'), '當地特色');
      expect(poiCategoryLabel('沖繩麵'), '沖繩麵');
      expect(poiCategoryLabel('居酒屋'), '居酒屋');
      expect(poiCategoryLabel('すし'), 'すし');
    });

    test('含 ASCII 拉丁字母或非 curated 雜訊 → 映射成乾淨 label', () {
      expect(poiCategoryLabel('restaurant 餐廳'), '餐廳');
      expect(poiCategoryLabel('izakaya 居酒屋'), '餐廳');
      expect(poiCategoryLabel('拉麵 ramen'), '景點');
      for (final junk in ['123', '!!!', '🍜', 'ＲＡＭＥＮ']) {
        final label = poiCategoryLabel(junk);
        expect(label, '景點');
        expect(RegExp(r'[a-zA-Z]').hasMatch(label!), isFalse);
      }
    });
  });
}
