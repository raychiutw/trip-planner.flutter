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
        'submode': 'monorail',
        'min': 20,
        'distanceM': 4200,
        'source': 'haversine',
        'computedAt': 1700000000000,
        'version': 3,
        'noTravel': 1,
      });
      expect(seg.id, 5);
      expect(seg.fromEntryId, 11);
      expect(seg.toEntryId, 12);
      expect(seg.mode, 'transit');
      expect(seg.submode, 'monorail');
      expect(seg.min, 20);
      expect(seg.distanceM, 4200);
      expect(seg.source, 'haversine');
      expect(seg.isStale, isFalse);
      expect(seg.noTravel, isTrue);
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
      expect(seg.isStale, isFalse);
      expect(seg.noTravel, isFalse);
      expect(seg.version, 0);
    });

    test('computedAt null marks segment stale', () {
      final seg = TripSegment.fromJson({
        'id': 2,
        'mode': 'driving',
        'computedAt': null,
      });

      expect(seg.isStale, isTrue);
    });
  });
}
