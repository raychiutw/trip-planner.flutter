# 建立／編輯行程 設計 spec

> P1。Flutter client 對既有後端(`https://trip-planner-dby.pages.dev/api`)的建立/編輯行程表單。
> 設計決策由後端契約 + web UX 推導。delete 已存在(行程清單長按)。

## 目標

讓行程清單從「唯讀 + 刪除」變成可**建立**(對齊 web 的目的地優先流程)與**編輯**(後端 PUT 收的基本欄位)。一個 PR,內部分 3 phase。

## 後端契約(權威來源,已查 web repo)

### 建立 `POST /api/trips` → 201 `{ok, tripId, daysCreated, destinationsCreated}`(不回整列)
- 必填:`id`(client 產 slug,`^[a-z0-9-]+$`,≤100,重複→409)、`name`(非空)、`startDate`、`endDate`(`YYYY-MM-DD`)。
- 選填(server 有預設):`title`、`description`、`countries`(預設 `JP`,逗號串)、`published`(POST 預設 0)、`data_source`(預設 `manual`)、`lang`(預設 `zh-TW`)、`destinations[]`。
- `destinations[]` 每筆(**snake_case**):`name`(必,無 name 者被濾掉)、`lat`、`lng`、`day_quota`、`sub_areas`(string[]→JSON)。server 自動排 `dest_order`。`place_id` 被忽略。
- request body **不** camelCase(只有 response 會);所以送 `data_source`、`day_quota`、`sub_areas`。
- 驗證:日期格式 `^\d{4}-\d{2}-\d{2}$`、`endDate≥startDate`、總天數 ≤30、`lang∈{zh-TW,en,ja}`、`data_source∈{manual,tp-create,imported}`、`destinations`≤30。
- 副作用:自動建好 `[startDate,endDate]` 每日 `trip_days` + owner 權限 + 5 個空 doc stub。**不需自己建 days**。

### 編輯 `PUT /api/trips/:id`(是 PUT 非 PATCH)→ 200 `{ok}`
- 白名單欄位:`name`、`title`、`description`、`countries`、`published`、`data_source`、`lang` + `destinations`(全量替換:給陣列→刪光重建;給 `[]`→清空;不給→不動)。
- **diff-only**:只送有改的 key。無有效欄位 → 400。
- **日期/天數不在 PUT 內**(在 `trip_days`,要另走 `/days` 端點)→ 本功能編輯期不動日期(日管理另案)。
- **無 OCC**:trips 表無 `version`,last-write-wins,**不要送 `expectedVersion`**。
- 權限:viewer 擋(403);owner/admin/member 可改。

### 刪除 `DELETE /api/trips/:id`
已實作(`tripRepository.deleteTrip`,行程清單長按)。本功能不動。

## 範圍

### 建立(對齊 web,full parity)
1. **目的地優先**:POI 搜尋(重用 `PoiRepository.searchPois`)多選 + 拖曳排序 + 熱門目的地 chips。≥1 必填。
2. **日期模式**(segmented):
   - 固定:起 + 訖日期(訖 `min=起`)。
   - 彈性:天數 stepper(1–30,預設 5)+ 未來 6 個月 chips;起 = 該月 1 號,訖 = 起 + (天數−1)。
3. **每地天數分配**(≥2 目的地時顯示):per-destination stepper,提示總和=總天數;送 `day_quota`。
4. **想做什麼**:preferences textarea(≤2000)→ `description`。
5. 送出衍生:`name`=目的地名以「、」串接;`id`=`genTripId(name)`;`countries`=目的地 `country` 去重(fallback `JP`);`published:1`;`data_source:'manual'`;`lang:'zh-TW'`。

### 編輯(PUT 欄位)
目的地(可加 / 拖曳排序 / 移除)、title、description、lang(select)、published(toggle)。**明確「儲存」鈕**(非 web 的自動存檔):送 diff-only PUT;destinations 有改則一併重算 `countries`。不動 `name`/日期。

### 不在範圍(明列)
- 日期/天數編輯(日管理:`/days` add/remove/shift)— 另案。
- `最近搜尋`持久化(web localStorage)— 需新 dep,v1 略過;熱門 chips 保留。
- `sub_areas`、彈性日期的「分配折進 description」web 小 quirk — 只送 `day_quota`,description = preferences。
- travel mode/self-drive(web 已移除的 dead columns)。

## 架構(分層沿用既有單向依賴)

### Phase 0 — API / models / 純函式
- `lib/models/destination_input.dart`:`DestinationInput{name, lat?, lng?, country?, dayQuota?}`(表單值型別;附 `fromPoi(PoiSearchResult)`)。
- `lib/api/trip_repository.dart`:
  - `createTrip({id, name, startDate, endDate, title?, description?, countries, published, dataSource, lang, destinations})` → POST `/trips`,回 `({tripId, daysCreated, destinationsCreated})`。
  - `updateTrip(id, {name?, title?, description?, countries?, published?, dataSource?, lang?, destinations?})` → PUT `/trips/:id`,**只放非 null 的 key**(null-aware map),destinations 給了才送。無 expectedVersion。
