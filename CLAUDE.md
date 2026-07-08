# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 專案性質

[trip-planner React SPA](https://github.com/raychiutw/trip-planner) 的 iOS/Android 移植版(Flutter)。**後端不動**:共用同一套 Cloudflare Pages Functions API(`https://trip-planner-dby.pages.dev/api`),本 repo 只是另一個 client — 多數設計決策由此約束推導。P0(唯讀畫面)已完成;P1/P2 範圍見 `docs/PORTING_PLAN.md`。

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

- **TDD 紅綠重構**:任何 production code 變更先寫失敗測試。修 bug 先寫重現測試。
- **完成定義**:`flutter analyze` 零 error/warning + `flutter test` 全綠。
- **不直接 commit 到 `master`**:開 feature branch → `/ship` 開 PR。base branch 是 `master`(無 `main`)。
- 文件、註解、commit message 一律繁體中文(台灣用語),技術名詞保留英文。

## 架構

分層單向依賴(上層用下層):`features/` → `app/` → `api/` → `models/` → `theme/`。`models/` 是純 Dart(不 import Flutter),`theme/` 不依賴任何人。深度說明見 `docs/explanation-architecture.md`,文件索引在 README「文件」一節。

### Provider 鏈(riverpod 3.x)

`sessionStoreProvider` → `apiClientProvider` → `authRepositoryProvider`/`tripRepositoryProvider` → `authStateProvider`(全 app 認證 SoT)→ `appRouterProvider`。測試 override 鏈上任一節點即可替換下游。行程詳情的 trip/days/notes 用 `FutureProvider.family<_, String tripId>`(`lib/features/trip_detail/trip_providers.dart`)— timeline/map/notes 三畫面 watch 同一 family 實例共用 fetch,對應 web 版 TripLayout。

注意:flutter_riverpod 3.x 未匯出 `Override` 型別,測試的 overrides 直接以 list literal 傳入 `ProviderScope`。

### 認證(關鍵且非顯而易見)

後端是瀏覽器導向的 session cookie + CSRF Origin allowlist,app 扮演瀏覽器:

- 登入走 raw `client.dio` 讀 `set-cookie` 解析 `tripline_session`,存 flutter_secure_storage
- 每個 request 手動帶 `Cookie:`;**mutating request 必帶 `Origin: https://trip-planner-dby.pages.dev`**(缺少 → 403),`ApiClient` 已統一處理,不要繞過它用 raw dio 打 API
- `currentUser()` 401 回 null 不 throw;登入後跳轉靠 router redirect(`refreshListenable` 橋接 authState 變化),LoginScreen 自己不導航

### ApiClient 行為規則(每條有對應測試,改動需同步測試)

1. 非 2xx → throw `ApiError`(三層 fallback 解析,見 `api_error.dart`)
2. 429 只 retry GET 一次(讀 `Retry-After`,cap 30s);mutation 絕不 retry
3. 204/空 body → `null`
4. 路徑參數 `Uri.encodeComponent`

### Model 解析規則(所有 fromJson 一致)

wire 是 camelCase(server `deepCamel()`);數字 `(json['x'] as num?)?.toInt()/.toDouble()`(server 可能回 int 或 double);bool flag 是 0/1:`json['x'] == 1 || json['x'] == true`;日期時間存字串不轉 DateTime;list 缺漏 → `[]`;`sortOrder`/`version` 缺漏 → `0`。欄位表見 `docs/reference-models.md`。`docs/CONTRACTS.md` 是多 agent 開發的歷史契約,個別欄位以程式碼為準。

### Theme 取色守則

語意色走 `colorScheme`;三色 tone(accent=玩/看/買、sage=住/移動、pink=吃,各 4 階)走 `Theme.of(context).extension<TpTones>()!` — 不要直接引用 `TpColorsLight/Dark` 常數(會壞 dark mode)。poi_type → tone 對照在 `lib/features/trip_detail/widgets/entry_tone.dart`。設計禁忌:無 gradient 裝飾、無 emoji icon、無 rainbow 色(地圖 pin palette 是唯一例外)。

### 地圖 adapter

`flutter_map` / `latlong2` 轉接集中在 `lib/features/map/map_adapter.dart`。Feature screen 使用 `TripMapPoint`、`TripMapRoute`、`TripMapMarker` 與 `FlutterMapCanvas`;不要在 TripMap / AddEntry / GlobalMap 之類畫面直接保存 raw `LatLng`、`MapController`、`Marker`、`Polyline` 或 layer widget。

### OCC

models 帶 `version` 欄位;後端 PATCH 要 `expectedVersion`,409 `STALE_ENTRY` 時重抓再套用。Entry edit/move 與 POI mutation 目前已在畫面層重抓 entry,用最新 `version` / `entryPoisVersion` retry 同一個操作一次。

## 測試慣例

三層鏡像 `lib/`:models(純 fromJson + edge case)、api(`http_mock_adapter` + `InMemorySessionStore`,不碰 `SecureSessionStore`)、screens(widget test + `ProviderScope` override,mocktail mock repository,假 GoRouter 當導航探針)。具體手法見 `docs/howto-test-with-providers.md`。
