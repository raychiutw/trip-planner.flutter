library;

export '../../models/field_merge.dart';

/// 從 days 快取(day 組成的 List)跨 day 找 timeline 內 id==entryId 的 row,
/// 取出 [fields] 各欄位 + `version`(camelCase wire)。找不到 → null。
Map<String, dynamic>? extractEntryFields(
  Object? cachedDays,
  int entryId,
  List<String> fields,
) {
  if (cachedDays is! List) return null;
  for (final day in cachedDays) {
    final timeline = (day is Map) ? day['timeline'] : null;
    if (timeline is! List) continue;
    for (final row in timeline) {
      if (row is Map && row['id'] == entryId) {
        return _pick(row, fields);
      }
    }
  }
  return null;
}

/// 從 notes 快取(段名→row List 的 Map)的 [sectionKey] 段找 id==rowId 的 row,
/// 取出 [fields] + `version`。找不到 → null。
Map<String, dynamic>? extractNoteFields(
  Object? cachedNotes,
  String sectionKey,
  int rowId,
  List<String> fields,
) {
  if (cachedNotes is! Map) return null;
  final section = cachedNotes[sectionKey];
  if (section is! List) return null;
  for (final row in section) {
    if (row is Map && row['id'] == rowId) {
      return _pick(row, fields);
    }
  }
  return null;
}

Map<String, dynamic> _pick(Map row, List<String> fields) => {
  for (final f in fields)
    if (row.containsKey(f)) f: row[f],
  if (row.containsKey('version')) 'version': row['version'],
};
