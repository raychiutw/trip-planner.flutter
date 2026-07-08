# API 層參考(`lib/api/`)

Tripline 的 API 層封裝對 Cloudflare Pages Functions 後端(`https://trip-planner-dby.pages.dev/api`)的所有 HTTP 存取。由四個部分組成:`ApiClient`(dio 封裝)、`ApiError`(錯誤型別)、`SessionStore`(token 儲存)、兩個 repository(`AuthRepository`、`TripRepository`),最後以 riverpod providers 串起來。

> 想了解「為什麼這樣設計」(cookie 認證、CSRF Origin、429 retry 策略),請看[架構說明](explanation-architecture.md)。想新增 endpoint,請看 [How to 新增 API endpoint](howto-add-endpoint.md)。

## ApiClient(`api_client.dart`)

```dart
const String kTriplineOrigin = 'https://trip-planner-dby.pages.dev';

class ApiClient {
  ApiClient({
    required SessionStore sessionStore,
    Dio? dio,                          // 測試注入用;預設 new Dio()
    String origin = kTriplineOrigin,   // base URL = '$origin/api'
  });

  Future<dynamic> get(String path, {Map<String, dynamic>? query});
  Future<dynamic> post(String path, {Object? body});
  Future<dynamic> put(String path, {Object? body});
  Future<dynamic> patch(String path, {Object? body});
  Future<dynamic> delete(String path);

  Dio get dio;  // 供 AuthRepository 直接讀 response headers(set-cookie)

  static int parseRetryAfterSeconds(String? headerValue);
}
```

### 行為規則(每條都有對應測試,見 `test/api/api_client_test.dart`)

