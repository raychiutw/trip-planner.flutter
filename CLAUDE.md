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
  - 主線:`/grill-with-docs`(訪談收斂,同時產出 `GLOSSARY.md` 詞彙與 `docs/adr/`)→ `/to-spec`(合成 spec 並發成 GitHub Issue,貼 `ready-for-agent`)→ `/to-tickets`(拆成 tracer-bullet 票)→ `/implement`(內部驅動 `/tdd` 一次一個紅綠切片,收尾跑 `/code-review`)。
  - 單一 fresh context 做得完、沒有 blocker、沒有需要另行發布的產品決策，且無有意義垂直切片的小功能，可在 `/grill-with-docs` 確認範圍與測試 seam 後略過 `/to-spec`、`/to-tickets`，直接進入 `/implement`。
  - **步驟 1~3 要在同一個 context window 內完成**,不要中途 compact;接近上限就 `/handoff` 換新 session。每個 `/implement` 開新 context。
  - 分流:bug 用 `/diagnosing-bugs`;外部進來的 issue 用 `/triage`(自己 `/to-tickets` 產的票不要 triage);設計問題需要跑起來才答得出來時用 `/prototype`;範圍大到一個 session 裝不下的用 `/wayfinder`。
  - 忘記該用哪個 skill 就問 `/ask-matt`。
- **寫 `lib/` 的程式碼前先讀 `CODING_STANDARDS.md`** 中相關的節(九節,附行號):它是編碼規範的唯一出處,也是 `/code-review` Standards 軸的主要依據,規則有異動改那裡,本檔只留摘要、衝突時以它為準。UI／UX 在 `DESIGN.md`,詞彙在 `GLOSSARY.md`,難逆轉的決策在 `docs/adr/`,貢獻流程在 `CONTRIBUTING.md`。
- **TDD 紅綠重構**:任何 production code 變更先寫失敗測試。修 bug 先寫重現測試。
- **完成定義**:`flutter analyze` 零 error/warning + `flutter test` 全綠。
- **不直接 commit 到 `master`**:開 feature branch → `/ship` 開 PR。base branch 是 `master`(無 `main`)。
- 文件、註解、commit message 一律繁體中文(台灣用語),技術名詞保留英文。

## 架構

分層單向依賴(上層用下層):`features/` → `ui/` → `app/` → `api/` → `models/` → `theme/`。`models/` 是純 Dart(不 import Flutter),`theme/` 不依賴任何人。分層規範與兩個既有例外見 `CODING_STANDARDS.md`「分層與依賴方向」。

### Provider 鏈(riverpod 3.x)

`bearerTokenSourceProvider` → `apiClientProvider` → `authRepositoryProvider`／`accountRepositoryProvider`／`tripRepositoryProvider`；`authRepositoryProvider` 與 `accountRepositoryProvider` 供 `authStateProvider`（全 app 認證 SoT）使用，後者再驅動 `appRouterProvider`。測試 override 鏈上任一節點即可替換下游。行程詳情的 trip/days/notes 使用 `StreamProvider.family<_, String>`（`lib/features/trip_detail/trip_providers.dart:16,32,49`）；segments 同型，entry 使用 `(tripId, entryId)` 作為 key。timeline/map/notes 三畫面 watch 同一 family 實例共用 fetch（對應 web 版 TripLayout），SWR 先 emit 本機快取再 emit 網路。

注意:flutter_riverpod 3.x 未匯出 `Override` 型別,測試的 overrides 直接以 list literal 傳入 `ProviderScope`。

### 認證(關鍵且非顯而易見)

認證只走 OAuth PKCE 與 Bearer(ADR-0014,取代 ADR-0005 的 cookie 路線):

- 登入是系統瀏覽器授權(`OAuthLoginService`),以 https callback(Universal Link／App Link)回到 app;**App 內沒有密碼表單,也不保管密碼**。callback 網域、client id、API origin 都是 `--dart-define`／gradle 設定值,不得寫死
- access token 只放記憶體(15 分鐘);refresh token 每次使用即輪替,落地在 Keychain／Keystore(`SecureOAuthTokenStore`),保護等級 `passcode`(預設)或 `biometric`(設定頁開啟)。裝置沒設密碼時不落地
- `ApiClient` 統一帶 `Authorization`(token 綁定金鑰時是 `DPoP` 加每請求重簽的 proof,否則 `Bearer`;ADR-0015);**不送 Cookie／Origin**。不要繞過它用 raw dio 打 API
- DPoP 金鑰每次登入產生一把(硬體優先:iOS Secure Enclave／Android Keystore,沒有才退軟體金鑰),隨登入憑證一起刪除;介面是 `ProofKey`(`lib/api/dpop/`)。SSE 帶同樣的標頭並處理 `event: reconnect`
- refresh 被後端拒絕(400／401)會清憑證並由 `bearerTokenSource.signedOut` 通知 `authStateProvider` 回到未登入
- `authStateProvider` 的身分優先取 id_token claims(驗過 `exp`／`aud`),否則落回 `currentUser()`(401 回 null 不 throw);登入後跳轉靠 router redirect(`refreshListenable` 橋接 authState 變化),LoginScreen 自己不導航
- **master 在新 api 切換前不可發版**:新認證連不上舊入口(見 ADR-0014)

## 測試慣例

三層鏡像 `lib/`:models(純 fromJson + edge case)、api(`http_mock_adapter` + `InMemoryOAuthTokenStore`,不碰 `SecureOAuthTokenStore` 的真平台通道)、screens(widget test + `ProviderScope` override,mocktail mock repository,假 GoRouter 當導航探針)。具體手法、provider override 與假綠燈防呆見 `CODING_STANDARDS.md`「測試規範」「測試不可假綠」。

## Agent skills

### Issue tracker

Issues 與 PRD 使用 GitHub Issues（`raychiutw/trip-planner.flutter`），透過 `gh` CLI 操作。詳見 `docs/agents/issue-tracker.md`。

### Triage labels

使用預設五種 triage labels：`needs-triage`、`needs-info`、`ready-for-agent`、`ready-for-human`、`wontfix`。詳見 `docs/agents/triage-labels.md`。

### Domain docs

採 single-context 架構。根目錄 `GLOSSARY.md` 是**詞彙表**(只定義語彙,不寫實作細節),由 `/grill-with-docs` 驅動的 `/domain-modeling` 隨討論即時更新;`docs/adr/` 按需建立,只有「難以逆轉 + 沒 context 會困惑 + 真實 trade-off」三者皆備才開。詳見 `docs/agents/domain.md`。
