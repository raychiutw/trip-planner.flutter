# 貢獻指南

個人專案,但流程照團隊標準走。讀完這頁就能開工。

**本頁是 `code-review` Standards 軸的主要依據** —— 審查程式碼是否符合本 repo 規範時以本頁條文為準,不要只讀連結。UI 變更另須一併讀取根目錄 [`DESIGN.md`](DESIGN.md),見〈UI 規範〉。領域詞彙見 [`CONTEXT.md`](CONTEXT.md);架構決策的理由與被拒方案見 [`docs/adr/`](docs/adr)。

## 環境

```bash
flutter --version    # 發布工具鏈使用 Flutter 3.44.7 / Dart 3.12.2(pubspec: sdk ^3.11.3)
flutter pub get
flutter test         # 全綠才算環境就緒;數量以當次輸出為準
```

### 指向本機後端

預設連正式站 `https://trip-planner-dby.pages.dev`。**連 prod 時破壞性操作(刪除等)會真的打到正式資料** —— 測破壞性流程一律先改指本機後端,或使用測試帳號。

用 `--dart-define` 覆寫 origin(值是 origin,**不含** `/api`;app 會自動補 `/api`,並用同一個 origin 當 CSRF `Origin` header):

```bash
flutter run --dart-define=TRIPLINE_API_ORIGIN=http://localhost:8787
```

多個 define 可重複加旗標,或用 `--dart-define-from-file`。本機後端的 CSRF allowlist 必須允許你傳入的 origin。

驗證覆寫真的生效:

```bash
flutter test --dart-define=TRIPLINE_API_ORIGIN=https://example.test \
  test/api/api_client_test.dart
```

`dart-define TRIPLINE_API_ORIGIN` group 的測試在帶旗標時會真正斷言 `kTriplineOrigin` 已變成注入值,未帶旗標時是 no-op。

## 開發流程

1. **開 feature branch** — 不直接 commit 到 `master`(base branch 是 `master`,無 `main`)
2. **TDD 紅綠重構** — 任何 production code 變更先寫失敗測試;修 bug 先寫重現測試。見〈測試規範〉與〈測試不可假綠〉
3. **完成定義** — `flutter analyze` 零 error/warning、`flutter test` 全綠、新增 public class/method 有 `///` 文件註解
4. **開 PR** — commit message 與 PR 一律繁體中文(台灣用語),技術名詞保留英文
5. **同步文件** — 規範變更改本頁;難以逆轉且有真實被拒方案的決策開 ADR;領域詞彙進 `CONTEXT.md`;使用者可感知的變更補進 `CHANGELOG.md` 的 `[Unreleased]`

**待辦、規格與 PRD 一律走 GitHub Issues**,不用檔案追蹤。完整的 agent 工作流規定見 [`CLAUDE.md`](CLAUDE.md) 與 [`AGENTS.md`](AGENTS.md)。


## 分層與依賴方向

單向依賴鏈（上層可用下層，反向禁止）：

```
features/ → ui/ → app/ → api/ → models/ → theme/
```

> 註:`AGENTS.md` 與 `CLAUDE.md` 早期版本的依賴鏈漏了 `lib/ui/`(`Tp*` 共用 widget,11 個檔),以本節為準。

規則：

- 新增 import 前先確認方向。下層檔案出現指向上層目錄的 `import '../<上層>/...'` 一律退回。
- `models/` 是純 Dart：`lib/models/` 內**不得出現任何 `package:flutter` import**（含 `flutter_riverpod`、`flutter_secure_storage`）。目前實測零命中，這條是硬邊界。
- `theme/` 不依賴專案內任何其他層。只允許 `package:flutter/material.dart` 與 theme 內部互引（`lib/theme/app_theme.dart:1,3`、`lib/theme/tokens.dart:1`）。
- `api/` 不得 import `package:flutter/*`（無 widget、無 `BuildContext`）。允許的 Flutter 生態套件僅限 `flutter_riverpod`（`lib/api/providers.dart:4`）與 `flutter_secure_storage`（`lib/api/session_store.dart:4`、`lib/api/settings_store.dart:4`、`lib/api/oauth/oauth_token_store.dart:6`）。PR 若在 `api/` 引入 `material.dart` 即違反。
- `ui/` 的 widget 不得 import `features/`。共用 widget 需要資料時由呼叫端以參數傳入，不自行 watch feature provider。

### `lib/api/cache/` 的位置

- `api/cache/` 是 `api/` 的**內部子層**，不是獨立一層。整個目錄零 `package:flutter` import。
- 上層取用快取只走兩個入口：`cacheStoreProvider`（`lib/api/providers.dart:31`）與 `ApiClient`（`lib/api/providers.dart:33-43`）。
- `features/` 只可 import 抽象介面 `api/cache/cache_store.dart`（現況：`lib/features/offline/conflict_resolve_sheet.dart:7`、`lib/features/offline/offline_sync.dart:8`）。**不得 import 具體實作** `drift_cache_store.dart` / `sembast_cache_store.dart` / `optimistic_patchers.dart` / `rebase_merge.dart`。具體實作只在 `lib/main.dart:79-100` 被組裝並 override 進 `cacheStoreProvider`。

### 兩個既有例外（不得擴大）

- `lib/app/router.dart` 是唯一允許 import `features/` 的 `app/` 檔（composition root，需要 27 個 screen 建路由表；`lib/app/router.dart:10,21`）。新增其他 `app/` 檔 import `features/` 一律退回。
- `ui/` 對 `app/` 的唯一允許依賴是 `app/accessibility_scope.dart`（`lib/ui/tp_glass_surface.dart:4`、`lib/ui/tp_horizontal_selector.dart:7`、`lib/ui/tp_root_scaffold.dart:6`）。`ui/` import 任何其他 `app/` 檔即違反。反向 `lib/app/adaptive.dart:15-17` import `ui/` 則符合鏈方向。

## Provider 與測試 seam

### Provider 鏈

`sessionStoreProvider`（`lib/api/providers.dart:22`）／`cacheStoreProvider`（同檔 `:31`）→ `apiClientProvider`（`:33`）→ `authRepositoryProvider`（`:45`）／`tripRepositoryProvider`（`:52`）／其餘 repository（`:56-74`）→ `authStateProvider`（`:156`，全 app 認證 SoT）→ `appRouterProvider`（`lib/app/router.dart:44`，經 `refreshListenable` 橋接 authState 變化，`lib/app/router.dart:52,58`）。

- 測試 override 鏈上任一節點即可替換全部下游。**優先 override 最靠近被測畫面的那一節**：測 screen override repository provider，不要 override `apiClientProvider` 再去 mock HTTP。
- production code 不得為了「方便測試」新增 provider。既有節點已足夠當 seam。

### 行程詳情 family

- `trip`／`days`／`notes`／`entry`／`segments` 一律用 **`StreamProvider.family`**，不是 `FutureProvider.family`（`lib/features/trip_detail/trip_providers.dart:13,17,24,33,43`）。
  > 修正：`AGENTS.md:89` 寫成 `FutureProvider.family` 是過期敘述。改 `StreamProvider` 是為了 SWR 兩段式發射（stale → fresh，見同檔 `:10-12` 註解），改回 `FutureProvider` 會直接砍掉離線 stale 那一段。測試對應寫法是 `Stream.error(...)` / `Stream.value(...)`（`test/features/favorites/favorites_screen_test.dart:449-452`）。
- timeline／map／notes 三畫面 watch **同一個 family 實例**共用 fetch：`trip_timeline_screen.dart:209-210`、`trip_map_screen.dart:129`、`trip_notes_screen.dart:141`。新畫面要行程資料時 watch 既有 family，**不得自行呼叫 `tripRepository.fetch*` 重打 API**。
- 寫入後刷新一律 `ref.invalidate(tripXxxProvider(tripId))`，不是重呼叫 repository（範例：`lib/features/chat/chat_controller.dart:319-321`、`lib/features/trips/edit/edit_trip_controller.dart:244-245`）。

