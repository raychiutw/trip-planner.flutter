import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/features/trip_detail/day_warnings.dart';
import 'package:tripline/models/entry.dart';

void main() {
  group('validateDay', () {
    test('空 timeline → 回空陣列', () {
      expect(validateDay(const []), isEmpty);
    });

    test('早於 master 營業時間 → 不再警告', () {
      final warnings = validateDay(const [
        TimelineEntry(
          id: 1,
          sortOrder: 0,
          version: 0,
          startTime: '08:00',
          title: '美麗海水族館',
          master: EntryPoiInfo(
            poiId: 100,
            name: '沖繩美麗海水族館',
            hours: '09:00-18:00',
          ),
        ),
      ]);
      expect(warnings, isEmpty);
    });

    test('晚於營業時間 → 無警告', () {
      final warnings = validateDay(const [
        TimelineEntry(
          id: 1,
          sortOrder: 0,
          version: 0,
          startTime: '10:00',
          title: '美麗海水族館',
          master: EntryPoiInfo(poiId: 100, name: '水族館', hours: '09:00-18:00'),
        ),
      ]);
      expect(warnings, isEmpty);
    });

    test('hours 為 null → 略過不警告', () {
      final warnings = validateDay(const [
        TimelineEntry(
          id: 1,
          sortOrder: 0,
          version: 0,
          startTime: '06:00',
          title: '早起景點',
          master: EntryPoiInfo(poiId: 100, name: '景點'),
        ),
      ]);
      expect(warnings, isEmpty);
    });

    test('startTime 為 null → 略過不警告', () {
      final warnings = validateDay(const [
        TimelineEntry(
          id: 1,
          sortOrder: 0,
          version: 0,
          title: '無時間',
          master: EntryPoiInfo(poiId: 100, name: '景點', hours: '09:00-18:00'),
        ),
      ]);
      expect(warnings, isEmpty);
    });

    test('master 與 alternate 營業時間都早於到達時間 → 不再警告', () {
      final warnings = validateDay(const [
        TimelineEntry(
          id: 1,
          sortOrder: 0,
          version: 0,
          startTime: '08:00',
          title: '行程點',
          master: EntryPoiInfo(poiId: 100, name: '主景點', hours: '09:00-18:00'),
          alternates: [
            EntryPoiInfo(poiId: 200, name: '備選景點', hours: '10:00-19:00'),
          ],
        ),
      ]);
      expect(warnings, isEmpty);
    });
  });
}
