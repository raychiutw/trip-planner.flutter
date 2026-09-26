/// 時間軸與地圖共用的行程日查找。
library;

import '../../models/day.dart';
import '../../models/entry.dart';
import '../../models/trip.dart';

/// 從同一次 days 發射建立；換行程或 fresh 發射時重建一次。
class TripDaysIndex {
  TripDaysIndex(List<TripDay> days)
    : days = days,
      _entryDayNums = {
        for (final day in days)
          for (final entry in day.timeline) entry.id: day.dayNum,
      },
      _entriesByDay = {for (final day in days) day.dayNum: day.timeline};

  final List<TripDay> days;
  final Map<int, int> _entryDayNums;
  final Map<int, List<TimelineEntry>> _entriesByDay;

  int? dayNumContaining(int entryId) => _entryDayNums[entryId];

  List<TimelineEntry> entriesForDay(int dayNum) =>
      _entriesByDay[dayNum] ?? const [];
}

/// 行程顯示標題：detail 標題 → summary 標題 → detail 名稱 → summary 名稱。
String tripDisplayTitle({Trip? detail, TripSummary? summary}) {
  for (final candidate in [
    detail?.title,
    summary?.title,
    detail?.name,
    summary?.name,
  ]) {
    final title = candidate?.trim();
    if (title != null && title.isNotEmpty) return title;
  }
  return '行程';
}
