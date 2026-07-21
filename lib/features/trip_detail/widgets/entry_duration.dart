/// 停留時長計算與格式化（純函式,對應 web 版景點時長顯示）。
library;

/// 解析 `"HH:MM"` 為當日分鐘數;格式不符回 null。
int? _parseMinutes(String? time) {
  if (time == null) return null;
  final parts = time.split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return h * 60 + m;
}

/// 由 start/end（`"HH:MM"`）計算時長並格式化為 web 風格字串。
///
/// 整點用整數（120 → `"2 hr"`）、半點用 `.5`（90 → `"1.5 hr"`）；
/// 其他間隔保留精確分鐘，避免顯示時長與起訖時間不一致。
/// 任一為 null、解析失敗或 end <= start → 回 null。
String? formatEntryDuration(String? startTime, String? endTime) {
  final start = _parseMinutes(startTime);
  final end = _parseMinutes(endTime);
  if (start == null || end == null) return null;
  final diff = end - start;
  if (diff <= 0) return null;

  final hours = diff ~/ 60;
  final minutes = diff % 60;
  if (minutes == 0) return '$hours hr';
  if (minutes == 30) return '$hours.5 hr';
  if (hours == 0) return '$minutes min';
  return '$hours hr $minutes min';
}
