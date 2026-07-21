import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/features/trip_detail/widgets/entry_duration.dart';

void main() {
  group('formatEntryDuration', () {
    test('整點時長 → 整數 hr（120 分 = 2 hr）', () {
      expect(formatEntryDuration('09:00', '11:00'), '2 hr');
    });

    test('半點時長 → .5 hr（90 分 = 1.5 hr）', () {
      expect(formatEntryDuration('09:00', '10:30'), '1.5 hr');
    });

    test('2.5 hr（150 分）', () {
      expect(formatEntryDuration('09:00', '11:30'), '2.5 hr');
    });

    test('不足半點仍依分鐘換算（30 分 = 0.5 hr）', () {
      expect(formatEntryDuration('09:00', '09:30'), '0.5 hr');
    });

    test('非半小時倍數維持精確分鐘（45 分 = 45 min）', () {
      expect(formatEntryDuration('12:00', '12:45'), '45 min');
    });

    test('超過一小時的零散分鐘不被四捨五入', () {
      expect(formatEntryDuration('12:00', '13:15'), '1 hr 15 min');
    });

    test('startTime 為 null → 回 null', () {
      expect(formatEntryDuration(null, '11:00'), isNull);
    });

    test('endTime 為 null → 回 null', () {
      expect(formatEntryDuration('09:00', null), isNull);
    });

    test('end == start → 回 null', () {
      expect(formatEntryDuration('09:00', '09:00'), isNull);
    });

    test('end < start → 回 null', () {
      expect(formatEntryDuration('11:00', '09:00'), isNull);
    });
  });
}
