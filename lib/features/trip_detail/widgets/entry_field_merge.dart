/// 線上編輯停留點時的三方欄位合併 —— 重用離線 rebase 的純函式,不在 widget 裡再寫一份。
///
/// base = 上次接受的伺服器版本,ours = 表單目前的值,theirs = 剛到的新版本。
library;

import '../../../api/cache/rebase_merge.dart';
import '../../../models/entry.dart';

/// 表單能改的三個欄位;`description` 用空字串表示「沒有」,時間一律 HH:mm。
const entryEditableFields = ['description', 'startTime', 'endTime'];

typedef EntryFields = Map<String, dynamic>;

/// 把停留點正規化成可比對的欄位 map。
EntryFields entryFieldsOf(TimelineEntry entry) => {
  'description': entry.description ?? '',
  'startTime': normalizeHm(entry.startTime),
  'endTime': normalizeHm(entry.endTime),
};

/// `9:5` → `09:05`;不是 HH:mm 形就當沒有。
String? normalizeHm(String? hm) {
  if (hm == null) return null;
  final parts = hm.split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// 回傳:真衝突的欄位([conflicts])、該直接帶入對方值的欄位([adopt] = 使用者沒改過的)。
///
/// 先前已標衝突的欄位,只要表單值仍與對方不同就維持衝突;使用者已把它改成對方的值
/// 就解除。
({Set<String> conflicts, Set<String> adopt}) mergeEntryFields({
  required EntryFields base,
  required EntryFields ours,
  required EntryFields theirs,
  required Set<String> previousConflicts,
}) {
  final fresh = rebaseMerge(base, ours, theirs).toSet();
  final kept = {
    for (final field in previousConflicts)
      if (ours[field] != theirs[field]) field,
  };
  final dirty = dirtyFields(base, ours);
  return (
    conflicts: {...fresh, ...kept},
    adopt: {
      for (final field in entryEditableFields)
        if (!dirty.contains(field)) field,
    },
  );
}
