/// 離線佇列引擎:樂觀入佇列、重連 flush、STALE_ENTRY 三方 rebase、衝突解決。
///
/// 只認兩樣東西:一個會送請求的函式([OfflineSend])與一個 [CacheStore]。
/// 測試用 function literal 當 send 就能驅動,不需要 dio。決策(ADR-0006 快取層級、
/// ADR-0007 rebase 政策)不變,這裡只是把程式碼從 ApiClient 搬到自己的 module。
library;

import 'dart:async';

import 'package:dio/dio.dart';

import '../api_error.dart';
import 'cache_keys.dart';
import 'cache_read_policy.dart';
import 'cache_store.dart';
import 'flush_policy.dart';
import 'offline_op.dart';
import 'optimistic_patchers.dart';
import 'rebase_merge.dart';

/// 引擎與 transport 之間的 seam:同參數送一次請求,非 2xx 丟 [ApiError],
/// 連線層失敗丟 [DioException]。
typedef OfflineSend =
    Future<Object?> Function(
      String method,
      String path, {
      Object? body,
      Map<String, dynamic>? query,
      CacheReadPolicy policy,
      bool evictMutationCache,
    });

/// flushQueue 的結果:成功同步筆數 + 上報的衝突(已從佇列移除)。
class FlushResult {
  const FlushResult({required this.synced, required this.conflicts});
  final int synced;
  final List<QueuedMutation> conflicts;
  static const empty = FlushResult(synced: 0, conflicts: <QueuedMutation>[]);
}

/// rebase 單筆結果:成功重送 / 真衝突已入庫 / 離線中止 / 重送暫時失敗待下次。
enum RebaseOutcome { synced, conflict, offline, retryLater }

/// 連線層錯誤(離線/逾時/無回應)→ 可回退快取;HTTP 4xx/5xx 不算(server 有回)。
bool isOfflineError(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return true;
    default:
      return e.type == DioExceptionType.unknown && e.response == null;
  }
}

/// mutation 成功後,依失效表移除受影響的 GET 快取(body 供 add-to-trip 取 tripId)。
Future<void> evictForMutation(
  CacheStore store,
  String method,
  String path,
  Object? body,
) async {
  for (final prefix in evictionPrefixesFor(method, path, body)) {
    await store.evictByPrefix(prefix);
  }
}

class OfflineSyncEngine {
  OfflineSyncEngine({required OfflineSend send, required CacheStore store})
    : _send = send,
      _store = store;

  final OfflineSend _send;
  final CacheStore _store;
  int _mutationCounter = 0;
  bool _flushing = false;
  bool _flushAgain = false;
  Future<void>? _queueLockTail;
  final Map<String, Future<void>> _mutationResourceTails = {};
  final StreamController<void> _queueFlushRequests =
      StreamController<void>.broadcast(sync: true);

  /// 新寫入排在 idle queue 後時通知同步層；由同步層統一處理結果、錯誤與 provider refresh。
  Stream<void> get queueFlushRequests => _queueFlushRequests.stream;

