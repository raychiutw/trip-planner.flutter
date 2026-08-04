# AGENTS.md

本檔是 Codex 與其他 coding agent 在此 repository 的強制工作契約。**每次開始任何探索、編輯、測試或外部操作前，必須先完整閱讀根目錄 `AGENTS.md`**。

本檔依使用者明確要求與 `CLAUDE.md` 並存。兩者各自維護，沒有自動同步機制；改到共同規則時記得兩邊都改。若內容衝突，不得自行挑選，先向使用者指出差異。

## 開工前檢查

1. 先讀本檔，再讀任務明確點名或依工作流需要使用的每一份 `SKILL.md`；必要 skill 不可用時必須停下並回報，不得跳過，也不得以手動步驟冒充已執行 skill。
2. 讀取 `CONTEXT.md` 與工作範圍相關的 `docs/adr/`，沿用既有領域詞彙與決策。
3. 先確認目前 branch、worktree 與既有變更；不得覆蓋或順手提交不屬於本次任務的內容。
4. 程式碼探索優先使用下列 Codebase Knowledge Graph；不足時才退回文字或檔案搜尋。

<!-- codebase-memory-mcp:start -->
# Codebase Knowledge Graph (codebase-memory-mcp)

This project uses codebase-memory-mcp to maintain a knowledge graph of the codebase.
ALWAYS prefer MCP graph tools over grep/glob/file-search for code discovery.

## Priority Order
1. `search_graph` — find functions, classes, routes, variables by pattern
2. `trace_path` — trace who calls a function or what it calls
3. `get_code_snippet` — read specific function/class source code
4. `query_graph` — run Cypher queries for complex patterns
5. `get_architecture` — high-level project summary

## When to fall back to grep/glob
- Searching for string literals, error messages, config values
- Searching non-code files (Dockerfiles, shell scripts, configs)
- When MCP tools return insufficient results

## Examples
- Find a class: `search_graph(name_pattern=".*TripRepository.*")`
- Who calls it: `trace_path(function_name="ApiClient", direction="inbound")`
- Read source: `get_code_snippet(qualified_name="lib.api.api_client.ApiClient")`
<!-- codebase-memory-mcp:end -->

## 專案性質

