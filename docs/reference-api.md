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
  Future<dynamic> post(String path, {Map<String, dynamic>? query, Object? body});
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
  Future<SignupResult> signup({required String email, required String password, String? displayName, String? invitationToken});
  Future<AuthMessageResult> requestPasswordReset(String email);
  Future<AuthMessageResult> resetPassword({required String token, required String password});
  Future<void> verifyEmail(String token);
  Future<AuthMessageResult> sendVerificationEmail(String email);
  Future<void> logout();
  Future<UserInfo?> currentUser();
}
```

| 方法 | 行為 |
|---|---|
| `login` | `POST /oauth/login`(走 raw `client.dio` 才能讀 headers)→ 用 regex 從 `set-cookie` 解析 `tripline_session=<value>` → 寫入 store → `GET /oauth/userinfo` 回 `UserInfo`。找不到 cookie 時 throw `ApiError(code: 'AUTH_NO_SESSION_COOKIE')` |
| `signup` | `POST /oauth/signup`(走 raw `client.dio` 讀 `set-cookie`)→ 寫入 `tripline_session` → 回 `SignupResult`。`displayName` 與 `invitationToken` 只有非空才送出 |
| `requestPasswordReset` | `POST /oauth/forgot-password`；後端用 generic 200 避免 email enumeration,回 `AuthMessageResult` |
| `resetPassword` | `POST /oauth/reset-password`；成功後不建立 session,使用者需回登入頁 |
| `verifyEmail` | `POST /oauth/verify`；Flutter 畫面要求 user gesture 後才送 token,避免 email security scanner 消耗 token |
| `sendVerificationEmail` | `POST /oauth/send-verification`；用於 signup 後 best-effort 寄送與 check-email 頁手動重寄 |
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
  Future<TripHealthReport?> fetchTripHealthReport(String tripId); // GET /trips/:id/health-check
  Future<TripHealthReport>  startTripHealthCheck(String tripId); // POST /trips/:id/health-check
  Future<List<TripPermission>> fetchTripPermissions(String tripId); // GET /permissions?tripId=...
  Future<PendingInvitationPage> fetchPendingInvitations(String tripId); // GET /invitations?tripId=...
  Future<PermissionInviteResult> createTripPermissionInvite({
    required String tripId,
    required String email,
    String role = 'member',
  }); // POST /permissions
  Future<void> revokeTripInvitation({
    required String tripId,
    required String email,
  }); // POST /invitations/revoke
  Future<PermissionRoleUpdateResult> updateTripPermissionRole({
    required int permissionId,
    required String role,
  }); // PATCH /permissions/:id
  Future<void> deleteTripPermission(int permissionId); // DELETE /permissions/:id
  Future<InvitationPreview> fetchInvitation(String token); // GET /invitations?token=...
  Future<InvitationAcceptResult> acceptInvitation(String token); // POST /invitations/accept
  Future<List<TripShareLink>> fetchTripShares(String tripId); // GET /trips/:id/shares
  Future<CreatedTripShare> createTripShare(
    String tripId, {
    required List<String> visibleSections,
    String label = '',
    int? expiresAt,
    bool anonymous = false,
  }); // POST /trips/:id/shares
  Future<void> updateTripShare(
    String tripId,
    int shareId, {
    required List<String> visibleSections,
    String label = '',
    int? expiresAt,
    bool anonymous = false,
  }); // PATCH /trips/:id/shares/:shareId action=update
  Future<CreatedTripShare> rotateTripShare(String tripId, int shareId); // PATCH action=rotate
  Future<void> revokeTripShare(String tripId, int shareId); // PATCH action=revoke
  Future<void> deleteTripShare(String tripId, int shareId); // DELETE /trips/:id/shares/:shareId
  Future<TripRequestPage>   fetchTripRequests({
    required String tripId,
    int limit = 5,
    String sort = 'desc',
    String? before,
    int? beforeId,
  }); // GET /requests?tripId=...&limit=...&sort=...
  Future<TripRequest>       createTripRequest({
    required String tripId,
    required String message,
  }); // POST /requests
  Future<TripRequest>       fetchTripRequest(int id);    // GET /requests/:id
  Future<String>            createTrip({
    required String id,
    required String name,
    required String? title,
    required String? description,
    required String startDate,
    required String endDate,
    String countries = 'JP',
    bool published = true,
    String lang = 'zh-TW',
    List<TripDestinationInput> destinations = const [],
  }); // POST /trips
  Future<String>            importTripJson(String jsonText); // POST /trips/import raw JSON text
  Future<void>              updateTrip({
    required String id,
    required String? title,
    required String? description,
    required bool published,
    required String lang,
    required List<TripDestinationInput> destinations,
  }); // PUT /trips/:id
  Future<List<TripDay>>     fetchDays(String id);        // GET /trips/:id/days?all=1
  Future<TripDay>           createTripDay({
    required String tripId,
    required String position,
    String? date,
  }); // POST /trips/:id/days
  Future<TripDayDeleteResult> deleteTripDay({
    required String tripId,
    required int dayNum,
  }); // DELETE /trips/:id/days/:num
  Future<TripDaysShiftResult> shiftTripDays({
    required String tripId,
    required String startDate,
  }); // POST /trips/:id/days/shift
  Future<List<TripSegment>> fetchTripSegments(String tripId); // GET /trips/:id/segments
  Future<TripSegment>       updateTripSegment({
    required String tripId,
    required int segmentId,
    required String mode,
    int? min,
    required int expectedVersion,
  }); // PATCH /trips/:id/segments/:sid
  Future<TimelineEntry>     fetchEntry(String tripId, int entryId); // GET /trips/:id/entries/:entryId
  Future<TimelineEntry>     updateEntry(
    String tripId,
    int entryId, {
    required int expectedVersion,
    required String? startTime,
    required String? endTime,
    required String? description,
  }); // PATCH /trips/:id/entries/:entryId
  Future<void>              deleteEntry(String tripId, int entryId); // DELETE /trips/:id/entries/:entryId
  Future<TimelineEntry>     copyEntry({
    required String tripId,
    required int entryId,
    required int targetDayId,
  }); // POST /trips/:id/entries/:entryId/copy
  Future<TimelineEntry>     moveEntry({
    required String tripId,
    required int entryId,
    required int targetDayId,
    required int expectedVersion,
  }); // PATCH /trips/:id/entries/:entryId
  Future<void>              replaceEntryMasterPoiFromSearchResult({
    required String tripId,
    required int entryId,
    required PoiSearchResult poi,
    required String? entryPoisVersion,
  }); // PUT /trips/:id/entries/:entryId/poi-id
  Future<void>              replaceEntryMasterPoiWithPoiId({
    required String tripId,
    required int entryId,
    required int poiId,
    required String? entryPoisVersion,
  }); // PUT /trips/:id/entries/:entryId/poi-id
  Future<EntryPoisMutationResult> addEntryAlternateFromSearchResult({
    required String tripId,
    required int entryId,
    required PoiSearchResult poi,
    required String? entryPoisVersion,
  }); // POST /trips/:id/entries/:entryId/alternates
  Future<EntryPoisMutationResult> addEntryAlternateWithPoiId({
    required String tripId,
    required int entryId,
    required int poiId,
    required String? entryPoisVersion,
  }); // POST /trips/:id/entries/:entryId/alternates
  Future<EntryPoisMutationResult> deleteEntryAlternate({
    required String tripId,
    required int entryId,
    required int poiId,
    required String? entryPoisVersion,
  }); // DELETE /trips/:id/entries/:entryId/alternates/:poiId?entryPoisVersion=...
  Future<EntryAlternatesReorderResult> reorderEntryAlternates({
    required String tripId,
    required int entryId,
    required List<int> orderedPoiIds,
    required String? entryPoisVersion,
  }); // PATCH /trips/:id/entries/:entryId/alternates/reorder
  Future<TripNotes>         fetchNotes(String id);       // GET /trips/:id/notes
  Future<TripFlight>        createTripFlight({required String tripId, String? airline, String? flightNo, String? cabinClass, String? departAirport, String? arriveAirport, String? departAt, String? arriveAt, String? note}); // POST /trips/:id/notes/flights
  Future<TripFlight>        updateTripFlight({required String tripId, required int rowId, required int expectedVersion, String? airline, String? flightNo, String? cabinClass, String? departAirport, String? arriveAirport, String? departAt, String? arriveAt, String? note}); // PATCH /trips/:id/notes/flights/:rowId
  Future<TripLodging>       createTripLodging({required String tripId, String? name, String? address, String? checkInAt, String? checkOutAt, String? bookingNo, String? phone, String? note}); // POST /trips/:id/notes/lodgings
  Future<TripLodging>       updateTripLodging({required String tripId, required int rowId, required int expectedVersion, String? name, String? address, String? checkInAt, String? checkOutAt, String? bookingNo, String? phone, String? note}); // PATCH /trips/:id/notes/lodgings/:rowId
  Future<TripReservation>   createTripReservation({required String tripId, String? kind, String? title, String? reservedAt, int? partySize, String? reservationNo, String? phone, String? note}); // POST /trips/:id/notes/reservations
  Future<TripReservation>   updateTripReservation({required String tripId, required int rowId, required int expectedVersion, String? kind, String? title, String? reservedAt, int? partySize, String? reservationNo, String? phone, String? note}); // PATCH /trips/:id/notes/reservations/:rowId
  Future<TripPretripNote>   createTripPretripNote({required String tripId, String? section, String? title, String? content}); // POST /trips/:id/notes/pretrip
  Future<TripPretripNote>   updateTripPretripNote({required String tripId, required int rowId, required int expectedVersion, String? section, String? title, String? content}); // PATCH /trips/:id/notes/pretrip/:rowId
  Future<TripEmergencyContact> createTripEmergencyContact({required String tripId, String? name, String? relationship, String? phone, String? email, String? kind}); // POST /trips/:id/notes/emergency
  Future<TripEmergencyContact> updateTripEmergencyContact({required String tripId, required int rowId, required int expectedVersion, String? name, String? relationship, String? phone, String? email, String? kind}); // PATCH /trips/:id/notes/emergency/:rowId
  Future<void>              deleteTripNoteRow({required String tripId, required TripNoteSection section, required int rowId}); // DELETE /trips/:id/notes/:section/:rowId
  Future<TripNoteAiGenerationJob> generateTripNotes({required String tripId, required String docType}); // POST /trips/:id/notes/:docType/generate
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
  Future<void> createEntryFromPoiSearchResult({
    required String tripId,
    required int dayNum,
    required PoiSearchResult poi,
    required String startTime,
    required String endTime,
  }); // POST /trips/:id/days/:num/entries
  Future<void> createCustomEntry({
    required String tripId,
    required int dayNum,
    required String name,
    required String? note,
    required double lat,
    required double lng,
    required String poiType,
    required String startTime,
    required String endTime,
  }); // POST /trips/:id/days/:num/entries
  Future<void>              recomputeTravel(String tripId, {int? dayNum}); // POST /trips/:id/recompute-travel?day=N
}
```