### family Notifier 的參數注入

- family Notifier 取自身參數走 **constructor 注入**：`ChatController(this.tripId)` + `NotifierProvider.autoDispose.family<ChatController, ChatState, String>(ChatController.new)`（`lib/features/chat/chat_controller.dart:79-82,327-328`；另見 `lib/features/trips/collab/collab_controller.dart:80-81,217-218`）。
- **禁止 `ref.$arg`**。它是 `@internal`，會噴 `invalid_use_of_internal_member` warning，直接違反「`flutter analyze` 零 error／warning」的完成定義。
  > `lib/` 與 `test/` 全域 grep `$arg` 零命中,規則目前無違反者。

### 測試 seam 寫法

- **overrides 一律以 list literal inline 傳入 `ProviderScope`**：`overrides: [xxxProvider.overrideWithValue(mock)]`。flutter_riverpod 3.x 未匯出 `Override` 型別，不得宣告 `List<Override> overrides = ...` 抽成變數。實測全 repo 零 `List<Override>` / `<Override>[`。
- **測 provider error state 必須關掉自動重試**：`ProviderScope(retry: (retryCount, error) => null, overrides: [...], child: ...)`。少了它，error 態會被自動重試蓋掉而 flake。
  範例：`test/features/trips/collab/collab_screen_test.dart:34`、`test/features/favorites/favorites_screen_test.dart:446`、`test/features/trip_detail/trip_timeline_screen_test.dart:294`（全 repo 現有 17 處）。
- 只 override 到 repository 層，`api/` 測試用 `http_mock_adapter` + `InMemorySessionStore`，不碰 `SecureSessionStore`。

## API 層規範

### ApiClient 是唯一出口

- 所有 HTTP 存取一律走 `ApiClient` 的方法（`get` / `post` / `put` / `patch` / `delete` / `sendMutation` / `postForResponse` / `postForRedirect` / `getTextStream`）。不得用 `client.dio` 自己發 request —— 繞過去就同時失去 Cookie／Bearer／Origin、錯誤轉換、重試與快取。
- 只有需要 Dio 原生 request options 的 OAuth PKCE 流程可取 `client.dio`；需要讀 response headers（例如登入解 `set-cookie`）用 `postForResponse`（`lib/api/api_client.dart:106`），不是 raw dio。

### 認證 header：兩種模式互斥

`_authHeadersFor()`（`lib/api/api_client.dart:946-968`）依有無 Bearer token 二選一，repository 與畫面層都不得自己拼這些 header：

- **Bearer 模式**（`BearerTokenSource` 回非空 token）：只帶 `Authorization: Bearer <token>`，**不送 `Cookie`、不送 `Origin`**（後端對「有 Bearer 且無 Origin」跳過 CSRF 檢查）。
- **cookie 模式**（無 token）：`sessionStore` 有值才帶 `Cookie: tripline_session=<token>`；且方法非 `GET`／`HEAD` 時必帶 `Origin: <origin>` —— 缺這個 header 的 mutation 後端回 403。


### origin 常數

- `kTriplineOrigin` 是 `String.fromEnvironment('TRIPLINE_API_ORIGIN', defaultValue: 'https://trip-planner-dby.pages.dev')`（`lib/api/api_client.dart:21-24`）。不得改回字面常數，本機後端靠 `--dart-define` 覆寫。
- 一個 origin 同時決定 base URL（`'$origin/api'`，`lib/api/api_client.dart:78`）與 CSRF `Origin` header，不可分別設定。
- origin 必須是純 origin：不含 `/api` 路徑、無結尾斜線（有測試守：`test/api/api_client_test.dart:430`）。


### 重試：三條分支共用「同參數重送一次」

`_send()` 的三種重送共用同一個 `retry()`（`lib/api/api_client.dart:795-806`），每條都靠 `isRetryAttempt` 限制**最多一次**：

1. **429** — 僅 `GET`／`HEAD`（`lib/api/api_client.dart:794`、`:807-815`）。讀 `Retry-After` 等待後重送一次。
2. **edge block page** — 2xx（非 204）但 `Content-Type` 含 `text/html` 視為 CDN 攔截頁（`lib/api/api_client.dart:723-733`），重試條件與 429 完全相同（同一個 `if`，`:807`）。重送後仍是 block page → 丟 `ApiError(code: 'SYS_UPSTREAM_UNAVAILABLE')`，`status` 是原本那個 2xx（`lib/api/api_client.dart:735-739`、`:827-829`）。
3. **Bearer 401** — `auth.useBearer` 且 `_bearerSource.refresh()` 回 true 才重送，**不分 method**：`POST`／`PATCH`／`DELETE` 一樣會被重送一次（`lib/api/api_client.dart:816-823`）。`refresh()` 回 false → 直接丟 `ApiError(401)`（`test/api/api_client_bearer_test.dart:87`）。

- SSE 串流版 `_getTextStream()` 走同一組規則（`lib/api/api_client.dart:884-911`），改重試邏輯要兩處一起改。
- 429／edge block **不重送 mutation**（`test/api/api_client_test.dart:228`、`:358`）；Bearer 401 refresh 則會。「mutation 絕不 retry」是錯的說法，不要寫進註解或文件。
- 離線佇列重播**不是** retry：只有帶 `OfflineOp` 的 mutation 才進佇列（`lib/api/api_client.dart:265-275`），重連後由 `flushQueue` 依序重送。
- `parseRetryAfterSeconds`：delta-seconds 或 HTTP-date，一律 clamp 0–30 秒；缺漏／空／無效值回 1（`lib/api/api_client.dart:702-721`）。
- 動到任何一條重試分支，同一個 PR 必須改 `test/api/api_client_test.dart` 或 `test/api/api_client_bearer_test.dart`。

> **注意常見誤述**:「429 只 retry GET 一次;mutation 絕不 retry」是錯的說法,曾出現在多份舊文件裡。它漏了 edge block page 與 Bearer 401 兩條分支,且與 `lib/api/api_client.dart:816-823` 矛盾。看到這句話出現在註解或 PR 描述裡,以本節為準。

### 錯誤與空 body

- dio 的 `validateStatus` 全收，狀態碼判斷集中在 `_send()`（`lib/api/api_client.dart:79-80`）。不要在別處加 `validateStatus`。
- 非 2xx 一律 `throw ApiError.fromResponse(...)`（`lib/api/api_client.dart:824-826`）。repository 不得吞掉例外改回 `null`（唯一例外見下方 `currentUser()`）。
- `ApiError.fromResponse` 三層 fallback（`lib/api/api_error.dart:27-62`），依序：
  1. `{error: {code, message, detail}}` → 取 `code`／`message`／`detail`
  2. `{error: "字串", error_description: "..."}`（OAuth flat shape）→ `error` 當 code、`error_description` 當 message
  3. 都不符 → `code = 'HTTP_<status>'`、`message = 'HTTP <status>'`
- `detail` 一律截斷到 200 字（`lib/api/api_error.dart:64-67`）。原始 body 保留在 `payload`，`409` 的 `conflictWith` 等結構化資訊從 `payload` 取（`lib/api/api_error.dart:21-22`）。
- 204 與空 body（`null` 或空字串）一律回 `null`（`lib/api/api_client.dart:830-861`）。呼叫端回傳型別寫 `Future<void>` 或自行判 null，不得無條件 `as Map<String, dynamic>`。
- GET 遇連線層失敗（離線／逾時）且有本機快取時回快取而不丟（`lib/api/api_client.dart:777-789`）。因此「拿到資料」不代表這次連上了網 —— 需要保證新鮮度的 GET 要傳 `fallbackToCache: false`（例：`lib/api/trip_repository.dart:194-199`）。

### repository 方法

