/// 地圖視覺樣式：對齊 web `src/lib/dayPalette.ts` 與 `src/lib/mapHelpers.ts`。
///
/// 刻意做成純資料（不碰地圖 SDK、不算圖）—— 視覺契約才能用單元測試鎖住，
/// 與 web 把 `markerStyle` 從 DOM 建構拆出來的理由相同。
library;

import 'package:flutter/material.dart';

/// 逐日輪替 10 色（Tailwind -500）。
///
/// 順序必須與 web `DAY_PALETTE` 逐色一致，否則同一趟行程在 web 與 app 的
/// 日別色會對不起來。
///
/// design.md data-viz 例外的**範圍**（對齊 web dayPalette.ts 的使用範圍註記）：
/// 只用於路線色與 marker 的外圈／數字，**不可當 marker 填色或 UI chrome**。
const List<Color> kDayPinPalette = [
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
];

/// 品牌 accent（design.md soft brown）：聚焦 marker 的填色。
const Color kTripMapFocusColor = Color(0xFFA97A4A);

/// 取第 N 天（1-based）的色；超過 10 天輪回 day 1，無效值回 day 1。
///
/// 以 `dayNum` 而非陣列 index 取色 —— 對齊 web `dayColor(dayNum)`，天數有
/// 缺口時兩個 client 才不會配色錯位。
Color dayPinColor(int dayNum) {
  if (dayNum < 1) return kDayPinPalette.first;
  return kDayPinPalette[(dayNum - 1) % kDayPinPalette.length];
}

/// marker 的視覺契約（對齊 web `mapHelpers.markerStyle`）。
@immutable
class TripMapMarkerStyle {
  const TripMapMarkerStyle({
    required this.fill,
    required this.stroke,
    required this.text,
    required this.diameter,
    required this.borderWidth,
    required this.fontSize,
    required this.zIndex,
  });

  /// 圓形底色。
  final Color fill;

  /// 外圈色。
  final Color stroke;

  /// 數字色。
  final Color text;

  /// 直徑（logical px）。
  final double diameter;
  final double borderWidth;
  final double fontSize;

  /// 疊放層級；聚焦點必須壓過鄰近 marker。
  final int zIndex;

  @override
  bool operator ==(Object other) {
    return other is TripMapMarkerStyle &&
        other.fill == fill &&
        other.stroke == stroke &&
        other.text == text &&
        other.diameter == diameter &&
        other.borderWidth == borderWidth &&
        other.fontSize == fontSize &&
        other.zIndex == zIndex;
  }

  @override
  int get hashCode =>
      Object.hash(fill, stroke, text, diameter, borderWidth, fontSize, zIndex);
}

/// 白底圓形 chip + 日別色外圈與數字；聚焦點改用品牌 accent 填底 + 白字並放大。
///
/// 日別色只做外圈／數字，不做填色 —— 這是 web 的視覺語言，也讓地圖上不會出現
/// 一整片彩虹色塊。
TripMapMarkerStyle tripMapMarkerStyle({
  required Color dayColor,
  required bool isFocused,
}) {
  if (isFocused) {
    return const TripMapMarkerStyle(
      fill: kTripMapFocusColor,
      stroke: Colors.white,
      text: Colors.white,
      diameter: 36,
      borderWidth: 2,
      fontSize: 12,
      zIndex: 1000,
    );
  }
  return TripMapMarkerStyle(
    fill: Colors.white,
    stroke: dayColor,
    text: dayColor,
    diameter: 28,
    borderWidth: 1.5,
    fontSize: 11,
    zIndex: 0,
  );
}

/// 路線的視覺契約（對齊 web `mapHelpers.segmentStyle`）。
@immutable
class TripMapRouteStyle {
  const TripMapRouteStyle({
    required this.color,
    required this.strokeWidth,
    required this.opacity,
    required this.dashed,
  });

  final Color color;
  final double strokeWidth;
  final double opacity;

  /// 偶數天畫虛線：色盲使用者靠線型（而非只靠顏色）區分不同天。
  final bool dashed;
}

/// 日別色細線；偶數天虛線（web F008 色盲輔助），聚焦段加粗提高對比。
TripMapRouteStyle tripMapRouteStyle({
  required int dayNum,
  required bool isActive,
}) {
  return TripMapRouteStyle(
    color: dayPinColor(dayNum),
    strokeWidth: isActive ? 4 : 3,
    opacity: isActive ? 0.85 : 0.6,
    dashed: dayNum >= 1 && dayNum.isEven,
  );
}
