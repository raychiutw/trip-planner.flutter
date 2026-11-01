import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/display_format.dart';

void main() {
  group('formatTimeRange', () {
    test('起訖都有 → 半形冒號、中間半形連字號', () {
      expect(formatTimeRange('09:30', '11:00'), '09:30 - 11:00');
    });

    test('只有起或只有訖 → 單一時間', () {
      expect(formatTimeRange('09:30', null), '09:30');
      expect(formatTimeRange('', '11:00'), '11:00');
    });

    test('全形冒號的輸入統一轉成半形', () {
      expect(formatTimeRange('09：30', '11：00'), '09:30 - 11:00');
    });

    test('兩端皆空 → 空字串,由呼叫端決定佔位文字', () {
      expect(formatTimeRange(null, null), '');
      expect(formatTimeRange(' ', ''), '');
    });
  });

  group('dayLabel', () {
    test('只有序號 → Day N,不補零、不全大寫', () {
      expect(dayLabel(1), 'Day 1');
      expect(dayLabel(12), 'Day 12');
    });

    test('帶標題 → Day N · 標題', () {
      expect(dayLabel(2, title: '首里城'), 'Day 2 · 首里城');
    });

    test('標題與預設 Day N 相同或為空 → 不重複', () {
      expect(dayLabel(2, title: 'Day 2'), 'Day 2');
      expect(dayLabel(2, title: '  '), 'Day 2');
    });
  });

  group('formatEntryTime', () {
    test('起訖都有 → 範圍，忽略 time', () {
      expect(formatEntryTime('09:00', '10:30', '早上'), '09:00 - 10:30');
    });
    test('只有一端 → 優先用 time，沒有才退回該端', () {
      expect(formatEntryTime('09:00', null, '早上'), '早上');
      expect(formatEntryTime('09:00', '', null), '09:00');
      expect(formatEntryTime(null, '10:30', ' '), '10:30');
    });
    test('全空 → 空字串', () {
      expect(formatEntryTime(null, null, null), '');
    });
  });

  group('formatUtcTimestamp（後端 datetime(\'now\') 是 UTC，沒有時區標記）', () {
    const taipei = Duration(hours: 8);

    test('沒有時區的字串視為 UTC，換成本地時間（+8）', () {
      expect(
        formatUtcTimestamp('2026-07-09 01:00:00', localOffset: taipei),
        '2026-07-09 09:00',
      );
    });

    test('跨日要進位', () {
      expect(
        formatUtcTimestamp('2026-07-09 20:30:00', localOffset: taipei),
        '2026-07-10 04:30',
      );
    });

    test('ISO 帶 Z 或帶時區偏移都照該時區換算', () {
      expect(
        formatUtcTimestamp('2026-07-09T01:00:00Z', localOffset: taipei),
        '2026-07-09 09:00',
      );
      expect(
        formatUtcTimestamp('2026-07-09T09:00:00+08:00', localOffset: taipei),
        '2026-07-09 09:00',
      );
    });

    test('解析不了就原樣回傳，不吞掉資料', () {
      expect(formatUtcTimestamp('昨天', localOffset: taipei), '昨天');
      expect(formatUtcTimestamp('', localOffset: taipei), '');
    });
  });
}
