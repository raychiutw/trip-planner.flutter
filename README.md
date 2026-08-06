# Tripline Flutter

[trip-planner](https://github.com/raychiutw/trip-planner) React SPA 的 **iOS / Android 移植版**。後端共用同一套 Cloudflare Pages Functions API（`https://trip-planner-dby.pages.dev/api`），本 repo 只是另一個 client。

## 功能狀態

**P0（已完成）**
- 登入（email/密碼 → `tripline_session` cookie，flutter_secure_storage 持久化）
- 4-tab Liquid Glass shell（聊天 / 行程 / 地圖 / 收藏）— go_router StatefulShellRoute + auth redirect；帳號由各內容頁 Header 開啟獨立 Navigation Stack sheet
- 行程清單（中性 grouped surface、pull-to-refresh、尾端左滑刪除，並保留長按操作）
- 行程時間軸（單層 day selector、D1 單 rail、單行起訖時間、Google 分類、travel pill）
- 行程地圖（原生 Google Maps、逐日 marker、路線 polyline、day tabs、entry cards 同步）
- 行程筆記（航班/住宿/預訂/行前/緊急 5-section accordion，支援新增、編輯、刪除與排序）
- 帳號（profile、通知、登入裝置、隱私權政策、不可復原刪除與登出；外觀跟隨系統）
- 未登入首頁（功能導覽、隱私權政策入口與登入後開始使用）

**P1（已完成）**：收藏 + 探索、Entry CRUD 表單群、建立/編輯行程、AI 聊天、全域地圖、共編邀請。
**P2（已完成）**：分享/列印/匯入、設定子頁、通知偏好 toggle、OAuth PKCE Bearer 認證（production `tripline-mobile` public client 已 provision）、離線快取。

## 開發

```bash
flutter pub get
flutter test       # 全部測試
flutter analyze
flutter run        # 連 prod API（注意：請用測試帳號）
```

## 架構

```
lib/
  theme/        # iOS 系統語意色 tokens + Light／Dark／High Contrast ThemeData
  models/       # Trip/Day/Entry/Notes/User —— camelCase wire fromJson
  api/          # dio 封裝（Bearer／cookie、Origin CSRF、429 retry、204）+ repositories + riverpod providers
    cache/      # drift 永續快取、離線佇列、樂觀更新與 rebase 合併
  ui/           # Tp* 共用 widget（TpAppBar／TpGlassSurface／TpStateView…）
  app/          # go_router（4-tab StatefulShellRoute、Account sheet + auth redirect）
  features/     # account / auth / chat / favorites / invite / map / offline
                # / share / shell / trip_detail（timeline·map·notes）/ trips
docs/
  adr/          # 架構決策與被拒方案（13 份）
  agents/       # agent 用的 issue tracker／triage labels／domain docs 設定
  mobile-e2e.md # Patrol／Firebase Test Lab 與發布 runbook
```

## 文件

| 想做什麼 | 看哪份 |
|---|---|
| 貢獻流程、環境設定與 PR 規矩 | [CONTRIBUTING](CONTRIBUTING.md) |
| **程式碼該怎麼寫（全部規範）** | **[CODING_STANDARDS](CODING_STANDARDS.md)** |
| 懂分層與依賴方向 | [CODING_STANDARDS § 分層與依賴方向](CODING_STANDARDS.md#分層與依賴方向) |
| 新增 API endpoint | [CODING_STANDARDS § API 層規範](CODING_STANDARDS.md#api-層規範) |
| 查 model 欄位與 fromJson 解析規則 | [CODING_STANDARDS § Model 與 fromJson 解析規則](CODING_STANDARDS.md#model-與-fromjson-解析規則) |
| 新增畫面、導覽玻璃與鍵盤 | [CODING_STANDARDS § 畫面撰寫規範](CODING_STANDARDS.md#畫面撰寫規範) · [§ 導覽玻璃與鍵盤](CODING_STANDARDS.md#導覽玻璃與鍵盤) |
| 寫測試（provider override、不可假綠） | [CODING_STANDARDS § Provider 與測試 seam](CODING_STANDARDS.md#provider-與測試-seam) · [§ 測試規範](CODING_STANDARDS.md#測試規範) · [§ 測試不可假綠](CODING_STANDARDS.md#測試不可假綠) |
| 查 UI／UX 規範（iOS HIG） | [design.md](design.md) · [CODING_STANDARDS § UI 規範](CODING_STANDARDS.md#ui-規範) |
| 查領域詞彙（停留點、正選／備選 POI、工單） | [CONTEXT.md](CONTEXT.md) |
| 理解架構決策與被拒方案 | [docs/adr/](docs/adr/)（13 份） |
| 跑 Patrol／Firebase Test Lab、發布 TestFlight／Google Play | [docs/mobile-e2e.md](docs/mobile-e2e.md) |
| 設定 agent 的 issue tracker／triage labels／domain docs | [docs/agents/](docs/agents/) |
| 看變更紀錄 | [CHANGELOG](CHANGELOG.md) |
| 找待辦、spec 與 PRD | [GitHub Issues](https://github.com/raychiutw/trip-planner.flutter/issues) |

技術棧：Flutter 3.44.7 stable / Dart 3.12.2（pubspec `sdk: ^3.11.3`）、flutter_riverpod 3、go_router 17、dio 5、google_navigation_flutter 0.10。

## API client 關鍵行為（與 web `src/lib/apiClient.ts` 對齊）

- 雙軌認證：有 Bearer access token 就走 Bearer 模式（帶 `Authorization: Bearer …`，不送 Cookie／Origin，後端對此跳過 CSRF 檢查）；否則走 cookie 模式，帶 `Cookie: tripline_session=…`
- cookie 模式的 mutating request 一律帶 `Origin`，值為 `kTriplineOrigin`（`String.fromEnvironment('TRIPLINE_API_ORIGIN')`，預設 `https://trip-planner-dby.pages.dev`）—— 後端 CSRF Origin allowlist，缺少 → 403
- Bearer 模式收到 401 會先嘗試 refresh，成功才用同參數重送一次
- 429 讀 `Retry-After`（cap 30s）只 retry GET 一次；mutation 不 retry
- 錯誤 shape `{error:{code,message,detail}}`；204 → null

## 設計

Flutter 的互動與版型以根目錄 [`design.md`](design.md) 為唯一設計 SOT，[CODING_STANDARDS § UI 規範](CODING_STANDARDS.md#ui-規範)只補充實作方式。方向是保留單一柔褐 tint，內容使用 iOS 系統語意 surface、Apple Music 的內容階層、Liquid Glass 功能層與 Apple HIG 平台慣例；舊三色內容分類已退場。