- `lib/features/trips/trip_form_logic.dart`(純函式,可單測):
  - `slugify(String)`、`genTripId(String name, int nowMillis)`(`slugify-base36(now).last4`;slug 空→`trip-<suffix>`;≤100)。
  - `deriveTripName(List<DestinationInput>)`(「、」串接)、`deriveCountries(List<DestinationInput>)`(去重 join,fallback `JP`)。
  - `flexibleRange(int year, int month, int dayCount)` → `(start, end)` 字串。
  - `tripDayCount(String start, String end)`、`isTripDatesValid(...)`(格式 + 順序 + ≤30)。
- `pubspec.yaml`:加 `flutter_localizations`(zh-TW 日期選擇);app `MaterialApp.router` 補 `localizationsDelegates`/`supportedLocales`(zh-TW/en/ja)。

### Phase 1 — 建立流程
- `lib/features/trips/create/create_trip_controller.dart`:`NotifierProvider<CreateTripController, CreateTripState>`。state:`destinations`、`dateMode`、`fixedStart/fixedEnd`、`flexMonth/flexDayCount`、`dayQuotas`、`description`、`submitting`、`error`。衍生 getter:`startDate`/`endDate`/`totalDays`/`canSubmit`。方法:add/remove/reorder destination、setDateMode/日期 setters、setQuota、setDescription、`submit()`(成功回 tripId)。
- `lib/features/trips/create/create_trip_screen.dart`:三段式表單 + 送出。成功 → `ref.invalidate(myTripsProvider)` → `context.go('/trips/<tripId>')`。
- 子 widget:`_DestinationPicker`(POI 搜尋 + 結果 + chips + 拖曳清單)、`_DateModeSection`、`_DayQuotaSection`。
- 路由:**top-level** `/new-trip`(全螢幕,無底部導航,避開 `/trips/:tripId` 衝突)。入口:`TripsListScreen` FAB。

### Phase 2 — 編輯流程
- `lib/features/trips/edit/edit_trip_controller.dart`:`NotifierProvider.autoDispose.family<EditTripController, EditTripState, String tripId>`(constructor 注入 tripId,沿用 chat 慣例)。`build` 讀 `tripDetailProvider(tripId)` 帶入初值(title/description/lang/published/destinations)。state 記 original 以算 diff。方法:欄位 setters、destination add/remove/reorder、`save()`(diff-only PUT;destinations 改則一併送 countries)。
- `lib/features/trips/edit/edit_trip_screen.dart`:載入態 → 表單(目的地 + title + description + lang select + published toggle + 儲存鈕)。成功 → invalidate `myTripsProvider` + `tripDetailProvider(id)` → `context.pop()`。
- 路由:top-level `/edit-trip/:tripId`。入口:行程詳情(`TripTimelineScreen`)AppBar 編輯 action。

## 重用
`PoiRepository.searchPois`(+ `poiRepositoryProvider`)、`reorderable_row`/`reorder_helpers`(目的地拖曳/移除)、`TpTones`/`TpSpacing`、`myTripsProvider`、`tripDetailProvider`。

## 驗證(客端先擋,鏡像 server)
建立 `canSubmit`:≥1 目的地、日期有效(格式/順序/≤30 天)、≤30 目的地、非 submitting。編輯:diff 非空才可 save。送出失敗顯示 `error`(409 重複 id → 罕見,重產 id 重試一次)。

## 測試(三層鏡像)
- 純函式:`trip_form_logic_test`(slugify/genTripId/deriveName/deriveCountries/flexibleRange/tripDayCount/isTripDatesValid 邊界)。
- API:`trip_repository_test` 增 createTrip(body 含 snake_case destinations)、updateTrip(diff-only、destinations 全替換、無 expectedVersion)。
- controller:create(加/移/排序目的地、日期模式切換衍生日期、canSubmit gating、submit 呼叫 createTrip)、edit(帶入初值、diff、save)。
- screen:create(POI 搜尋 override → 加目的地 → 送出 verify createTrip + 導頁)、空目的地 → 送出 disabled、edit(帶入 → 改欄位 → 儲存 verify updateTrip)。

## 決策摘要
- 建立 full parity(目的地優先 + 固定/彈性日期 + 每地天數);編輯 = PUT 欄位 + **明確儲存鈕**;1 個 PR(Phase 0/1/2)。
- `id` client 產(`genTripId`);slug 空(全中文名)→ `trip-<base36 後4碼>`(比 web 的 `-<suffix>` 乾淨,仍合 `^[a-z0-9-]+$`)。
- 編輯無 OCC、不動日期/name。
- 路由用 top-level `/new-trip`、`/edit-trip/:tripId`(全螢幕、避開 shell `/trips/:tripId` 衝突)。
