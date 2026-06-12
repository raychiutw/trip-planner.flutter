/// 離線快取持久化抽象與記憶體實作（沿用 SessionStore 慣例）。
library;

import 'cache_keys.dart';

/// 一筆回應快取:原始 wire JSON + 寫入時間。
class CacheEntry {
  const CacheEntry({required this.data, required this.cachedAt});
  final Object? data;
  final DateTime cachedAt;
}

/// 回應快取介面(PR-1 僅 response + clear;queue 於 PR-3 擴充)。
abstract class CacheStore {
  Future<CacheEntry?> readResponse(String key);
  Future<void> writeResponse(String key, Object? data, {DateTime? cachedAt});
  Future<void> evictByPrefix(String prefix);
  Future<void> clear();
}

/// 測試用純記憶體實作。
class InMemoryCacheStore implements CacheStore {
  final Map<String, CacheEntry> _entries = {};

  @override
  Future<CacheEntry?> readResponse(String key) async => _entries[key];

  @override
  Future<void> writeResponse(
    String key,
    Object? data, {
    DateTime? cachedAt,
  }) async {
    _entries[key] = CacheEntry(
      data: data,
      cachedAt: cachedAt ?? DateTime.now(),
    );
  }

  @override
  Future<void> evictByPrefix(String prefix) async {
    _entries.removeWhere((key, _) => cacheKeyMatchesPrefix(key, prefix));
  }

  @override
  Future<void> clear() async => _entries.clear();
}
