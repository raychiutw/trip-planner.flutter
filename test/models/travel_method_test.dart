import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/travel_method.dart';

void main() {
  group('travelMethodLabel(submode)', () {
    test('transit submode 各有中文名(區分共用 train icon 的方式)', () {
      expect(travelMethodLabel('monorail'), '單軌');
      expect(travelMethodLabel('bus'), '公車');
      expect(travelMethodLabel('metro'), '地鐵');
      expect(travelMethodLabel('train'), '火車');
      expect(travelMethodLabel('hsr'), '高鐵');
    });

    test('null/空 submode(駕車/步行)不顯示方式名', () {
      expect(travelMethodLabel(null), '');
      expect(travelMethodLabel(''), '');
    });

    test('未知 submode(其他自由文字)原樣 passthrough', () {
      expect(travelMethodLabel('纜車'), '纜車');
    });
  });

  test('kTravelMethods 為 8 選項且含 other', () {
    expect(kTravelMethods.length, 8);
    expect(kTravelMethods.map((m) => m.key), contains('other'));
    expect(kTravelMethods.firstWhere((m) => m.key == 'metro').label, '地鐵');
  });
}
