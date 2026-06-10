# 設計:探索(ExploreScreen)+ 加入行程(AddToTrip)

> 日期:2026-06-11
> 狀態:已批准方向(2 PR、不簡化),待 review spec
> 來源任務:P1「收藏 + 探索」decompose 後的第 2、3 子專案
> 契約來源:web public repo `raychiutw/trip-planner`(前端呼叫 + 後端 handler 雙向交叉驗證,非推測)

## 背景

收藏清單(PR #3)已完成但**沒有新增收藏的入口**。探索(ExplorePage)是新增收藏的主入口(搜尋 POI → heart 收藏);加入行程把 POI/收藏放進行程某天。後端契約在 discovery 原本沒記錄,已從 web 原始碼補齊(見「後端契約」)。

## 交付邊界(一份 spec、兩個 PR、兩個 plan)

- **PR-A 探索**:後端契約用到的 poi-search / find-or-create / poi-favorites POST;PoiSearchResult model;poiType 映射;PoiRepository;FavoritesRepository.addFavorite;ExploreScreen 完整 UI(不簡化,POI card 只含 heart 收藏)。
- **PR-B 加入行程**:ApiError payload 改造;add-to-trip(favorite mode)+ entries POST(direct mode);AddToTripScreen + 409 ConflictDialog;`/add-to-trip` route;收藏清單 card 與探索 POI card 的「加入行程」入口(此時 route 已存在)。

## 目標 / 非目標

**目標**:探索搜尋 + 收藏 toggle(閉環:搜尋→收藏→收藏清單);加入行程(收藏 mode + 探索 direct mode)。對齊 web ExplorePage 行為(不簡化)。

**非目標**:不做共編 / 全域地圖;不重寫後端;不做 web 退役的批次選取 checkbox;不做 region 的 server-side locationBias 表(那是後端的事,client 只送中文城市名)。

---

## 後端契約(雙向驗證,保存供兩個 PR)

### GET /api/poi-search(PR-A)
- query:`q`(trim 2–200 字必填,<2 → 400 `DATA_VALIDATION`)、`limit`(1–20,預設10;前端固定 20)、`region`(中文城市名,「全部地區」/空則**省略**整個參數)。
- response:`{ results: PoiSearchResult[] }`。item **snake_case**:`place_id`(必)、`name`(必)、`address?`、`lat`/`lng`、`category?`(Google primary type)、`country?`、`country_name?`、`rating?`、`business_status?`。
- 錯誤:400 / 429 `RATE_LIMITED`(Retry-After,GET 自動 retry 1 次)/ 502 `MAPS_UPSTREAM_FAILED` / 503 `MAPS_LOCKED`。

### POST /api/pois/find-or-create(PR-A,需登入)
- body **全 snake_case**:`name`(必)、`type`(必,**須過 poiType 映射**成 whitelist 值否則 503)、`lat?`、`lng?`、`address?`、`category?`(原始 Google type,原樣存)、`source`(預設 `'user-explore'`)、`place_id?`。
- response:`{ id: number }`(後端 pois PK = poiId)。
- 錯誤:400 / 401 / 503(type constraint)。

### POST /api/poi-favorites(PR-A,連帶)
- body **camelCase** `{ poiId }`(把 find-or-create 回的 id 當 poiId)。重複 409 / POI 不存在 404。
- 取消:`DELETE /api/poi-favorites/:id` → 204(已在收藏清單實作)。

### POST /api/poi-favorites/:id/add-to-trip(PR-B,favorite mode,`:id`=favorite id)
- body **全 camelCase**:`tripId`(必,String)、`dayNum`(必,1-based int)、`startTime`/`endTime`(**必填** `HH:MM`,空字串會 400;web 型別寫選填是陷阱)。廢除 `position`/`anchorEntryId`(送了 400)。
- response 201:`{ ok, entryId, dayId, sortOrder, startTime, endTime, note }`。
- **409 CONFLICT**:body `{ error:'CONFLICT', conflictWith:{ entryId, time?, title, dayNum } }`(`time` 是 `"HH:MM-HH:MM"` 或單一或 null)。
- 錯誤:400 / 401 / 403 `PERM_DENIED` / 404 `DATA_NOT_FOUND` / 409 / 429。

### POST /api/trips/:id/days/:num/entries(PR-B,direct mode = 探索 POI 直接加入)
- body(snake_case,api-auth.md:44):`title`(必)、`poi_type?`、`description?`、`note?`、`lat?`、`lng?`、`rating?`、`sort_order?`、`start_time?`/`end_time?`、`source?` → 201 entry row;後端自動 find-or-create POI + master 綁定。

---

## A. 資料層

- **model `PoiSearchResult`**(`lib/models/poi_search_result.dart`,**snake_case** fromJson):placeId/name/address?/lat/lng/category?/country?/countryName?/rating?/businessStatus?(enum operational/closedTemporarily/closedPermanently)。寬鬆解析;UI 過濾無效列(place_id/name 缺)。
- **`lib/models/poi_type.dart`**:移植 `mapGooglePrimaryTypeToPoiType`(Dart regex,順序敏感:hotel→parking→transport→activity→restaurant→shopping→attraction,fallback `attraction`;whitelist passthrough)+ `kPoiTypeLabels`(restaurant 餐廳/attraction 景點/shopping 購物/hotel 飯店/parking 停車/transport 交通/activity 活動/other 其他)。pure function。
- **`PoiRepository`**(`lib/api/poi_repository.dart`):`searchPois({required q, int limit=20, String? region, CancelToken? cancelToken})`(GET poi-search,region「全部地區」/null 省略)、`findOrCreatePoi({...snake-case...})` → int poiId。
- **擴充 `FavoritesRepository`**:`addFavorite(int poiId)`(POST `{poiId}`)。(PR-B 再加 `addFavoriteToTrip`、`addPoiToTripDirect`)
- **`ApiError` 改造(PR-B)**:加 `final Map<String, dynamic>? payload`(原始 body),`fromResponse` 保留;既有 `api_error_test` 不破(nullable 預設 null)。供 409 讀 `payload['conflictWith']`。

## B. 探索 UI(PR-A,`lib/features/favorites/explore/`,對齊 web 不簡化)

- **`ExploreScreen`**(ConsumerStatefulWidget):
  - **region pill + popover**:6 預設(全部地區/沖繩/東京/京都/首爾/台北)+「+ 自訂地區…」(對話框自由文字;空/「全部地區」→ 省略 region)。自訂值插入清單第 2 位去重。
  - **搜尋 bar**:submit-based(Enter / 搜尋鈕),最少 2 字(<2 → SnackBar「至少輸入 2 個字」),`limit=20`,**無 debounce**。防 race:dio `CancelToken` 取消上一筆 + sequence guard(只認最後一次)。搜尋中按鈕「搜尋中…」+ disabled + 舊結果保留。
  - **mount auto-search seed**:進頁自動搜「東京」(region 非全部地區則搜 region 名),只跑一次。
  - **分類 chips（5,client-side regex filter,比對原始 `category`)**:為你推薦(all=全收不排序)/景點(`attract|museum|park|temple|景點|公園`)/美食(`restaurant|cafe|food|bar|bakery|餐|食`)/住宿(`hotel|hostel|guest|inn|住宿|飯店`)/購物(`shop|mall|market|購物`)。
  - **4 種狀態**:① 結果 grid（標題:query≥2「搜尋結果」否則「推薦景點」+「N/M 個景點 · 點愛心加入收藏」）② 有 query 無果「沒有找到「{q}」的結果。換個關鍵字試試?」③ auto-search 無果:eyebrow「沒拿到結果」+「試試這些」+ SUGGESTED_QUERIES chips（沖繩美麗海水族館/首里城/國際通/古宇利大橋/美國村,點擊填欄即搜)④ 分類過濾 0 筆「沒有符合「{分類}」的結果。試試其他分類或回到「為你推薦」」+「回到為你推薦」鈕。錯誤走 SnackBar。