本 repo 是 [trip-planner React SPA](https://github.com/raychiutw/trip-planner) 的 iOS／Android Flutter 移植版。**後端不動**：共用 Cloudflare Pages Functions API（`https://trip-planner-dby.pages.dev/api`），此 repo 只是另一個 client。P0（唯讀畫面）、P1（收藏／停留點 CRUD／AI 聊天／共編）與 P2（分享匯入、設定、OAuth PKCE Bearer 認證、離線快取）皆已完成，現在是既有功能的維護與增修。

## 強制開發流程

凡新增、移除或改變產品行為，或修改 production code，必須使用 Matt Pocock engineering skills，且同類任務優先於 Superpowers／gstack：

`grill-with-docs → to-spec → to-tickets → implement → code-review`

本節即為使用者對這條 repo 工作流的預先指定；不必等使用者逐一重打 slash command，但每個 skill 規定的停點、確認與外部發布步驟仍必須照做。

- `grill-with-docs`：在寫 code 前逐題收斂共同理解；一次只問一題。能由 repository 回答的事自行查證，不問使用者。即時維護 `CONTEXT.md` 詞彙；ADR 只在「難以逆轉、缺少脈絡會困惑、存在真實 trade-off」三者都成立時建立。
- `to-spec`：**一律不可省略**。沿用已完成的討論，不重新訪談；探索現況、提出最少且最高層的既有測試 seam，取得使用者確認後，將 spec 發布到 GitHub Issues 並加上 `ready-for-agent`。在 spec Issue 建立前不得修改 production code。
- `to-tickets`：將工作拆成可獨立驗證、可在單一 fresh context 完成的 tracer-bullet 垂直切片，標示 blocking edges，取得使用者同意後發布。**只有整個變更確定可在單一 fresh context 完成、沒有 blocker，且無有意義的垂直切片可拆時才可省略**；省略後必須由 `to-spec` 直接進入 `implement`，不得同時省略前後兩步。
- `implement`：**一律不可省略，也不得以直接手動編輯取代**。從已核准的 spec 或 tickets 開始，每個 `implement` 使用 fresh context；在已確認的 seam 以 `tdd` 一次完成一個 red → green 垂直切片，定期跑單檔測試與 type check，結尾跑完整測試，再依 `code-review` 對 Standards／Spec 兩軸審查，最後才提交目前 feature branch。
- `code-review` 是 `implement` 的完成 gate，不是可選的事後補件；必須能追溯到原始 spec／Issue，並使用明確 fixed point。

流程分流仍不得繞過 `to-spec`／`implement`：bug 先用 `diagnosing-bugs` 找 root cause 與重現方式；外部 issue 先用 `triage`（自己由 `to-tickets` 建立的票不 triage）；需要跑起來才能回答的設計問題用 `prototype`；大到一個 session 裝不下的工作先用 `wayfinder`；不確定流程時用 `ask-matt`。

`grill-with-docs`、`to-spec` 與需要的 `to-tickets` 應在同一 context window 完成，不得中途 compact；接近上限時用 `handoff` 換新 session。每個 `implement` 另開 fresh context。

純唯讀回答、狀態查核，以及只維護 agent 指令本身，不需要為此建立產品 spec；但使用者明確點名的 skill 仍必須完整執行。

## Git 與完成定義

- 不直接 commit 到 `master`；使用 feature branch，最後透過 `ship` 開 PR。base branch 是 `master`，不是 `main`。
- 有既有 worktree 變更時只刻意 stage 本次檔案，不使用會收進無關變更的廣泛 staging。
- production code 變更必須先有失敗測試；bug fix 先有重現測試。測試驗證公開行為，不耦合內部實作。
- 完成定義：`flutter analyze` 零 error／warning，且 `flutter test` 全綠。
- 文件、註解與 commit message 一律使用繁體中文（台灣用語）；技術名詞保留英文。

## 常用指令

```bash
flutter pub get
flutter test                                          # 全部測試
flutter test test/api/api_client_test.dart            # 單檔
flutter test --plain-name "429"                       # 依測試名稱過濾
flutter analyze                                       # 完成定義：零 error／warning
flutter run                                           # 連 prod API；一律使用測試帳號
```

## 架構

分層單向依賴（上層使用下層）：`features/` → `ui/` → `app/` → `api/` → `models/` → `theme/`。`models/` 是純 Dart，不 import Flutter；`theme/` 不依賴其他層。完整規則與既有例外見 `CONTRIBUTING.md`「分層與依賴方向」一節。

### Provider 鏈（Riverpod 3.x）

`sessionStoreProvider` → `apiClientProvider` → `authRepositoryProvider`／`tripRepositoryProvider` → `authStateProvider`（全 app 認證 SoT）→ `appRouterProvider`。測試可 override 鏈上任一節點以替換下游。

行程詳情的 trip／days／notes／entry／segments 使用 `StreamProvider.family`（`lib/features/trip_detail/trip_providers.dart:13,17,24,33,43`），不是 `FutureProvider.family` —— StreamProvider 才能做 SWR 兩段式發射（先 emit 本機快取 stale，再 emit 網路 fresh）。timeline／map／notes 三個畫面 watch 同一 family 實例共用 fetch，對應 web 版 TripLayout。

Flutter Riverpod 3.x 未匯出 `Override` 型別；測試 overrides 直接用 list literal 傳入 `ProviderScope`。

### 認證與 API 安全規則

認證有 **cookie 與 Bearer 兩種互斥模式**，由 `_authHeadersFor()`（`lib/api/api_client.dart:946-968`）依有無 access token 二選一，repository 與畫面層都不得自己拼這些 header：

- **cookie 模式**（無 Bearer token）：後端使用瀏覽器導向的 session cookie 與 CSRF Origin allowlist，app 扮演瀏覽器。登入走 `postForResponse`（`lib/api/auth_repository.dart:101`）讀取 `set-cookie`，解析 `tripline_session` 並存入 `flutter_secure_storage`；之後每個 request 帶 `Cookie:`，**且非 `GET`／`HEAD` 的 mutating request 必帶 `Origin:`**，否則回 403。
- **Bearer 模式**（`BearerTokenSource` 回非空 token）：只帶 `Authorization: Bearer <token>`，**不送 `Cookie`、不送 `Origin`**（後端對「有 Bearer 且無 Origin」跳過 CSRF 檢查）。
- Origin 值是 `kTriplineOrigin = String.fromEnvironment('TRIPLINE_API_ORIGIN', defaultValue: 'https://trip-planner-dby.pages.dev')`（`lib/api/api_client.dart:21-24`），同時決定 base URL 與 CSRF header，本機後端靠 `--dart-define` 覆寫，不得改回字面常數。
- 以上 `ApiClient` 已統一處理，不得繞過它用 raw Dio 呼叫 API。
- `currentUser()` 收到 401 時回傳 `null`，不 throw。登入後跳轉靠 router redirect（`refreshListenable` 橋接 `authState` 變化）；`LoginScreen` 本身不導航。

### ApiClient 行為規則

每條規則都有對應測試，改動時必須同步測試：

1. 非 2xx → throw `ApiError`（三層 fallback 解析見 `api_error.dart`）。
2. 三條分支共用「同參數重送一次」的 `retry()`（`lib/api/api_client.dart:795-806`），各自靠 `isRetryAttempt` 限制**最多一次**：①**429** 僅 `GET`／`HEAD`，讀 `Retry-After` 等待後重送（clamp 0–30 秒，缺漏回 1 秒）；②**edge block page**（2xx 非 204 但 `Content-Type` 含 `text/html` 的 CDN 攔截頁）重試條件與 429 完全相同，重送後仍是攔截頁則丟 `SYS_UPSTREAM_UNAVAILABLE`；③**Bearer 401** 且 `_bearerSource.refresh()` 回 true 才重送，**不分 method**（`POST`／`PATCH`／`DELETE` 一樣重送）。「mutation 絕不 retry」是錯的說法，只有 429／edge block 不重送 mutation。SSE 串流版 `_getTextStream()`（`lib/api/api_client.dart:884-911`）走同一組規則，改重試邏輯要兩處一起改。
3. 204／空 body → `null`。
4. 路徑參數使用 `Uri.encodeComponent`。

### Model 解析規則

Wire 格式是 camelCase（server `deepCamel()`）；數字使用 `(json['x'] as num?)?.toInt()`／`.toDouble()`；bool flag 接受 0／1 與 bool：`json['x'] == 1 || json['x'] == true`；日期時間保留字串，不轉 `DateTime`；缺少 list → `[]`；缺少 `sortOrder`／`version` → `0`。完整規則、欄位行號與後端契約細節見 `CONTRIBUTING.md`「Model 與 fromJson 解析規則」與「API 層規範／後端契約細節」兩節；個別欄位仍以程式碼為準。

### Theme 取色規則

Widget 一律透過 `Theme.of(context).colorScheme` 取色。柔褐 tint 是唯一品牌強調色，內容 surface 跟隨 iOS 系統語意層級。`TpSystemColorsLight`／`TpSystemColorsDark` 只供 `AppTheme` 工廠建立 Light／Dark／High Contrast 主題，feature 不得直接引用；地圖逐日 pin／route palette 是唯一 rainbow 色例外。禁止 gradient 裝飾與 emoji icon。

### OCC

Models 帶 `version` 欄位；後端 PATCH 要傳 `expectedVersion`，收到 409 `STALE_ENTRY` 時重抓 server 真相後再套用，離線佇列走三方 rebase。停留點 meta、筆記與交通段的編輯路徑都已在用；行程本身無 `version`（走 `PUT /trips/:id`，last-write-wins），另有字串型的 `entryPoisVersion` 管 POI 結構操作，兩套 OCC 不可混用。

## 測試慣例

測試三層鏡像 `lib/`：

- Models：純 `fromJson` 與 edge case。
- API：`http_mock_adapter` + `InMemorySessionStore`，不碰 `SecureSessionStore`。
- Screens：widget test + `ProviderScope` override、mocktail mock repository、假 `GoRouter` 作為導航探針。

具體手法（provider override、關掉 error 態自動重試、假綠燈防線）見 `CONTRIBUTING.md`「測試規範」與「測試不可假綠」兩節。只在已與使用者確認的公開 seam 測試；一次寫一個 failing test，再補最少 production code 使其通過。

## Agent skills

### Issue tracker

Issues 與 PRD 使用 GitHub Issues（`raychiutw/trip-planner.flutter`），透過 `gh` CLI 操作。詳見 `docs/agents/issue-tracker.md`。

### Triage labels

使用五種 triage labels：`needs-triage`、`needs-info`、`ready-for-agent`、`ready-for-human`、`wontfix`。詳見 `docs/agents/triage-labels.md`。

### Domain docs

採 single-context 架構。根目錄 `CONTEXT.md` 只作詞彙表，不放實作細節或 spec；由 `grill-with-docs` 驅動的 `domain-modeling` 隨討論即時更新。`docs/adr/` 只按上述三重門檻建立。詳見 `docs/agents/domain.md`。

## Matt Pocock 官方依據

以下來源皆為 `mattpocock/skills` 官方 GitHub repository，於 2026-08-03 核對：

- [README：Codex 安裝、一次性 setup 與 skills 分類](https://github.com/mattpocock/skills/blob/main/README.md)
- [grill-with-docs：主流程與文件產出規則](https://github.com/mattpocock/skills/blob/main/docs/engineering/grill-with-docs.md)
- [to-spec：測試 seam 確認、發布 spec 與 ready-for-agent](https://github.com/mattpocock/skills/blob/main/skills/engineering/to-spec/SKILL.md)
- [to-tickets：tracer-bullet 垂直切片、blocking edges 與發布規則](https://github.com/mattpocock/skills/blob/main/skills/engineering/to-tickets/SKILL.md)
- [implement：TDD、type check、完整測試、code-review 與 commit](https://github.com/mattpocock/skills/blob/main/skills/engineering/implement/SKILL.md)
- [tdd：預先確認 seam 與逐一 red → green](https://github.com/mattpocock/skills/blob/main/skills/engineering/tdd/SKILL.md)
- [code-review：Standards／Spec 兩軸審查](https://github.com/mattpocock/skills/blob/main/skills/engineering/code-review/SKILL.md)
- [setup-matt-pocock-skills：AGENTS／CLAUDE 與 docs/agents 設定契約](https://github.com/mattpocock/skills/blob/main/skills/engineering/setup-matt-pocock-skills/SKILL.md)
