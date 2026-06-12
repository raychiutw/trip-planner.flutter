# PR-1 透明離線讀 — 實作 plan

> **For agentic workers:** 用 superpowers:executing-plans / subagent-driven-development 逐步實作。步驟用 `- [ ]`。
> 總綱見 `docs/superpowers/specs/2026-06-12-offline-cache-design.md` §4、§7(PR-1)。

**Goal:** 在 `ApiClient` 層加透明回應快取:GET 成功 write-through、網路失敗回退本機快取、mutation 成功後依失效表 evict、登出清快取。**不動任何 provider/screen**,離線即可讀已快取資料。

**Architecture:** 新增 `CacheStore` 抽象(沿用 `SessionStore` 慣例)+ `SembastCacheStore`(app 永續)+ `InMemoryCacheStore`(測試);cache key 與失效前綴為純函式;`ApiClient` 注入 `CacheStore?`(null=維持現狀)。

**Tech Stack:** Dart/Flutter、riverpod 3.x、dio 5.x、sembast、path_provider、mocktail、http_mock_adapter。

---

## File Structure

- Create `lib/api/cache/cache_keys.dart` — `cacheKeyFor`、`cacheKeyMatchesPrefix`、`evictionPrefixesFor`(純函式)。
- Create `lib/api/cache/cache_store.dart` — `CacheEntry`、`CacheStore` 抽象、`InMemoryCacheStore`。
- Create `lib/api/cache/sembast_cache_store.dart` — `SembastCacheStore` + `openCacheDatabase()`。
- Modify `lib/api/api_client.dart` — 注入 `CacheStore?`;`_send` write-through/fallback/evict。
- Modify `lib/api/providers.dart` — `cacheStoreProvider`(預設 InMemory)、接入 `apiClientProvider`、logout 清快取。
- Modify `lib/main.dart` — 開 sembast DB、override `cacheStoreProvider`。
- Modify `pubspec.yaml` — `flutter pub add sembast path_provider`。
- Tests:
  - `test/api/cache/cache_keys_test.dart`
  - `test/api/cache/in_memory_cache_store_test.dart`
  - `test/api/cache/api_client_cache_test.dart`

---

## Task 1: 加依賴

- [ ] **Step 1**:`flutter pub add sembast path_provider`
- [ ] **Step 2**:`flutter pub get`;`flutter analyze`(預期仍 0)。

## Task 2: cache_keys.dart(純函式 + 測試先行)

**Files:** Create `lib/api/cache/cache_keys.dart`、`test/api/cache/cache_keys_test.dart`

- [ ] **Step 1: 失敗測試**(`cache_keys_test.dart`)

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/cache/cache_keys.dart';

