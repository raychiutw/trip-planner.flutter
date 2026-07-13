import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/entry.dart';

void main() {
  group('Travel.fromJson', () {
    test('解析完整欄位', () {
      final travel = Travel.fromJson({
        'type': 'driving',
        'desc': '開車 25 分',
        'submode': 'bus',
        'min': 25,
        'distanceM': 18000,
        'source': 'google',
      });

      expect(travel.type, 'driving');
      expect(travel.desc, '開車 25 分');
      expect(travel.submode, 'bus');
      expect(travel.min, 25);
      expect(travel.distanceM, 18000);
      expect(travel.source, 'google');
    });

    test('nullable 欄位缺漏時為 null', () {
      final travel = Travel.fromJson({'type': 'walking'});

      expect(travel.desc, isNull);
      expect(travel.min, isNull);
      expect(travel.distanceM, isNull);
      expect(travel.source, isNull);
      expect(travel.sameplace, isFalse);
    });

    test('免交通 payload 的 type:null 不會解析崩潰', () {
      final travel = Travel.fromJson({'type': null, 'sameplace': true});

      expect(travel.type, 'transit');
      expect(travel.sameplace, isTrue);
    });
  });

  group('EntryPoiInfo.fromJson', () {
    test('rating int 轉 double', () {
      final poiInfo = EntryPoiInfo.fromJson({
        'poiId': 555,
        'name': '暖暮拉麵',
        'rating': 4,
      });

      expect(poiInfo.rating, 4.0);
      expect(poiInfo.rating, isA<double>());
    });

    test('解析完整欄位', () {
      final poiInfo = EntryPoiInfo.fromJson({
        'poiId': 555,
        'name': '暖暮拉麵',
        'lat': 26.21,
        'lng': 127.68,
        'type': 'restaurant',
        'category': '拉麵',
        'hours': '11:00-22:00',
        'rating': 4.5,
        'price': r'$',
        'note': '排隊名店',
        'reservation': '已訂位 18:00',
        'reservationUrl': 'https://book.example/abc',
        'description': '招牌豚骨',
        'sortOrder': 2,
      });

      expect(poiInfo.poiId, 555);
      expect(poiInfo.name, '暖暮拉麵');
      expect(poiInfo.lat, 26.21);
      expect(poiInfo.lng, 127.68);
      expect(poiInfo.type, 'restaurant');
      expect(poiInfo.category, '拉麵');
      expect(poiInfo.hours, '11:00-22:00');
      expect(poiInfo.rating, 4.5);
      expect(poiInfo.price, r'$');
      expect(poiInfo.note, '排隊名店');
      expect(poiInfo.reservation, '已訂位 18:00');
      expect(poiInfo.reservationUrl, 'https://book.example/abc');
      expect(poiInfo.description, '招牌豚骨');
      expect(poiInfo.sortOrder, 2);
    });

    test('poiId 以外全 nullable，缺漏為 null', () {
      final poiInfo = EntryPoiInfo.fromJson({'poiId': 1});

      expect(poiInfo.name, isNull);
      expect(poiInfo.lat, isNull);
      expect(poiInfo.lng, isNull);
      expect(poiInfo.type, isNull);
      expect(poiInfo.category, isNull);
      expect(poiInfo.hours, isNull);
      expect(poiInfo.rating, isNull);
      expect(poiInfo.price, isNull);
      expect(poiInfo.note, isNull);
      expect(poiInfo.sortOrder, isNull);
    });
  });

  group('TimelineEntry.fromJson', () {
    test('解析內嵌 travel / master / alternates', () {
      final entry = TimelineEntry.fromJson({
        'id': 9001,
        'dayId': 101,
        'sortOrder': 1,
        'time': '12:00',
        'startTime': '12:00',
        'endTime': '13:30',
        'title': '午餐：暖暮拉麵',
        'description': '人氣排隊店',
        'note': '備案在隔壁',
        'version': 2,
        'entryPoisVersion': 7,
        'travel': {'type': 'driving', 'min': 15, 'distanceM': 8000},
        'master': {'poiId': 555, 'name': '暖暮拉麵', 'rating': 4},
        'alternates': [
          {'poiId': 556, 'name': '通堂拉麵', 'sortOrder': 2},
          {'poiId': 557, 'name': '金月蕎麥麵', 'sortOrder': 3},
        ],
      });

      expect(entry.id, 9001);
      expect(entry.dayId, 101);
      expect(entry.sortOrder, 1);
      expect(entry.time, '12:00');
      expect(entry.startTime, '12:00');
      expect(entry.endTime, '13:30');
      expect(entry.title, '暖暮拉麵');
      expect(entry.description, '人氣排隊店');
      expect(entry.note, '備案在隔壁');
      expect(entry.version, 2);
      expect(entry.entryPoisVersion, '7'); // int wire → string
      expect(entry.travel?.type, 'driving');
      expect(entry.travel?.min, 15);
      expect(entry.master?.poiId, 555);
      expect(entry.master?.rating, 4.0);
      expect(entry.alternates, hasLength(2));
      expect(entry.alternates.first.name, '通堂拉麵');
      expect(entry.alternates.last.sortOrder, 3);
    });

    test('travel/master 缺漏為 null，alternates 缺漏預設空清單', () {
      final entry = TimelineEntry.fromJson({
        'id': 9002,
        'sortOrder': 4,
        'title': '自由活動',
        'version': 1,
      });

      expect(entry.dayId, isNull);
      expect(entry.time, isNull);
      expect(entry.startTime, isNull);
      expect(entry.endTime, isNull);
      expect(entry.description, isNull);
      expect(entry.note, isNull);
      expect(entry.travel, isNull);
      expect(entry.master, isNull);
      expect(entry.alternates, isEmpty);
    });

    test('新後端無 title 時用 displayTitle / master.name 當顯示標題', () {
      final entry = TimelineEntry.fromJson({
        'id': 9003,
        'sortOrder': 5,
        'displayTitle': '暖暮拉麵',
        'version': 1,
        'master': {'poiId': 555, 'name': '暖暮拉麵'},
      });

      expect(entry.title, '暖暮拉麵');
    });

    test('legacy title 不再當作顯示標題 fallback', () {
      final entry = TimelineEntry.fromJson({
        'id': 9004,
        'sortOrder': 6,
        'title': '舊 trip_entries.title',
        'version': 1,
      });

      expect(entry.title, '（未選擇景點）');
    });
  });
}
