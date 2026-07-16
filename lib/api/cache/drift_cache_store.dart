/// drift(sqlite)-backed 永續快取（app 用;測試走 InMemoryCacheStore）。
///
/// 取代 sembast:sembast 開啟時會把整個 DB 載入記憶體，而 POI 搜尋與 AI 對話
/// 歷史是無界增長的，會連坐拖垮行程資料的存取。sqlite 只讀取用到的 page。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'cache_store.dart';

part 'drift_cache_store.g.dart';

/// 開啟快取 DB(目錄由 path_provider 提供,於 main() 呼叫)。
///
/// 檔名刻意不同於 sembast 的 `tripline_cache.db` —— 舊檔要留給
/// [migrateSembastCacheToDrift] 找得到並搬遷，不能被覆蓋。
///
/// 走 [LazyDatabase] + `createInBackground`：實際開檔延到第一次查詢，且在
/// 獨立 isolate，不卡 app 啟動的 UI thread。
CacheDatabase openCacheDatabase(String directoryPath) => CacheDatabase(
  LazyDatabase(
    () async => NativeDatabase.createInBackground(
      File('$directoryPath/tripline_cache.sqlite'),
    ),
  ),
);

/// 回應快取。key 為 [cacheKeyFor] 正規化後的 `<METHOD> <path>?<query>`。
@DataClassName('ResponseCacheRow')
class ResponseCacheRows extends Table {
  TextColumn get key => text()();

  /// wire JSON 原樣序列化（`Object?` → 可能是 map/list/純量/null）。
  TextColumn get data => text()();

  /// ISO8601 字串而非 drift 的 DateTimeColumn —— 後者預設存 unix 秒，會把毫秒
  /// 截掉，TTL 判斷跟著失準。sembast 版也是存字串，行為對齊。
  TextColumn get cachedAt => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// 離線寫入佇列。[seq] 自增 → 依 seq 排序即插入序(= 重播序)。
@DataClassName('MutationQueueRow')
class MutationQueueRows extends Table {
  IntColumn get seq => integer().autoIncrement()();
  TextColumn get mutationId => text()();
  TextColumn get payload => text()();
}

/// 待使用者解決的衝突區。
@DataClassName('ConflictRow')
class ConflictRows extends Table {
  IntColumn get seq => integer().autoIncrement()();
  TextColumn get conflictId => text()();
  TextColumn get payload => text()();
}

@DriftDatabase(tables: [ResponseCacheRows, MutationQueueRows, ConflictRows])
class CacheDatabase extends _$CacheDatabase {
  CacheDatabase(super.e);

  @override
  int get schemaVersion => 1;
}

class DriftCacheStore implements CacheStore {
  DriftCacheStore(this._db);

  final CacheDatabase _db;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  Future<void> close() async {
    await _changes.close();
    await _db.close();
  }

  // ── 回應快取 ──────────────────────────────────────────────────────────────

  @override
  Future<CacheEntry?> readResponse(String key) async {
    final row = await (_db.select(
      _db.responseCacheRows,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    if (row == null) return null;
    return CacheEntry(
      data: jsonDecode(row.data),
      cachedAt: DateTime.parse(row.cachedAt),
    );
  }

  @override
  Future<void> writeResponse(
    String key,
    Object? data, {
    DateTime? cachedAt,
  }) async {
    await _db
        .into(_db.responseCacheRows)
        .insertOnConflictUpdate(
          ResponseCacheRowsCompanion.insert(
            key: key,
            data: jsonEncode(data),
            cachedAt: (cachedAt ?? DateTime.now()).toIso8601String(),
          ),
        );
  }

  @override
  Future<void> evictByPrefix(String prefix) async {
    // 對齊 cacheKeyMatchesPrefix:相等、或後接 `/`、`?`。
    //
    // 刻意不用 LIKE:快取 key 裡的 tripId 走 Uri.encodeComponent，會帶 `%XX`，
    // 而 `%`/`_` 正是 LIKE 的萬用字元 → 會靜默誤刪別的 trip。GLOB 也不行(它的
    // 萬用字元 `*`/`?` 中的 `?` 就在 key 格式裡)。substr 純字面比對，無此問題。
    await _db.customStatement(
      'DELETE FROM response_cache_rows '
      'WHERE "key" = ?1 '
      'OR substr("key", 1, length(?1) + 1) IN (?1 || \'/\', ?1 || \'?\')',
      [prefix],
    );
  }

  // ── 離線寫入佇列 ──────────────────────────────────────────────────────────

  @override
  Future<List<QueuedMutation>> readQueue() async {
    final rows = await (_db.select(
      _db.mutationQueueRows,
    )..orderBy([(t) => OrderingTerm.asc(t.seq)])).get();
    return List.unmodifiable(
      rows.map(
        (r) => QueuedMutation.fromMap(
          (jsonDecode(r.payload) as Map).cast<String, Object?>(),
        ),
      ),
    );
  }

  @override
  Future<void> appendMutation(QueuedMutation mutation) async {
    await _db
        .into(_db.mutationQueueRows)
        .insert(
          MutationQueueRowsCompanion.insert(
            mutationId: mutation.id,
            payload: jsonEncode(mutation.toMap()),
          ),
        );
    _changes.add(null);
  }

  @override
  Future<void> removeMutation(String id) async {
    await (_db.delete(
      _db.mutationQueueRows,
    )..where((t) => t.mutationId.equals(id))).go();
    _changes.add(null);
  }

  // ── 衝突區 ────────────────────────────────────────────────────────────────

  @override
  Future<List<ConflictRecord>> readConflicts() async {
    final rows = await (_db.select(
      _db.conflictRows,
    )..orderBy([(t) => OrderingTerm.asc(t.seq)])).get();
    return List.unmodifiable(
      rows.map(
        (r) => ConflictRecord.fromMap(
          (jsonDecode(r.payload) as Map).cast<String, Object?>(),
        ),
      ),
    );
  }

  @override
  Future<void> appendConflict(ConflictRecord conflict) async {
    await _db
        .into(_db.conflictRows)
        .insert(
          ConflictRowsCompanion.insert(
            conflictId: conflict.id,
            payload: jsonEncode(conflict.toMap()),
          ),
        );
    _changes.add(null);
  }

  @override
  Future<void> removeConflict(String id) async {
    await (_db.delete(
      _db.conflictRows,
    )..where((t) => t.conflictId.equals(id))).go();
    _changes.add(null);
  }

  @override
  Future<void> clear() async {
    await _db.batch((b) {
      b.deleteAll(_db.responseCacheRows);
      b.deleteAll(_db.mutationQueueRows);
      b.deleteAll(_db.conflictRows);
    });
    _changes.add(null);
  }
}