void main() {
  group('cacheKeyFor', () {
    test('無 query', () {
      expect(cacheKeyFor('GET', '/my-trips'), 'GET /my-trips');
    });
    test('query 依 key 排序穩定', () {
      final a = cacheKeyFor('GET', '/x', {'b': '2', 'a': '1'});
      final b = cacheKeyFor('GET', '/x', {'a': '1', 'b': '2'});
      expect(a, b);
      expect(a, 'GET /x?a=1&b=2');
    });
  });

  group('cacheKeyMatchesPrefix', () {
    test('完全相等 / 子路徑 / query 邊界都命中', () {
      expect(cacheKeyMatchesPrefix('GET /trips/abc', 'GET /trips/abc'), isTrue);
      expect(cacheKeyMatchesPrefix('GET /trips/abc/days', 'GET /trips/abc'), isTrue);
      expect(cacheKeyMatchesPrefix('GET /trips/abc?x=1', 'GET /trips/abc'), isTrue);
      expect(cacheKeyMatchesPrefix('GET /trips/abc/days?all=1', 'GET /trips/abc/days'), isTrue);
    });
    test('id 前綴相同但不同 trip 不誤刪', () {
      expect(cacheKeyMatchesPrefix('GET /trips/abcdef/days', 'GET /trips/abc'), isFalse);
    });
  });

  group('evictionPrefixesFor', () {
    test('GET 不失效任何快取', () {
      expect(evictionPrefixesFor('GET', '/trips/t/days'), isEmpty);
    });
    test('entries mutation → days/segments/entries', () {
      final p = evictionPrefixesFor('PATCH', '/trips/t/entries/5');
      expect(p, containsAll(<String>[
        'GET /trips/t/days', 'GET /trips/t/segments', 'GET /trips/t/entries',
      ]));
    });
    test('notes mutation → notes', () {
      expect(evictionPrefixesFor('POST', '/trips/t/notes/flights'),
          contains('GET /trips/t/notes'));
    });
    test('segments mutation → segments + days', () {
      final p = evictionPrefixesFor('PATCH', '/trips/t/segments/9');
      expect(p, containsAll(<String>['GET /trips/t/segments', 'GET /trips/t/days']));
    });
    test('trip 編輯/刪除 → trip + 清單', () {
      final p = evictionPrefixesFor('PUT', '/trips/t');
      expect(p, containsAll(<String>['GET /trips/t', 'GET /my-trips', 'GET /trips']));
    });
    test('建立 trip → 清單', () {
      expect(evictionPrefixesFor('POST', '/trips'),
          containsAll(<String>['GET /my-trips', 'GET /trips']));
    });
    test('favorites → poi-favorites', () {
      expect(evictionPrefixesFor('POST', '/poi-favorites'),
          contains('GET /poi-favorites'));
    });
  });
}
```

- [ ] **Step 2**:`flutter test test/api/cache/cache_keys_test.dart`(預期 FAIL:檔案不存在)
- [ ] **Step 3: 實作** `lib/api/cache/cache_keys.dart`

```dart
/// 快取鍵正規化與失效前綴對照（純函式,無 IO,可單測）。
library;

/// 正規化快取鍵:`<METHOD> <path>` + 依 key 排序的 query。
String cacheKeyFor(String method, String path, [Map<String, dynamic>? query]) {
  if (query == null || query.isEmpty) return '$method $path';
  final keys = query.keys.toList()..sort();
  final encoded = keys.map((k) => '$k=${query[k]}').join('&');
  return '$method $path?$encoded';
}

/// prefix 以 path 段邊界比對:相等、或後接 `/`、`?`。
/// 避免 `/trips/abc` 誤刪 `/trips/abcdef/...`。
bool cacheKeyMatchesPrefix(String key, String prefix) =>
    key == prefix || key.startsWith('$prefix/') || key.startsWith('$prefix?');

/// mutation(非 GET/HEAD)成功後應失效的 GET 快取鍵前綴。
List<String> evictionPrefixesFor(String method, String path) {
  if (method == 'GET' || method == 'HEAD') return const [];

  final tripMatch = RegExp(r'^/trips/([^/]+)').firstMatch(path);
  if (tripMatch != null) {
    final trip = '/trips/${tripMatch.group(1)!}';
    if (path.contains('/entries') ||
        path.contains('/days') ||
        path.endsWith('/recompute-travel')) {
      return ['GET $trip/days', 'GET $trip/segments', 'GET $trip/entries'];
    }
    if (path.contains('/notes')) return ['GET $trip/notes'];
    if (path.contains('/segments')) return ['GET $trip/segments', 'GET $trip/days'];
    // /trips/:id 本身(PUT/DELETE)
    return ['GET $trip', 'GET /my-trips', 'GET /trips'];
  }
  if (path == '/trips') return ['GET /my-trips', 'GET /trips'];
  if (path.startsWith('/poi-favorites')) return ['GET /poi-favorites'];
  return const [];
}
```

- [ ] **Step 4**:`flutter test test/api/cache/cache_keys_test.dart`(預期 PASS)
- [ ] **Step 5**:commit `feat: 離線快取 cache key 與失效前綴純函式`

## Task 3: cache_store.dart(InMemory + 測試)

**Files:** Create `lib/api/cache/cache_store.dart`、`test/api/cache/in_memory_cache_store_test.dart`

- [ ] **Step 1: 失敗測試**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/cache/cache_store.dart';

void main() {
  late InMemoryCacheStore store;
  setUp(() => store = InMemoryCacheStore());

  test('write 後 read 回 data + cachedAt', () async {
    await store.writeResponse('GET /x', {'a': 1});
    final e = await store.readResponse('GET /x');
    expect(e!.data, {'a': 1});
    expect(e.cachedAt, isA<DateTime>());
  });

  test('miss 回 null', () async {
    expect(await store.readResponse('GET /none'), isNull);
  });

  test('evictByPrefix 只刪命中,不誤刪 id 前綴相同者', () async {
    await store.writeResponse('GET /trips/abc/days?all=1', [1]);
    await store.writeResponse('GET /trips/abc/notes', {'n': 1});
    await store.writeResponse('GET /trips/abcdef/days', [2]);
    await store.evictByPrefix('GET /trips/abc/days');
    expect(await store.readResponse('GET /trips/abc/days?all=1'), isNull);
    expect(await store.readResponse('GET /trips/abc/notes'), isNotNull);
    expect(await store.readResponse('GET /trips/abcdef/days'), isNotNull);
  });

  test('clear 清空', () async {
    await store.writeResponse('GET /x', 1);
    await store.clear();
    expect(await store.readResponse('GET /x'), isNull);
  });
}
```

