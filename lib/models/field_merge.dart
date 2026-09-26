/// 三方 merge: 回傳 ours 改過且與 theirs 真衝突的欄位名。
/// 空 list = 可自動 rebase；base == null 時視為無衝突。
library;

List<String> rebaseMerge(
  Map<String, dynamic>? base,
  Map<String, dynamic> ours,
  Map<String, dynamic> theirs,
) {
  if (base == null) return const [];
  final conflicts = <String>[];
  for (final field in ours.keys) {
    final before = _norm(base[field]);
    final current = _norm(ours[field]);
    if (current == before) continue;
    final latest = _norm(theirs[field]);
    if (before == latest || current == latest) continue;
    conflicts.add(field);
  }
  return conflicts;
}

/// 使用者實際改過的欄位；base == null 時全部視為 dirty。
Set<String> dirtyFields(Map<String, dynamic>? base, Map<String, dynamic> ours) {
  if (base == null) return ours.keys.toSet();
  return {
    for (final field in ours.keys)
      if (_norm(ours[field]) != _norm(base[field])) field,
  };
}

Object? _norm(Object? value) => value is num ? value.toDouble() : value;
