/// dio 封裝：cookie 認證、CSRF Origin、錯誤轉換、暫時性失敗 retry、204 處理。
library;

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'api_error.dart';
import 'cache/cache_keys.dart';
import 'cache/cache_store.dart';
import 'cache/offline_op.dart';
import 'cache/optimistic_patchers.dart';
import 'cache/rebase_merge.dart';
import 'retry_policy.dart' as retry;
import 'session_store.dart';

/// 本 build 連線的 origin。預設正式站，可用 --dart-define=TRIPLINE_API_ORIGIN
/// 覆寫（本機開發指向本機後端）。一個 origin 同時決定 base URL（`origin/api`）
/// 與 mutating request 的 CSRF Origin header。
const String kTriplineOrigin = String.fromEnvironment(
  'TRIPLINE_API_ORIGIN',
  defaultValue: 'https://trip-planner-dby.pages.dev',
);

/// 高基數 GET 的永續快取容量上限（path prefix → 最多保留幾筆）。
///
/// 這兩條路徑每個 query 都是新 key，且沒有任何 mutation 會 evict 它們 —— 快取
/// 只增不減，沒有上限就會無界成長。其他路徑靠 `evictionPrefixesFor` 在 mutation
/// 後失效，天生有界，不需要上限。
///
/// 100 對齊 web 版 `useRoute.ts` 的 IndexedDB LRU 容量。
const Map<String, int> kCacheCapacityByPathPrefix = {
  '/poi-search': 100,
  '/route': 100,
};

/// Redirect-style API response where callers need the `Location` header.
class ApiRedirectResponse {
  const ApiRedirectResponse({required this.statusCode, required this.location});

  final int statusCode;
  final String? location;
}

/// 提供 Bearer access token 與 refresh 能力(OAuth 模式)。
/// 注入 ApiClient 後,有 token 即走 Bearer(不送 Cookie/Origin);null/無 token → cookie 模式。
abstract class BearerTokenSource {
  Future<String?> accessToken();

  /// 嘗試用 refresh token 換新 access token;成功(有新 token 可用)回 true。
  Future<bool> refresh();
}

/// flushQueue 的結果:成功同步筆數 + 上報的衝突(已從佇列移除)。
class FlushResult {
  const FlushResult({required this.synced, required this.conflicts});
  final int synced;
  final List<QueuedMutation> conflicts;
  static const empty = FlushResult(synced: 0, conflicts: <QueuedMutation>[]);
}

/// Tripline API client，base = `<origin>/api`。
class ApiClient {
  ApiClient({
    required SessionStore sessionStore,
    Dio? dio,
    String origin = kTriplineOrigin,
    BearerTokenSource? bearerSource,
    CacheStore? cacheStore,
    Map<String, int> cacheCapacityByPathPrefix = kCacheCapacityByPathPrefix,
  }) : _sessionStore = sessionStore,
       _origin = origin,
       _bearerSource = bearerSource,
       _cacheStore = cacheStore,
       _cacheCapacityByPathPrefix = cacheCapacityByPathPrefix,
       _dio = dio ?? Dio() {
    _dio.options.baseUrl = '$origin/api';
    // 全收所有 status code，由 _send 自行判斷丟 ApiError
    _dio.options.validateStatus = (_) => true;
  }

  final SessionStore _sessionStore;
  final String _origin;
  final BearerTokenSource? _bearerSource;
  final CacheStore? _cacheStore;
  final Map<String, int> _cacheCapacityByPathPrefix;
  final Dio _dio;
  int _mutationCounter = 0;
  bool _flushing = false;
  bool _flushAgain = false;
  Future<void>? _queueLockTail;
  final Map<String, Future<void>> _mutationResourceTails = {};
  final StreamController<void> _queueFlushRequests =
      StreamController<void>.broadcast(sync: true);

  String get baseUrl => _dio.options.baseUrl;

  /// 新寫入排在 idle queue 後時通知同步層；由同步層統一處理結果、錯誤與 provider refresh。
  Stream<void> get queueFlushRequests => _queueFlushRequests.stream;