`updateProfile` 的 `displayName` 傳 `null` 表示清除顯示名稱(body 仍會帶 `{'displayName': null}`)。
`fetchMyTrips` 解析 `/my-trips` rich summary rows,包含 owner/role/countries/start/end/updated/member/archive 欄位。`TripsListScreen` 以這份資料在 client 端做分類 tabs、搜尋與排序；「最新編輯」保留 API 回傳順序。
共編/邀請第一波由 `fetchTripPermissions`、`fetchPendingInvitations`、`createTripPermissionInvite`、`revokeTripInvitation`、`updateTripPermissionRole`、`deleteTripPermission`、`fetchInvitation`、`acceptInvitation` 覆蓋。`createTripPermissionInvite` 與 `updateTripPermissionRole` 只允許 `member` / `viewer`（預設/ fallback `member`）,client 會 trim/lowercase invitation email；owner role 不可由 Flutter 變更或移除,後端也會拒絕。
分享連結管理由 `fetchTripShares`、`createTripShare`、`updateTripShare`、`rotateTripShare`、`revokeTripShare`、`deleteTripShare` 覆蓋。`createTripShare` / `rotateTripShare` 才會回 raw token/url；list 不會拿到既有網址。`visibleSections` 會經 `share.dart` allowlist 正規化,預設公開航班/住宿/行前須知,預訂與緊急聯絡預設關閉。
`fetchTripRequests` / `createTripRequest` / `fetchTripRequest` 對應 web ChatPage 的 AI request queue。`fetchTripRequests` 預設讀 active trip 最新 5 筆且支援後端 paginated shape `{items, hasMore}`；若後端回 legacy array,repository 會包成 `TripRequestPage(hasMore: false)`。`ChatScreen` 第一波使用 polling `GET /requests/:id` 取代 web SSE。
`fetchTripHealthReport` / `startTripHealthCheck` 對應 web `TripHealthCheckPage`。GET 解析 wrapper `{report}` 並允許 `report: null`;POST 送空 body 觸發後端建立 health-check request,回 pending `TripHealthReport`。`TripHealthScreen` 第一波用 `GET /trips/:id/health-check` 每 3 秒 polling report terminal state；若後端回 `TRIP_EMPTY`,畫面顯示 persistent error。
`createTrip` 對齊 web `NewTripPage` 的 `POST /trips`:送 `id`、`name`、`startDate`、`endDate`、`countries`、`published`、`lang`、`data_source: manual` 與 `destinations`;成功回傳新 `tripId`。`importTripJson` 對齊 web 匯入行程,將已通過 client 端大小與 `schemaVersion == 1` 檢查的 raw JSON text 送到 `POST /trips/import`,成功回傳新 `tripId`。`updateTrip` 對齊 web `EditTripPage` 的 `PUT /trips/:id`:更新 `title`、`description`、`published`、`lang`,並以 full-replacement 語意送 `destinations`。
`createTripDay` / `deleteTripDay` / `shiftTripDays` 對齊 web `EditTripPage` 的 day management immediate mutation。`createTripDay` body 送 `position: start|end|insert`,只有 `insert` 補缺日時才送 `date`;`deleteTripDay` 解析後端 `removedEntryCount`,UI 會先用目前 day timeline 顯示刪除影響範圍;`shiftTripDays` 送新的 Day 1 `startDate`,回傳新的起訖日期摘要。
`addPoiFavoriteToTrip` 只送後端現行 4-field contract:`tripId`、`dayNum`、`startTime`、`endTime`;不送已廢除的 `position` / `anchorEntryId`。
`fetchTripSegments` 讀取 `trip_segments` source of truth；後端目前回 snake_case row,由 `TripSegment.fromJson` 解析。`updateTripSegment` 對既有 segment 送 `mode` 與必填 `expectedVersion`;只有 `mode == 'transit'` 且 `min` 非 null 時送 `min`,driving/walking 讓後端依 from/to entry 座標重算。
`updateEntry` 目前暴露 entry 時間與 `description` 編輯:body 使用 `start_time`、`end_time`、`description` 與必填 OCC `expectedVersion`;不送 entry-level `note`。
`copyEntry` 送 `POST /trips/:id/entries/:entryId/copy` 與 body `targetDayId`;`moveEntry` 復用 entry PATCH endpoint,body 使用 `day_id` 與必填 OCC `expectedVersion`。畫面成功後會對受影響 day 呼叫 `recomputeTravel`。
`replaceEntryMasterPoi*`、`addEntryAlternate*`、`deleteEntryAlternate` 與 `reorderEntryAlternates` 會送 `entryPoisVersion`（可為 null）對齊後端 POI 關聯 OCC；search-result 版本會把 `PoiSearchResult.category` 映射成後端白名單 `type`,並帶 `place_id`。刪除備選因 DELETE 無 body,以 query string 帶 `entryPoisVersion`;排序 body 使用完整 alternate `poiId` 陣列 `order`（不含 master）。
`EditEntryScreen`、`ChangePoiScreen` 與 `EntryActionScreen` 在 edit/move/POI mutation 收到 409 `STALE_ENTRY` 時會先 `fetchEntry`,再以最新 `version` 或 `entryPoisVersion` retry 同一個使用者操作一次；travel segment edit 收到 `STALE_ENTRY` 時會先 `fetchTripSegments`,用同一 `id` 或同一 from/to pair 的最新 `version` retry 一次；非 stale 錯誤不做自動 retry。
行程筆記 CRUD 第一波由 `fetchNotes` + 5 組 `createTrip*` / `updateTrip*` + `deleteTripNoteRow` 覆蓋。POST/PATCH body 送後端白名單 snake_case 欄位；PATCH 一律帶 notes row `expectedVersion`。`generateTripNotes` 只給行前須知/緊急聯絡用,docType 對齊後端 `tips` / `lodging-tips` / `emergency`,畫面會用回傳的 `requestId` 呼叫 `fetchTripRequest` polling terminal state 後重新整理 notes。
`createEntryFromPoiSearchResult` 是 Explore direct-mode 與 `AddEntryScreen` 搜尋 tab 使用的 fast-path:用搜尋結果建立 day entry,送 `name`、`note`(地址)、`lat`、`lng`、`source: google`、`time` 與映射後的 `poi_type`;成功後畫面會觸發 `recomputeTravel` 更新 travel segments。
`createCustomEntry` 是 `AddEntryScreen` 自訂 tab / `/add-custom-stop` 使用的 map-pin path:送 `name`、`note`、`lat`、`lng`、`source: custom`、`time` 與 `poi_type`;client 會先驗證 title 非空與 lat/lng 範圍,成功後觸發 `recomputeTravel`。
`AddEntryScreen` 收藏 tab 仍走 `addPoiFavoriteToTrip` 的 4-field favorite fast-path,成功後同樣觸發 `recomputeTravel`。

