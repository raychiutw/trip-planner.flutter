/// sembast → drift 的一次性資料搬遷。
library;

import 'dart:io';

import 'cache_store.dart';
import 'sembast_cache_store.dart';

/// 把舊 sembast DB 的離線佇列與衝突區搬進 [target]，成功後刪掉舊檔。
/// 回傳搬遷筆數（無舊檔 → 0）。
///
/// **只搬 queue + conflicts，不搬回應快取**：快取丟了只是重抓一次，但使用者
/// 沒同步的離線編輯丟了就是永久消失 —— 這是整個遷移唯一不可逆的風險點。
///
/// 讀取失敗（檔損毀）時不刪檔也不拋，讓下次啟動能再試；已搬的部分靠 id 去重
/// 不會重複排隊（重播兩次會把同一筆編輯套兩遍）。
Future<int> migrateSembastCacheToDrift({
  required String directoryPath,
  required CacheStore target,
}) async {
  final legacyFile = File('$directoryPath/tripline_cache.db');
  if (!legacyFile.existsSync()) return 0;

  final List<QueuedMutation> queue;
  final List<ConflictRecord> conflicts;
  try {
    final db = await openCacheDatabase(directoryPath);
    final legacy = SembastCacheStore(db);
    queue = await legacy.readQueue();
    conflicts = await legacy.readConflicts();
    await db.close();
  } catch (_) {
    return 0;
  }

  final existingMutationIds = (await target.readQueue())
      .map((m) => m.id)
      .toSet();
  final existingConflictIds = (await target.readConflicts())
      .map((c) => c.id)
      .toSet();

  var moved = 0;
  for (final mutation in queue) {
    if (existingMutationIds.contains(mutation.id)) continue;
    await target.appendMutation(mutation);
    moved++;
  }
  for (final conflict in conflicts) {
    if (existingConflictIds.contains(conflict.id)) continue;
    await target.appendConflict(conflict);
    moved++;
  }

  // 全部搬完才刪 —— 中途拋出時舊檔留著，下次啟動重試。
  await legacyFile.delete();
  return moved;
}