- 每個 public 方法的 `///` 第一行必須寫出 HTTP method 與路徑，含關鍵約束（例：`lib/api/trip_repository.dart:151`、`:370`、`:385`）。沒有這行的新方法不予通過。
- 路徑參數一律 `Uri.encodeComponent`（`lib/api/trip_repository.dart:153`、`:376`、`:395`）；`dayNum`／`rowId`／`entryId` 這類 int 直接插值。
- `currentUser()` 遇 401 回 `null` 不 throw，其他狀態 rethrow（`lib/api/auth_repository.dart:249-257`）。這是唯一允許把 401 轉成 `null` 的方法，不要複製到別處。
- repository 不得自帶 `Origin`／`Cookie`／`Authorization`。
- 新增 endpoint 走 TDD：先 model 測試（紅）→ model（綠）→ repository 測試（`http_mock_adapter`）→ repository 方法。

### 後端契約細節

以下四條後端行為在程式碼裡只以註解存在，改動前先讀完：

- **兩套 OCC 不可混用。** `entryPoisVersion` 是 **string**，server 一律字串化，client 用 `.toString()` 收（`lib/models/entry.dart:151`），送出時是 `String?`（`lib/api/trip_repository.dart:793-797`），用於 master／alternates 的 POI 結構操作。`expectedVersion` 是 **number**，用於 entry meta、notes、segments 的 row-level OCC（`lib/api/trip_repository.dart:466-473`、`:623-636`）。不要把其中一個塞進另一個的位置。
- **筆記段名有兩套字。** `pretrip`／`emergency` 是 CRUD 的 **URL 段**（`NoteSection.name`，`lib/api/trip_repository.dart:376`、`:395`），但聚合 `GET /trips/:id/notes` 的 **response key 是 `pretripNotes`／`emergencyContacts`**（`lib/models/note_section.dart:1-2`、`lib/api/trip_repository.dart:81-86`）。離線樂觀 patch 打 response key，發 request 打 URL 段。另有第三套 `NoteGenerationType.pathSegment`（`tips`／`lodging-tips`／`emergency`）給 AI 生成與排除清單用（`lib/models/note_section.dart:25-29`、`lib/api/trip_repository.dart:446`、`:486`），三套互不相通。
- **停留點的 `startTime`／`endTime` 送空字串會 400。** 後端強制必填 `"HH:MM"`，web 型別標成選填是陷阱。加入行程的路徑一律宣告成 `required String`（`lib/api/favorites_repository.dart:43-57`）；沒有時間就不要送這個 request，別送 `''`。
- **`trips` 表無 `version` 欄位。** 更新行程走 **`PUT /trips/:id`**（不是 PATCH），diff-only 只送非 null 欄位，**不要送 `expectedVersion`**，衝突語意是 last-write-wins（`lib/api/trip_repository.dart:151-178`）。`destinations` 有給才全量替換：給 `[]` 是清空，不給是不動。

> 這四條原本散落在數份已刪除的舊文件裡,是後端行為的一手考證,無法從本 repo 的程式碼反推。上面每一條都已重新對 `lib/` 驗證並附行號。

## Model 與 fromJson 解析規則

- **手寫 immutable class**：`const` 建構子 + named 參數 + `factory X.fromJson(Map<String, dynamic> json)`。**model 的 JSON 解析不引入 codegen**（ADR-0013，`docs/adr/0013-hand-written-fromjson-no-codegen.md`）。repo 確實有 `build_runner`／`drift_dev`，但只服務 drift 快取層，全 repo 唯一產生檔是 `lib/api/cache/drift_cache_store.g.dart` —— 不要據此把 `json_serializable` 引進 `lib/models/`。
- `lib/models/` 是純 Dart，不得 import `package:flutter/*`；`fromJson` 內不得做 I/O 或非同步。
- **直接讀 camelCase key**（server `deepCamel()` 已轉），不做 snake_case 轉換。既有例外只有兩處：`lib/models/entry.dart:31`（`distanceM ?? distance_m`）、`lib/models/day.dart:89`、`:91`（`dayNum`／`day_num`、`dayOfWeek`／`day_of_week`）。新欄位不得再加 fallback；要加就要在 PR 說明後端為何沒轉。
- **數字一律經 `num`**：`(json['x'] as num?)?.toInt()` / `?.toDouble()`（`lib/models/entry.dart:30`、`:78-79`、`:89`）；必填數字用 `(json['id'] as num).toInt()`（`lib/models/entry.dart:141`）。出現 `as int` / `as double` 直接視為違反 —— server 同一欄位可能回 int 也可能回 double。
- **bool flag 接受 0/1 或 bool**：`json['x'] == 1 || json['x'] == true`（`lib/models/entry.dart:33`）。寫成 `json['x'] as bool?` 會永遠 false。
- **日期時間一律存字串，不轉 `DateTime`**，顯示層要用再 parse。實際格式：停留點 `startTime`／`endTime` 是 `"HH:MM"`（`lib/models/entry.dart:118-120`）、day `date` 是 `"YYYY-MM-DD"`（`lib/models/day.dart:69-70`）、航班 `departAt`／`arriveAt` 是 ISO8601 local datetime 字串、`createdAt`／`updatedAt` 是 `"YYYY-MM-DD HH:MM:SS"`（UTC）。唯一 epoch 例外是移動段的 `computedAt`／`updatedAt`（int）。
- **list 欄位缺漏 → `[]`**：`(json['xs'] as List<dynamic>? ?? []).map(...).toList()`（`lib/models/entry.dart:156`、`lib/models/day.dart:98`）。
- **`sortOrder`／`version` 缺漏 → `0`**：`(json['sortOrder'] as num?)?.toInt() ?? 0`（`lib/models/entry.dart:143`、`:150`、`lib/models/day.dart:94`）。
- **enum 用 top-level `parseX(String?)` 解析，未知字串走安全預設，絕不 throw**。安全 = 偏向「還沒結束、繼續觀察」：
  - `parseTripNoteAiJobStatus` 未知 → `pending`（`lib/models/notes.dart:392-399`），不誤判為終止狀態。
  - `parseRequestStatus` 未知 → `processing`（`lib/models/trip_request.dart:7-12`），工單續 poll。
  - `parseNoteGenerationType` 未知 → `null`（`lib/models/note_section.dart:15-20`）。
- 衍生欄位可以在 `fromJson` 內算，但 fallback 鏈要寫成註解可讀：停留點 `title` = `displayTitle` → 正選 POI 名稱 → `（未選擇景點）`（`lib/models/entry.dart:136-139`）。
- **帶 `version` 的 model 走 OCC**：PATCH 必帶 `expectedVersion`（`lib/api/trip_repository.dart:623-636`）；409 `STALE_ENTRY` 時重抓 server 真相再套用，離線佇列的三方 rebase 走 `_tryRebase`（`lib/api/api_client.dart:541-575`），`expectedVersion` 在 rebase 時永遠保留並換成新值（`lib/api/api_client.dart:690-700`）。行程本身無 version，見上方後端契約細節。
- 每個新 model 至少一個 `fromJson` 測試，且必須含 edge case：欄位缺漏、int↔double、0/1 bool。fixture 用後端實際輸出，不要用猜的。

## 畫面撰寫規範

適用 `lib/features/**` 下所有 screen 與其私有 widget。

### Widget 型別與資料狀態

- 無本地 state 的畫面用 `ConsumerWidget`；有表單、`TextEditingController`、`ScrollController`、動畫或任何 `dispose` 需求的用 `ConsumerStatefulWidget`。目前 `lib/features/` 有 9 個 `ConsumerWidget`、37 個 `ConsumerStatefulWidget`，兩者都是常態，判準是「有沒有需要釋放的物件」，不是畫面大小。
- 所有 async 資料一律 `ref.watch(xxxProvider).when(data:, error:, loading:)`，三態都要有實體 UI，不得省略任一分支或用 `.value ?? fallback` 繞過。
- error 態必須提供 retry 入口，且 retry 動作要真的重抓資料。參考 `lib/features/trips/trips_list_screen.dart:452` 的 `_ErrorState(onRetry: () => ref.invalidate(myTripsProvider))`，元件本體在同檔 `:752`。只印錯誤字串沒有按鈕視為違反。
- loading 態用 `AppListLoadingSkeleton`（`lib/app/app_loading_skeleton.dart:6`）保留版型；不得只留空白或在頁面中央放單一 spinner。

