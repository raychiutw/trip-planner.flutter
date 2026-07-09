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
        'min': 20,
        'distanceM': 4200,
        'source': 'manual',
        'version': 3,
      });
      expect(seg.id, 5);
      expect(seg.fromEntryId, 11);
      expect(seg.toEntryId, 12);
      expect(seg.mode, 'transit');
      expect(seg.min, 20);
      expect(seg.distanceM, 4200);
      expect(seg.source, 'manual');
      expect(seg.version, 3);
    });

    test('nullable 缺漏 + version 預設 0', () {
      final seg = TripSegment.fromJson({'id': 1, 'mode': 'driving'});
      expect(seg.fromEntryId, isNull);
      expect(seg.toEntryId, isNull);
      expect(seg.min, isNull);
      expect(seg.distanceM, isNull);
      expect(seg.source, isNull);
      expect(seg.version, 0);
    });

    test('解析後端 snake_case 欄位', () {
      final seg = TripSegment.fromJson({
        'id': 6,
        'from_entry_id': 21,
        'to_entry_id': 22,
        'mode': 'walking',
        'distance_m': 950,
        'version': 4,
      });

      expect(seg.fromEntryId, 21);
      expect(seg.toEntryId, 22);
      expect(seg.distanceM, 950);
      expect(seg.version, 4);
    });
  });
}