- [ ] **Step 2**:`flutter test test/api/cache/in_memory_cache_store_test.dart`(FAIL)
- [ ] **Step 3: 實作** `lib/api/cache/cache_store.dart`

```dart
/// 離線快取持久化抽象與記憶體實作(沿用 SessionStore 慣例)。
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
  Future<void> writeResponse(String key, Object? data, {DateTime? cachedAt}) async {
    _entries[key] = CacheEntry(data: data, cachedAt: cachedAt ?? DateTime.now());
  }

  @override
  Future<void> evictByPrefix(String prefix) async {
    _entries.removeWhere((key, _) => cacheKeyMatchesPrefix(key, prefix));
  }

  @override
  Future<void> clear() async => _entries.clear();
}
```

- [ ] **Step 4**:`flutter test test/api/cache/in_memory_cache_store_test.dart`(PASS)
- [ ] **Step 5**:commit `feat: 離線快取 CacheStore 抽象 + InMemory 實作`

## Task 4: sembast_cache_store.dart(app 永續)

**Files:** Create `lib/api/cache/sembast_cache_store.dart`

> 不寫 IO 單元測試(走 InMemory);此檔僅 app 用。以 `flutter analyze` 把關。

- [ ] **Step 1: 實作**

```dart
/// sembast-backed 永續快取(app 用;測試走 InMemoryCacheStore)。
library;

import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';

import 'cache_keys.dart';
import 'cache_store.dart';

/// 開啟快取 DB(目錄由 path_provider 提供,於 main() 呼叫)。
Future<Database> openCacheDatabase(String directoryPath) =>
    databaseFactoryIo.openDatabase('$directoryPath/tripline_cache.db');

class SembastCacheStore implements CacheStore {
  SembastCacheStore(this._db);

  final Database _db;
  final StoreRef<String, Map<String, Object?>> _store =
      stringMapStoreFactory.store('response_cache');

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
  Future<void> writeResponse(String key, Object? data, {DateTime? cachedAt}) async {
    await _store.record(key).put(_db, {
      'data': data,
      'cachedAt': (cachedAt ?? DateTime.now()).toIso8601String(),
    });
  }

  @override
  Future<void> evictByPrefix(String prefix) async {
    final keys = await _store.findKeys(_db);
    final toDelete =
        keys.where((k) => cacheKeyMatchesPrefix(k, prefix)).toList();
    if (toDelete.isNotEmpty) await _store.records(toDelete).delete(_db);
  }

  @override
  Future<void> clear() async => _store.delete(_db);
}
```

- [ ] **Step 2**:`flutter analyze`(0)
- [ ] **Step 3**:commit `feat: SembastCacheStore 永續快取實作`

## Task 5: ApiClient 接入快取(write-through / fallback / evict)

**Files:** Modify `lib/api/api_client.dart`、Create `test/api/cache/api_client_cache_test.dart`

