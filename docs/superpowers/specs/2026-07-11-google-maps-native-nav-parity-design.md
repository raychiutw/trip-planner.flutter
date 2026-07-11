# 設計:Google Maps SDK + Apple 原生導覽 + Web 功能補齊

- 日期:2026-07-11
- 狀態:草案(待使用者 review)
- 分支基準:`master`(現有 `fix/timeline-recompute-use-after-dispose` 先落地,見 §9)

## 1. 背景與目標

trip-planner Flutter 是 [web React SPA](https://github.com/raychiutw/trip-planner) 的 iOS/Android 移植,後端共用。本次一次處理使用者提出的四件事,收斂成三個工作流:

1. **讀 web commit 補功能** → WS-B(經比對後範圍很小,見 §6)
2. **地圖改用 Google Maps SDK** + **地圖功能對齊 web** → WS-C(主工程)
3. **標題位置/捲動效果對標 Apple app** → WS-A

## 2. 範圍拆解與順序

| 工作流 | 內容 | 規模 | PR |
| --- | --- | --- | --- |
| WS-A | 導覽/標題/捲動統一(adaptive iOS 原生) | 中 | 1 條(可含 WS-B) |
| WS-B | 交通方式文字 label + 手動覆寫指示 | 小 | 併入 WS-A PR |
| WS-C | 地圖 → google_maps_flutter + 功能對齊 | 大 | 分階段 stacked(C1/C2/C3) |

**順序**:先落地現有分支 → WS-A(建立 nav 殼)→ WS-B → WS-C(新畫面套 nav 殼)。WS-A 先行,讓 WS-C 的地圖/明細頁直接套用統一 nav。

## 3. 決策記錄

- **D1 = iOS 原生大標題(adaptive)**:iOS 用 `CupertinoSliverNavigationBar`,Android 用 Material `SliverAppBar.large`,收進既有 `lib/app/adaptive.dart` 架構。
- **D2 = 真實道路折線**:地圖路線打後端 `/api/route`(見契約),不畫直線。
- **D3 = iOS 最低版本 13 → 15**:GoogleMaps pod 硬需求,2026 幾無裝置影響。
- **D4 = 先落地現有分支**:`ab72153`(sync timeline)+ iOS HIG 補強共 ~20 commit 未 merge,先收斂成 PR,避免 parity 工作被拆散。

### `/api/route` 契約(已查證 `functions/api/route.ts`)
- 請求:`GET /api/route?from=lng,lat&to=lng,lat`(**lng,lat** 順序)
- 回應:`{ polyline: [[lat,lng],...], duration: number|null, distance: number }`(polyline 後端已解碼為 lat/lng)
- 失敗:502 `MAPS_UPSTREAM_FAILED` / 503 `MAPS_LOCKED` → web **不** fallback 直線,隱藏該段折線
- Flutter:GET → 直接走現有透明快取(`api_client.dart` `cacheKeyFor('GET', path, query)`),**不自建快取**;失敗語意同 web(該段無折線)

## 4. WS-A|導覽/標題/捲動系統

### 問題
只有 `trips_list`/`favorites`/`account` 用 `SliverAppBar.large`,其餘 20+ 畫面全陽春 `AppBar`,捲動行為不一、明細頁上方留白突兀。

### 設計:三種畫面類別,各一種 iOS 慣例

- **C1 根層清單頁**(`trips_list`、`favorites`、`account`):大標題,捲動平滑收合成 inline + scroll-under 模糊。iOS `CupertinoSliverNavigationBar`(支援 large title + 底部搜尋/篩選列),Android `SliverAppBar.large`。
- **C2 沉浸式全螢幕**(`global_map`、`chat`):**無**大標題,inline 半透明標題列(地圖/對話填滿,對標 Apple Maps / Messages)。維持現狀類別但統一 nav 外觀。
- **C3 推入明細/表單頁**(`edit_trip`、`create_trip`、`entry_poi`、`trip_notes`、`trip_print`、`share`、`collab`、`oauth_consent`、account 設定子頁、`add_to_trip`、`explore`、`trip_timeline`、`trip_map` 等):標準 inline 標題 + 返回鈕,捲動時 scroll-under 模糊,**移除**多餘上方留白。

### 元件(擴充 `lib/app/adaptive.dart`)
- `AppLargeTitleScaffold({title, actions, slivers, bottom?})` — C1 用。iOS `CustomScrollView` + `CupertinoSliverNavigationBar(largeTitle:)`;Android `SliverAppBar.large`。吸收既有 3 頁重複碼。
- `AppInlineNavBar`(或沿用 `AppBar` + 統一設定 helper)— C3 用。iOS 走 Cupertino 風 inline(置中標題、chevron 返回、blur),Android Material。統一高度與 `centerTitle` adaptive。
- C2 維持各自 Scaffold,只把標題列換成 `AppInlineNavBar` 的半透明版。

### 驗收
- 三類畫面各自捲動行為一致、可預期。
- 明細頁無異常上方留白。
- iOS 大標題有原生收合 + 模糊;Android 維持 Material large。
- 既有 large-title 測試(`findsWidgets` 雙渲染 gotcha)沿用。

## 5. WS-A 受影響檔案(概覽,細節交 plan)
- 新增/擴充:`lib/app/adaptive.dart`
- C1:`lib/features/trips/trips_list_screen.dart:266`、`lib/features/favorites/favorites_screen.dart:28`、`lib/features/account/account_screen.dart:37`(改用共用 scaffold)
- C3:§4 列出的 ~18 個 `appBar: AppBar(...)` 畫面改用 `AppInlineNavBar`
- 測試:各畫面 widget test 斷言標題/返回鈕存在;平台解析為 Apple 時的 Cupertino 分支處理(見既有 gotcha)

## 6. WS-B|Web 功能補齊

經 subagent 逐檔比對,web 7 項新功能 **6 項已在現有分支落地**。只剩:

### DO-1|交通方式文字 label(必做)
- 問題:地鐵/火車/高鐵/單軌共用同一 train icon,無文字 → 時間軸分不出(`lib/features/trip_detail/widgets/travel_pill.dart:63-95`)。
- 做法:抽共用 `travelMethodLabel(mode, submode)`(對照 web `src/lib/travelMode.ts`),SoT 從 `travel_edit_sheet.dart:20-35` 私有 `_methods` 提出到共用檔(如 `lib/models/travel_method.dart`),pill 與 sheet 共用。pill label 前置方式名(「地鐵 · 25 分鐘 · 3 km」),`other` 用 submode 自由文字。sameplace 維持現狀。

### DO-2|手動覆寫指示(選配)
- `travel.source == 'manual'` 時 pill 加 `Icons.lock_outline`(**不用 emoji**,遵設計禁忌)。先確認 web 是否真顯示鎖標,否則跳過。

### 不做
- 就地改時間 chip(架構取捨,編輯 sheet 已等價覆蓋)。

## 7. WS-C|地圖 → Google Maps SDK + 功能對齊

### C1|SDK 底座(先維持現有功能不退化)
- **依賴**:`pubspec.yaml` 加 `google_maps_flutter: ^2.12.1`;移除 `flutter_map`、`latlong2`(僅 `map_adapter.dart` 用)。
- **iOS**:`ios/Runner/AppDelegate.swift` 加 `GMSServices.provideAPIKey`;三處 `IPHONEOS_DEPLOYMENT_TARGET` 13 → 15、解註 `Podfile` `platform :ios, '15.0'`。
- **Android**:`AndroidManifest.xml` `<application>` 內加 `com.google.android.geo.API_KEY` meta-data(`${MAPS_API_KEY}` placeholder);確認 `minSdk >= 21`。
- **API key(不進版控)**:iOS 走未追蹤的 `Secrets.xcconfig`(`.gitignore`),`AppDelegate` 從 `Bundle` 讀;Android 走 `local.properties` + `manifestPlaceholders`。iOS/Android **兩把分開**(綁 bundle id / SHA-1)。提供 `*.example` 範本 + README 說明。
- **`map_adapter.dart` 重寫**(保留 `TripMapPoint`/`TripMapRoute`/`TripMapMarker` 抽象,換底層):
  - `FlutterMapCanvas` → `GoogleMap` widget(`initialCameraPosition` + `onMapCreated`)
  - `FlutterTripMapController` 包 `GoogleMapController`,**async ready gate**(map 未 layout 前 `newLatLngBounds` 會 throw);`fitPoints` → `animateCamera(newLatLngBounds)`,單點改 `newLatLngZoom`;`move` → `animateCamera(newLatLngZoom)`(原生帶動畫,更接近 web flyTo)
  - tile presets → `GoogleMap.mapType`(normal/satellite/hybrid;丟棄 OSM/OTM/Esri URL)
  - `onTap` → `GoogleMap.onTap`
- **關鍵風險 — 彩色序號 pin(Widget → BitmapDescriptor)**:Google `Marker` 只吃 `BitmapDescriptor`。做法:runtime `ui.PictureRecorder` + `Canvas` 畫圓/白邊/置中數字 → `toImage` → `toByteData(png)` → `BitmapDescriptor.bytes`。**依 `devicePixelRatio` 放大繪製**(retina 不糊);以 `(color, number, state)` 為 key 快取復用;markers async 備妥後 `setState`(先空集合)。抽成 `lib/features/map/marker_bitmap.dart` 純函式(可 golden test)。

### C2|功能對齊 web(打勾式增量)
現有 Flutter 行程圖差距(subagent 查證):
- **[缺,重大] per-day 路線折線**:目前完全無折線。每段打 `/api/route`(見契約)取道路折線 → `Polyline`;失敗該段無折線(同 web)。Google `Polyline` **無 border** → 用兩條疊放(下寬深色 + 上窄色)模擬 outline;approx/交替日 `dashed`(`patterns: [Dash, Gap]`,色盲輔助)。
- **[不同] marker 狀態**:補 idle(白底 + day 色邊 + 數字)/ focused(accent 實心放大 + `zIndex` 提高)/ past(灰化)三態,對照 web `mapHelpers.ts` `markerStyle`。
- **[不同] day 配色盤**:對齊 web `dayPalette.ts`(sky/teal/amber/rose/violet/lime/orange/cyan/fuchsia/emerald),取代現 `trip_map_screen.dart:11-22`。
- **[缺] hotel pin**:住宿入 pin(index 0),對照 web `useMapData.ts:70-80`。
- **[缺] 底圖切換 FAB**:roadmap/satellite(對齊 web hybrid),取代寫死 `kTripMapTilePresets.first`。
- **[缺] fit-all + 我的位置 FAB**:fit-all 重算 bounds;我的位置需加 `geolocator` + iOS `NSLocationWhenInUseUsageDescription`(選配,可延後)。
- **[部分缺] 行程圖 pin 可點**:marker `onTap` → focus + 捲動對應卡(目前只有底部卡可點)。
- **[缺] 地圖 deep-link**:`router.dart` 加 `?day` / entry 參數,timeline map chip 帶當日/停留點跳轉(對照 web `/trip/:id/map?day=N`)。
- **[改設計] 標準 `/map` 分頁 → 「行程總覽」**(對齊 web `GlobalMapPage`,回應使用者「切換行程 + 顯示每天 POI」需求):
  - **trip picker**:頂部下拉 / sheet 切換要顯示的行程(讀使用者行程清單;沿用 `lib/features/trip_detail/trip_providers.dart` family 依 tripId 抓 days/entries)。
  - **per-day POI**:選定行程後依天分組顯示 entry pins(day 配色)+ day tabs(總覽 / DAY N),per-day 折線同 trip map(`/api/route`)。
  - **抽共用 trip-overview 核心**:pin 萃取、色盤、bounds、polyline、day tabs 一套邏輯,**trip map = 固定 tripId、`/map` = 可切換 tripId**(對照 web MapPage / GlobalMapPage 共用 hooks)。
  - **不顯示收藏**(已定案):`/map` 完全比照 **web 手機版** `GlobalMapPage` — 切換行程 + 顯示該行程每天景點與路線;收藏地點只在收藏清單頁。手機呈現參考 web mobile(底部 carousel/sheet 選日與 POI,非桌面側欄)。

### C3|測試重構
- google_maps_flutter 在 widget test 無法真渲染 → 現有 `test/.../map_adapter_test.dart`、`trip_map_screen_test.dart`、`global_map_screen_test.dart` 需改。
- 策略:
  1. 抽純邏輯做 unit test:pin 萃取、pinNumber、色盤對應、bounds 計算、bitmap cache key、`/api/route` 參數組法與 null 處理。
  2. adapter 改斷言產出的 `Set<Marker>` / `Set<Polyline>`(markerId/position/onTap、polyline points/pattern),而非找 widget tree。
  3. 保留 card / day tab / `_SelectedCard` / 空狀態 / loading / error 這些普通 widget 測試。
  4. widget test 內避免實例化 `GoogleMap`(或用 platform interface mock)。
  5. marker bitmap 加 golden test(選配)。

## 8. 測試策略(全案)
- TDD 紅綠重構:每項 production 變更先寫失敗測試(WS-B/C1/C2 邏輯層皆可測)。
- 完成定義:`flutter analyze` 零 error/warning + `flutter test` 全綠。
- 地圖 UI 層因 SDK 限制改測邏輯 + adapter 契約(§7 C3)。
- 真機 verify:WS-A/WS-B 可直接跑;**WS-C 地圖畫面需使用者提供 API key 才能驗證渲染**。

## 9. 落地與依賴
1. **先落地現有分支**:`fix/timeline-recompute-use-after-dispose`(含 timeline sync + iOS HIG)收斂成 PR merge 到 master(WS-B 六成隨之落地)。
2. WS-A + WS-B:新分支 off master,一條 PR。
3. WS-C:新分支,C1 → C2 → C3 stacked PR(或單分支分 commit)。

## 10. 風險與未決
- **API key 阻塞**:地圖真機驗證需使用者提供 iOS + Android 兩把 Maps SDK key(GCP 綁 bundle id / SHA-1);程式與原生設定用 placeholder 先寫好。
- **iOS 15 最低版本**:排除 iOS 13/14 裝置(2026 幾無影響,仍記錄)。
- **`/api/route` 計費**:走後端 Google Routes proxy,後端已有;Flutter 端只讀,受現有快取保護。
- **marker bitmap 效能**:須 cache,否則每 frame 重繪卡頓。
- **scope**:WS-C 若實作中膨脹,C2 各項可獨立取捨(deep-link / 我的位置 FAB 可延後),不影響 C1 底座落地。
- **收藏地圖去留(已定案:移除)**:`/map` 比照 web 手機版行程總覽;現有「收藏 POI 顯示於地圖」移除,收藏維持清單頁。`global_map_screen.dart` 資料源從收藏 POI 改為「trip picker 選定行程的 entries + per-day 折線」。
