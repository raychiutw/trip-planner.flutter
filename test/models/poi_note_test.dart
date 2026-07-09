import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/poi_note.dart';

void main() {
  group('condenseHours', () {
    test('compresses identical weekly hours', () {
      expect(
        condenseHours(
          '星期一: 09:00-18:00\n星期二: 09:00-18:00\n星期三: 09:00-18:00\n星期四: 09:00-18:00\n星期五: 09:00-18:00\n星期六: 09:00-18:00\n星期日: 09:00-18:00',
        ),
        '09:00-18:00',
      );
    });

    test('compresses weekday and weekend split', () {
      expect(
        condenseHours(
          '星期一: 09:00-18:00 星期二: 09:00-18:00 星期三: 09:00-18:00 星期四: 09:00-18:00 星期五: 09:00-18:00 星期六: 10:00-17:00 星期日: 10:00-17:00',
        ),
        '週一–五 09:00-18:00 · 週末 10:00-17:00',
      );
    });

    test('normalizes Japanese 24h labels', () {
      expect(condenseHours('24時間営業'), '24 小時');
    });
  });

  group('buildPoiNote', () {
    test('uses hours, price, then address', () {
      expect(
        buildPoiNote(
          hoursRaw:
              '星期一: 09:00-18:00\n星期二: 09:00-18:00\n星期三: 09:00-18:00\n星期四: 09:00-18:00\n星期五: 09:00-18:00\n星期六: 09:00-18:00\n星期日: 09:00-18:00',
          priceLevel: 'PRICE_LEVEL_MODERATE',
          address: '沖繩縣本部町石川424',
        ),
        '營業 09:00-18:00\n消費 ￥￥\n沖繩縣本部町石川424',
      );
    });

    test('returns null when all fields are empty', () {
      expect(buildPoiNote(), isNull);
    });
  });
}
