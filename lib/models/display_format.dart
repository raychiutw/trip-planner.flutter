/// 跨畫面共用的顯示字串格式:時間範圍與 Day 標籤只在這裡定義,各畫面不各寫一套。
library;

/// 起訖時間範圍,例如 `09：30 - 11：00`(DESIGN D1 定版格式:全形冒號、半形連字號)。
///
/// 只有一端時回單一時間,兩端皆空回空字串(佔位文字如「未設定時間」由呼叫端決定)。
String formatTimeRange(String? start, String? end) {
  final from = _normalizeTime(start);
  final to = _normalizeTime(end);
  if (from.isEmpty && to.isEmpty) return '';
  if (from.isEmpty) return to;
  if (to.isEmpty) return from;
  return '$from - $to';
}

String _normalizeTime(String? value) =>
    (value ?? '').trim().replaceAll(':', '：');

/// Day 標籤,例如 `Day 2` 或 `Day 2 · 首里城`。
///
/// [title] 為空或本身就是預設的 `Day N` 時不重複顯示。
String dayLabel(int dayNum, {String? title}) {
  final base = 'Day $dayNum';
  final text = title?.trim();
  if (text == null || text.isEmpty || text == base) return base;
  return '$base · $text';
}