1. **Cookie 認證** — 每個 request 先 `sessionStore.read()`,有值就帶 `Cookie: tripline_session=<token>`;無值(未登入)不帶。
2. **CSRF Origin** — `GET`/`HEAD` 以外的方法一律帶 `Origin: https://trip-planner-dby.pages.dev` header。後端有 Origin allowlist,缺少此 header 的 mutation 會被 403 拒絕。
3. **錯誤轉換** — 非 2xx 一律 throw [`ApiError`](#apierrorapi_errordart)。dio 的 `validateStatus` 設為全收,狀態碼判斷集中在 `_send()`。
4. **429 retry** — 僅限 `GET`:讀 `Retry-After` header 等待後重試**一次**;mutation(POST/PUT/PATCH/DELETE)**絕不重試**(避免重複寫入)。
5. **204 / 空 body → `null`** — 不要對回傳值假設一定有 JSON。

### `parseRetryAfterSeconds`

解析 `Retry-After` header,回傳等待秒數:

| 輸入 | 結果 |
|---|---|
| `"5"`(delta-seconds) | `5`(clamp 0–30) |
| HTTP-date(如 `"Wed, 21 Oct 2026 07:28:00 GMT"`) | 與現在的秒差(clamp 0–30) |
| `null` / 空字串 / 無效值 | `1` |

上限 30 秒(`maxWaitSeconds`),避免被 server 指示等過久。

## ApiError(`api_error.dart`)

```dart
class ApiError implements Exception {
  final int status;       // HTTP 狀態碼
  final String code;      // 穩定機器碼,如 AUTH_REQUIRED / STALE_ENTRY
  final String message;   // 人話訊息
  final String? detail;   // 額外細節,截斷至 200 字

  factory ApiError.fromResponse(int status, dynamic body);
}
```

`fromResponse` 的解析優先序(三層 fallback):

1. `{error: {code, message, detail}}` — 標準 API 錯誤 shape
2. `{error: "字串", error_description: "..."}` — OAuth 端點的 flat shape;`error` 當 code、`error_description` 當 message
3. 以上都不符 → `code = 'HTTP_<status>'`、`message = 'HTTP <status>'`

已知的後端錯誤碼(來源:web repo `src/lib/errors.ts`):`AUTH_REQUIRED`、`PERM_DENIED`、`STALE_ENTRY`(OCC 版本衝突)、`SYS_RATE_LIMIT`、`LOGIN_INVALID`、`LOGIN_RATE_LIMITED`。本機自造碼:`AUTH_NO_SESSION_COOKIE`(登入回應缺 session cookie)。

## SessionStore(`session_store.dart`)

```dart
abstract class SessionStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}
```

| 實作 | 用途 |
|---|---|
| `SecureSessionStore` | 正式環境。flutter_secure_storage,key 固定 `tripline_session`(iOS Keychain / Android Keystore) |
| `InMemorySessionStore` | 測試替身。純記憶體,測試結束即消失 |

## AuthRepository(`auth_repository.dart`)

對應 `/api/oauth/*` 認證 endpoints。

```dart
class AuthRepository {
  AuthRepository({required ApiClient client, required SessionStore sessionStore});

  Future<UserInfo> login({required String email, required String password});
  Future<void> logout();
  Future<UserInfo?> currentUser();
}
```

| 方法 | 行為 |
|---|---|
| `login` | `POST /oauth/login`(走 raw `client.dio` 才能讀 headers)→ 用 regex 從 `set-cookie` 解析 `tripline_session=<value>` → 寫入 store → `GET /oauth/userinfo` 回 `UserInfo`。找不到 cookie 時 throw `ApiError(code: 'AUTH_NO_SESSION_COOKIE')` |
| `logout` | `POST /oauth/logout`(**失敗忽略**,server 端登出失敗不影響本機)+ `store.clear()`(必執行,在 `finally`) |
| `currentUser` | `GET /oauth/userinfo`;**401 回 `null` 不 throw**(未登入是正常狀態),其他錯誤 rethrow |

## TripRepository(`trip_repository.dart`)

對應 `/api/my-trips`、`/api/trips/*`、`/api/account/*`、`/api/poi-favorites`、`/api/poi-search`。路徑參數一律 `Uri.encodeComponent` 編碼。

```dart
class TripRepository {
  TripRepository({required ApiClient client});

  Future<List<TripSummary>> fetchMyTrips();              // GET /my-trips
  Future<List<Trip>>        fetchTrips();                // GET /trips(published 清單)
  Future<Trip>              fetchTrip(String id);        // GET /trips/:id
  Future<List<TripDay>>     fetchDays(String id);        // GET /trips/:id/days?all=1
  Future<TripNotes>         fetchNotes(String id);       // GET /trips/:id/notes
  Future<void>              deleteTrip(String id);       // DELETE /trips/:id(限 owner/admin)
  Future<AccountStats>      fetchStats();                // GET /account/stats
  Future<UserInfo>          updateProfile({String? displayName}); // PATCH /account/profile
  Future<List<PoiFavorite>> fetchPoiFavorites();         // GET /poi-favorites
  Future<List<PoiSearchResult>> searchPois({required String query, String? region, int limit = 20}); // GET /poi-search
  Future<int>               findOrCreatePoi(PoiSearchResult poi); // POST /pois/find-or-create
  Future<PoiFavorite>       createPoiFavorite({required int poiId, String? note}); // POST /poi-favorites
  Future<void>              deletePoiFavorite(int id);   // DELETE /poi-favorites/:id
  Future<PoiFavoriteAddToTripResult> addPoiFavoriteToTrip(
    int favoriteId, {
    required String tripId,
    required int dayNum,
    required String startTime,
    required String endTime,
  }); // POST /poi-favorites/:id/add-to-trip
}
```

`updateProfile` 的 `displayName` 傳 `null` 表示清除顯示名稱(body 仍會帶 `{'displayName': null}`)。
`addPoiFavoriteToTrip` 只送後端現行 4-field contract:`tripId`、`dayNum`、`startTime`、`endTime`;不送已廢除的 `position` / `anchorEntryId`。

回傳的 model 結構見 [Models 參考](reference-models.md)。

## Riverpod providers(`providers.dart`)

```dart
final sessionStoreProvider   = Provider<SessionStore>((ref) => SecureSessionStore());
final apiClientProvider      = Provider<ApiClient>(...);       // 注入 sessionStoreProvider
final authRepositoryProvider = Provider<AuthRepository>(...);  // 注入 client + store
final tripRepositoryProvider = Provider<TripRepository>(...);  // 注入 client

class AuthNotifier extends AsyncNotifier<UserInfo?> {
  Future<void> login(String email, String password);
  Future<void> logout();
}
final authStateProvider = AsyncNotifierProvider<AuthNotifier, UserInfo?>(AuthNotifier.new);
```

`authStateProvider` 是全 app 的認證狀態 single source of truth:

| 狀態 | 意義 |
|---|---|
| `AsyncData(null)` | 未登入 |
| `AsyncData(UserInfo)` | 已登入 |
| `AsyncLoading` | 啟動時查 `currentUser()` 中,或登入請求進行中 |
| `AsyncError` | 登入失敗(`login()` 用 `AsyncValue.guard` 把例外收進 state,LoginScreen 讀此顯示錯誤 banner) |

`build()` 即 `currentUser()` — app 啟動時自動以既存 session 驗證登入狀態。router 的 redirect 邏輯依賴此 provider,見[導航參考](reference-navigation.md)。

行程詳情層級的 scoped providers(`tripDetailProvider` 等 family)定義在 `lib/features/trip_detail/trip_providers.dart`,見[架構說明 — trip scope](explanation-architecture.md#trip-scope共用-fetch)。

## 相關文件

- [架構說明](explanation-architecture.md) — 認證與 CSRF 設計的「為什麼」
- [Models 參考](reference-models.md) — 各 endpoint 回應的解析規則
- [How to 新增 API endpoint](howto-add-endpoint.md)
- [How to 用 provider override 寫測試](howto-test-with-providers.md)
