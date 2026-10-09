import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/display_format.dart';

void main() {
  group('formatTimeRange', () {
    test('起訖都有 → D1 定版格式(全形冒號、中間半形連字號)', () {
      expect(formatTimeRange('09:30', '11:00'), '09：30 - 11：00');
    });

    test('只有起或只有訖 → 單一時間', () {
      expect(formatTimeRange('09:30', null), '09：30');
      expect(formatTimeRange('', '11:00'), '11：00');
    });

    test('已是全形冒號的輸入不重複轉換', () {
      expect(formatTimeRange('09：30', '11：00'), '09：30 - 11：00');
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
}
