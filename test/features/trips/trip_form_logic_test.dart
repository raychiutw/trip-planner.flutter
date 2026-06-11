import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/features/trips/trip_form_logic.dart';
import 'package:tripline/models/destination_input.dart';

void main() {
  group('slugify', () {
    test('ascii → 連字號', () => expect(slugify('Tokyo Kyoto!!'), 'tokyo-kyoto'));
    test('全非 ascii → 空', () => expect(slugify('東京、京都'), ''));
    test('首尾/連續分隔收斂', () => expect(slugify('  Hello---World  '), 'hello-world'));
  });

  group('genTripId', () {
    test('ascii 名 → slug-base36', () {
      final id = genTripId('Tokyo', 1717000000000);
      expect(id.startsWith('tokyo-'), isTrue);
      expect(RegExp(r'^[a-z0-9-]+$').hasMatch(id), isTrue);
    });
    test('全中文名 → trip-<suffix>', () {
      final id = genTripId('東京', 1717000000000);
      expect(id.startsWith('trip-'), isTrue);
      expect(RegExp(r'^[a-z0-9-]+$').hasMatch(id), isTrue);
    });
    test('長度 ≤100', () {
      expect(genTripId('a' * 200, 1717000000000).length, lessThanOrEqualTo(100));
    });
  });

  test('deriveTripName 以「、」串接', () {
    expect(
      deriveTripName(const [DestinationInput(name: 'A'), DestinationInput(name: 'B')]),
      'A、B',
    );
  });

  group('deriveCountries', () {
    test('去重 join', () {
      expect(
        deriveCountries(const [
          DestinationInput(name: 'A', country: 'JP'),
          DestinationInput(name: 'B', country: 'KR'),
          DestinationInput(name: 'C', country: 'JP'),
        ]),
        'JP,KR',
      );
    });
    test('全無 → JP', () {
      expect(deriveCountries(const [DestinationInput(name: 'A')]), 'JP');
    });
  });

  test('flexibleRange：該月 1 號起 dayCount 天', () {
    expect(flexibleRange(2026, 7, 5), ('2026-07-01', '2026-07-05'));
  });

  test('tripDayCount 含頭尾', () {
    expect(tripDayCount('2026-07-01', '2026-07-05'), 5);
  });

  group('isTripDatesValid', () {
    test('正常 → true', () => expect(isTripDatesValid('2026-07-01', '2026-07-05'), isTrue));
    test('格式錯 → false', () => expect(isTripDatesValid('2026/7/1', '2026-07-05'), isFalse));
    test('順序錯 → false', () => expect(isTripDatesValid('2026-07-05', '2026-07-01'), isFalse));
    test('31 天 → false', () => expect(isTripDatesValid('2026-07-01', '2026-07-31'), isFalse));
    test('30 天 → true', () => expect(isTripDatesValid('2026-07-01', '2026-07-30'), isTrue));
  });
}
