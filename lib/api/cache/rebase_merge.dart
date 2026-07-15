/// 三方 merge:回傳離線(ours)改過的欄位中,與 server(theirs)真衝突的欄位名。
/// 空 list = 可自動 rebase。base==null → 降級 last-write-wins(視為無衝突)。
library;

List<String> rebaseMerge(
  Map<String, dynamic>? base,
  Map<String, dynamic> ours,
  Map<String, dynamic> theirs,
) {
  if (base == null) return const [];
  final conflicts = <String>[];
  for (final f in ours.keys) {
    final b = _norm(base[f]);
    final o = _norm(ours[f]);
    // 真實 caller 送整包(full-form);使用者沒改該欄(ours==base)→ 非衝突,
    // 重送也不送該欄(保留 server theirs)。放最前避免被誤判成三方衝突。
    if (o == b) continue;
    final t = _norm(theirs[f]);
    if (b == t) continue; // server 沒動該欄 → 安全採 ours
    if (o == t) continue; // 剛好同值 → 無衝突
    conflicts.add(f); // base/ours/theirs 三方不同 → 真衝突
  }
  return conflicts;
}

/// 使用者實際改過的欄位(ours 與 base 不同);base==null → 全部視為 dirty(降級)。
/// rebase 無衝突重送 / 「保留你的」重送時據此只送改過的欄位,不覆蓋 server。
Set<String> dirtyFields(Map<String, dynamic>? base, Map<String, dynamic> ours) {
  if (base == null) return ours.keys.toSet();
  return {
    for (final f in ours.keys)
      if (_norm(ours[f]) != _norm(base[f])) f,
  };
}

/// [C1] 型別正規化:wire 數字可能 int 或 double,統一轉 double 再比;其餘原樣。
Object? _norm(Object? v) => v is num ? v.toDouble() : v;

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