### 取色與視覺階層

- Widget 取色只走 `Theme.of(context).colorScheme`。
- **不得直接引用 `TpSystemColorsLight` / `TpSystemColorsDark`**（`lib/theme/tokens.dart:4`、`:37`）。這兩組常數只供 `AppTheme` 工廠建立 Light／Dark／High Contrast 三套主題（`lib/theme/app_theme.dart:14-16`）。
- 柔褐 tint 是唯一品牌強調色，且**只上前景** —— 文字、字符、選取指示。不得把 tint 畫成框線或選取膠囊的底色；膠囊本身走中性語意層，tint 上在字符與標籤。
- 唯一的 rainbow 例外是地圖逐日 pin／route 的 `kDayPinPalette`（`lib/features/map/map_style.dart:16`），取色一律經 `dayPinColor(dayNum)`（同檔 `:34`），不得自行 index。這是資料視覺化，不是 UI 分類色 —— 停留點卡片、收藏、設定列都不得靠彩色分類。
- 顏色不得是唯一資訊來源。階層用字重、留白與 separator 建立。
- 無 gradient 裝飾、無 emoji icon。

### 版面與寬度

- 依內容角色以 `AppAdaptiveContent`（`lib/app/adaptive_content.dart:18`）限寬，常數在同檔 `:5`：
  - `AppContentWidth.authCard`（`420`）—— shell 外的登入／註冊／密碼復原卡片
  - `AppContentWidth.form`（`720`）—— 表單、設定、共編、異動紀錄
  - `AppContentWidth.conversation`（`860`）—— 聊天與搜尋結果
  - `AppContentWidth.feed`（`920`）—— 卡片流
- 手機自然維持全寬，不需另外分支。畫面在寬螢幕撐滿全寬 = 沒包 `AppAdaptiveContent`。
- 根頁底部淨空一律用 `TpRootTabGeometry.clearance(context)`（`lib/theme/tokens.dart:113`），不得寫 magic number。root 捲動用 `TpRootScrollView`（`lib/ui/tp_root_scaffold.dart:237`）時它已經自己補了底部 inset（同檔 `:316`），不要再加一層。
- 最小 tap target `TpSpacing.tapMin`（`44`，`lib/theme/tokens.dart:88`）。icon-only 的 bar button 與列上動作必須有 `tooltip` 或 semantics label。

### 共用元件邊界

- 確認框、action sheet、搜尋列、日期／時間選擇、短暫通知一律重用 `lib/app/adaptive.dart`，不得在 feature 內重寫平台判斷。
- `lib/features/**` 不得出現 `showModalBottomSheet`、`showCupertinoModalPopup`、`showGeneralDialog`、`showAppLargeSheet`、`showAppLargeScreenSheet`。守門測試在 `test/ui/shared_ui_usage_test.dart:44`；`lib/` 全域只有 `lib/app/adaptive.dart` 可以呼叫這三個平台 API（同檔 `:65`）。
- feature 不得直接建 `AppBar` / `SliverAppBar` / `GlassAppBar`；標題與動作幾何來自 `TpRootScaffold`（浮動 header）或 `TpAppBar`（固定 bar）。守門測試 `test/ui/shared_ui_usage_test.dart:6`，唯一豁免是 `lib/features/auth/welcome_screen.dart`。
- 破壞性確認一律經 `showAppDestructiveConfirm`（`lib/app/adaptive.dart:247`），不得自己組 `showAppConfirm`。`source` 參數是必填且有語意：
  - `TpDestructiveConfirmSource.menu` —— 從 `TpMoreMenuButton`（`lib/ui/tp_app_bar.dart:720`）選單選中，確認走 action sheet
  - `TpDestructiveConfirmSource.direct` —— 左滑刪除、列上按鈕這類直接觸發，確認走 alert
  - 同一個動作同時掛在選單與左滑上時，`source` 由呼叫端各自傳，不得在 helper 內寫死（`lib/app/irreversible_action.dart:12`）
- 不可復原的動作（刪除行程、Day、停留點、筆記、分享連結）用 `confirmAndRunIrreversibleAction`（`lib/app/irreversible_action.dart:14`）或 `confirmAndDelete`（同檔 `:87`），它們一併處理執行中鎖定、成功通知與可重試失敗。
- 內容卡用 `TpContentSurface`（`lib/ui/tp_content_surface.dart:5`）。

### 通知與錯誤

- 成功／低風險結果用 `showAppNotice`（`lib/app/adaptive.dart:1135`）—— 頂部橫幅，約 2.5 秒自動消失，沒有動作按鈕。
- 真正的錯誤用 `showAppError`（`lib/app/app_feedback.dart:4`）—— 持續留在畫面上直到使用者關閉或重試。可恢復的錯誤必須傳 `onRetry`。
- 不得用 `showAppNotice` 或裸 `SnackBar` 報錯誤（一閃就消失）。`allowDismiss: false` 時必須同時給 `onRetry`，否則觸發 assert（`lib/app/app_feedback.dart:11`）。

### 字體與溢位

- 不指定 `fontFamily`，沿用平台系統字、Theme 的 HIG 字階與 Dynamic Type。
- **不得以縮小字級處理溢位**。改用截行、換行或重排版面。
- 中文 `letterSpacing` 固定 `0`。全 App 不提供 Large Title。

### 路由與測試

- 掛路由改 `lib/app/router.dart`。行程子頁掛在 `/trips` branch 的 `:tripId` 底下（`lib/app/router.dart:354`），新增子頁照 `entries/new`（`:393`）、`notes`（`:369`）的寫法，path 參數從 `state.pathParameters` 取並以 `Uri.encodeComponent` 編碼。
- shell 外的整頁（無 root tab bar）加在 `routes` 頂層、`StatefulShellRoute` 之外。
- 未登入時 shell 內的頁自動被 redirect 到 **`/welcome`**（`lib/app/router.dart:72-74`，經 `_welcomeLocationWithRedirect`），不是 `/login`。原始請求路徑會保存在 `redirect_after` query。shell 外的新頁若要公開，必須加進 `_publicShellOutsideRoutes`（`lib/app/router.dart:495`），否則同樣被踢到 `/welcome`。
- widget test 必須 override `authStateProvider`，否則啟動時 `currentUser()` 走真 `SecureSessionStore` 失敗，畫面一進來就被視為未登入。
- 每個 screen 檔頭加 `///` library doc 說明畫面職責，格式照 `lib/app/router.dart:1-2`。

---

## 導覽玻璃與鍵盤

適用 `lib/ui/tp_glass_surface.dart`、`lib/ui/tp_app_bar.dart`、`lib/ui/tp_root_scaffold.dart` 與任何會碰到玻璃或輸入欄位的畫面。

### 對比

- 導覽玻璃上的 15–17pt 文字（`titleLarge` 17 / `titleMedium`、`bodyLarge` 15）必須對**實際合成後**的背景達 4.5:1，不是對 token 的名目色。玻璃是半透明的，底下捲什麼過去就合成什麼。
- 100% 與 200% Dynamic Type 兩種字級都要驗；驗收方式是拿高對比黑白內容捲過浮動 header，確認下層字詞不可辨識且前景仍達 4.5:1。
- `Increase Contrast` 或 `Reduce Transparency` 任一開啟時，玻璃收斂為接近不透明的系統背景：`tpResolveGlassSettings`（`lib/ui/tp_glass_surface.dart:10`）把 `glassColor`、`backerColor`、`platformViewFallbackColor` 全設成 alpha `1` 的 surface，並把 `thickness`／`blur`／`chromaticAberration`／`lightIntensity`／`ambientStrength`／`ambientRim`／`glowIntensity`／`shadowElevation` 歸零。新增材質參數時必須一併歸零，漏一個就是 fallback 仍帶材質。
- 一般模式不描邊；只有 `Increase Contrast` 才補實心邊（`tpGlassEdgeColor`，`lib/ui/tp_glass_surface.dart:118`）。

