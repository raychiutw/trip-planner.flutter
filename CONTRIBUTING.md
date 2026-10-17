# 貢獻指南

個人專案,但流程照團隊標準走。讀完這頁就能開工。

本頁只談**怎麼參與**:環境、流程、PR 規矩。**程式碼該怎麼寫在 [`CODING_STANDARDS.md`](CODING_STANDARDS.md)** —— 那份是 `code-review` Standards 軸的主要依據,動手前先讀。UI／UX 規範在 [`DESIGN.md`](DESIGN.md),領域詞彙在 [`CONTEXT.md`](CONTEXT.md),架構決策的理由與被拒方案在 [`docs/adr/`](docs/adr)。

## 環境

```bash
flutter --version    # 發布工具鏈使用 Flutter 3.44.7 / Dart 3.12.2(pubspec: sdk ^3.11.3)
flutter pub get
flutter test         # 全綠才算環境就緒;數量以當次輸出為準
```

PDF 測試會讀取真正的輸出檔案：macOS 使用 Xcode Command Line Tools 的 Swift 與 PDFKit；Linux／Ubuntu 需先安裝 `poppler-utils`（`sudo apt-get install poppler-utils`），提供 `pdftotext` 與 `pdfinfo`。測試使用 repository 的固定中文字型，不連線下載；來源、授權及解析器說明見 [PDF 字型驗證素材](test/fixtures/fonts/noto-sans-tc/README.md)。

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
2. **TDD 紅綠重構** — 任何 production code 變更先寫失敗測試;修 bug 先寫重現測試。見 [`CODING_STANDARDS.md`](CODING_STANDARDS.md) 的〈測試規範〉與〈測試不可假綠〉
3. **完成定義** — `flutter analyze` 零 error/warning、`flutter test` 全綠、新增 public class/method 有 `///` 文件註解
4. **開 PR** — commit message 與 PR 一律繁體中文(台灣用語),技術名詞保留英文
5. **同步文件** — 編碼規範改 `CODING_STANDARDS.md`;UI／UX 規範改 `DESIGN.md`;難以逆轉且有真實被拒方案的決策開 ADR;領域詞彙進 `CONTEXT.md`;使用者可感知的變更補進 `CHANGELOG.md` 的 `[Unreleased]`

**待辦、規格與 PRD 一律走 GitHub Issues**,不用檔案追蹤。完整的 agent 工作流規定見 [`CLAUDE.md`](CLAUDE.md) 與 [`AGENTS.md`](AGENTS.md)。

## 專案導覽

從 README 移過來的開發者資訊：指令、目錄結構、文件索引與 API client 行為。

### 常用指令

```bash
flutter pub get
flutter test       # 全部測試
flutter analyze
flutter run        # 連 prod API（注意：請用測試帳號）
```

