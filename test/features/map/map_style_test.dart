import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/features/map/map_style.dart';

void main() {
  group('dayPinColor', () {
    test('色盤順序與 web DAY_PALETTE 一致', () {
      // 順序必須逐色對齊 web src/lib/dayPalette.ts —— 同一趟行程在兩個 client
      // 的日別色若對不起來，使用者會以為看錯行程。
      expect(kDayPinPalette, const [
        Color(0xFF0EA5E9), // sky-500     day 1
        Color(0xFF14B8A6), // teal-500    day 2
        Color(0xFFF59E0B), // amber-500   day 3
        Color(0xFFF43F5E), // rose-500    day 4
        Color(0xFF8B5CF6), // violet-500  day 5
        Color(0xFF84CC16), // lime-500    day 6
        Color(0xFFF97316), // orange-500  day 7
        Color(0xFF06B6D4), // cyan-500    day 8
        Color(0xFFD946EF), // fuchsia-500 day 9
        Color(0xFF10B981), // emerald-500 day 10
      ]);
    });

    test('以 dayNum（1-based）取色，超過 10 天輪回 day 1', () {
      expect(dayPinColor(1), const Color(0xFF0EA5E9));
      expect(dayPinColor(10), const Color(0xFF10B981));
      expect(dayPinColor(11), dayPinColor(1));
    });

    test('無效 dayNum 回退 day 1', () {
      expect(dayPinColor(0), kDayPinPalette.first);
      expect(dayPinColor(-3), kDayPinPalette.first);
    });
  });

  group('tripMapMarkerStyle', () {
    test('未聚焦：白底 + 日別色外圈與數字（日別色不當填色）', () {
      final style = tripMapMarkerStyle(
        dayColor: const Color(0xFF0EA5E9),
        isFocused: false,
      );

      expect(style.fill, const Color(0xFFFFFFFF));
      expect(style.stroke, const Color(0xFF0EA5E9));
      expect(style.text, const Color(0xFF0EA5E9));
      expect(style.diameter, 28);
      expect(style.borderWidth, 1.5);
      expect(style.zIndex, 0);
    });

    test('聚焦：品牌 accent 填底 + 白字，放大並提高層級', () {
      final style = tripMapMarkerStyle(
        dayColor: const Color(0xFF0EA5E9),
        isFocused: true,
      );

      expect(style.fill, kTripMapFocusColor);
      expect(style.stroke, const Color(0xFFFFFFFF));
      expect(style.text, const Color(0xFFFFFFFF));
      expect(style.diameter, 36);
      expect(style.zIndex, 1000);
    });
  });

  group('tripMapRouteStyle', () {
    test('奇數天：日別色實線、粗細 5、透明度 0.6', () {
      final style = tripMapRouteStyle(dayNum: 1, isActive: false);

      expect(style.color, const Color(0xFF0EA5E9));
      expect(style.strokeWidth, 5);
      expect(style.dashed, isFalse);
      expect(style.opacity, 0.6);
    });

    test('偶數天：虛線（色盲輔助，對齊 web F008）', () {
      expect(tripMapRouteStyle(dayNum: 2, isActive: false).dashed, isTrue);
      expect(tripMapRouteStyle(dayNum: 3, isActive: false).dashed, isFalse);
    });

    test('聚焦段：加粗到 6、透明度 0.85', () {
      final style = tripMapRouteStyle(dayNum: 1, isActive: true);

      expect(style.strokeWidth, 6);
      expect(style.opacity, 0.85);
    });
  });
}