### 材質語意

- 導覽材質只有兩種語意，由 `TpNavigationGlassRecipe`（`lib/ui/tp_glass_surface.dart:6`）表達：
  - `regular` —— 底下是文字內容
  - `platformView` —— 底下是平台視圖（地圖圖磚），走媒體暗化層
- **alpha 只能住在 `tpNavigationGlassSettings`**（`lib/ui/tp_glass_surface.dart:181`）。feature 與各 chrome 元件不得自己 `LiquidGlassSettings(...)`。守門測試 `test/ui/shared_ui_usage_test.dart:97` 斷言 `lib/ui/tp_app_bar.dart`、`lib/features/shell/apple_root_tab_bar.dart`、`lib/ui/tp_root_scaffold.dart`、`lib/ui/tp_horizontal_selector.dart` 四處都必須含 `tpNavigationGlassSettings(` 且不得含 `LiquidGlassSettings(`。
- `platformViewBackdrop` 只表示「底下是平台視圖」的相容合成路徑（`lib/ui/tp_glass_surface.dart:209`、`:240`、`:268`），它決定 backdrop 怎麼合成與要不要上暗化層 —— **不代表「內容是不是文字」**，也不是可讀性的開關。判準是底層 widget，不是內容型別：地圖分頁的 root tab bar 傳 `selectedIndex == 2`（`lib/features/shell/apple_root_tab_bar.dart:224`）、行程地圖傳 `true`（`lib/features/trip_detail/trip_map_screen.dart:142`）、bottom accessory 傳 `true`（`lib/ui/tp_bottom_accessory.dart:34`）。
- 玻璃上的字符與文字走 `tpBarForeground(context, onMedia:)`（`lib/ui/tp_glass_surface.dart:51`），**不得用 app 的明暗模式判斷** —— 地圖圖磚在深色模式下仍是亮的。
- 玻璃只用於功能層：root tab bar、浮動 header、bottom accessory、sheet、選單。內容層一律實色 grouped surface。停留點卡、備選 POI 卡、設定 group 不套 glass。不得 glass 內巢狀 glass。

### 鍵盤

- 單一政策，不建立每頁專屬 helper：
  1. 可捲動的表單與搜尋結果設 `keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag`。
  2. tap-outside 收合由 app root 的 `AppKeyboardDismissRegion`（`lib/app/adaptive.dart:21`）統一提供，掛在 `MaterialApp.router` 的 `builder`（`lib/main.dart:163`）。
  3. 欄位附屬的清除、麥克風、送出、日期／時間按鈕用 `TextFieldTapRegion` 包住，避免點控制項時先誤收鍵盤（現有唯一實例：聊天 composer，`lib/features/chat/chat_screen.dart:1000`）。
- **feature 不得再包一層 `AppKeyboardDismissRegion`** —— root 已經包了，重複包會疊出兩層 gesture listener。同理，root 捲動走 `TpRootScrollView` 的畫面不必自己設 `onDrag`，它已經設了（`lib/ui/tp_root_scaffold.dart:310`）；只有不屬於這些共用容器的捲動視圖才在 feature 層自己設（如 `lib/features/trip_detail/widgets/entry_edit_sheet.dart:579`）。
- 收鍵盤**只准做一件事：`unfocus()`**。不得清空文字、觸發 submit、改 dirty state、關閉 sheet 或取消進行中的 request。實作是 `intent.focusNode.unfocus()`（`lib/app/adaptive.dart:33`）與 `FocusManager.instance.primaryFocus?.unfocus()`（同檔 `:41`），且 `ScrollStartNotification` 回傳 `false` 不吞通知。
- 拖曳才收，不是任何捲動都收：`notification.dragDetails != null` 才 unfocus（`lib/app/adaptive.dart:39`）—— 程式化捲動（scroll-to-day、scroll-to-top）不得收鍵盤。
- 聊天草稿屬於行程，收鍵盤與切走再切回都要恢復。

---

### 來源文件修正紀錄

以下是**容易寫錯的實際值**與**既有債**,全部對程式碼驗證過。舊文件曾就這幾項給出相反或過時的說法,以本節為準：

- **`PlaceholderScreen`**—— 全 repo 無此符號。四個 branch 現在都直接掛真 screen（`lib/app/router.dart:333-487`）。整條「換掉 placeholder tab」步驟已剔除。
- **`AppMapLoadingSkeleton`**—— 不存在。`lib/app/app_loading_skeleton.dart` 只有 `AppListLoadingSkeleton`（`:6`）。已改為只提後者。
- **未登入導向 `/login`**—— 實際導向 `/welcome`（`lib/app/router.dart:72-74`），並帶 `redirect_after`。已改正。
- **`TpRootScrollScaffold`**—— 已刪除，`test/ui/shared_ui_usage_test.dart:30` 斷言檔案不得存在、`:133` 斷言符號不得回到 `lib/`。已改為 `TpRootTabGeometry.clearance(context)`（`lib/theme/tokens.dart:113`）與 `TpRootScrollView`（`lib/ui/tp_root_scaffold.dart:237`）。
- **`/trips/:tripId`（複數）是正確的**，與交辦說明相反。`lib/app/router.dart:354` 的 `:tripId` 掛在 `/trips` 之下，是真正建畫面的路由；單數 `/trip/:tripId`（`lib/app/router.dart:182`）只是 web 時代留下的 alias，`redirect` 到複數版（`_tripAlias`，`:507`）。子頁一律加在複數路徑下。
- **玻璃 alpha 表**—— 只有 regular 的 Light `.40`／Dark `.48` 正確（`lib/ui/tp_glass_surface.dart:194`）。PlatformView 實際是 `Colors.black` alpha `0.35`（`tpMediaScrimOpacity`，同檔 `:44`、`:192`），不是 `.56/.62`；High Contrast 實際是 alpha `1` 全不透明（同檔 `:22`），不是 `.96`。本節依程式碼描述，未沿用該表數字。
- **`AppContentWidth` 少一項**—— 除了 `form` 720 / `conversation` 860 / `feed` 920，還有 `authCard` 420（`lib/app/adaptive_content.dart:10`），已補上。
- **`AppKeyboardDismissRegion` 的掛法**（舊計畫文件曾寫「表單內容外層使用」）—— 實作收斂成只掛 app root 一次（`lib/main.dart:163`）。已改寫為「feature 不得再包一層」。
- **已知既有債（不是許可）**：「不直接引用 Light／Dark 常數」這條目前有 3 處 feature 違反，都是取語意 success 色 —— `lib/features/auth/login_screen.dart:106-107`、`lib/features/auth/welcome_screen.dart:441-442`、`lib/features/invite/invite_screen.dart:639-640`。新程式碼不得比照辦理。

## UI 規範

**`DESIGN.md` 是本 repo 的第二份 standards source。** `code-review` 的 Standards 軸除了本檔,**必須一併讀取根目錄 `DESIGN.md`**(Tripline iOS HIG 規範,約 360 行,含「HIG 必須／HIG 建議／Tripline 決策」三級強制標記)。任何動到 `lib/ui/`、`lib/features/`、`lib/theme/`、`lib/app/adaptive.dart` 的 diff,兩份文件都要對。判讀強制等級:`DESIGN.md` 標「HIG 必須」= release blocker,標「HIG 建議」的偏離要在 PR 說明補一筆理由,標「Tripline 決策」= 不得單方面改動。

下面四塊是 `DESIGN.md` 裡**每個 PR 都該逐條對**的部分(折自 §12 刪除動線、§18 Accessibility release gate、§19 驗收矩陣,加上 `CONTEXT.md`「動作動詞」的實作層規範),已對程式碼驗證。其餘章節仍以 `DESIGN.md` 原文為準。

### 動作動詞的圖示與顏色

