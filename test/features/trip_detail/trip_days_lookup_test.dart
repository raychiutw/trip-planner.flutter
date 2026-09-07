import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/features/trip_detail/trip_days_lookup.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/models/trip.dart';

void main() {
  const days = [
    TripDay(
      id: 1,
      dayNum: 1,
      version: 0,
      timeline: [TimelineEntry(id: 11, sortOrder: 0, title: 'a', version: 0)],
    ),
    // id / dayNum / 陣列索引三者刻意都不同:回錯任何一種都會被抓到。
    TripDay(
      id: 7,
      dayNum: 3,
      version: 0,
      timeline: [TimelineEntry(id: 22, sortOrder: 0, title: 'b', version: 0)],
    ),
  ];

  test('dayNumContaining:找到停留點所在的 Day(回 dayNum 不是 id 或索引);找不到回 null', () {
    expect(dayNumContaining(days, 22), 3);
    expect(dayNumContaining(days, 99), isNull);
    expect(dayNumContaining(const [], 22), isNull);
  });

  test(
    'tripDisplayTitle:detail 標題 → summary 標題 → detail 名稱 → summary 名稱 → 行程',
    () {
      const detail = Trip(id: 't', name: 'detail-name', title: '  ');
      const summary = TripSummary(
        tripId: 't',
        name: 'summary-name',
        title: '摘要標題',
      );
      expect(tripDisplayTitle(detail: detail, summary: summary), '摘要標題');
      expect(
        tripDisplayTitle(
          detail: const Trip(id: 't', name: 'n', title: '細節標題'),
          summary: summary,
        ),
        '細節標題',
      );
      expect(
        tripDisplayTitle(
          detail: detail,
          summary: const TripSummary(tripId: 't', name: 'sn'),
        ),
        'detail-name',
      );
      expect(
        tripDisplayTitle(
          summary: const TripSummary(tripId: 't', name: 'sn'),
        ),
        'sn',
      );
      expect(tripDisplayTitle(), '行程');
    },
  );
}
