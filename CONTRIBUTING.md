# 貢獻指南

個人專案,但流程照團隊標準走。讀完這頁就能開工。

本頁只談**怎麼參與**:環境、流程、PR 規矩。**程式碼該怎麼寫在 [`CODING_STANDARDS.md`](CODING_STANDARDS.md)** —— 那份是 `code-review` Standards 軸的主要依據,動手前先讀。UI／UX 規範在 [`DESIGN.md`](DESIGN.md),領域詞彙在 [`CONTEXT.md`](CONTEXT.md),架構決策的理由與被拒方案在 [`docs/adr/`](docs/adr)。

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
2. **TDD 紅綠重構** — 任何 production code 變更先寫失敗測試;修 bug 先寫重現測試。見 [`CODING_STANDARDS.md`](CODING_STANDARDS.md) 的〈測試規範〉與〈測試不可假綠〉
3. **完成定義** — `flutter analyze` 零 error/warning、`flutter test` 全綠、新增 public class/method 有 `///` 文件註解
4. **開 PR** — commit message 與 PR 一律繁體中文(台灣用語),技術名詞保留英文
5. **同步文件** — 編碼規範改 `CODING_STANDARDS.md`;UI／UX 規範改 `DESIGN.md`;難以逆轉且有真實被拒方案的決策開 ADR;領域詞彙進 `CONTEXT.md`;使用者可感知的變更補進 `CHANGELOG.md` 的 `[Unreleased]`

**待辦、規格與 PRD 一律走 GitHub Issues**,不用檔案追蹤。完整的 agent 工作流規定見 [`CLAUDE.md`](CLAUDE.md) 與 [`AGENTS.md`](AGENTS.md)。