  /// 寫入:線上直送(成功即依失效表 evict);離線且帶 [optimistic] → 入持久化佇列
  /// + 對 op.cacheKey 套樂觀 patch + 回 null(樂觀成功)。無 optimistic 或非離線 → rethrow。
  Future<dynamic> sendMutation(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    OfflineOp? optimistic,
  }) async {
    final store = _store;
    if (optimistic == null) {
      return _send(method, path, body: body, query: query);
    }
    // 只有等待同資源前一筆寫入時才預先保存快取；一般 enqueue 仍在
    // queue lock 內讀取，避免與 flush 收尾的 eviction 交錯。
    final cachedBeforeWait =
        _mutationResourceTails.containsKey(optimistic.cacheKey)
        ? store.readResponse(optimistic.cacheKey)
        : null;
    return _withMutationResourceLock(optimistic.cacheKey, () async {
      final fallbackCache = cachedBeforeWait == null
          ? null
          : await cachedBeforeWait;
      var shouldFlush = false;
      final queued = await withQueueLock(() async {
        final queue = await store.readQueue();
        if (!queue.any(
          (mutation) => mutation.cacheKey == optimistic.cacheKey,
        )) {
          return false;
        }
        await _enqueueOptimisticMutation(
          store: store,
          method: method,
          path: path,
          body: body,
          query: query,
          optimistic: optimistic,
          fallbackCache: fallbackCache,
        );
        if (_flushing) {
          _flushAgain = true;
        } else {
          shouldFlush = true;
        }
        return true;
      });
      if (queued) {
        if (shouldFlush) _queueFlushRequests.add(null);
        return null;
      }
      try {
        return await _send(method, path, body: body, query: query);
      } on DioException catch (e) {
        if (isOfflineError(e)) {
          await withQueueLock(() async {
            await _enqueueOptimisticMutation(
              store: store,
              method: method,
              path: path,
              body: body,
              query: query,
              optimistic: optimistic,
              fallbackCache: fallbackCache,
            );
            if (_flushing) _flushAgain = true;
          });
          return null;
        }
        rethrow;
      }
    });
  }

  /// 同一 optimistic cache 的網路寫入依序執行，避免一筆成功 eviction 與另一筆
  /// 離線入佇列交錯，清掉後者用來擷取 rebase base 的快取。
  Future<T> _withMutationResourceLock<T>(
    String cacheKey,
    Future<T> Function() action,
  ) async {
    final previous = _mutationResourceTails[cacheKey];
    final release = Completer<void>();
    final tail = release.future;
    _mutationResourceTails[cacheKey] = tail;
    if (previous != null) await previous;
    try {
      return await action();
    } finally {
      release.complete();
      if (identical(_mutationResourceTails[cacheKey], tail)) {
        _mutationResourceTails.remove(cacheKey);
      }
    }
  }

  /// 將 queue 的「檢查 → 寫入」與 flush 的「移除 → cache eviction → 收尾」
  /// 線性化。鎖只包本機持久化，不包網路請求，避免慢網路阻塞使用者編輯。
  Future<T> withQueueLock<T>(Future<T> Function() action) async {
    final previous = _queueLockTail;
    final release = Completer<void>();
    _queueLockTail = release.future;
    if (previous != null) await previous;
    try {
      return await action();
    } finally {
      release.complete();
    }
  }

  Future<void> _enqueueOptimisticMutation({
    required CacheStore store,
    required String method,
    required String path,
    required Object? body,
    required Map<String, dynamic>? query,
    required OfflineOp optimistic,
    required CacheEntry? fallbackCache,
  }) async {
    final now = DateTime.now();
    final seq = _mutationCounter++;
    final id = '${now.microsecondsSinceEpoch}-$seq';
    // 穩定臨時 id:由「微秒×1000 + seq」導出唯一負值,存進 args 一次 →
    // 入佇列當下與日後 getStream 重播讀同一值(冪等);連續離線新增不碰撞、
    // 跨重啟單調遞減。已帶 tempId(測試)則尊重之。
    final args = optimistic.args.containsKey('tempId')
        ? optimistic.args
        : {
            ...optimistic.args,
            'tempId': -(now.microsecondsSinceEpoch * 1000 + (seq % 1000)),
          };
    final current =
        await store.readResponse(optimistic.cacheKey) ?? fallbackCache;
    final base = _extractBase(current?.data, optimistic);
    await store.appendMutation(
      QueuedMutation(
        id: id,
        method: method,
        path: path,
        query: query,
        body: body,
        type: optimistic.type,
        cacheKey: optimistic.cacheKey,
        args: args,
        createdAt: now.toIso8601String(),
        base: base,
      ),
    );
    final patched = applyOptimisticPatch(optimistic.type, current?.data, args);
    // null 代表無 base 可 patch(該資源未快取)→ 不寫,僅留佇列待 flush。
    if (patched != null) {
      await store.writeResponse(optimistic.cacheKey, patched);
    }
  }

  /// 重連後依序重播離線佇列。成功 → 移除(_send 已 evict 受影響快取);
  /// 409 STALE_ENTRY 且可 rebase(entry.update / note.update)→ 重抓 server 真相
  /// 三方 merge:無衝突重送(帶新 version)、有衝突入 conflict store 並上報;
  /// 其他 HTTP 錯誤(409 非 STALE / 400 / 404 等永久無效)→ 上報並移除;
  /// 5xx / 401 / 403 / 連線錯誤 → 中止並保留剩餘佇列(下次再試)。重入時直接回 empty。
  Future<FlushResult> flushQueue() async {
    final store = _store;
    final shouldStart = await withQueueLock(() async {
      if (_flushing) {
        _flushAgain = true;
        return false;
      }
      _flushing = true;
      _flushAgain = false;
      return true;
    });
    if (!shouldStart) return FlushResult.empty;
    // [P1] 同一輪 flush 內,同 cacheKey 的整包重抓只打一次(同 trip 多筆 STALE 共用)。
    final refetchCache = <String, Future<Object?>>{};
    try {
      final conflicts = <QueuedMutation>[];
      var synced = 0;
      while (true) {
        await withQueueLock(() async {
          _flushAgain = false;
        });
        final queued = await store.readQueue();
        final remainingByPath = <String, int>{};
        for (final mutation in queued) {
          remainingByPath.update(
            mutation.path,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        }
        for (final m in queued) {
          remainingByPath[m.path] = remainingByPath[m.path]! - 1;
          try {
            await _send(
              m.method,
              m.path,
              body: m.body,
              query: m.query,
              evictMutationCache: false,
            );
            await _removeQueuedMutation(store, m);
            synced++;
            if (remainingByPath[m.path]! > 0) {
              refetchCache.remove(m.cacheKey);
            }
          } on ApiError catch (e) {
            final action = classifyFlushError(e, rebasable: _rebasable(m.type));
            if (action == FlushErrorAction.rebase) {
              final outcome = await _tryRebase(
                m,
                refetchCache,
                evictMutationCache: false,
              );
              if (outcome == RebaseOutcome.synced) {
                await _removeQueuedMutation(store, m);
                synced++;
                if (remainingByPath[m.path]! > 0) {
                  refetchCache.remove(m.cacheKey);
                }
              } else if (outcome == RebaseOutcome.conflict) {
                await _removeQueuedMutation(store, m);
                conflicts.add(m);
              } else {
                break; // offline / retryLater → 保留佇列待下次
              }
            } else if (action == FlushErrorAction.retryLater) {
              break;
            } else {
              conflicts.add(m);
              await _removeQueuedMutation(store, m);
            }
          } on DioException catch (e) {
            if (isOfflineError(e)) break;
            rethrow;
          }
        }
        final repeat = await withQueueLock(() async {
          if (_flushAgain) {
            _flushAgain = false;
            return true;
          }
          _flushing = false;
          return false;
        });
        if (!repeat) {
          return FlushResult(synced: synced, conflicts: conflicts);
        }
        refetchCache.clear();
      }
    } catch (_) {
      await withQueueLock(() async {
        _flushing = false;
      });
      rethrow;
    }
  }

  /// queue mutation（成功或永久拒絕）先在同一臨界區移除；只有該 cacheKey
  /// 已沒有後續 pending 時才 eviction。如此同資源新編輯能先從完整樂觀 cache
  /// 擷取 rebase base，最後一筆被拒絕時也不會留下孤兒 optimistic cache。
  Future<void> _removeQueuedMutation(
    CacheStore store,
    QueuedMutation mutation,
  ) => withQueueLock(() async {
    await store.removeMutation(mutation.id);
    final queue = await store.readQueue();
    if (!queue.any((pending) => pending.cacheKey == mutation.cacheKey)) {
      await evictForMutation(
        _store,
        mutation.method,
        mutation.path,
        mutation.body,
      );
    }
  });

  static const _rebasableTypes = {'entry.update', 'note.update'};
  bool _rebasable(String type) => _rebasableTypes.contains(type);

  /// STALE 重抓 server 真相 → 三方 merge → 無衝突重送 / 有衝突入 conflict store。
  Future<RebaseOutcome> _tryRebase(
    QueuedMutation m,
    Map<String, Future<Object?>> refetchCache, {
    bool evictMutationCache = true,
  }) async {
    final store = _store;
    final tripId = _tripIdFromPath(m.path);
    if (tripId == null) return RebaseOutcome.conflict;
    final Object? fresh;
    try {
      fresh = await refetchCache.putIfAbsent(
        m.cacheKey,
        () => _refetchFor(m, tripId),
      );
    } on DioException catch (e) {
      return isOfflineError(e) ? RebaseOutcome.offline : RebaseOutcome.conflict;
    }
    final theirs = _theirsFrom(m, fresh);
    if (theirs == null) return RebaseOutcome.conflict; // row 可能已被刪
    final newVersion = (theirs.remove('version') as num?)?.toInt();
    final ours = _oursFrom(m);
    final conflictFields = rebaseMerge(m.base, ours, theirs);
    // newVersion 缺失(server row 無 version,異常)→ 無法安全重送(會送回舊
    // expectedVersion 造成永久 STALE livelock)→ 當衝突上報,交使用者處理。
    // conflictFields 可能為空(僅 version 異常),此時退而標記所有 ours 欄位。
    if (newVersion == null) {
      await store.appendConflict(
        _conflictFor(
          m,
          ours,
          theirs,
          0,
          conflictFields.isEmpty ? ours.keys.toList() : conflictFields,
        ),
      );
      return RebaseOutcome.conflict;
    }
    if (conflictFields.isEmpty) {
      try {
        await _send(
          m.method,
          m.path,
          body: rebasedBody(m.base, ours, m.body, newVersion),
          query: m.query,
          evictMutationCache: evictMutationCache,
        );
        return RebaseOutcome.synced;
      } on ApiError {
        return RebaseOutcome.retryLater;
      } on DioException catch (e) {
        return isOfflineError(e)
            ? RebaseOutcome.offline
            : RebaseOutcome.retryLater;
      }
    }
    await store.appendConflict(
      _conflictFor(m, ours, theirs, newVersion, conflictFields),
    );
    return RebaseOutcome.conflict;
  }

  /// 由單筆 mutation + 三方 merge 結果組 ConflictRecord(真衝突與 version 缺失共用)。
  ConflictRecord _conflictFor(
    QueuedMutation m,
    Map<String, dynamic> ours,
    Map<String, dynamic> theirs,
    int newVersion,
    List<String> conflictFields,
  ) => ConflictRecord(
    id: m.id,
    type: m.type,
    path: m.path,
    body: m.body,
    args: m.args,
    cacheKey: m.cacheKey,
    ours: ours,
    theirs: theirs,
    newVersion: newVersion,
    conflictFields: conflictFields,
    createdAt: m.createdAt,
    base: m.base, // 「保留你的」重送時據此只送 dirty 欄位
  );

  static final _tripIdRe = RegExp(r'/trips/([^/]+)/');
  String? _tripIdFromPath(String path) => _tripIdRe.firstMatch(path)?.group(1);

  /// 依 type 重抓對應整包(entry→days?all=1;note→notes),noStore
  /// (重抓是「拿 server 真相做 merge」,不可覆寫已含 pending patch 的快取)。
  Future<Object?> _refetchFor(QueuedMutation m, String tripId) {
    if (m.type == 'entry.update') {
      return _send(
        'GET',
        '/trips/$tripId/days',
        query: {'all': '1'},
        policy: CacheReadPolicy.noStore,
      );
    }
    return _send(
      'GET',
      '/trips/$tripId/notes',
      policy: CacheReadPolicy.noStore,
    );
  }

  /// 從重抓結果抽 theirs(含 version);找不到 row → null。
  Map<String, dynamic>? _theirsFrom(QueuedMutation m, Object? fresh) {
    if (m.type == 'entry.update') {
      return extractEntryFields(fresh, m.args['entryId'] as int, _ourKeys(m));
    }
    final fields = (m.args['fields'] as Map).cast<String, dynamic>();
    return extractNoteFields(
      fresh,
      m.args['sectionKey'] as String,
      m.args['rowId'] as int,
      fields.keys.map(snakeToCamel).toList(),
    );
  }

  /// ours = 離線改成的值(camelCase),與 base/theirs 同鍵集合。
  Map<String, dynamic> _oursFrom(QueuedMutation m) {
    if (m.type == 'entry.update') {
      return {for (final k in _ourKeys(m)) k: m.args[k]};
    }
    final fields = (m.args['fields'] as Map).cast<String, dynamic>();
    return {for (final e in fields.entries) snakeToCamel(e.key): e.value};
  }

  List<String> _ourKeys(QueuedMutation m) => [
    for (final k in const ['title', 'description', 'startTime', 'endTime'])
      if (m.args.containsKey(k)) k,
  ];

  // ─────────────────────────────────────────────────────────────────────────
  // 衝突解決 API(供 T10 衝突 UI 呼叫)
  // ─────────────────────────────────────────────────────────────────────────

  /// 衝突解決:保留離線版本 → 重送原 body(換上 newVersion)。
  /// 成功才 removeConflict;離線 → 往上拋保留衝突記錄;
  /// 再 409 STALE → 重新 rebase(同 flushQueue 邏輯)。
  Future<void> resolveConflictKeepOurs(ConflictRecord c) async {
    final store = _store;
    try {
      await _send(
        'PATCH',
        c.path,
        body: rebasedBody(c.base, c.ours, c.body, c.newVersion),
      );
      await store.removeConflict(c.id);
    } on ApiError catch (e) {
      if (e.status == 409 && e.code == 'STALE_ENTRY') {
        await store.removeConflict(c.id);
        final outcome = await _tryRebase(
          _asQueued(c),
          <String, Future<Object?>>{},
        );
        // synced → 已解;conflict → _tryRebase 內已重新 appendConflict;
        // offline/retryLater → 重新入主佇列待下次 flush。
        if (outcome == RebaseOutcome.offline ||
            outcome == RebaseOutcome.retryLater) {
          await store.appendMutation(_asQueued(c));
        }
        return;
      }
      rethrow; // 其他 4xx → 往上報給呼叫端
    }
    // DioException(離線)不 catch → 往上拋,衝突留存,UI 提示「仍離線」
  }

  /// 衝突解決:採用 server 版本 → 丟棄離線改動(純本機,不會失敗)。
  Future<void> resolveConflictKeepTheirs(ConflictRecord c) =>
      _store.removeConflict(c.id);

  /// ConflictRecord → QueuedMutation(重新 rebase / 入佇列用)。
  /// base 沿用原始離線 base,讓重新 rebase 的 dirty 判斷正確(只比對/重送使用者
  /// 真正改過的欄位);c.base 為 null(降級)→ 全送 last-write-wins,可接受。
  QueuedMutation _asQueued(ConflictRecord c) => QueuedMutation(
    id: c.id,
    method: 'PATCH',
    path: c.path,
    body: c.body,
    type: c.type,
    cacheKey: c.cacheKey,
    args: c.args,
    createdAt: c.createdAt,
    base: c.base, // 原始離線 base 供 dirty-aware 三方 merge
  );

  /// 依佇列順序套用同資源 patch，並同步 entry detail 的跨資源 update。
  /// patcher 以穩定 tempId 保持冪等，因此 queue 已寫、cache 尚未寫就崩潰時，
  /// stale leg 仍可安全重播而不會重複新增。
  Future<Object?> applyPendingPatches(String key, Object? base) async {
    final queue = await _store.readQueue();
    var result = base;
    for (final mutation in queue) {
      final sameResource = mutation.cacheKey == key;
      final crossResource =
          mutation.cacheKey != key &&
          mutation.type == 'entry.update' &&
          key == cacheKeyFor('GET', mutation.path);
      if (sameResource || crossResource) {
        result = applyOptimisticPatch(mutation.type, result, mutation.args);
      }
    }
    return result;
  }

  /// 入佇列時從快取擷取「離線改過欄位」的當下值,供 flush rebase 三方比對。
  /// 只對 entry.update / note.update;其餘回 null。
  Map<String, dynamic>? _extractBase(Object? cached, OfflineOp op) {
    if (op.type == 'entry.update') {
      return extractEntryFields(
        cached,
        op.args['entryId'] as int,
        _entryFieldKeys(op.args),
      );
    }
    if (op.type == 'note.update') {
      final fields = (op.args['fields'] as Map).cast<String, dynamic>();
      final camelKeys = fields.keys.map(snakeToCamel).toList();
      return extractNoteFields(
        cached,
        op.args['sectionKey'] as String,
        op.args['rowId'] as int,
        camelKeys,
      );
    }
    return null;
  }

  /// entry.update args 內實際帶的可編輯欄位(camelCase)。
  List<String> _entryFieldKeys(Map<String, dynamic> args) => [
    for (final k in const ['title', 'description', 'startTime', 'endTime'])
      if (args.containsKey(k)) k,
  ];
}
