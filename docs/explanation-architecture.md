# 架構說明:Tripline Flutter 為什麼長這樣

Tripline Flutter 是 [trip-planner React SPA](https://github.com/raychiutw/trip-planner) 的行動版移植。核心約束只有一條:**後端不動**。同一套 Cloudflare Pages Functions API 同時服務 web 與 app,本 repo 只是另一個 client。這條約束決定了下面大多數設計。

## 分層

```
┌─────────────────────────────────────────────┐
│ features/   畫面與 widget(auth/trips/      │
│             trip_detail/account/shell)     │
├─────────────────────────────────────────────┤
│ app/        go_router(5-tab shell +        │
│             auth redirect)                  │
├─────────────────────────────────────────────┤
│ api/        ApiClient(dio)+ repositories  │
│             + riverpod providers            │
├─────────────────────────────────────────────┤
│ models/     純 Dart immutable class +       │
│             手寫 fromJson                   │
├─────────────────────────────────────────────┤
│ theme/      design tokens + ThemeData +     │
│             TpTones ThemeExtension          │
└─────────────────────────────────────────────┘
```

依賴方向由上往下單向:`features` 用 `app`/`api`/`models`/`theme`;`models` 與 `theme` 不依賴任何人。`models` 不 import Flutter(純 Dart),解析測試可以跑在 VM 不開 widget binding。

## Provider 依賴圖

```
sessionStoreProvider (SecureSessionStore)
        │
        ▼
apiClientProvider (ApiClient + dio)
        │                  │
        ▼                  ▼
authRepositoryProvider   tripRepositoryProvider
        │                  │
        ▼                  ▼
authStateProvider        tripDetailProvider ──┐
(AsyncNotifier,          tripDaysProvider     ├─ family<_, String tripId>
 全 app 認證 SoT)        tripNotesProvider  ──┘
        │
        ▼
appRouterProvider (redirect + refreshListenable)
```

整條鏈的根是 `sessionStoreProvider`。測試只要 override 根節點(或任一中間節點)就能替換整個下游,見 [How to 用 provider override 寫測試](howto-test-with-providers.md)。

## 認證:為什麼是 session cookie 而不是 OAuth Bearer

### 問題

後端認證體系是給瀏覽器設計的:`POST /api/oauth/login` 發 `Set-Cookie: tripline_session`,之後靠 cookie 辨識;CSRF 防護靠檢查 mutating request 的 `Origin` header(allowlist)。OAuth PKCE + Bearer token 流程存在,但需要在後端註冊 public client,而「後端不動」是本案前提。

### 做法

App 自己扮演瀏覽器:

1. 登入時走 raw dio 讀 `set-cookie`,regex 撈出 `tripline_session=<token>`,存 flutter_secure_storage(iOS Keychain / Android Keystore)
2. 之後每個 request 手動帶 `Cookie: tripline_session=<token>`
3. mutating request 手動帶 `Origin: https://trip-planner-dby.pages.dev` — 對後端來說,app 跟正式站網頁長得一模一樣

### 取捨

- ✅ 後端零改動,web/app 行為完全一致(連錯誤 shape 都相同)
- ✅ secure storage 比瀏覽器 cookie jar 更可控
- ❌ 偽造 Origin 是 hack(瀏覽器不允許,native 才做得到);若後端改驗 CSRF token 就會壞
- ❌ session 過期只能重新打密碼,沒有 refresh token 機制
- 之後遷移路徑:P2 註冊 OAuth public client 走 PKCE + Bearer,屆時只需改 `ApiClient` 與 `AuthRepository`,上層無感

## 429 retry:為什麼只 retry GET

後端有 rate limit(`SYS_RATE_LIMIT`)。GET 重試是安全的(冪等);mutation 重試有重複寫入風險 — 例如 DELETE 後 retry 又刪一次、POST retry 建兩筆。所以規則寫死:**429 只 retry GET 一次**(讀 `Retry-After`,cap 30 秒),mutation 一律把錯誤丟給呼叫端決定。web 版 `apiClient.ts` 同樣行為,兩端對齊。

## Trip scope:共用 fetch

web 版的 `TripLayout` 在 layout 層抓一次 trip/days/notes,底下 timeline/map/notes 三個分頁共用。Flutter 版用 riverpod `FutureProvider.family` 達成同一效果(`lib/features/trip_detail/trip_providers.dart`):

```dart
final tripDaysProvider = FutureProvider.family<List<TripDay>, String>((ref, tripId) {
  return ref.watch(tripRepositoryProvider).fetchDays(tripId);
});
```

三個畫面 watch 同一個 family 實例(`tripDaysProvider(tripId)`),riverpod 自動快取:從 timeline 切到 map 不會重新打 API。family 以 `tripId` 為 key,跨行程不互相污染。這正是選 riverpod 而非 Provider/BLoC 的主因 — scoped 共用 fetch 是內建能力,不用自己搭 cache。

## 為什麼手寫 fromJson

server 端 `deepCamel()` 已把回應轉成 camelCase,欄位名 1:1 對應,json_serializable + build_runner 換來的只有 codegen 的建置複雜度。手寫的代價是 boilerplate,風險靠兩件事控制:

1. 通用解析規則(num 轉型、0/1 bool、list 預設)集中文件化於 [Models 參考](reference-models.md#通用解析規則),所有 model 一致
2. 每個 model 都有 fromJson 測試(fixture 對齊後端實際輸出)

## 為什麼 flutter_map(OSM)而不是 google_maps_flutter

免 API key、零帳務設定,個人專案的維運成本最低。已知取捨:OSM tile 風格較陽春、無 Google POI 資料。介面上地圖只在 `TripMapScreen` 一處,之後要換 google_maps_flutter 影響面有限。

## OCC(樂觀並行控制)

`TripDay`/`TimelineEntry`/notes row 都帶 `version` 欄位。後端 PATCH 要求 `expectedVersion`,版本不符回 409 `STALE_ENTRY`,client 應重抓再套用。P0 全唯讀所以尚未用到,但 model 已保留 `version` — P1 做 Entry CRUD 時直接可用。

## 測試策略

TDD,測試分三層(對應 `test/` 鏡像結構;數量以 `flutter test` 輸出為準):

| 層 | 工具 | 驗什麼 |
|---|---|---|
| models | flutter_test(純 VM) | fromJson 解析規則與 edge case(nullable、0/1 bool、num 轉型) |
| api | http_mock_adapter + mocktail | ApiClient 行為規則各一測試、AuthRepository set-cookie 解析 |
| screens | widget test + ProviderScope override | 每個 screen 至少一測試,假 repository 注入 |

完成定義:`flutter analyze` 零 error/warning、`flutter test` 全綠。

## 相關文件

- [API 層參考](reference-api.md)/[Models 參考](reference-models.md)/[導航參考](reference-navigation.md)/[Theme 參考](reference-theme.md)
- [`PORTING_PLAN.md`](PORTING_PLAN.md) — 移植藍圖與 P0/P1/P2 範圍
- [`CONTRACTS.md`](CONTRACTS.md) — 多 agent 平行開發用的模組契約(歷史文件,個別欄位以程式碼為準)
