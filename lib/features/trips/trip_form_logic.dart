/// 建立/編輯行程的純衍生邏輯(無 Flutter 依賴,可單測)。
library;

import '../../models/destination_input.dart';

String deriveTripName(List<DestinationInput> dests) =>
    dests.map((d) => d.name).join('、');

/// 目的地 country 去重 join;全無 → 'JP'。
String deriveCountries(List<DestinationInput> dests) {
  final codes = <String>[];
  for (final d in dests) {
    final c = d.country;
    if (c != null && c.isNotEmpty && !codes.contains(c)) codes.add(c);
  }
  return codes.isEmpty ? 'JP' : codes.join(',');
}

String _pad2(int n) => n.toString().padLeft(2, '0');
String _ymd(DateTime d) => '${d.year}-${_pad2(d.month)}-${_pad2(d.day)}';

/// 彈性模式:該月 1 號起算 dayCount 天 → (start, end)。
(String, String) flexibleRange(int year, int month, int dayCount) {
  final start = DateTime(year, month, 1);
  final end = start.add(Duration(days: dayCount - 1));
  return (_ymd(start), _ymd(end));
}

/// 含頭尾天數。
int tripDayCount(String start, String end) =>
    DateTime.parse(end).difference(DateTime.parse(start)).inDays + 1;

final _ymdRe = RegExp(r'^\d{4}-\d{2}-\d{2}$');

bool isTripDatesValid(String start, String end) {
  if (!_ymdRe.hasMatch(start) || !_ymdRe.hasMatch(end)) return false;
  final days = tripDayCount(start, end);
  return days >= 1 && days <= 30;
}
