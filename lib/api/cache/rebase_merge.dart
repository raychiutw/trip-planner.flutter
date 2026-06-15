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
    final t = _norm(theirs[f]);
    final o = _norm(ours[f]);
    if (b == t) continue; // server 沒動該欄 → 安全採 ours
    if (o == t) continue; // 剛好同值 → 無衝突
    conflicts.add(f); // base/ours/theirs 三方不同 → 真衝突
  }
  return conflicts;
}

/// [C1] 型別正規化:wire 數字可能 int 或 double,統一轉 double 再比;其餘原樣。
Object? _norm(Object? v) => v is num ? v.toDouble() : v;
