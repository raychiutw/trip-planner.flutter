/// sembast-backed 永續快取（app 用;測試走 InMemoryCacheStore）。
library;

import 'package:sembast/sembast_io.dart';

import 'cache_keys.dart';
import 'cache_store.dart';

/// 開啟快取 DB(目錄由 path_provider 提供,於 main() 呼叫)。
Future<Database> openCacheDatabase(String directoryPath) =>
    databaseFactoryIo.openDatabase('$directoryPath/tripline_cache.db');

class SembastCacheStore implements CacheStore {
  SembastCacheStore(this._db);

  final Database _db;
  final StoreRef<String, Map<String, Object?>> _store = stringMapStoreFactory
      .store('response_cache');
  final StoreRef<int, Map<String, Object?>> _queueStore = intMapStoreFactory
      .store('mutation_queue');

  @override
  Future<CacheEntry?> readResponse(String key) async {
    final record = await _store.record(key).get(_db);
    if (record == null) return null;
    final cachedAt = record['cachedAt'] as String?;
    return CacheEntry(
      data: record['data'],
      cachedAt: cachedAt != null ? DateTime.parse(cachedAt) : DateTime.now(),
    );
  }

  @override
  Future<void> writeResponse(
    String key,
    Object? data, {
    DateTime? cachedAt,
  }) async {
    await _store.record(key).put(_db, {
      'data': data,
      'cachedAt': (cachedAt ?? DateTime.now()).toIso8601String(),
    });
  }

  @override
  Future<void> evictByPrefix(String prefix) async {
    final keys = await _store.findKeys(_db);
    final toDelete = keys
        .where((k) => cacheKeyMatchesPrefix(k, prefix))
        .toList();
    if (toDelete.isNotEmpty) await _store.records(toDelete).delete(_db);
  }

  @override
  Future<List<QueuedMutation>> readQueue() async {
    // key 為自增 int → 依 key 排序即插入序(= 重播序)。
    final records = await _queueStore.find(
      _db,
      finder: Finder(sortOrders: [SortOrder(Field.key)]),
    );
    return List.unmodifiable(
      records.map((r) => QueuedMutation.fromMap(r.value)),
    );
  }

  @override
  Future<void> appendMutation(QueuedMutation mutation) async {
    await _queueStore.add(_db, mutation.toMap());
  }

  @override
  Future<void> removeMutation(String id) async {
    await _queueStore.delete(
      _db,
      finder: Finder(filter: Filter.equals('id', id)),
    );
  }

  @override
  Future<void> clear() async {
    await _store.delete(_db);
    await _queueStore.delete(_db);
  }
}
