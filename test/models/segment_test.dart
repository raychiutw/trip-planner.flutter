import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/segment.dart';

void main() {
  group('TripSegment.fromJson', () {
    test('解析完整欄位', () {
      final seg = TripSegment.fromJson({
        'id': 5,
        'fromEntryId': 11,
        'toEntryId': 12,
        'mode': 'transit',
        'submode': 'hsr',
        'min': 20,
        'distanceM': 4200,
        'source': 'manual',
        'computedAt': 1783904400000,
        'updatedAt': 1783904460000,
        'noTravel': true,
        'version': 3,
      });
      expect(seg.id, 5);
      expect(seg.fromEntryId, 11);
      expect(seg.toEntryId, 12);
      expect(seg.mode, 'transit');
      expect(seg.submode, 'hsr');
      expect(seg.min, 20);
      expect(seg.distanceM, 4200);
      expect(seg.source, 'manual');
      expect(seg.computedAt, 1783904400000);
      expect(seg.updatedAt, 1783904460000);
      expect(seg.noTravel, isTrue);
      expect(seg.isStale, isFalse);
      expect(seg.version, 3);
    });

    test('nullable 缺漏 + version 預設 0', () {
      final seg = TripSegment.fromJson({'id': 1, 'mode': 'driving'});
      expect(seg.fromEntryId, isNull);
      expect(seg.toEntryId, isNull);
      expect(seg.submode, isNull);
      expect(seg.min, isNull);
      expect(seg.distanceM, isNull);
      expect(seg.source, isNull);
      expect(seg.computedAt, isNull);
      expect(seg.updatedAt, isNull);
      expect(seg.noTravel, isFalse);
      expect(seg.isStale, isFalse);
      expect(seg.version, 0);
    });

    test('解析後端 snake_case 欄位', () {
      final seg = TripSegment.fromJson({
        'id': 6,
        'from_entry_id': 21,
        'to_entry_id': 22,
        'mode': 'walking',
        'distance_m': 950,
        'computed_at': 1783904400000,
        'updated_at': 1783904460000,
        'no_travel': 1,
        'version': 4,
      });

      expect(seg.fromEntryId, 21);
      expect(seg.toEntryId, 22);
      expect(seg.distanceM, 950);
      expect(seg.computedAt, 1783904400000);
      expect(seg.updatedAt, 1783904460000);
      expect(seg.noTravel, isTrue);
      expect(seg.isStale, isFalse);
      expect(seg.version, 4);
    });

    test('computedAt null marks segment stale', () {
      final seg = TripSegment.fromJson({
        'id': 2,
        'mode': 'driving',
        'computedAt': null,
      });

      expect(seg.isStale, isTrue);
    });

    test('computed_at null marks segment stale', () {
      final seg = TripSegment.fromJson({
        'id': 3,
        'mode': 'walking',
        'computed_at': null,
      });

      expect(seg.isStale, isTrue);
    });
  });

  test('交通方式 mapping 支援 8 種方式與自訂名稱', () {
    expect(travelMethodKey('transit', 'monorail'), 'monorail');
    expect(travelMethodKey('transit', 'bus'), 'bus');
    expect(travelMethodKey('transit', 'metro'), 'metro');
    expect(travelMethodKey('transit', 'train'), 'train');
    expect(travelMethodKey('transit', 'hsr'), 'hsr');
    expect(travelMethodLabel('transit', '機場快線'), '機場快線');
    expect(travelMethodOptions, hasLength(8));
    expect(
      travelMethodOptions
          .where(
            (option) => const {'metro', 'train', 'hsr'}.contains(option.key),
          )
          .every((option) => option.automatic),
      isTrue,
    );
    expect(
      travelMethodOptions
          .singleWhere((option) => option.key == 'other')
          .automatic,
      isFalse,
    );
  });
}