- **`PoiSearchCard`**:cover 漸層(poiType tone)+ 類型 label(`kPoiTypeLabels[map(category)]`)+ name + address(2 行)+ rating（僅有值 `★ x.x`）+ **heart toggle**(右上)。(「加入行程」鈕 PR-B 才加,連同 `/add-to-trip` route,避免 PR-A 導向尚未存在的 route。)
- **收藏狀態**:進頁 `listFavorites` 建 `Map<"poiType::name", favoriteId>`(key 用**映射後** poiType);heart 已收藏判斷查 map。未收藏→`findOrCreatePoi`→`addFavorite`→重抓 map;已收藏→`removeFavorite(favoriteId)`→重抓。toggle 中該卡 disabled。
- **providers**:`exploreControllerProvider`(`Notifier`,riverpod 3.x;管 query/region/category/results/searching/savedMap 狀態,命令式 `search()`/`toggleFavorite()`/`setRegion()`/`setCategory()`);沿用既有 riverpod 風格。

## C. 加入行程 UI(PR-B,`lib/features/favorites/add_to_trip/`,fullpage 對齊 web)

- **`AddToTripScreen`** 支援 2 mode:
  - **favorite mode**(從收藏 card `/favorites/:id/add-to-trip`):`addFavoriteToTrip(favoriteId, tripId, dayNum, startTime, endTime)`。
  - **direct mode**(從探索 POI `/add-to-trip?place_id&name&lat&lng[&address&category]`):POST `/trips/:tripId/days/:dayNum/entries`(snake-case body:title=name、poi_type=map(category)、lat/lng/start_time/end_time、source）。
  - 共用 UI:選 trip(`myTripsProvider`)→ 選 day(該 trip days)→ `startTime`/`endTime`(TimePicker,**送出前驗 `^([01]\d|2[0-3]):[0-5]\d$`**)→ 送出。
- **409 conflict**(favorite mode):catch `ApiError.status==409` → 讀 `payload['conflictWith']` → `ConflictDialog`(顯示衝突 entry 時間/標題,提示改時間重試)。
- 成功 → SnackBar + 返回。

## D. Router + 入口

- PR-A:`/explore`(收藏 tab branch 下,active 歸收藏);收藏清單 AppBar 加「探索」action → `/explore`。探索 POI card PR-A 只有 heart(收藏);「加入行程」入口 PR-B 才加。
- PR-B:`/favorites/:id/add-to-trip`(favorite mode)+ `/add-to-trip`(direct mode,query 帶 POI);收藏 card 加「加入行程」。

## E. 測試(TDD)

- **PR-A**:`poi_search_result` fromJson;`mapGooglePrimaryTypeToPoiType`(各類別 regex + whitelist passthrough + fallback);`PoiRepository`(searchPois query 組裝 / region 省略 / find-or-create body snake-case);`FavoritesRepository.addFavorite`;`PoiSearchCard`(欄位 / rating 條件 / heart 狀態);`ExploreScreen`(搜尋 submit / <2字 / 分類 filter / 4 狀態 / heart toggle find-or-create+favorite / CancelToken 防 race)。
- **PR-B**:`ApiError` payload 保留;`addFavoriteToTrip`(201 / 409 帶 conflictWith);entries POST(direct);`AddToTripScreen`(選 trip/day/時間 / 時間驗證 / 送出 / 409 ConflictDialog);收藏 card 加入行程入口。

## F. 風險

1. **poi-search 實際 response 是否含 rating/business_status** — 後端 handler doc 沒列這兩個(型別有)。fromJson 寫寬鬆(nullable),真機跑一次 search 確認;rating 缺則卡片不顯示。
2. **direct mode 與 favorite mode 共用 AddToTripScreen 的分支複雜度** — 用 sealed/enum mode 參數清楚切。
3. **mapGooglePrimaryTypeToPoiType regex 移植** — Dart 與 JS regex 邊界語意(`(?:^|_)x(?:_|$)`)需逐一測試對齊;測試覆蓋每個 pattern 代表值。

## 驗收條件

- [ ] `flutter analyze` 0 issues、`flutter test` 全綠(PR-A、PR-B 各自)。
- [ ] 探索:搜尋(seed + 手動)、region/分類 filter、4 狀態、heart 收藏 toggle(閉環到收藏清單)皆動(mock 驗證)。
- [ ] 加入行程:favorite mode + direct mode、時間驗證、409 ConflictDialog 皆動。
- [ ] reference-navigation / reference-api / discovery(補 3 endpoint 契約)/ TODOS / CHANGELOG 更新。