四個動詞的**語意定義在 [`CONTEXT.md`](CONTEXT.md#動作動詞)**(新增／加入／移除／刪除),本節只規範對應的圖示與顏色,兩者一起看才完整。

| 動詞 | 圖示 | `TpActionItem.role` | 顏色 |
|---|---|---|---|
| 新增 | `CupertinoIcons.add` / `add_circled` | `normal` | `scheme.onSurface` |
| 加入 | 帶 `plus` 的**範圍專屬**符號(`calendar_badge_plus`、`paperclip`) | `normal` | `scheme.onSurface` |
| 移除 | 帶 `minus` 的範圍專屬符號(`person_badge_minus`) | `destructive` | `scheme.error` |
| 刪除 | `CupertinoIcons.delete` | `destructive` | `scheme.error` |

- 顏色不手寫,由 `role` 推導 —— `lib/ui/tp_app_bar.dart:1011` 是唯一的映射點(`destructive` → `scheme.error`,否則 `scheme.onSurface`)。diff 裡出現寫死的紅色或 `foregroundColor:` 覆寫選單項目顏色 = 違反。
- 新增／加入用 `add` 系列且 `role` 維持 `normal`;移除／刪除用 `minus`／`delete` 且 `role` 必為 `destructive`。動詞與 role 不匹配(例如「加入」配 `destructive`)= 違反。
- 選單項目(`TpMoreMenuButton`)一律要 `icon`;action sheet 專用項目一律**不給** `icon`(給了也畫不出來,見 `lib/ui/tp_action_item.dart:22`)。
- 破壞性項目放在 `actions` 陣列尾端,且 `dividerBefore: true`(`lib/features/trips/trips_list_screen.dart:642`、`lib/features/trips/collab/collab_screen.dart:229`、`lib/features/favorites/favorites_screen.dart:453`)。
- 圖示走 `CupertinoIcons`。`Icons.*`(Material)只在沒有對應 Cupertino 符號時使用。

> 標註(與 `DESIGN.md` 原文的差異):**這張表是從程式碼歸納的,`DESIGN.md` 沒有寫圖示與顏色規則**,只在 §4.1 L74 泛稱「destructive action 使用 system destructive role」。表中的三處已知 outlier,審查看到不必當新違規、但也不要照抄擴散:`lib/features/trips/share/share_screen.dart:503` 的刪除用了 Material `Icons.delete_outline`;`lib/features/favorites/favorites_screen.dart:450` 標「刪除」卻配 `heart_slash`(語彙混用已記在 ADR-0008 第 39 行);`lib/features/trip_detail/trip_timeline_screen.dart:1390` 的刪除項少了 `dividerBefore: true`。

### 刪除語意(DESIGN.md §12,決策脈絡見 ADR-0008)

- **刪除一律不可復原。** 不得新增 Undo、垃圾桶、復原期限或 restore 動線,對行程、Day、停留點、筆記、分享連結、收藏一體適用。
- **一律先確認。** 每個刪除入口都要走 `confirmAndDelete` / `confirmAndRunIrreversibleAction`(`lib/app/irreversible_action.dart:87` / `:14`)。diff 裡直接呼叫 repository 的 delete 而沒有經過這兩支 = 違反。
- **確認文案必須指名對象與連帶影響**,不得只寫「確定要刪除嗎?」。沒有復原路徑時,含糊文案等於資料遺失(ADR-0008 Consequences)。破壞性按鈕明寫「刪除」,不用「確定」。
- **永久刪除只可由左滑揭露後點擊執行,不允許 full swipe 直接執行。** 左滑外殼固定用 `SwipeToDelete`(`lib/ui/swipe_to_delete.dart`);手勢只揭露紅色動作,執行仍走 `onDelete` 內的確認流程。`Dismissible` 或任何 `DismissDirection` 直接觸發刪除 = 違反。
- **確認界面依觸發來源分流,不可寫死。** 呼叫端必填 `TpDestructiveConfirmSource`:選單觸發用 `menu`(走 action sheet),右滑／列上按鈕用 `direct`(走 alert)。理由與 HIG 引文在 `lib/app/adaptive.dart:214`。
- **伺服器成功後才從畫面移除資料**,失敗保留原資料與選取狀態並提供重試(`lib/app/irreversible_action.dart:76`)。樂觀刪除(先改畫面再送請求)= 違反。
- **左滑刪除必須有不依賴手勢的替代 action** —— `CustomSemanticsAction`,已由 `SwipeToDelete` 統一提供(`lib/ui/swipe_to_delete.dart:69`)。

### Accessibility release gate(DESIGN.md §18)

以下任一失敗**阻擋 release**,不是「之後再補」:

- **所有互動控制至少 44×44pt**,尺寸走 `TpSpacing.tapMin`(`lib/theme/tokens.dart:88`),不寫魔術數字 44。`test/flows/hig_regression_matrix_test.dart:98`／`:102` 對 header 動作與帳號鈕鎖了實際量測值。
- **VoiceOver 的 label、value、hint、selected、expanded 語意正確。** 選取狀態走 `Semantics.selected` flag,**不要把「已選取」寫進 label 字串**(`lib/ui/tp_horizontal_selector.dart:269`)。
- **Voice Control 名稱要對得上可見 label。** 用了 `excludeSemantics: true` 的 widget,`label` 必須包含畫面上看得到的文字;`semanticLabel` 覆寫時必須以可見 label 開頭再接補充(範例:`lib/features/trip_detail/trip_timeline_screen.dart:1377` 停用時的「移動到其他天,目前行程只有一天,無法使用」)。
- **Switch Control、Full Keyboard Access、外接鍵盤與 pointer 可完成核心流程。** 拖拉排序必須同時提供 `CustomSemanticsAction`(上移／下移／移至其他 Day)與 `CallbackShortcuts` 方向鍵(`lib/features/trip_detail/trip_timeline_screen.dart:1604`、`:1615`;`lib/features/trip_detail/widgets/reorderable_row.dart:60`、`:73`)。新增可排序清單時三者缺一 = 違反。
- **支援 Dynamic Type 與 Bold Text**:不載入自訂字型(`pubspec.yaml` 的 `fonts:` 保持註解狀態),不以固定高度裁切內容 —— 卡片、表單列、訊息、設定 row 隨字級增高。
- **Increase Contrast**:走 `MediaQuery.highContrastOf(context)`,主題側由 `lib/main.dart:154`／`:156` 的 `highContrastTheme` 供給。
- **Reduce Transparency**:**Flutter 沒有這個 MediaQuery flag**,一律走 `AppAccessibilityScope.reduceTransparencyOf(context)`(`lib/app/accessibility_scope.dart:24`)。用 MediaQuery 找這個設定 = 違反。
- **Reduce Motion**:位移、縮放、彈性動畫的時間走 `TpMotion.resolve(context, ...)`(`lib/theme/tokens.dart:133`),或在動畫前用 `MediaQuery.disableAnimationsOf(context)` 早退。純淡入淡出可豁免(DESIGN.md §17 明文允許以短淡入淡出替代)。
- **focus 不被浮動 header、鍵盤、root tab bar、sheet 或行程 POI accessory 遮住。**
- **不以顏色為唯一資訊來源** —— 地圖 marker、Day、路線、錯誤與選取都要另有編號、線型、字符或 selected flag。

> 標註:DESIGN.md §18 原文列出「支援全部 …… Differentiate Without Color 與 Button Shapes」。**Flutter 的 `MediaQueryData` 沒有這兩個 flag**(可用的只有 `accessibleNavigation`、`invertColors`、`highContrast`、`onOffSwitchLabels`、`disableAnimations`、`boldText`),無法直接偵測,因此改寫為上面最後一條可稽核的「不以顏色為唯一資訊來源」。Reduce Transparency 那條也同理,原文沒說它得自己接 platform channel。

### 驗收矩陣(DESIGN.md §19)

**自動驗收 —— 每個 PR 必過,與 CI 一致:**

- `flutter analyze --no-fatal-infos` 零 error/warning(`.github/workflows/mobile.yml:61`)
- `flutter test` 全綠 —— 跑**整個** `test/`,不挑檔(`.github/workflows/mobile.yml:69`)
- 格式檢查:`git ls-files -z '*.dart' ':!:patrol_test/test_bundle.dart' | xargs -0 dart format --output=none --set-exit-if-changed`(`.github/workflows/mobile.yml:58`)
- HIG 十態矩陣:`test/flows/hig_regression_matrix_test.dart:47` 的 `_states` —— Light／Dark × (一般字級、2× 字級、Reduce Motion、Increased Contrast、Reduce Transparency),於 390×844 驗證幾何與行為。**新增 chrome 元件要進這支測試。**
- 畫面證據集:`test/flows/app_owned_release_flow_artifacts_test.dart:104` 的 14 個畫面 × 10 態 = 140 張 PNG,輸出到 `build/test-artifacts/app-owned`(`:144` 鎖住總數)。**新增 root 畫面要進 `expected` 集合。**
- 共用元件邊界:`test/ui/shared_ui_usage_test.dart` —— `lib/features/` 不得出現 `AppBar`／`SliverAppBar`(`:6`)、不得直接呼叫 `showModalBottomSheet`／`showCupertinoModalPopup`／`showGeneralDialog`(`:44`),平台 sheet API 只有 `lib/app/adaptive.dart` 能碰(`:65`)。
- 窄版與大字級:新畫面的 widget test 至少覆蓋 320×568 與 `TextScaler.linear(2)` 以上(既有範例:`test/features/favorites/favorites_screen_test.dart:233`、`test/features/share/public_share_screen_test.dart:198` 用到 3.2×)。

**手動驗收 —— release 前逐項走過:**

- iPhone compact、iPhone landscape、iPad regular、iPad split view
- Android phone 與 Android tablet 呈現同一套 iOS HIG 視覺
- Light／Dark、Increase Contrast、Reduce Transparency、Reduce Motion、Bold Text
- VoiceOver、Voice Control、Switch Control、Full Keyboard Access、pointer 與外接鍵盤
- 鍵盤、safe area、旋轉、sheet、tab state restoration、edge-back
- 聊天、切換行程、Day、日期／時間 picker、拖拉排序、地圖、行程 POI、收藏、Account,以及**全部不可復原刪除流程**
- 真機或 simulator 驗證 Liquid Glass、PlatformView、效能與 raster jank

> 標註(與 DESIGN.md §19 原文的差異,以程式碼與 CI 為準):
> 1. §19.1 寫的格式指令是 `dart format --output=none --set-exit-if-changed .`。**照抄會誤判** —— repo 根目錄跑 `.` 會撞到 `build/` 產物,而 CI 另外排除了 `patrol_test/test_bundle.dart`(由 `patrol build` 重新產生,格式不受控)。上面採用 CI 的實際指令。
> 2. §19.1 寫「關鍵畫面 screenshot／golden regression」。**repo 裡沒有 golden 檔**(`test/` 下無 `.png` 基準,無 `matchesGoldenFile`);實際做的是 `app_owned_release_flow_artifacts_test.dart` 產出 140 張 PNG 供人眼比對,以及 `hig_regression_matrix_test.dart` 以數值斷言鎖住玻璃參數與幾何。上面照實寫,沒有把 golden regression 列為必過項。
> 3. §19.1 的「320pt compact 與 regular width widget tests」不是集中一支,而是散在各畫面測試裡,因此改寫成對新畫面的要求。

### 已知失效條文(不予採用)

以下 `DESIGN.md` 條文與現行程式碼／ADR 衝突,**Standards 審查不得據以報違規**:

- **§4.1 L72「不替每個 icon 自製圓框、厚 border 或不同尺寸;由 system toolbar／Liquid Glass 分組」** —— 已被 [ADR-0004](docs/adr/0004-neutral-selection-surface-with-tinted-foreground.md) 推翻。現行結構是**每個控制項各自成膠囊,不是一整片玻璃板**(`lib/ui/tp_root_scaffold.dart:118` 的註解與 `CONTEXT.md`「動作群組」)。該條掛著「HIG 必須」,照它審會對每個 header 變更報假陽性。
- **§4.1 L65 後半／§16.3「所有頁面使用 system inline navigation title」** —— 不成立。[ADR-0001](docs/adr/0001-keep-liquid-glass-over-native-cupertino.md) 決定不用 Cupertino 導覽元件,實作是自繪的浮動玻璃 header(`TpRootScaffold`)與固定 bar(`TpAppBar`)。**只保留同句前半的「全 App 不使用 Large Title」**(§16.3 L301 亦有獨立敘述),那條仍然有效。
- **§20 來源階層** —— 整節不採用,它描述的是一份即將刪除的文件。

## 測試規範

### 檔案擺放

- 測試目錄鏡像 `lib/` 的分層：`test/models/`（純 `fromJson` 與 edge case，不 import Flutter widget）、`test/api/`（`ApiClient` 與 repository，mock HTTP 層）、`test/features/<feature>/`（widget test + `ProviderScope` override）。
- 另有四個不鏡像 `lib/` 的橫向目錄，新測試要放對：`test/app/`（router、adaptive、全 app 行為）、`test/ui/`（`lib/ui/` 共用元件）、`test/flows/`（跨畫面流程與 HIG 回歸矩陣）、`test/platform/`（建置設定、原生 key 檢查）、`test/docs/`（文件連結守門）。
- 檔名一律 `<被測物>_test.dart`。**共用的契約 suite 不加 `_test` 後綴**，否則 runner 會單獨跑它 —— 例：`test/api/cache/cache_store_contract.dart`，由 `test/api/cache/in_memory_cache_store_test.dart:3` 與 `test/api/cache/drift_cache_store_test.dart:4` 各自 import 後套用。
- 新增 `CacheStore` 實作 → 必須掛上 `cache_store_contract.dart` 的共用契約，不可只寫自己的測試。

### 測試替身

- **測試中不得呼叫 `SecureSessionStore` 的任何方法**（走平台 channel，會丟 `MissingPluginException`）。一律用 `InMemorySessionStore`（`lib/api/session_store.dart:34`，正式碼提供的測試替身）。
  - 唯一允許出現 `SecureSessionStore` 字樣的地方是型別斷言，例如 `test/api/providers_test.dart:50-58` 的 `expect(container.read(sessionStoreProvider), isA<SecureSessionStore>())` —— 只讀型別，不觸發 channel。
- api 層測試 mock **HTTP 層**，不 mock repository：`http_mock_adapter` 的 `DioAdapter`（`test/api/api_client_test.dart:73-74`）。
  - `DioAdapter` 無法對同一 request 簽章依序回不同 response（429 → 200 的 retry 測試）。需要序列回應時自寫 `HttpClientAdapter`，樣板見 `test/api/api_client_test.dart:15-39` 的 `SequencedResponseAdapter`。
- **不要在 `Dio(BaseOptions(...))` 設 `baseUrl`。** `ApiClient` 建構子第 `lib/api/api_client.dart:78` 行無條件覆寫成 `'$origin/api'`，任何在 `BaseOptions` 設的 `baseUrl` 都會被丟掉。要改 base 一律走 `ApiClient(origin: ...)`。
- api 測試的 mock path 寫「`<origin>/api` 之後的相對路徑」：`dioAdapter.onGet('/my-trips', ...)`，不是完整 URL。

### Provider override

- 資料 provider 是 **`StreamProvider`**，override 要回 `Stream`，不是 `Future`：
  - `myTripsProvider`（`lib/features/trips/trips_list_screen.dart:149`）→ `myTripsProvider.overrideWith((ref) => Stream.value(fakeTrips))`（用例：`test/features/trips/trips_list_screen_test.dart:150`）。
  - `tripProvider` / `tripDaysProvider` / `tripNotesProvider` 是 `StreamProvider.family`（`lib/features/trip_detail/trip_providers.dart:13,17,24`）→ `tripDaysProvider.overrideWith((ref, tripId) => Stream.value(fakeDays))` 一次覆寫所有 key。
- flutter_riverpod 3.x 未匯出 `Override` 型別 —— overrides 直接在 `ProviderScope` / `ProviderContainer` 建構處以 list literal 傳入，不要宣告 `List<Override>` 變數。
- 需要登入狀態的畫面：override `authStateProvider`，用一個 `extends AuthNotifier` 且只覆寫 `build()` 的假 notifier：

  ```dart
  class _FakeAuthNotifier extends AuthNotifier {
    _FakeAuthNotifier(this._fixedUser);
    final UserInfo? _fixedUser;
    @override
    Future<UserInfo?> build() async => _fixedUser;   // null = 未登入
  }
  // authStateProvider.overrideWith(() => _FakeAuthNotifier(user)),
  ```

  現行用例：`test/app/router_test.dart:62-69,162`、`test/features/trips/trips_list_screen_test.dart:22-29`。
- 需要在測試中主動操作 router（`container.read(appRouterProvider).go(...)`）時，用 `ProviderContainer` + `UncontrolledProviderScope`，並 `addTearDown(container.dispose)`（`test/app/router_test.dart:160-186`）。

### widget test

- 畫面的 mutation 互動用 mocktail mock 整個 repository，斷言 `verify(() => mock.deleteTrip('okinawa-trip-2026')).called(1)`（`test/features/trips/trips_list_screen_test.dart:864-866,906-908`）。
- **mutation stub 一律 `thenAnswer((_) async {})`**，漏掉會丟 `Null is not a subtype of Future`（例：`test/features/chat/chat_screen_test.dart:166`）。
- 導航斷言鋪假 `GoRouter` 探針路由，不掛真路由表：目的地 route 只回一個帶識別字串的 `Scaffold`，用 `expect(find.text('detail:okinawa-trip-2026'), findsOneWidget)` 收尾（樣板：`test/features/trips/trips_list_screen_test.dart:93-126`）。
  - 自建 `GoRouter` 一律 `addTearDown(router.dispose)`（`test/features/shell/app_shell_test.dart:259-260`）。
- **畫面上有永不停止的動畫（`CircularProgressIndicator`、思考中氣泡）時不得用 `pumpAndSettle`**，它會 timeout。改固定次數 `pump()`：
  ```dart
  // 進行中泡泡有一顆永遠在轉的 spinner,pumpAndSettle 會 timeout。
  for (var i = 0; i < 8; i++) { await tester.pump(const Duration(milliseconds: 100)); }
  ```
  現行用例：`test/features/chat/chat_screen_test.dart:168-170`、`test/features/trip_detail/trip_notes_screen_test.dart:1104-1106`。
- 改測試視窗尺寸必須成對還原，兩種寫法擇一，不要混：
  - `tester.view.physicalSize = ...` → 同時設 `tester.view.devicePixelRatio = 1`，並 `addTearDown(tester.view.resetPhysicalSize)` + `addTearDown(tester.view.resetDevicePixelRatio)`（`test/features/shell/app_shell_test.dart:255-258`）。
  - `tester.binding.setSurfaceSize(...)` → `addTearDown(() => tester.binding.setSurfaceSize(null))`（`test/features/trips/trips_list_screen_test.dart:61-64`）。
- **有 size class 分支的畫面，測試必須覆蓋 compact 與 regular 兩種寬度。** 判定規則只有一條：`appIsRegularSizeClass`（`lib/app/adaptive.dart:752-755`，`width >= 720 && height >= 700`）。既有測試的標準尺寸是 compact `Size(390, 844)`、regular `Size(1024, 768)`（`test/features/shell/app_shell_test.dart:255,278`）。`Size(600, 820)` 仍是 compact（寬度未過 720），不要拿它當 regular。

### 新增程式碼的測試門檻

- 新增 model → 至少一個 `fromJson` 測試，且必須含 wire 型別 edge case：nullable 欄位缺漏回 null（`test/models/entry_test.dart:24-32`）、`0`/`1` 轉 bool（`test/models/user_test.dart:24-37`、`test/models/notes_test.dart:138`、`test/models/trip_test.dart:112`）、後端回 int 或 double 都要收（`test/models/entry_test.dart:42-51` rating `4` → `4.0`；`test/models/trip_test.dart:46-54` `memberCount: 3.0` → `3`）。
- 改 `ApiClient` 的四條行為規則（Cookie／Origin、429 retry、204 空 body、路徑編碼）→ 對應 group 的測試要同步改，不得只改實作。group 命名沿用「規則 N：<行為>」（`test/api/api_client_test.dart:88,113`）。
- 新增 screen → 至少一個 widget test。
- 修 bug → 先寫一支重現該 bug 的失敗測試，再修。

### 格式與 CI 閘門

- **不要跑 `dart format .`** —— 會遞迴進 `build/` 的 Gradle 產物並崩潰。
- 本機格式化指定目錄：`dart format lib test`（視改動加上 `integration_test`、`tool`）。
- CI 的格式閘門是 git 追蹤檔清單，不是目錄（`.github/workflows/mobile.yml:56-58`）：
  ```bash
  git ls-files -z '*.dart' ':!:patrol_test/test_bundle.dart' \
    | xargs -0 dart format --output=none --set-exit-if-changed
  ```
  `patrol_test/test_bundle.dart` 由 `patrol build` 產生、格式不受控，**排除它是刻意的**，不要把它加回檢查範圍。
- 完成定義：`flutter analyze --no-fatal-infos` 零 error/warning + `flutter test`（跑整個 `test/`）全綠。`patrol_test/` 不在 `flutter test` 預設範圍，由 `mobile-e2e.yml` 另跑。

> **注意兩則常見誤述**（舊文件與早期 `CLAUDE.md`／`AGENTS.md` 都寫過，以本節為準）：
> 1. 「資料 provider 是 `FutureProvider`,override 用 `overrideWith((ref) async => ...)`」—— 實際上 `myTripsProvider`、`tripProvider`、`tripDaysProvider`、`tripNotesProvider` 都已改為 `StreamProvider`，override 必須回 `Stream`。
> 2. 「測試完全不碰 `SecureSessionStore`」—— 實際上 `test/api/providers_test.dart:50` 有一支型別斷言測試合法引用它，規則收斂為「不呼叫其方法」。
> 3. `DESIGN.md:337` 寫格式檢查是 `dart format --output=none --set-exit-if-changed .`。CI 實際用 `git ls-files` pathspec，且 `.` 會撞 `build/`；以 CI 寫法為準。
> 4. 來源文件都寫「三層鏡像」。實際 `test/` 有 12 個頂層目錄，已補上 `app/`、`ui/`、`flows/`、`platform/`、`docs/` 的擺放規則。

## 測試不可假綠

- **新測試一寫完就綠 = 可疑。** 宣稱一支測試守住某行為之前，先做 mutation check：暫時把實作或斷言期望值改壞 → 跑 → 確認 **FAIL** → 改回 → 確認 PASS。沒紅過的測試不算數。
- 特別容易假綠的兩類：斷言目標其實不在畫面上（`findsNothing` 恆真）、清單／捲動測試的資料量不足以觸發被測條件。既有測試已用註解標明過這個陷阱：「清單必須長到溢出視窗,否則捲不動、最後一張卡停在畫面中段,斷言會假綠燈」（`test/features/trips/trips_list_screen_test.dart:134`）。
- **為既有已出貨的 code 補測試時，流程反過來**：寫測試刻畫既有行為 → 跑 → **預期 PASS**。若預期 PASS 卻 FAIL，停下調查（可能是理解錯，也可能既有 code 真有 bug），**不要改測試去遷就實作**。
- 測試寫完後自然就紅、且紅的原因正是它要抓的東西時，不需要另做 mutation check —— 那已經是真紅燈。例：`test/docs/doc_links_test.dart` 一寫完就抓到 `DESIGN.md` 的兩條懸空連結。
- PR 描述要寫出實際的 `flutter test` 通過數；沒跑起來的測試（例如缺 device 的 `integration_test`）如實標明環境限制，不得假裝通過。
