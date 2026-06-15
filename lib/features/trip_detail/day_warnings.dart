/// 當日行程注意事項偵測（純函式,移植 web src/lib/validateDay）。
library;

import '../../models/entry.dart';

final _timeRe = RegExp(r'(\d{1,2}):(\d{2})');

/// 逐筆檢查 timeline:若 entry.startTime 開頭小時早於其 POI（master/alternates)
/// 的營業開始小時,加入一筆提醒字串。回傳警告清單（無問題回 []）。
List<String> validateDay(List<TimelineEntry> timeline) {
  final warnings = <String>[];
  for (final entry in timeline) {
    final startTime = entry.startTime;
    if (startTime == null) continue;
    final entryMatch = _timeRe.firstMatch(startTime);
    if (entryMatch == null) continue;
    final entryHour = int.parse(entryMatch.group(1)!);

    final pois = <EntryPoiInfo>[
      if (entry.master != null) entry.master!,
      ...entry.alternates,
    ];
    for (final poi in pois) {
      final hours = poi.hours;
      if (hours == null) continue;
      final openMatch = _timeRe.firstMatch(hours);
      if (openMatch == null) continue;
      final openHour = int.parse(openMatch.group(1)!);
      if (entryHour < openHour) {
        warnings.add(
          '${entry.title}（$startTime)可能早於 ${poi.name} 營業時間（$hours)',
        );
      }
    }
  }
  return warnings;
}