  /// POST 並保留完整 response（例如 AuthRepository 需要讀 set-cookie）。
  ///
  /// 仍統一套用 Cookie／Bearer／Origin，避免需要 response headers 的流程繞過
  /// [ApiClient] 的認證與 CSRF 規則。
  Future<Response<dynamic>> postForResponse(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    bool followRedirects = true,
  }) async {
    final auth = await _authHeadersFor('POST');
    final response = await _dio.request<dynamic>(
      path,
      queryParameters: query,
      data: body,
      options: Options(
        method: 'POST',
        headers: auth.headers,
        followRedirects: followRedirects,
      ),
    );
    // 登入 / 註冊的 raw POST 不重送:429 是 mutation,401 就是憑證錯(走 Bearer
    // refresh 會重放憑證,refresh 失敗還會把 OAuth session 清掉)。只轉錯誤。
    _throwIfFailed(response, acceptRedirects: !followRedirects);
    return response;
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
    bool writeCache = true,
    bool fallbackToCache = true,
  }) => _send(
    'GET',
    path,
    query: query,
    cancelToken: cancelToken,
    writeCache: writeCache,
    fallbackToCache: fallbackToCache,
  );

  Future<dynamic> head(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) => _send('HEAD', path, query: query, cancelToken: cancelToken);

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) => _send('POST', path, body: body, query: query);

  Future<dynamic> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);

  Future<dynamic> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body);

  Future<dynamic> delete(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) => _send('DELETE', path, body: body, query: query);

  /// POST that preserves 3xx redirect response instead of following it.
  Future<ApiRedirectResponse> postForRedirect(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    final response = await postForResponse(
      path,
      body: body,
      query: query,
      followRedirects: false,
    );
    return ApiRedirectResponse(
      statusCode: response.statusCode ?? 0,
      location: response.headers.value('location'),
    );
  }

  /// SWR 讀取:先 emit 本機快取(stale),再抓網路;fresh 到達後套用尚未 flush 的
  /// 樂觀 patch(維持「快取 = server 真相 + pending patch」不變式)再 emit。
  /// 離線且已 emit 過 stale → 收斂不報錯;離線且無快取 → emit error。
  Stream<dynamic> getStream(String path, {Map<String, dynamic>? query}) async* {
    final store = _cacheStore;
    final key = cacheKeyFor('GET', path, query);
    var yieldedStale = false;
    if (store != null) {
      Object? stale;
      var foundStale = false;
      await _withQueueLock(() async {
        final cached = await store.readResponse(key);
        if (cached == null) return;
        stale = await _applyPendingPatches(store, key, cached.data);
        if (!identical(stale, cached.data)) {
          // 當機可能發生在 queue 已落盤、樂觀 patch 尚未寫回之間。讀 queue、
          // 重播與寫回必須和 flush completion 共用臨界區，避免 queue 已移除後
          // 又把沒有對應 pending record 的 optimistic cache 復活。
          await store.writeResponse(key, stale, cachedAt: cached.cachedAt);
        }
        foundStale = true;
      });
      if (foundStale) {
        yield stale;
        yieldedStale = true;
      }
    }
    try {
      // 網路 leg 不走 get() 的離線回退(回退已由上面的 stale 處理),才能把 fresh
      // 當「server 真相」套 pending patch,不會對已 patch 的快取重複套用。
      final fresh = await _send(
        'GET',
        path,
        query: query,
        fallbackToCache: false,
        writeCache: false,
      );
      if (store == null) {
        yield fresh;
      } else {
        Object? patched;
        await _withQueueLock(() async {
          final patchedValue = await _applyPendingPatches(store, key, fresh);
          patched = patchedValue;
          final isEmpty =
              patchedValue == null ||
              (patchedValue is String && patchedValue.isEmpty);
          if (!isEmpty) {
            await store.writeResponse(key, patchedValue);
            final capacity = _capacityFor(path);
            if (capacity != null) {
              await store.enforceCapacity(
                'GET ${capacity.key}',
                capacity.value,
              );
            }
          }
        });
        yield patched;
      }
    } on DioException catch (e) {
      // 離線且已顯示 stale → 收斂;否則(無快取可顯示)讓 stream emit error。
      if (!_isOfflineError(e) || !yieldedStale) rethrow;
    }
  }

  /// Authenticated streaming GET for text-based long-lived responses such as
  /// `text/event-stream`. This intentionally bypasses cache/SWR handling.
  Stream<String> getTextStream(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) => _getTextStream(path, query: query, cancelToken: cancelToken);

  /// 寫入:線上直送(成功即依失效表 evict);離線且帶 [optimistic] → 入持久化佇列
  /// + 對 op.cacheKey 套樂觀 patch + 回 null(樂觀成功)。無 optimistic 或非離線 → rethrow。
  Future<dynamic> sendMutation(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    OfflineOp? optimistic,
  }) async {
    final store = _cacheStore;
    if (optimistic == null || store == null) {
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
      final queued = await _withQueueLock(() async {
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
        if (_isOfflineError(e)) {
          await _withQueueLock(() async {
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
  Future<T> _withQueueLock<T>(Future<T> Function() action) async {
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
    final store = _cacheStore;
    if (store == null) return FlushResult.empty;
    final shouldStart = await _withQueueLock(() async {
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
        await _withQueueLock(() async {
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
            if (e.status == 409 &&
                e.code == 'STALE_ENTRY' &&
                _rebasable(m.type)) {
              final outcome = await _tryRebase(
                m,
                refetchCache,
                evictMutationCache: false,
              );
              if (outcome == _RebaseOutcome.synced) {
                await _removeQueuedMutation(store, m);
                synced++;
                if (remainingByPath[m.path]! > 0) {
                  refetchCache.remove(m.cacheKey);
                }
              } else if (outcome == _RebaseOutcome.conflict) {
                await _removeQueuedMutation(store, m);
                conflicts.add(m);
              } else {
                break; // offline / retryLater → 保留佇列待下次
              }
            } else if (e.status >= 500 || e.status == 401 || e.status == 403) {
              // 5xx 暫時失敗、401/403 認證未就緒(如 session 過期、冷啟動 sync 早於重新登入)
              // → 中止保留佇列、待重試,避免永久遺失離線編輯。
              break;
            } else {
              // 其他 4xx(409 非 STALE / 400 / 404 等永久無效)→ 上報並移除。
              conflicts.add(m);
              await _removeQueuedMutation(store, m);
            }
          } on DioException catch (e) {
            if (_isOfflineError(e)) break;
            rethrow;
          }
        }
        final repeat = await _withQueueLock(() async {
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
      await _withQueueLock(() async {
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
  ) => _withQueueLock(() async {
    await store.removeMutation(mutation.id);
    final queue = await store.readQueue();
    if (!queue.any((pending) => pending.cacheKey == mutation.cacheKey)) {
      await _evictForMutation(mutation.method, mutation.path, mutation.body);
    }
  });

  static const _rebasableTypes = {'entry.update', 'note.update'};
  bool _rebasable(String type) => _rebasableTypes.contains(type);

  /// STALE 重抓 server 真相 → 三方 merge → 無衝突重送 / 有衝突入 conflict store。
  Future<_RebaseOutcome> _tryRebase(
    QueuedMutation m,
    Map<String, Future<Object?>> refetchCache, {
    bool evictMutationCache = true,
  }) async {
    final store = _cacheStore!;
    final tripId = _tripIdFromPath(m.path);
    if (tripId == null) return _RebaseOutcome.conflict;
    final Object? fresh;
    try {
      fresh = await refetchCache.putIfAbsent(
        m.cacheKey,
        () => _refetchFor(m, tripId),
      );
    } on DioException catch (e) {
      return _isOfflineError(e)
          ? _RebaseOutcome.offline
          : _RebaseOutcome.conflict;
    }
    final theirs = _theirsFrom(m, fresh);
    if (theirs == null) return _RebaseOutcome.conflict; // row 可能已被刪
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
      return _RebaseOutcome.conflict;
    }
    if (conflictFields.isEmpty) {
      try {
        await _send(
          m.method,
          m.path,
          body: _rebasedBody(m.base, ours, m.body, newVersion),
          query: m.query,
          evictMutationCache: evictMutationCache,
        );
        return _RebaseOutcome.synced;
      } on ApiError {
        return _RebaseOutcome.retryLater;
      } on DioException catch (e) {
        return _isOfflineError(e)
            ? _RebaseOutcome.offline
            : _RebaseOutcome.retryLater;
      }
    }
    await store.appendConflict(
      _conflictFor(m, ours, theirs, newVersion, conflictFields),
    );
    return _RebaseOutcome.conflict;
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

  /// 依 type 重抓對應整包(entry→days?all=1;note→notes),writeCache:false
  /// (重抓是「拿 server 真相做 merge」,不可覆寫已含 pending patch 的快取)。
  Future<Object?> _refetchFor(QueuedMutation m, String tripId) {
    if (m.type == 'entry.update') {
      return _send(
        'GET',
        '/trips/$tripId/days',
        query: {'all': 1},
        writeCache: false,
        fallbackToCache: false,
      );
    }
    return _send(
      'GET',
      '/trips/$tripId/notes',
      writeCache: false,
      fallbackToCache: false,
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

  /// rebase 重送 body:真實 caller 送整包(full-form),只保留使用者改過的
  /// (ours≠base)欄位 + 換新 expectedVersion;使用者沒改的欄位不送 → 保留 server
  /// theirs,避免用離線舊值覆蓋協作者的變更。base==null(降級)→ 原 body 全送
  /// (last-write-wins)。body 非 Map → 原樣。
  ///
  /// body 欄位是 snake_case(entry: `start_time`、note: `flight_no`),dirty 集合
  /// 是 camelCase,故以 [snakeToCamel] 對齊比對;`expectedVersion` 永遠保留並換新值。
  Object? _rebasedBody(
    Map<String, dynamic>? base,
    Map<String, dynamic> ours,
    Object? body,
    int? newVersion,
  ) {
    if (body is! Map) return body;
    final dirty = dirtyFields(base, ours);
    return {
      for (final e in body.entries)
        if (e.key == 'expectedVersion')
          e.key: newVersion ?? e.value
        else if (base == null || dirty.contains(snakeToCamel(e.key as String)))
          e.key: e.value,
    };
  }

  /// 解析 Retry-After;實作在 retry_policy.dart,這裡只是給既有測試的別名。
  static int parseRetryAfterSeconds(String? headerValue) =>
      retry.parseRetryAfterSeconds(headerValue);

  static bool _isEdgeBlockPage(Response<dynamic> response) {
    final statusCode = response.statusCode ?? 0;
    return statusCode >= 200 &&
        statusCode < 300 &&
        statusCode != 204 &&
        (response.headers
                .value(Headers.contentTypeHeader)
                ?.toLowerCase()
                .contains('text/html') ??
            false);
  }

  static ApiError _upstreamUnavailable(int statusCode) => ApiError(
    status: statusCode,
    code: 'SYS_UPSTREAM_UNAVAILABLE',
    message: '伺服器暫時無法回應，請稍後重試',
  );

  /// 一般請求與 SSE 共用的重送決策;RetryAfterRefresh 已把 refresh 做掉,失敗即 NoRetry。
  Future<retry.RetryDecision> _retryDecision(
    Response<dynamic> response, {
    required bool useBearer,
    required bool retryableMethod,
    required bool isRetryAttempt,
    CancelToken? cancelToken,
  }) async {
    final decision = retry.decideRetry(
      statusCode: response.statusCode ?? 0,
      retryAfterHeader: response.headers.value('retry-after'),
      isEdgeBlockPage: _isEdgeBlockPage(response),
      useBearer: useBearer,
      retryableMethod: retryableMethod,
      isRetryAttempt: isRetryAttempt,
    );
    switch (decision) {
      case retry.RetryAfterWait(:final seconds):
        await _waitForRetry(seconds, cancelToken);
        return decision;
      case retry.RetryAfterRefresh():
        final source = _bearerSource;
        return source != null && await source.refresh()
            ? decision
            : const retry.NoRetry();
      case retry.NoRetry():
        return decision;
    }
  }

  /// 非成功回應 → ApiError;edge block page → 上游不可用。
  static void _throwIfFailed(
    Response<dynamic> response, {
    bool acceptRedirects = false,
  }) {
    final statusCode = response.statusCode ?? 0;
    if (_isEdgeBlockPage(response)) throw _upstreamUnavailable(statusCode);
    final upperBound = acceptRedirects ? 400 : 300;
    if (statusCode < 200 || statusCode >= upperBound) {
      throw ApiError.fromResponse(
        statusCode,
        response.data,
        retryAfterSeconds: int.tryParse(
          response.headers.value('retry-after') ?? '',
        ),
      );
    }
  }

  static Future<void> _waitForRetry(
    int seconds,
    CancelToken? cancelToken,
  ) async {
    final initialError = cancelToken?.cancelError;
    if (initialError != null) throw initialError;
    if (seconds <= 0) return;
    final delay = Future<void>.delayed(Duration(seconds: seconds));
    if (cancelToken == null) return delay;
    await Future.any<void>([delay, cancelToken.whenCancel.then<void>((_) {})]);
    final cancelError = cancelToken.cancelError;
    if (cancelError != null) throw cancelError;
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    CancelToken? cancelToken,
    bool isRetryAttempt = false,
    bool fallbackToCache = true,
    bool writeCache = true,
    bool evictMutationCache = true,
  }) async {
    final auth = await _authHeadersFor(method);

    final Response<dynamic> response;
    try {
      response = await _dio.request<dynamic>(
        path,
        queryParameters: query,
        data: body,
        options: Options(method: method, headers: auth.headers),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      // 連線層失敗(離線/逾時):GET 嘗試回退本機快取(getStream 的網路 leg 關閉此回退)
      final store = _cacheStore;
      if (fallbackToCache &&
          method == 'GET' &&
          store != null &&
          _isOfflineError(e)) {
        final cached = await store.readResponse(
          cacheKeyFor('GET', path, query),
        );
        if (cached != null) return cached.data;
      }
      rethrow;
    }

    final decision = await _retryDecision(
      response,
      useBearer: auth.useBearer,
      retryableMethod: method == 'GET' || method == 'HEAD',
      isRetryAttempt: isRetryAttempt,
      cancelToken: cancelToken,
    );
    if (decision is! retry.NoRetry) {
      // 429、edge block page、401 Bearer-refresh 共用「同參數重送一次」。
      return _send(
        method,
        path,
        query: query,
        body: body,
        cancelToken: cancelToken,
        isRetryAttempt: true,
        fallbackToCache: fallbackToCache,
        writeCache: writeCache,
        evictMutationCache: evictMutationCache,
      );
    }
    _throwIfFailed(response);
    final statusCode = response.statusCode ?? 0;
    if (statusCode == 204) {
      if (evictMutationCache) {
        await _evictForMutation(method, path, body);
      }
      return null;
    }
    final responseData = response.data;
    final isEmpty =
        responseData == null ||
        (responseData is String && responseData.isEmpty);
    if (method == 'GET') {
      if (writeCache && !isEmpty) {
        final store = _cacheStore;
        if (store != null) {
          await store.writeResponse(
            cacheKeyFor('GET', path, query),
            responseData,
          );
          // 高基數 GET(POI 搜尋、路線)沒有 mutation 會 evict 它們,只增不減 →
          // 每次寫入後就地修剪,不讓它無界成長。
          final capacity = _capacityFor(path);
          if (capacity != null) {
            await store.enforceCapacity('GET ${capacity.key}', capacity.value);
          }
        }
      }
    } else {
      if (evictMutationCache) {
        await _evictForMutation(method, path, body);
      }
    }
    return isEmpty ? null : responseData;
  }

  Stream<String> _getTextStream(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
    bool isRetryAttempt = false,
  }) async* {
    final auth = await _authHeadersFor('GET');
    final response = await _dio.request<ResponseBody>(
      path,
      queryParameters: query,
      options: Options(
        method: 'GET',
        responseType: ResponseType.stream,
        headers: {...auth.headers, Headers.acceptHeader: 'text/event-stream'},
      ),
      cancelToken: cancelToken,
    );

    // 429 / edge block 的 body 不是事件流:先收掉再等 Retry-After,
    // 不要讓連線在最長 30 秒的等待期間一直開著。
    // 已是重送就不會再重送,body 要留給下面轉 ApiError 用。
    var drained = false;
    if (!isRetryAttempt &&
        ((response.statusCode ?? 0) == 429 || _isEdgeBlockPage(response))) {
      await response.data?.stream.drain<void>();
      drained = true;
    }
    final decision = await _retryDecision(
      response,
      useBearer: auth.useBearer,
      retryableMethod: true,
      isRetryAttempt: isRetryAttempt,
      cancelToken: cancelToken,
    );
    if (decision is! retry.NoRetry) {
      if (!drained) await response.data?.stream.drain<void>();
      yield* _getTextStream(
        path,
        query: query,
        cancelToken: cancelToken,
        isRetryAttempt: true,
      );
      return;
    }
    final statusCode = response.statusCode ?? 0;
    if (statusCode < 200 || statusCode >= 300) {
      final body = await _decodeStreamBody(response.data);
      throw ApiError.fromResponse(statusCode, body);
    }
    if (_isEdgeBlockPage(response)) {
      await response.data?.stream.drain<void>();
      throw _upstreamUnavailable(statusCode);
    }

    final body = response.data;
    if (body == null) return;
    yield* body.stream.cast<List<int>>().transform(utf8.decoder);
  }

  Future<Object?> _decodeStreamBody(ResponseBody? body) async {
    final text =
        await body?.stream.cast<List<int>>().transform(utf8.decoder).join() ??
        '';
    if (text.isEmpty) return null;
    try {
      return jsonDecode(text);
    } on FormatException {
      return text;
    }
  }

  /// 命中 [_cacheCapacityByPathPrefix] 的 path → 回傳該前綴的快取上限。
  MapEntry<String, int>? _capacityFor(String path) {
    for (final entry in _cacheCapacityByPathPrefix.entries) {
      if (path.startsWith(entry.key)) return entry;
    }
    return null;
  }

  Future<({Map<String, dynamic> headers, bool useBearer})> _authHeadersFor(
    String method,
  ) async {
    final requestHeaders = <String, dynamic>{};
    final bearer = await _bearerSource?.accessToken();
    final useBearer = bearer != null && bearer.isNotEmpty;
    if (useBearer) {
      // Bearer 模式:帶 token,不送 Cookie/Origin
      //（後端對「有 Bearer 且無 Origin」的 request 跳過 CSRF 檢查）。
      requestHeaders['Authorization'] = 'Bearer $bearer';
    } else {
      final sessionToken = await _sessionStore.read();
      if (sessionToken != null && sessionToken.isNotEmpty) {
        requestHeaders['Cookie'] = 'tripline_session=$sessionToken';
      }
      final isMutation = method != 'GET' && method != 'HEAD';
      if (isMutation) {
        // cookie 認證的 mutating request 必帶 Origin（後端 CSRF 檢查）
        requestHeaders['Origin'] = _origin;
      }
    }
    return (headers: requestHeaders, useBearer: useBearer);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 衝突解決 API(供 T10 衝突 UI 呼叫)
  // ─────────────────────────────────────────────────────────────────────────

  /// 衝突解決:保留離線版本 → 重送原 body(換上 newVersion)。
  /// 成功才 removeConflict;離線 → 往上拋保留衝突記錄;
  /// 再 409 STALE → 重新 rebase(同 flushQueue 邏輯)。
  Future<void> resolveConflictKeepOurs(ConflictRecord c) async {
    final store = _cacheStore!;
    try {
      await _send(
        'PATCH',
        c.path,
        body: _rebasedBody(c.base, c.ours, c.body, c.newVersion),
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
        if (outcome == _RebaseOutcome.offline ||
            outcome == _RebaseOutcome.retryLater) {
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
      _cacheStore!.removeConflict(c.id);

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

  /// 連線層錯誤(離線/逾時/無回應)→ 可回退快取;HTTP 4xx/5xx 不算(server 有回)。
  bool _isOfflineError(DioException e) {
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

  /// 依佇列順序套用同資源 patch，並同步 entry detail 的跨資源 update。
  /// patcher 以穩定 tempId 保持冪等，因此 queue 已寫、cache 尚未寫就崩潰時，
  /// stale leg 仍可安全重播而不會重複新增。
  Future<Object?> _applyPendingPatches(
    CacheStore store,
    String key,
    Object? base,
  ) async {
    final queue = await store.readQueue();
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

  /// mutation 成功後,依失效表移除受影響的 GET 快取(body 供 add-to-trip 取 tripId)。
  Future<void> _evictForMutation(
    String method,
    String path,
    Object? body,
  ) async {
    final store = _cacheStore;
    if (store == null) return;
    for (final prefix in evictionPrefixesFor(method, path, body)) {
      await store.evictByPrefix(prefix);
    }
  }
}

/// rebase 單筆結果:成功重送 / 真衝突已入庫 / 離線中止 / 重送暫時失敗待下次。
enum _RebaseOutcome { synced, conflict, offline, retryLater }
