import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/features/account/account_display.dart';

void main() {
  group('humanAccountTime', () {
    final now = DateTime.utc(2026, 7, 15, 12);

    test('近期 ISO 時間顯示相對時間', () {
      expect(humanAccountTime('2026-07-15T11:55:00Z', now: now), '5 分鐘前');
      expect(humanAccountTime('2026-07-15T09:00:00Z', now: now), '3 小時前');
    });

    test('較舊 ISO 時間顯示人類日期', () {
      expect(humanAccountTime('2026-07-01T10:00:00Z', now: now), '2026/7/1');
    });

    test('epoch 毫秒不直接外露數字', () {
      expect(humanEpochTime(1783500000000), '2026/7/8');
    });
  });
}
