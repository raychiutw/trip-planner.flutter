# Tripline HIG / Glass / Google Map 重構 Handoff

**更新日期：** 2026-07-18
**狀態：** 設計決策、正式 spec／implementation plan 與文件一致性驗證已完成；尚未開始本輪程式實作，也尚未推遠端。

## 使用者已確認的產品決策

- 本次是針對**整份計畫**的全盤重構，不限制為局部補丁。
- 允許重整 Root Shell、Header、Sheet、Navigation Glass、Timeline、地圖 adapter 與測試架構。
- 保留產品行為、資料契約與可驗證結果；純粹為舊結構相容而存在的重複元件可移除。
- 四個主要功能改為全版內容，頂部使用單一整條、固定浮在內容上的 Glass Header 膠囊。
- Header 不隨內容離開；內容可從其下方捲入。Chat／行程／地圖顯示目前行程名稱並可點選換行程；收藏顯示「收藏」。
- Root Header 最多兩個右側動作，多餘功能進 More；帳號、More、返回、關閉共用同一套 44pt action button 幾何與 glass 材質。
- `TpAppBar` 僅保留 detail route 與 sheet 語意；Root 不再以 pinned `SliverAppBar` 或各頁自製 AppBar 拼裝。
- 地圖套件由 `google_maps_flutter` 全面換成 `google_navigation_flutter`，使用 `GoogleMapsMapView`，不啟動導航 session。
- Tripline 自有 POI 繼續使用目前的編號 marker、路線與橫滑底部卡片樣式。
- Google 原生底圖 POI 必須可見、可點；點擊後在同一個 bottom accessory slot 暫時顯示 Google POI 卡片，不與 Tripline 卡片堆疊。
- 點空白地圖、關閉 Google POI 卡，或重新點 Tripline marker 後，恢復 Tripline POI 卡片。
- Google POI 卡片提供明確的「在 Google 地圖開啟」按鈕；不自動切 App、不先顯示確認 alert。
- 外開使用 Google Maps Universal URL：`https://www.google.com/maps/search/?api=1&query=...&query_place_id=...`；有 Google Maps App 時開 App，否則由瀏覽器承接；失敗顯示非阻塞 notice。
- Flutter mobile 平台下限調整為 iOS 16、Android API 24；Flutter Web 不嵌入 `google_navigation_flutter`，改提供 Google Maps Web 外開 fallback。

## 已確認的現況與耦合點

- `lib/ui/tp_root_scroll_scaffold.dart` 仍以 pinned `SliverAppBar` 實作 Root header。
- `lib/features/chat/chat_screen.dart`、`lib/features/trips/trips_list_screen.dart`、`lib/features/favorites/favorites_screen.dart`、`lib/features/map/global_map_screen.dart` 尚未共用單一 Root Glass scaffold。
- `lib/features/map/map_adapter.dart` 的 `GoogleTripMapController` 直接持有 `google_maps_flutter.GoogleMapController`，不是套件中立介面。
- `TripMapCanvasConfig` 目前暴露 `clusterMarkers`；行程地圖在可見 pin 數大於等於 12 時啟用 clustering。
- `lib/features/trip_detail/trip_map_screen.dart` 的 `_TripMapViewState` 固定 Day 與 POI zoom 為 `12.0`，自有 POI accessory 已由 `TpBottomAccessory + PageView` 組成。
- 目前 `google_maps_flutter` 的直接 import 位於 map adapter 與相關測試；遷移時必須用 static guard 確保舊套件完全退場。
- `TpMenuAction<T>` 與 `AppSheetAction<T>` 目前是兩套重複 command model；正式 plan 已新增 Task 0，先以單一 `TpActionItem<T>` 原子遷移 More menu、action sheet 與所有現有 call sites，且不保留 typedef／adapter 相容層。

## 已查證的 `google_navigation_flutter` 條件

- 2026-07-18 pub.dev 最新版本為 `0.10.0`；它仍是 1.0 前版本，可能有 breaking changes。
- `GoogleMapsMapView` 提供 `onPoiClicked`、`onMarkerClicked`、`onMapClicked` 與 `GoogleMapViewController`。
- 自訂 marker 圖可先用 `registerBitmapImage` 註冊 PNG bytes，再以回傳的 `ImageDescriptor` 建立 marker options。
- 套件最低支援 Android API 24、iOS 16，且 Google Cloud 必須啟用 billing、Navigation SDK for Android 與 Navigation SDK for iOS。
- 套件只支援 Android／iOS；web 需明確 fallback，不可假設仍有 embedded map parity。

## 正式文件位置與待完成項目

1. 已更新 `docs/superpowers/specs/2026-07-18-hig-action-semantics-favorite-undo-design.md`
   - 重寫 Root Header 架構。
   - 新增全版固定 Glass Header 規格。
   - 新增 map engine、原生 Google POI、Universal URL 與 web fallback 規格。
   - 補 acceptance criteria、accessibility、Dynamic Type、錯誤處理與平台條件。
2. 已更新 `docs/superpowers/plans/2026-07-18-hig-navigation-sheet-semantics.md`
   - 在整份計畫的 Global Constraints 明訂「允許全盤合適重構」。
   - 調整 Goal／Architecture／File Map，使 Root 與 Map 不再沿用舊相容層。
   - 新增共用 action model、Root Glass scaffold 遷移、map engine 遷移、Google POI accessory／外開，以及全域清理與 screenshot QA 任務。
   - 每個任務需列出 exact file paths、test-first 步驟、介面、驗證命令與 commit 邊界。
3. 已完成文件驗證：三份文件無 whitespace error，Markdown code fence 成對，Task 0–16 順序完整，且沒有與新決策衝突的舊版本／舊角色限制。
4. 實作完成、準備推遠端前必須依序完成：
   - simplification pass：移除死碼、舊相容入口、重複 adapter／glass recipe 與不必要抽象，保留測試可讀性。
   - 全量 formatter、targeted tests、`flutter test`、`flutter analyze`、Android／iOS build 與 Light／Dark screenshot QA。
   - 對完整 merge-base diff 做獨立 code review，附 file／line 與 severity；P0／P1 必須清零，接受的其他發現需修正或交由使用者判斷。
   - gstack `/review`：偵測 base、做 plan completion audit、scope drift、critical checklist、specialist／adversarial review、Codex adversarial 與大型 diff structured review。
   - 修完所有已確認問題後重跑 review 與驗證；只有 review gate clean／pass 才能 push。
5. 目前文件階段不推遠端；若建立本地 commit，只 stage 上述 spec、plan、handoff，不得帶入工作樹其他修改。

## 繼續作業注意事項

- 先使用 codebase-memory-mcp 圖譜工具做 code discovery；字串／設定才使用 `rg`。
- 不開始程式實作，除非使用者另行要求執行 plan。
- 不因「忽略 ponytail 限制」而省略測試或安全邊界；其意義是整份 plan 不受最小改動偏好拘束。
- 不以一般 `git push` 跳過 simplification、gstack `/review`、Codex review 與驗證閘門。
- 若再次壓縮，先讀本 handoff，再從正式 spec／plan 的 diff 繼續，不重開設計討論。
