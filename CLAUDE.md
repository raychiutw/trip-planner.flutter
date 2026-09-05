# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 專案性質

[trip-planner React SPA](https://github.com/raychiutw/trip-planner) 的 iOS/Android 移植版(Flutter)。**後端不動**:共用同一套 Cloudflare Pages Functions API(`https://trip-planner-dby.pages.dev/api`),本 repo 只是另一個 client — 多數設計決策由此約束推導。P0~P2 移植範圍(唯讀畫面 → CRUD → 離線/AI)皆已完成,後續待辦一律在 GitHub Issues。

## 常用指令

```bash
flutter pub get
flutter test                                          # 全部測試
flutter test test/api/api_client_test.dart            # 單檔
flutter test --plain-name "429"                       # 依測試名過濾
flutter analyze                                       # 完成定義:零 error/warning
flutter run                                           # 連 prod API — 一律用測試帳號
```

## 開發流程(強制)

- **一律走 Matt Pocock engineering skill 工作流**:
  - 主線:`/grill-with-docs`(訪談收斂,同時產出 `CONTEXT.md` 詞彙與 `docs/adr/`)→ `/to-spec`(合成 spec 並發成 GitHub Issue,貼 `ready-for-agent`)→ `/to-tickets`(拆成 tracer-bullet 票)→ `/implement`(內部驅動 `/tdd` 一次一個紅綠切片,收尾跑 `/code-review`)。
  - 單一 fresh context 做得完、沒有 blocker、沒有需要另行發布的產品決策，且無有意義垂直切片的小功能，可在 `/grill-with-docs` 確認範圍與測試 seam 後略過 `/to-spec`、`/to-tickets`，直接進入 `/implement`。
  - **步驟 1~3 要在同一個 context window 內完成**,不要中途 compact;接近上限就 `/handoff` 換新 session。每個 `/implement` 開新 context。
  - 分流:bug 用 `/diagnosing-bugs`;外部進來的 issue 用 `/triage`(自己 `/to-tickets` 產的票不要 triage);設計問題需要跑起來才答得出來時用 `/prototype`;範圍大到一個 session 裝不下的用 `/wayfinder`。
  - 忘記該用哪個 skill 就問 `/ask-matt`。
- **寫 `lib/` 的程式碼前先讀 `CODING_STANDARDS.md`** 中相關的節(九節,附行號):它是編碼規範的唯一出處,也是 `/code-review` Standards 軸的主要依據,規則有異動改那裡,本檔只留摘要、衝突時以它為準。UI／UX 在 `DESIGN.md`,詞彙在 `CONTEXT.md`,難逆轉的決策在 `docs/adr/`,貢獻流程在 `CONTRIBUTING.md`。
- **TDD 紅綠重構**:任何 production code 變更先寫失敗測試。修 bug 先寫重現測試。
- **完成定義**:`flutter analyze` 零 error/warning + `flutter test` 全綠。
- **不直接 commit 到 `master`**:開 feature branch → `/ship` 開 PR。base branch 是 `master`(無 `main`)。
- 文件、註解、commit message 一律繁體中文(台灣用語),技術名詞保留英文。

## 架構

分層單向依賴(上層用下層):`features/` → `ui/` → `app/` → `api/` → `models/` → `theme/`。`models/` 是純 Dart(不 import Flutter),`theme/` 不依賴任何人。分層規範與兩個既有例外見 `CODING_STANDARDS.md`「分層與依賴方向」。

### Provider 鏈(riverpod 3.x)

`sessionStoreProvider` → `apiClientProvider` → `authRepositoryProvider`/`tripRepositoryProvider` → `authStateProvider`(全 app 認證 SoT)→ `appRouterProvider`。測試 override 鏈上任一節點即可替換下游。行程詳情的 trip/days/notes 用 `StreamProvider.family<_, String tripId>`(`lib/features/trip_detail/trip_providers.dart:13,17,24`,entry/segments 同款)— timeline/map/notes 三畫面 watch 同一 family 實例共用 fetch(對應 web 版 TripLayout),SWR 先 emit 本機快取再 emit 網路。

注意:flutter_riverpod 3.x 未匯出 `Override` 型別,測試的 overrides 直接以 list literal 傳入 `ProviderScope`。

### 認證(關鍵且非顯而易見)

後端是瀏覽器導向的 session cookie + CSRF Origin allowlist,app 扮演瀏覽器:

- 登入走 `postForResponse` 讀 `set-cookie`,解析 `tripline_session` 後存進 flutter_secure_storage
- Cookie 模式由 `ApiClient` 統一帶 `Cookie:`;**mutating request 必帶 `Origin: kTriplineOrigin`**(缺少 → 403)。origin 是 `String.fromEnvironment('TRIPLINE_API_ORIGIN', ...)`(`lib/api/api_client.dart:21-24`),不得寫死字面值,本機後端靠 `--dart-define` 覆寫
- Bearer 模式(`BearerTokenSource` 有 token)與 cookie 模式互斥:只帶 `Authorization: Bearer <token>`,**不送 Cookie/Origin**(`ApiClient._authHeadersFor`)。兩種 header 都由 `ApiClient` 統一處理,不要繞過它用 raw dio 打 API
- `currentUser()` 401 回 null 不 throw;登入後跳轉靠 router redirect(`refreshListenable` 橋接 authState 變化),LoginScreen 自己不導航

### ApiClient 行為規則(每條有對應測試,改動需同步測試)

1. 非 2xx → throw `ApiError`(三層 fallback 解析,見 `api_error.dart`)
2. 「同參數重送一次」的決策是純函式 `decideRetry`(`lib/api/retry_policy.dart`),`ApiClient._retryDecision` 包一層做等待 / refresh,一般請求與 SSE `_getTextStream` 兩個站點共用,`isRetryAttempt` 限一次;`postForResponse`(登入 / 註冊 raw POST)不重送、只走 `_throwIfFailed` 轉錯誤:429 僅 GET/HEAD(讀 `Retry-After`,cap 30s)、edge block page(2xx 但 `text/html`)同條件、Bearer 401 且 `refresh()` 成功則重送**不分 method**。改重試規則只改 `retry_policy.dart` 一處。「mutation 絕不 retry」是錯的說法
3. 204/空 body → `null`
4. 路徑參數 `Uri.encodeComponent`

### Model 解析規則(所有 fromJson 一致)

wire 是 camelCase(server `deepCamel()`);數字 `(json['x'] as num?)?.toInt()/.toDouble()`(server 可能回 int 或 double);bool flag 是 0/1:`json['x'] == 1 || json['x'] == true`;日期時間存字串不轉 DateTime;list 缺漏 → `[]`;`sortOrder`/`version` 缺漏 → `0`。完整規則與行號見 `CODING_STANDARDS.md`「Model 與 fromJson 解析規則」;無法從程式碼反推的後端行為(兩套 OCC、筆記段名三套字、停留點時間必填、`trips` 表無 `version`)見同檔「API 層規範／後端契約細節」。

### Theme 取色守則

Widget 取色一律走 `Theme.of(context).colorScheme`；柔褐 tint 是唯一品牌強調色，內容 surface 跟隨 iOS 系統語意層級。`TpSystemColorsLight/Dark` 只供 `AppTheme` 工廠建立 Light／Dark／High Contrast 主題，feature 不得直接引用；地圖逐日 pin／route palette 是唯一 rainbow 色例外。設計禁忌：無 gradient 裝飾、無 emoji icon。

### OCC

帶 `version` 的 model:後端 PATCH 要 `expectedVersion`,409 `STALE_ENTRY` 時重抓再套用,離線佇列走三方 rebase(`ApiClient._tryRebase`;決策見 ADR-0007)。行程本身無 `version`,更新走 `PUT /trips/:id` 且不送 `expectedVersion`。

## 測試慣例

三層鏡像 `lib/`:models(純 fromJson + edge case)、api(`http_mock_adapter` + `InMemorySessionStore`,不碰 `SecureSessionStore`)、screens(widget test + `ProviderScope` override,mocktail mock repository,假 GoRouter 當導航探針)。具體手法、provider override 與假綠燈防呆見 `CODING_STANDARDS.md`「測試規範」「測試不可假綠」。

## Agent skills

### Issue tracker

Issues 與 PRD 使用 GitHub Issues（`raychiutw/trip-planner.flutter`），透過 `gh` CLI 操作。詳見 `docs/agents/issue-tracker.md`。

### Triage labels

使用預設五種 triage labels：`needs-triage`、`needs-info`、`ready-for-agent`、`ready-for-human`、`wontfix`。詳見 `docs/agents/triage-labels.md`。

### Domain docs

採 single-context 架構。根目錄 `CONTEXT.md` 是**詞彙表**(只定義語彙,不寫實作細節),由 `/grill-with-docs` 驅動的 `/domain-modeling` 隨討論即時更新;`docs/adr/` 按需建立,只有「難以逆轉 + 沒 context 會困惑 + 真實 trade-off」三者皆備才開。詳見 `docs/agents/domain.md`。
