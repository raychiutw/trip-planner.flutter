/// 遺留的 sembast 快取存取（僅供一次性搬遷到 drift 時讀取舊 DB）。
///
/// **這不是活的 [CacheStore] 實作** —— app 現在跑 `DriftCacheStore`。這裡刻意
/// 不實作 `CacheStore` 介面：實作了就得跟著介面演進（例如 `enforceCapacity`），
/// 而那對一個唯讀的遺留格式毫無意義，只會養出死碼。
///
/// 只保留 [migrateSembastCacheToDrift] 真正需要的讀取，加上讓測試造出「舊版
/// app 的 DB」所需的寫入。
library;

import 'package:sembast/sembast_io.dart';

import 'cache_store.dart';

/// 開啟舊版 sembast 快取 DB。檔名與 drift 的 `tripline_cache.sqlite` 不同。
Future<Database> openCacheDatabase(String directoryPath) =>
    databaseFactoryIo.openDatabase('$directoryPath/tripline_cache.db');

class SembastCacheStore {
  SembastCacheStore(this._db);

  final Database _db;
  final StoreRef<String, Map<String, Object?>> _store = stringMapStoreFactory
      .store('response_cache');
  final StoreRef<int, Map<String, Object?>> _queueStore = intMapStoreFactory
      .store('mutation_queue');
  final StoreRef<int, Map<String, Object?>> _conflictStore = intMapStoreFactory
      .store('conflict_store');

  /// key 為自增 int → 依 key 排序即插入序(= 重播序)。
  Future<List<QueuedMutation>> readQueue() async {
    final records = await _queueStore.find(
      _db,
      finder: Finder(sortOrders: [SortOrder(Field.key)]),
    );
    return List.unmodifiable(
      records.map((r) => QueuedMutation.fromMap(r.value)),
    );
  }

  Future<List<ConflictRecord>> readConflicts() async {
    final records = await _conflictStore.find(
      _db,
      finder: Finder(sortOrders: [SortOrder(Field.key)]),
    );
    return List.unmodifiable(
      records.map((r) => ConflictRecord.fromMap(r.value)),
    );
  }

  // ── 以下僅供測試造出舊版 DB 的 fixture ──────────────────────────────────

  Future<void> appendMutation(QueuedMutation mutation) =>
      _queueStore.add(_db, mutation.toMap()).then((_) {});

  Future<void> appendConflict(ConflictRecord conflict) =>
      _conflictStore.add(_db, conflict.toMap()).then((_) {});

  Future<void> writeResponse(String key, Object? data, {DateTime? cachedAt}) =>
      _store
          .record(key)
          .put(_db, {
            'data': data,
            'cachedAt': (cachedAt ?? DateTime.now()).toIso8601String(),
          })
          .then((_) {});
}