回傳的 model 結構見 [Models 參考](reference-models.md)。

## Riverpod providers(`providers.dart`)

```dart
final sessionStoreProvider   = Provider<SessionStore>((ref) => SecureSessionStore());
final apiClientProvider      = Provider<ApiClient>(...);       // 注入 sessionStoreProvider
final authRepositoryProvider = Provider<AuthRepository>(...);  // 注入 client + store
final tripRepositoryProvider = Provider<TripRepository>(...);  // 注入 client

class AuthNotifier extends AsyncNotifier<UserInfo?> {
  Future<void> login(String email, String password);
  Future<SignupResult?> signup({required String email, required String password, String? displayName, String? invitationToken});
  Future<void> logout();
  Future<UserInfo> updateProfile({String? displayName});
}
final authStateProvider = AsyncNotifierProvider<AuthNotifier, UserInfo?>(AuthNotifier.new);
```

`authStateProvider` 是全 app 的認證狀態 single source of truth:

| 狀態 | 意義 |
|---|---|
| `AsyncData(null)` | 未登入 |
| `AsyncData(UserInfo)` | 已登入 |
| `AsyncLoading` | 啟動時查 `currentUser()` 中,或登入/註冊請求進行中 |
| `AsyncError` | 登入或註冊失敗(`login()`/`signup()` 把例外收進 state,畫面讀此顯示 persistent banner) |