完整測試包含真正 PDF 內容驗證；平台工具需求見 [上方〈環境〉](#環境)。

### 架構

現行發布工作流未傳入 `TRIPLINE_OAUTH_CLIENT_ID`，依該工作流建置時 OAuth 登入入口不顯示；正式 HTTPS callback 尚未由 Flutter 處理。

```
lib/
  theme/        # iOS 系統語意色 tokens + Light／Dark／High Contrast ThemeData
  models/       # Trip/Day/Entry/Notes/User —— camelCase wire fromJson + 純 Dart 唯讀筆記內容投影
  api/          # dio 封裝（Bearer／cookie、Origin CSRF、429 retry、204）+ repositories + riverpod providers
    cache/      # drift 永續快取、離線佇列、樂觀更新與 rebase 合併
  ui/           # Tp* 共用 widget（TpAppBar／TpGlassSurface／TpStateView…）
  app/          # go_router（4-tab StatefulShellRoute、Account sheet + auth redirect）
  features/     # account / auth / chat / favorites / invite / map / offline
                # / share / shell / trip_detail（timeline·map·notes）/ trips
docs/
  adr/          # 架構決策與被拒方案（13 份）
  agents/       # agent 用的 issue tracker／triage labels／domain docs 設定
  research/     # 套件選擇、Apple HIG 與後端契約查核紀錄
  evidence/     # 指定議題的畫面證據
  verification/ # 互動與輔助使用驗證紀錄
  liquid-glass-1.4.1-migration.md # 1.4.1 遷移去留、真機驗收紀錄與未完成缺口
  mobile-e2e.md # Patrol／Firebase Test Lab 與發布 runbook
  navigation-glass-semantic-validation.md # 導覽玻璃語意與平台驗證紀錄
```

### 文件

| 想做什麼 | 看哪份 |
|---|---|
| **程式碼該怎麼寫（全部規範）** | **[CODING_STANDARDS](CODING_STANDARDS.md)** |
| 懂分層與依賴方向 | [CODING_STANDARDS § 分層與依賴方向](CODING_STANDARDS.md#分層與依賴方向) |
| 新增 API endpoint | [CODING_STANDARDS § API 層規範](CODING_STANDARDS.md#api-層規範) |
| 查 model 欄位與 fromJson 解析規則 | [CODING_STANDARDS § Model 與 fromJson 解析規則](CODING_STANDARDS.md#model-與-fromjson-解析規則) |
| 新增畫面、導覽玻璃與鍵盤 | [CODING_STANDARDS § 畫面撰寫規範](CODING_STANDARDS.md#畫面撰寫規範) · [§ 導覽玻璃與鍵盤](CODING_STANDARDS.md#導覽玻璃與鍵盤) |
| 寫測試（provider override、不可假綠） | [CODING_STANDARDS § Provider 與測試 seam](CODING_STANDARDS.md#provider-與測試-seam) · [§ 測試規範](CODING_STANDARDS.md#測試規範) · [§ 測試不可假綠](CODING_STANDARDS.md#測試不可假綠) |
| 查 UI／UX 規範（iOS HIG） | [DESIGN.md](DESIGN.md) · [CODING_STANDARDS § UI 規範](CODING_STANDARDS.md#ui-規範) |
| 查領域詞彙（停留點、正選／備選 POI、工單） | [CONTEXT.md](CONTEXT.md) |
| 理解架構決策與被拒方案 | [docs/adr/](docs/adr/)（13 份） |
| 查 Liquid Glass 1.4.1 遷移去留、真機驗收紀錄與未完成缺口 | [docs/liquid-glass-1.4.1-migration.md](docs/liquid-glass-1.4.1-migration.md) |
| 查導覽玻璃語意與平台驗證紀錄 | [docs/navigation-glass-semantic-validation.md](docs/navigation-glass-semantic-validation.md) |
| 查議題畫面證據與互動驗證紀錄 | [docs/evidence/](docs/evidence/) · [docs/verification/](docs/verification/) |
| 查 Apple HIG 與後端契約研究 | [docs/research/](docs/research/) |
| 跑 Patrol／Firebase Test Lab、發布 TestFlight／Google Play | [docs/mobile-e2e.md](docs/mobile-e2e.md) |
| 設定 agent 的 issue tracker／triage labels／domain docs | [docs/agents/](docs/agents/) |
| 看變更紀錄 | [CHANGELOG](CHANGELOG.md) |
| 找待辦、spec 與 PRD | [GitHub Issues](https://github.com/raychiutw/trip-planner.flutter/issues) |

技術棧：Flutter 3.44.7 stable / Dart 3.12.2（pubspec `sdk: ^3.11.3`）、flutter_riverpod 3、go_router 17、dio 5、google_navigation_flutter 0.10。

### API client 關鍵行為（與 web `src/lib/apiClient.ts` 對齊）

- 雙軌認證：有 Bearer access token 就走 Bearer 模式（帶 `Authorization: Bearer …`，不送 Cookie／Origin，後端對此跳過 CSRF 檢查）；否則走 cookie 模式，帶 `Cookie: tripline_session=…`
- cookie 模式的 mutating request 一律帶 `Origin`，值為 `kTriplineOrigin`（`String.fromEnvironment('TRIPLINE_API_ORIGIN')`，預設 `https://trip-planner-dby.pages.dev`）—— 後端 CSRF Origin allowlist，缺少 → 403
- Bearer 模式收到 401 會先嘗試 refresh，成功才用同參數重送一次
- 429 與 edge block page 只 retry GET／HEAD 一次；Bearer 401 refresh 成功後則不分 method，以同參數重送一次
- 錯誤 shape `{error:{code,message,detail}}`；204 → null

### 設計

Flutter 的互動與版型以根目錄 [`DESIGN.md`](DESIGN.md) 為唯一設計 SOT，[CODING_STANDARDS § UI 規範](CODING_STANDARDS.md#ui-規範)只補充實作方式。方向是保留單一柔褐 tint，內容使用 iOS 系統語意 surface、Apple Music 的內容階層、Liquid Glass 功能層與 Apple HIG 平台慣例；舊三色內容分類已退場。
