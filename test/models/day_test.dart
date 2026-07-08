import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/day.dart';

void main() {
  group('TripLocation.fromJson', () {
    test('解析完整欄位，lat/lng int 也轉 double', () {
      final location = TripLocation.fromJson({
        'name': '那霸市',
        'lat': 26,
        'lng': 127.68,
      });

      expect(location.name, '那霸市');
      expect(location.lat, 26.0);
      expect(location.lng, 127.68);
    });

    test('全欄位缺漏時皆為 null', () {
      final location = TripLocation.fromJson({});

      expect(location.name, isNull);
      expect(location.lat, isNull);
      expect(location.lng, isNull);
    });
  });

  group('DayHotel.fromJson', () {
    test('解析完整欄位含巢狀 location', () {
      final hotel = DayHotel.fromJson({
        'id': 42,
        'name': '海濱飯店',
        'checkout': '11:00',
        'note': '含早餐',
        'location': {'name': '北谷', 'lat': 26.32, 'lng': 127.76},
      });

      expect(hotel.id, 42);
      expect(hotel.name, '海濱飯店');
      expect(hotel.checkout, '11:00');
      expect(hotel.note, '含早餐');
      expect(hotel.location?.name, '北谷');
      expect(hotel.location?.lat, 26.32);
    });

    test('nullable 欄位缺漏時為 null', () {
      final hotel = DayHotel.fromJson({'id': 7, 'name': '商務旅館'});

      expect(hotel.checkout, isNull);
      expect(hotel.note, isNull);
      expect(hotel.location, isNull);
    });
  });

  group('TripDay.fromJson', () {
    test('解析完整欄位含 hotel 與 timeline 巢狀', () {
      final day = TripDay.fromJson({
        'id': 101,
        'dayNum': 2,
        'date': '2026-04-24',
        'dayOfWeek': '五',
        'label': '北部觀光',
        'title': '美麗海水族館日',
        'version': 3,
        'hotel': {
          'id': 42,
          'name': '海濱飯店',
          'checkout': '11:00',
          'location': {'lat': 26.32, 'lng': 127.76},
        },
        'timeline': [
          {
            'id': 9001,
            'dayId': 101,
            'sortOrder': 1,
            'title': '美麗海水族館',
            'version': 1,
          },
        ],
      });

      expect(day.id, 101);
      expect(day.dayNum, 2);
      expect(day.date, '2026-04-24');
      expect(day.dayOfWeek, '五');
      expect(day.label, '北部觀光');
      expect(day.title, '美麗海水族館日');
      expect(day.version, 3);
      expect(day.hotel?.name, '海濱飯店');
      expect(day.timeline, hasLength(1));
      expect(day.timeline.first.title, '美麗海水族館');
    });

    test('nullable 缺漏為 null，timeline 缺漏預設空清單', () {
      final day = TripDay.fromJson({'id': 102, 'dayNum': 3, 'version': 1});

      expect(day.date, isNull);
      expect(day.dayOfWeek, isNull);
      expect(day.label, isNull);
      expect(day.title, isNull);
      expect(day.hotel, isNull);
      expect(day.timeline, isEmpty);
    });

    test('解析 day management 回傳的 snake_case 欄位與預設 version', () {
      final day = TripDay.fromJson({
        'id': 103,
        'day_num': 4,
        'date': '2026-10-04',
        'day_of_week': '日',
        'label': 'Day 4',
        'title': '返程前採買',
      });

      expect(day.id, 103);
      expect(day.dayNum, 4);
      expect(day.date, '2026-10-04');
      expect(day.dayOfWeek, '日');
      expect(day.version, 0);
    });

    test('displayTitle fallback：title → label → Day N', () {
      final dayWithTitle = TripDay.fromJson({
        'id': 1,
        'dayNum': 1,
        'version': 1,
        'title': '抵達日',
        'label': '南部',
      });
      final dayWithLabel = TripDay.fromJson({
        'id': 2,
        'dayNum': 2,
        'version': 1,
        'label': '中部',
      });
      final dayBare = TripDay.fromJson({'id': 3, 'dayNum': 3, 'version': 1});

      expect(dayWithTitle.displayTitle, '抵達日');
      expect(dayWithLabel.displayTitle, '中部');
      expect(dayBare.displayTitle, 'Day 3');
    });
  });

  group('TripDayDeleteResult.fromJson', () {
    test('解析刪除行程日結果', () {
      final result = TripDayDeleteResult.fromJson({
        'ok': true,
        'removedEntryCount': 3,
      });

      expect(result.ok, isTrue);
      expect(result.removedEntryCount, 3);
    });
  });

  group('TripDaysShiftResult.fromJson', () {
    test('解析整段日期平移結果', () {
      final result = TripDaysShiftResult.fromJson({
        'ok': true,
        'newStartDate': '2026-10-05',
        'newEndDate': '2026-10-07',
        'daysShifted': 3,
      });

      expect(result.ok, isTrue);
      expect(result.newStartDate, '2026-10-05');
      expect(result.newEndDate, '2026-10-07');
      expect(result.daysShifted, 3);
    });
  });
}
