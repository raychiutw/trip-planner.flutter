/// 時間軸與地圖共用的純查找：從 days 找 Day、決定行程標題。
///
/// 兩個畫面對同一份 `tripDaysProvider` 各自投影，但「這個停留點在哪一天」與
/// 「這個行程叫什麼」的答案必須一致，所以只寫在這裡。
library;

import '../../models/day.dart';
import '../../models/trip.dart';

/// 含有 [entryId] 的那一天的 dayNum；找不到回 null。
int? dayNumContaining(List<TripDay> days, int entryId) {
  for (final day in days) {
    if (day.timeline.any((entry) => entry.id == entryId)) return day.dayNum;
  }
  return null;
}

/// 行程顯示標題：detail 標題 → summary 標題 → detail 名稱 → summary 名稱 → 「行程」。
/// 空白視同缺席。
String tripDisplayTitle({Trip? detail, TripSummary? summary}) {
  for (final candidate in [
    detail?.title,
    summary?.title,
    detail?.name,
    summary?.name,
  ]) {
    final trimmed = candidate?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  }
  return '行程';
}
