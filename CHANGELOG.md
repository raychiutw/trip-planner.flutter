# Changelog

本專案的重要變更紀錄。格式參考 [Keep a Changelog](https://keepachangelog.com/zh-TW/1.1.0/),版本依 [Semantic Versioning](https://semver.org/lang/zh-TW/)。

## [Unreleased]

### 新增

- **公開分享頁補齊**:`/s/:token` 可未登入瀏覽公開行程、查看 days/notes 摘要,登入後可複製到自己的帳號。
- **列印與 PDF 預覽**:行程詳情新增列印頁,可預覽每日行程、筆記摘要並分享/輸出 PDF。新增 `pdf`、`printing` 依賴。
- **JSON 匯入/匯出**:行程清單支援 web 相容 `schemaVersion:1` JSON import/export,含 days、segments、notes。新增 `file_selector` 依賴。
- **帳號安全與 OAuth 設定**:新增登入裝置管理(`/account/sessions`)、已連結應用撤銷(`/account/connected-apps`)、開發者 OAuth app 清單/建立(`/dev/apps`)與 OAuth consent shell route(`/oauth/consent`)。
- **通知設定頁接上偏好 API**:Account「通知」row 轉正,`/settings/notifications` 與 web 相容 `/account/notifications` route 會讀寫 backend `/account/notifications` preferences,可分別切換行程更新、旅伴邀請、系統通知。
- **地圖 adapter**:新增 `features/map/map_adapter.dart`,集中 `flutter_map` 轉接層;`TripMapScreen` 與 `GlobalMapScreen` 改走 adapter,保留日後替換地圖 SDK 的空間。
- **帳號建立與復原流程**:補齊 web 相容 `/signup`、`/signup/check-email`、`/login/forgot`、`/auth/password/reset`、`/auth/verify-email` route,支援註冊、重寄驗證信、忘記密碼、重設密碼與 email 驗證。
- **AI 行程健檢頁**:新增 `/trips/:tripId/health` 與 web alias `/trip/:tripId/health`,可查看既有 AI findings、POI closed/missing 摘要、啟動/重新生成健檢,並在空行程時阻擋送出。
- **行程筆記 AI 生成**:`TripNotesScreen` 補齊行前須知（一般/住宿）與緊急聯絡 AI 生成入口,改打 web/backend 支援的 `tips`、`lodging-tips`、`emergency` doc type,並透過 `/requests/:id/events` SSE 完成後自動刷新筆記。
- **停留點 web route 相容**:新增 `/trips/:tripId/entries/:eid/edit|copy|move` 全頁入口,並支援 web alias `/trip/:tripId/stop/:entryId/edit|change-poi|copy|move`。

### 修正

- POI 分類顯示對齊 web:純中文/假名 curated 分類（如「沖繩麵」「すし」）保留原樣,英文 Google primaryType 顯示為 8 類中文 label,避免探索卡與時間軸誤顯「景點」或外露 `tourist_attraction`。
- 更新 reorder callback 參數名稱,對齊目前 Flutter SDK 的 `onReorder` API。
- 登入 return-to flow 會消費安全的站內 `redirect_after`,公開分享頁登入後可回到原分享頁；外部 redirect 會被忽略。

## [0.4.0] - 2026-06-16

行程清單名稱排序 + 聊天語音指令(本 repo 可做的 web parity 後續)。

### 新增

- **行程清單排序**:預設順序 / 名稱 A→Z,與搜尋並存。(web 的「最新編輯/出發日」需後端 `/my-trips` 回 `updatedAt`/`startDate`,暫不支援。)
- **聊天語音指令**:聊天輸入加麥克風語音轉文字(`speech_to_text`),對齊 web「輸入訊息或語音指令」。**lazy 權限**(點麥克風才請求),辨識文字回填輸入框沿用送出。新增 iOS `NSMicrophoneUsageDescription`/`NSSpeechRecognitionUsageDescription`、Android `RECORD_AUDIO`。

## [0.3.0] - 2026-06-15

離線寫衝突解決 + web 對齊:離線 OCC rebase(三方 merge)、時間軸資訊密度補齊、行程清單搜尋、聊天建議引導。

### 新增

- **離線寫 OCC 409 三方 merge rebase**:離線編輯重連 flush 遇 `STALE_ENTRY` 時自動 **dirty-aware 三方 merge**(只比對/重送使用者改過的欄位)→ 無真衝突靜默 rebase、真衝突進持久化 conflict store + banner 點開 bottom sheet 整筆二選一(保留你的 / 用對方的)。不丟資料:重抓/重送離線保留、`newVersion` 缺失當衝突、row 被刪上報;換帳號/登出一併清 conflict store。範圍 `entry.update` + `note.update`。新增 `rebase_merge.dart`(rebaseMerge / dirtyFields / entry|note 欄位擷取)、`ConflictRecord` + conflict store(Sembast)、`_send` writeCache 參數。
- **時間軸資訊補齊(對齊 web 手機版)**:交通段顯示距離 km(`travel.distanceM`)、當日總覽「N 個停留點 · 總距離 km」、景點停留時長、**注意事項卡**(POI 營業時間早於提醒,移植 web `validateDay`)、entry 編號 + 當日時間範圍。
- **行程清單搜尋**:本地 filter(名稱 / 標題)。
- **聊天空對話引導**:「從一個指令開始」+ 4 個建議 prompt 快捷鈕。

### 變更

- `AuthNotifier` 換帳號 / 登出清快取一併清 conflict store(沿用 `__cache_owner__` owner-check)。

## [0.2.0] - 2026-06-15

P1 + P2 收斂發版:收藏/探索、Entry CRUD、筆記 CRUD、AI 聊天、建立/編輯行程、全域地圖、共編邀請、設定子頁、分享連結、OAuth PKCE(就緒待啟用)、離線快取(讀寫同步)。

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
- **設定子頁**:帳號設定轉正 — **外觀**(主題 跟隨系統/淺色/深色,client 端持久化,`themeModeProvider` 接 `MaterialApp.themeMode`)+ **個人資料編輯**(displayName → `PATCH /account/profile` → invalidate authState)。新增 `SettingsStore`、`ThemeModeController`、`AppearanceScreen`、`ProfileEditScreen`(`/settings/appearance`、`/settings/profile`);Account「外觀/個人資料」row 由 placeholder 轉正(通知仍 coming-soon)。MVP:sessions/connected-apps/通知 延後。
- **分享(公開連結)**:為行程建立/管理唯讀公開分享連結(`trip_shares`)— 列出(label/狀態/瀏覽次數)、建立(顯示完整 `<origin>/s/<token>` URL + 複製,raw token 只回一次)、撤銷(二次確認)。`GET/POST /trips/:id/shares`、`PATCH .../:shareId {action:'revoke'}`;owner/editor 可管理(viewer 提示)。新增 `TripShare`/`ShareLink`、`ShareRepository`、`ShareController`。入口:清單長按 sheet「分享」。MVP:expiry/sections/anonymous/rotate 延後。
- **OAuth 2.1 PKCE + Bearer 認證（client 端,就緒待啟用）**:實作 native app 的 authorization-code + PKCE-S256 流程,取代「session cookie + 偽造 Origin」過渡方案。新增 `pkce`、`OAuthTokens`、`OAuthRepository`(authorize URL / token / refresh)、`OAuthTokenStore`、`OAuthLoginService`(RFC 8252 loopback);**`ApiClient` 新增 Bearer 模式**(有 token → 帶 `Authorization`、不送 Origin、401 自動 refresh-retry;無 token → 回退 cookie)。client_id/redirect 由 `--dart-define` 注入,**僅在設定後啟用**(預設仍 cookie,零破壞)。deps:`crypto`、`url_launcher`。**e2e 待 backend owner provision 一個 active public client**(見 `docs/howto-oauth-pkce.md`)。

### 變更

- `kTriplineOrigin` 由固定常數改為 `String.fromEnvironment`(預設值不變,既有測試零破壞)。
- `docs/PORTING_PLAN.md`:dart-define 覆寫由 `TRIPLINE_API_URL` 更正為 `TRIPLINE_API_ORIGIN`(origin 語意)。
- **favorites review cleanup**:收藏比對改「名稱」單一 key（消除 server poiType 與 client category 映射不一致致取消收藏失效）、AddToTripScreen 改純讀 fallback + 「結束晚於開始」驗證 + 送出守門、router add-to-trip 對遺失 extra 改 redirect 防 crash;移除 dead code `AddToTripResult`、`poi_type` RegExp 提升檔案層級、抽共用 `PoiRatingLabel` 與 `reorderedSortOrders`。
- **過時文案清理**:收藏空狀態移除「(即將推出)」(探索功能早已上線),改為「去探索」按鈕直達 `/favorites/explore`;校正 `AccountScreen` 設定群組過時註解(外觀/個人資料已可用,僅通知為即將推出)。

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