- [ ] **Step 1: 失敗測試**(http_mock_adapter + InMemoryCacheStore)

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/cache/cache_keys.dart';
import 'package:tripline/api/cache/cache_store.dart';
import 'package:tripline/api/session_store.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late InMemoryCacheStore cache;
  late ApiClient client;

  setUp(() {
    dio = Dio(BaseOptions())..options.validateStatus = (_) => true;
    adapter = DioAdapter(dio: dio);
    cache = InMemoryCacheStore();
    client = ApiClient(
      sessionStore: InMemorySessionStore(),
      dio: dio,
      cacheStore: cache,
    );
  });

  test('GET 成功 → write-through 寫入快取', () async {
    adapter.onGet('/my-trips', (s) => s.reply(200, [{'id': 't1'}]));
    await client.get('/my-trips');
    final entry = await cache.readResponse(cacheKeyFor('GET', '/my-trips'));
    expect(entry!.data, [{'id': 't1'}]);
  });

  test('GET 連線失敗 + 有快取 → 回退快取', () async {
    await cache.writeResponse(
        cacheKeyFor('GET', '/trips/t/days', {'all': '1'}), [{'dayNumber': 1}]);
    adapter.onGet('/trips/t/days',
        (s) => s.throws(503, DioException(
            requestOptions: RequestOptions(path: '/trips/t/days'),
            type: DioExceptionType.connectionError)),
        queryParameters: {'all': '1'});
    final result = await client.get('/trips/t/days', query: {'all': '1'});
    expect(result, [{'dayNumber': 1}]);
  });

  test('GET 連線失敗 + 無快取 → rethrow', () async {
    adapter.onGet('/trips/t/days',
        (s) => s.throws(503, DioException(
            requestOptions: RequestOptions(path: '/trips/t/days'),
            type: DioExceptionType.connectionError)),
        queryParameters: {'all': '1'});
    expect(() => client.get('/trips/t/days', query: {'all': '1'}),
        throwsA(isA<DioException>()));
  });

  test('mutation 成功 → 依失效表 evict', () async {
    final daysKey = cacheKeyFor('GET', '/trips/t/days', {'all': '1'});
    await cache.writeResponse(daysKey, [{'dayNumber': 1}]);
    adapter.onPatch('/trips/t/entries/5', (s) => s.reply(200, {'ok': true}),
        data: {'title': 'x'});
    await client.patch('/trips/t/entries/5', body: {'title': 'x'});
    expect(await cache.readResponse(daysKey), isNull);
  });

  test('cacheStore=null → 行為不變(GET 成功不報錯)', () async {
    final plain = ApiClient(sessionStore: InMemorySessionStore(), dio: dio);
    adapter.onGet('/trips', (s) => s.reply(200, []));
    expect(await plain.get('/trips'), []);
  });
}
```

- [ ] **Step 2**:`flutter test test/api/cache/api_client_cache_test.dart`(FAIL)
- [ ] **Step 3: 實作** — 修改 `lib/api/api_client.dart`:
  - import `cache/cache_keys.dart`、`cache/cache_store.dart`。
  - 建構子加 `CacheStore? cacheStore`,存 `_cacheStore`。
  - `_send` 改成下列骨架(保留既有 bearer/cookie/origin、429 retry、401 refresh 邏輯):

```dart
// _send 內:組好 requestHeaders 後 ——
final Response<dynamic> response;
try {
  response = await _dio.request<dynamic>(
    path,
    queryParameters: query,
    data: body,
    options: Options(method: method, headers: requestHeaders),
    cancelToken: cancelToken,
  );
} on DioException catch (e) {
  // 連線層失敗(離線/逾時):GET 嘗試回退快取
  if (method == 'GET' && _cacheStore != null && _isOfflineError(e)) {
    final cached =
        await _cacheStore.readResponse(cacheKeyFor('GET', path, query));
    if (cached != null) return cached.data;
  }
  rethrow;
}

final statusCode = response.statusCode ?? 0;
// ... 既有 429 retry / 401 refresh 不變 ...
if (statusCode < 200 || statusCode >= 300) {
  throw ApiError.fromResponse(statusCode, response.data);
}
if (statusCode == 204) {
  await _evictForMutation(method, path);
  return null;
}
final responseData = response.data;
final isEmpty =
    responseData == null || (responseData is String && responseData.isEmpty);