`build()` 即 `currentUser()` — app 啟動時自動以既存 session 驗證登入狀態。`signup()` 成功後會把 `SignupResult` 轉成最小 `UserInfo`,讓 router 立即視為已登入。`updateProfile()` 透過 `TripRepository.updateProfile()` PATCH `/account/profile`,成功後以回傳的 `UserInfo` 直接刷新全域 auth state。router 的 redirect 邏輯依賴此 provider,見[導航參考](reference-navigation.md)。

行程詳情層級的 scoped providers(`tripDetailProvider` 等 family)定義在 `lib/features/trip_detail/trip_providers.dart`,見[架構說明 — trip scope](explanation-architecture.md#trip-scope共用-fetch)。

Trip detail scope 目前包含 `tripDetailProvider`、`tripDaysProvider`、`tripSegmentsProvider`、`entryDetailProvider` 與 `tripNotesProvider`。`TripTimelineScreen` 以 `tripSegmentsProvider` 覆蓋 legacy `TimelineEntry.travel`,segments 載入失敗時保留 days payload fallback 並顯示 persistent banner。

## 相關文件

- [架構說明](explanation-architecture.md) — 認證與 CSRF 設計的「為什麼」
- [Models 參考](reference-models.md) — 各 endpoint 回應的解析規則
- [How to 新增 API endpoint](howto-add-endpoint.md)
- [How to 用 provider override 寫測試](howto-test-with-providers.md)
