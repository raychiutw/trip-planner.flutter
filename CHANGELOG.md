# Changelog

本專案的重要變更紀錄。格式參考 [Keep a Changelog](https://keepachangelog.com/zh-TW/1.1.0/),版本依 [Semantic Versioning](https://semver.org/lang/zh-TW/)。

## [Unreleased]

### 新增

- **`--dart-define=TRIPLINE_API_ORIGIN`**:build/run 時覆寫 API origin(本機後端開發),預設仍為正式站;同一 origin 同時驅動 base URL 與 CSRF Origin header。新增 `docs/howto-local-backend.md`。
- **測試補強**:trip_detail widgets(DayHeader/DayPills/HotelCard/TravelPill/TimelineEntryTile/entry_tone 色階)、TripCard、AppShell 5-tab 導航、跨畫面流程(登入＋瀏覽)、`integration_test` device smoke(iOS 模擬器驗證通過)。
- **收藏清單**:favorites tab 轉正 — `GET /poi-favorites` 渲染(名稱/類型 tone/評分/note/用於 N 個行程)+ heart 取消收藏(確認對話框 → `DELETE`)。POI 類型→tone 對應抽到共用 `lib/theme/poi_tone.dart`。
- **探索（ExploreScreen）**:收藏 tab 新增入口 — poi-search 搜尋（防 race）+ region/分類 filter（為你推薦/景點/美食/住宿/購物）+ 4 狀態 + auto-search seed + heart 收藏 toggle（find-or-create → favorite）。POI 類型映射 `mapGooglePrimaryTypeToPoiType`;`ApiClient.get` 支援 CancelToken。
- **加入行程（AddToTripScreen）**:收藏/探索 POI → 選 trip/day/時間加入行程（favorite mode `POST /poi-favorites/:id/add-to-trip` + direct mode `POST /trips/:id/days/:num/entries`）;409 時段衝突對話框。`ApiError` 加 `payload` 保留原始 body 供 conflictWith。
- **Entry CRUD（時間軸停留點）**:編輯/刪除/新增自訂停留點、同日拖曳排序 + 跨天搬移、地點管理全頁（正選切換／備選增刪排序／per-POI 備註·分類·訂位／POI 搜尋）、交通方式編輯（開車·步行重算／大眾運輸手動）。三套 OCC:entry `version`(meta)、`entryPoisVersion`(POI 結構)、segment `version`(交通),409 `STALE_ENTRY` 重抓。新增 `TripSegment` model。
- **行程筆記 CRUD**:筆記 5 區（航班/住宿/預訂/行前須知/緊急聯絡）由唯讀轉可新增/編輯/刪除 + 每區拖曳排序。吃後端「5 區共用泛型引擎」→ client `NoteSection` + 泛型 repository + spec-driven `NoteEditSheet`（一個表單服務 5 型）。OCC `expectedVersion`,409 `STALE_ENTRY`。
- **AI 聊天（行程助手）**:chat tab 由 placeholder 轉正 — 工單佇列模型（`POST /api/requests` 建單 → 外部 worker 填 reply）+ polling 到終態 + markdown 回覆（deep-link `/trip/:id/*` 映射成 app `/trips/:id/*`）。頂端行程下拉（預設最近）、樂觀送出、三方氣泡（自己/協作者/AI）、亂碼防護。**completed 後 invalidate 行程相關 providers**（AI 直接改行程,畫面才看得到）。新增 `TripRequest` model、`RequestsRepository`、`ChatController`(`NotifierProvider.autoDispose.family`)、`flutter_markdown_plus` 依賴。
- **建立／編輯行程**:行程清單可建立（目的地優先 POI 搜尋 + 固定/彈性日期模式 + 每地天數分配,送出衍生 `name`/`id` slug/`countries`）與編輯（PUT 欄位:目的地/標題/描述/語言/發布,明確儲存鈕,無 OCC,不動日期）。新增 `DestinationInput`、`trip_form_logic`(slugify/genTripId/日期推算)、`createTrip`/`updateTrip`、共用 `DestinationPicker`、`flutter_localizations`(zh-TW 日期)。入口:清單 FAB / 詳情 AppBar。
- **全域地圖**:map tab 由 placeholder 轉正 — 收藏 POI（`GET /poi-favorites`）跨行程畫在 `flutter_map`,依 poi_type 上色,點 marker 顯示名稱/評分/所屬行程。（web 的 /map 實為導回單行程地圖的 dead code;此為真正的跨行程地圖。）
- **共編邀請**:成員管理 — 已授權成員（改角色 member↔viewer / 移除）+ 待接受邀請（撤銷）+ 新增成員（email + 角色）。`/api/permissions` + `/api/invitations`;owner/admin 限定管理(他人顯示提示)、owner/admin 列不可改不可移除。新增 `TripMember`/`TripInvite`、`CollabRepository`、`CollabController`。入口:清單長按 sheet「共編設定」。

### 變更

- `kTriplineOrigin` 由固定常數改為 `String.fromEnvironment`(預設值不變,既有測試零破壞)。
- `docs/PORTING_PLAN.md`:dart-define 覆寫由 `TRIPLINE_API_URL` 更正為 `TRIPLINE_API_ORIGIN`(origin 語意)。
- **favorites review cleanup**:收藏比對改「名稱」單一 key（消除 server poiType 與 client category 映射不一致致取消收藏失效）、AddToTripScreen 改純讀 fallback + 「結束晚於開始」驗證 + 送出守門、router add-to-trip 對遺失 extra 改 redirect 防 crash;移除 dead code `AddToTripResult`、`poi_type` RegExp 提升檔案層級、抽共用 `PoiRatingLabel` 與 `reorderedSortOrders`。

## [0.1.0] - 2026-06-10

P0 里程碑:trip-planner 的 iOS/Android 唯讀版可用 — 登入後能瀏覽自己的行程、逐日時間軸、地圖與筆記,資料與 web 版完全同步(共用同一套後端)。

### 新增

- **登入**:email/密碼登入,session 以 flutter_secure_storage 持久化,重開 app 免重登
- **5-tab shell**:聊天/行程/地圖/收藏/帳號底部導航,各 tab 保留瀏覽狀態;未登入自動導向登入頁
- **行程清單**:三色 tone 卡片、下拉更新、長按刪除(二次確認)
- **行程時間軸**:day pills 換日、逐日 timeline(三色 POI tone、travel pill、hotel 卡)
- **行程地圖**:flutter_map + OSM(免 API key)、逐日 pin 配色、day tabs 與 entry cards 同步
- **行程筆記**:航班/住宿/預訂/行前/緊急聯絡 5-section accordion(唯讀)
- **帳號**:profile、行程統計、登出
- **基礎層**:design tokens + light/dark 雙主題、手寫 fromJson models、dio API client(cookie 認證、CSRF Origin、429 retry、204 處理)
- **測試**:TDD 全程,144 tests(models 解析/API client 行為/widget)

### 文件

- Diataxis 四象限文件 9 篇(新手教學、3 篇 how-to、4 篇 reference、架構說明),README 文件索引
- 專案 CLAUDE.md(agent 開發指南)
- PORTING_PLAN/CONTRACTS 與實作同步(riverpod 3.x、歷史契約標註)

[Unreleased]: https://github.com/raychiutw/trip-planner.flutter/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/raychiutw/trip-planner.flutter/releases/tag/v0.1.0