if (method == 'GET') {
  if (!isEmpty) {
    await _cacheStore?.writeResponse(cacheKeyFor('GET', path, query), responseData);
  }
} else {
  await _evictForMutation(method, path);
}
return isEmpty ? null : responseData;
```

  - 加兩個 private helper:

```dart
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

Future<void> _evictForMutation(String method, String path) async {
  final store = _cacheStore;
  if (store == null) return;
  for (final prefix in evictionPrefixesFor(method, path)) {
    await store.evictByPrefix(prefix);
  }
}
```

> 注意:429 retry / 401 refresh 的遞迴呼叫仍走 `_send`,快取/evict 落在最終非重試路徑,無重複。`cacheStore=null` 時所有 `_cacheStore?.` 跳過,且 try/catch 僅 rethrow → 與現狀一致。

- [ ] **Step 4**:`flutter test test/api/cache/api_client_cache_test.dart`(PASS)
- [ ] **Step 5**:`flutter test test/api/api_client_test.dart`(既有測試仍 PASS)
- [ ] **Step 6**:commit `feat: ApiClient 接入透明快取(write-through/fallback/evict)`

## Task 6: providers 接線 + 登出清快取

**Files:** Modify `lib/api/providers.dart`

- [ ] **Step 1**:加 `import 'cache/cache_store.dart';`
- [ ] **Step 2**:加 provider(預設 InMemory,app 於 main override):

```dart
final cacheStoreProvider = Provider<CacheStore>((ref) => InMemoryCacheStore());
```

- [ ] **Step 3**:`apiClientProvider` 加 `cacheStore: ref.watch(cacheStoreProvider)`。
- [ ] **Step 4**:`AuthNotifier.logout()` 在清 oauth 後加 `await ref.read(cacheStoreProvider).clear();`(避免跨帳號外洩)。
- [ ] **Step 5**:`flutter test test/api/providers_test.dart` 與全測試(PASS)。
- [ ] **Step 6**:commit `feat: cacheStoreProvider 接線 + 登出清離線快取`

## Task 7: main.dart 開永續 DB

**Files:** Modify `lib/main.dart`

- [ ] **Step 1**:`main()` 改 async,於 `runApp` 前:

```dart
WidgetsFlutterBinding.ensureInitialized();
final docsDir = await getApplicationDocumentsDirectory();
final cacheStore = SembastCacheStore(await openCacheDatabase(docsDir.path));
```

  並在 `ProviderScope(overrides: [..., cacheStoreProvider.overrideWithValue(cacheStore)])`。
  imports:`package:path_provider/path_provider.dart`、`api/cache/cache_store.dart`、`api/cache/sembast_cache_store.dart`、`api/providers.dart`(若未引)。
- [ ] **Step 2**:`flutter analyze`(0)
- [ ] **Step 3**:commit `feat: main 開 sembast 永續快取並 override cacheStoreProvider`

## Task 8: 完成驗收

- [ ] **Step 1**:`flutter analyze`(0 error/warning)
- [ ] **Step 2**:`flutter test`(全綠;既有 434 + 新增 cache 測試)
- [ ] **Step 3**:用 finishing-a-development-branch 收尾 → 開 PR(base `master`)。

---

## Self-Review 檢查

- **Spec 覆蓋**:對應 spec §7 PR-1 全部項目(CacheStore/sembast/InMemory、cache key、失效前綴、ApiClient 注入、write-through、fallback、evict、登出清快取、main 開 DB)。SWR/queue/sync 不在本 PR(屬 PR-2~5)。✓
- **Placeholder**:無 TBD;每個程式步驟附完整碼。✓
- **型別一致**:`CacheStore` 介面方法名(readResponse/writeResponse/evictByPrefix/clear)在 InMemory、Sembast、ApiClient、providers 用法一致;`cacheKeyFor`/`evictionPrefixesFor`/`cacheKeyMatchesPrefix` 簽章一致。✓
