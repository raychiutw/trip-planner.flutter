/// 離線快取持久化抽象與記憶體實作（沿用 SessionStore 慣例）。
library;

import 'dart:async';

import 'cache_keys.dart';

/// 一筆回應快取:原始 wire JSON + 寫入時間。
class CacheEntry {
  const CacheEntry({required this.data, required this.cachedAt});
  final Object? data;
  final DateTime cachedAt;
}

/// 離線寫入佇列的一筆 mutation(待重連後重播,見 PR-4)。
/// 同時帶 [type]/[cacheKey]/[args] 供樂觀 patch 與不變式重算。
class QueuedMutation {
  const QueuedMutation({
    required this.id,
    required this.method,
    required this.path,
    this.query,
    this.body,
    required this.type,
    required this.cacheKey,
    required this.args,
    required this.createdAt,
    this.base,
  });

  final String id;
  final String method;
  final String path;
  final Map<String, dynamic>? query;
  final Object? body;
  final String type; // 樂觀 op 類型(對應一個 patcher)
  final String cacheKey; // 受影響的 GET 快取 key
  final Map<String, dynamic> args; // patcher 參數
  final String createdAt;
  /// rebase 三方比對用:離線寫入當下受影響欄位的原始值,缺漏舊資料降級為 null。
  final Map<String, dynamic>? base;

  Map<String, Object?> toMap() => {
    'id': id,
    'method': method,
    'path': path,
    'query': query,
    'body': body,
    'type': type,
    'cacheKey': cacheKey,
    'args': args,
    'createdAt': createdAt,
    'base': base,
  };

  factory QueuedMutation.fromMap(Map<String, Object?> m) => QueuedMutation(
    id: m['id'] as String,
    method: m['method'] as String,
    path: m['path'] as String,
    query: (m['query'] as Map?)?.cast<String, dynamic>(),
    body: m['body'],
    type: m['type'] as String,
    cacheKey: m['cacheKey'] as String,
    args: (m['args'] as Map).cast<String, dynamic>(),
    createdAt: m['createdAt'] as String,
    base: (m['base'] as Map?)?.cast<String, dynamic>(),
  );
}

/// 回應快取 + 離線寫入佇列介面。
abstract class CacheStore {
  // 回應快取
  Future<CacheEntry?> readResponse(String key);
  Future<void> writeResponse(String key, Object? data, {DateTime? cachedAt});
  Future<void> evictByPrefix(String prefix);

  // 離線寫入佇列(插入序 = 重播序)
  Future<List<QueuedMutation>> readQueue();
  Future<void> appendMutation(QueuedMutation mutation);
  Future<void> removeMutation(String id);

  /// 佇列變動(append/remove/clear)事件流,供待同步筆數等 UI 反應式刷新。
  Stream<void> get changes;

  /// 清回應快取 + 佇列(登出 / 換帳號用)。
  Future<void> clear();
}

/// 測試用純記憶體實作。
class InMemoryCacheStore implements CacheStore {
  final Map<String, CacheEntry> _entries = {};
  final List<QueuedMutation> _queue = [];
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

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
  Future<List<QueuedMutation>> readQueue() async => List.unmodifiable(_queue);

  @override
  Future<void> appendMutation(QueuedMutation mutation) async {
    _queue.add(mutation);
    _changes.add(null);
  }

  @override
  Future<void> removeMutation(String id) async {
    _queue.removeWhere((m) => m.id == id);
    _changes.add(null);
  }

  @override
  Future<void> clear() async {
    _entries.clear();
    _queue.clear();
    _changes.add(null);
  }
}
