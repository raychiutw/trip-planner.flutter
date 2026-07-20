# Tripline iOS HIG UI 一致性、地圖 POI 與離線／恢復接線規格

> 狀態：App 實作完成；staging restore contract 待 protected environment 設定後補證據
> 稽核日期：2026-07-20
> 範圍：Flutter App；以下「現況／根因」保留為實作前稽核紀錄，定版方向已落地。
> 前置文件：`2026-07-18-hig-action-semantics-favorite-undo-design.md`、`2026-06-12-offline-cache-design.md`、`docs/backend-tasks/2026-07-18-poi-favorites-undo-restore-api.md`
> 執行任務：`docs/superpowers/plans/2026-07-20-ios-hig-ui-offline-restore.md`

## 1. 結論摘要

| # | 項目 | 現況判定 | 定版方向 |
|---|---|---|---|
| 1 | 單一行程字級 | 確認過大；行程內容大量使用 17–28pt，收藏卡主要為 15／13pt | 以收藏卡與 App `TextTheme` 為基準，行程內容降為 20／15／13pt 角色層級 |
| 2 | 回行程列表 | 確認缺少；共用 Root Header 沒有 leading slot | 共用 Header 增加可選 leading，行程詳情固定提供返回 `/trips` |
| 3 | Header／tab | 確認語意混雜且背景文字穿透；同一 control 混放 action 與 Day，玻璃後方文字又與前景標題重疊 | Bottom tab bar 只管根頁；Header 只放標題／toolbar action；Day control 只做 Day selection；文字頁使用可遮蔽字形的 regular material |
| 4 | 收藏搜尋 | 與行程列表不同，搜尋欄會取代 Header 標題並擠壓按鈕 | 改成與行程一覽相同的常駐 inline `AppSearchField` |
| 5 | 新增停留點 | 確認文字截斷、Day chips 過高、分類換行 | 短標籤、單一 Day 欄位、分類橫向單行、完整顯示「取消」 |
| 6 | 滑動刪除 | 部分完成；停留點／筆記已有，行程／收藏仍沒有 | 列表列統一共用 `SwipeToDelete`；表單結構刪除不強制套用 |
| 7 | Sheet grabber | 共用 Sheet 已存在；差異多半是固定／可調整語意造成，不是漏用共用元件 | 固定 Sheet 不顯示；可調整 Sheet 才顯示；禁止 feature 直接呼叫平台 Sheet API |
| 8 | 地圖 POI 卡 | UI 與互動問題皆確認；卡片滑頁會直接移動地圖 | 移除進度／箭頭，拆開時間與分類；滑頁只預覽，點卡片或 marker 才置中地圖 |
| 9 | 離線與收藏恢復 | 離線核心「部分完成」；收藏 restore App 接線與 release flag 已完成 | 補前景重連自動同步；保留明確離線能力邊界；以 staging contract 證明後端部署 |

### 1.1 2026-07-20 實作結果

- 需求 1–8 與 App 端離線重連／收藏 restore 接線均已完成；執行細節見 implementation tasks。
- 本機 Flutter 3.44.6：analyzer 0 issue、非 workflow 產品 suite 1,284 tests PASS、Android debug APK build PASS。
- `FavoritesRepository.restoreFavorite()` 已接 `POST /poi-favorites/{id}/restore`，簽署 release workflow 亦傳入 `FAVORITE_RESTORE_ENABLED=true`。
- 外部 TASK-10 尚未宣告 PASS：`mobile-release` protected environment 未設定真實 staging URL、fixture 與兩組 session，checked-in allowlist 目前只有不可公開解析的 `.test` 測試資料。

## 2. HIG 判斷基準

本規格不要求把 Flutter UI 做成 UIKit 複製品，而是遵守以下互動語意：

1. [Typography](https://developer.apple.com/design/human-interface-guidelines/typography)：使用一致的文字角色與 Dynamic Type；層級靠 text style／weight，不靠全面放大。
2. [Tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars)：tab bar 用於 App 根層級目的地，不承載頁內動作。
3. [Segmented controls](https://developer.apple.com/design/human-interface-guidelines/segmented-controls)：segments 必須是作用於同一內容的互斥選擇；不得混入「前往地圖／行程」這類 action。
4. [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars)：返回是導覽階層動作；地圖／列表切換若是跨頁 command，放在 toolbar 並提供標準圖示與可存取標籤。
5. [Search fields](https://developer.apple.com/design/human-interface-guidelines/search-fields) 與 [Searching](https://developer.apple.com/design/human-interface-guidelines/searching)：搜尋位置、placeholder、清除按鈕與輸入即搜尋行為應一致。
6. [Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets)：grabber 是可調整高度的 affordance，不是每張 Sheet 的裝飾；固定高度 Sheet 不應暗示可以 resize。
7. [Lists and tables](https://developer.apple.com/design/human-interface-guidelines/lists-and-tables) 與 [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)：列表可提供 swipe action，但必須保留非手勢替代路徑與至少 44×44pt 可操作區。
8. [Maps](https://developer.apple.com/design/human-interface-guidelines/maps)：地圖應維持可探索性；卡片預覽與地圖相機移動要有清楚、可預期的因果關係。
9. [Materials](https://developer.apple.com/design/human-interface-guidelines/materials) 與 [Color](https://developer.apple.com/design/human-interface-guidelines/color)：Liquid Glass 的 regular variant 應調整背景亮度並維持導覽可讀性；clear variant 只適合視覺豐富背景，前景文字不得與下層內容混在一起。

## 3. 詳細規格

### 3.1 單一行程頁字級

#### 現況證據

- App theme：`lib/theme/app_theme.dart:349-428` 已定義 28／22／20／17／15／13／12／11pt 角色。
- 收藏卡：`lib/features/favorites/poi_favorite_card.dart:90-173`，標題主要使用 15pt、地址／備註使用 13pt。
- 行程詳情：
  - `lib/features/trip_detail/widgets/day_header.dart:73-108`：Day 標題 28pt，DAY／時間／摘要 17pt。
  - `lib/features/trip_detail/widgets/timeline_entry_tile.dart:125-160,306-357`：時間 20pt、景點名 22pt、分類／說明 17pt。
  - `lib/features/trip_detail/widgets/travel_pill.dart:70-97,135-165`：交通資訊 17pt。

#### 定版字級

| 內容角色 | 目前 | 目標 `TextTheme` | 視覺基準 |
|---|---:|---|---|
| 頁面／行程標題 | 17pt | `titleLarge` 17pt | 保留；屬 navigation title |
| Day 顯示標題 | 28pt | `headlineSmall` 20pt | 最高內容層級，不得高於頁面標題過多 |
| DAY、日期、摘要 | 17pt | `titleSmall`／`bodyMedium` 13pt | 輔助資訊 |
| 停留時間起訖 | 20pt | `titleMedium` 15pt + tabular figures | 與收藏主資訊同級 |
| 景點名稱 | 22pt | `bodyLarge` 15pt、600 weight | 直接對標收藏卡標題 |
| 分類／說明 | 17pt | `bodyMedium` 13pt | 直接對標收藏次要資訊 |
| 交通 pill | 17pt | `bodyMedium` 13pt、600 weight | 功能標籤而非標題 |

規則：

- 僅使用既有 `TextTheme` token，不新增散落的 hard-coded font size。
- 保留 Dynamic Type；當字級放大時增加列高或換行，不以縮小文字、裁切關鍵資訊換取固定高度。
- 320pt 寬、100%／200% text scale、Light／Dark 都要納入視覺測試。

### 3.2 單一行程返回路徑

#### 根因

`TripTimelineScreen` 使用 `TpRootScaffold`，但 `TpRootHeaderConfig`／`TpRootGlassHeader`（`lib/ui/tp_root_scaffold.dart:7-18,76-135`）只有 title 與 actions，沒有 leading。路由由列表用 `go('/trips/:tripId')` 進入，深連結也可能沒有可 `pop()` 的歷史。

#### 規格

- 在既有 `TpRootHeaderConfig` 增加可選 `leading`；不得另做第二套行程 Header。
- `/trips/:tripId` 與其單一行程子頁的第一層 Header 顯示標準 chevron 返回按鈕，語意標籤為「返回行程列表」。
- 觸發後固定 `go('/trips')`，不只依賴 `Navigator.pop()`；從 push、go、通知或深連結進入都必須可返回。
- 返回按鈕維持至少 44×44pt hit target；RTL 時方向跟隨平台。

### 3.3 根頁、Header 與功能 tab

#### 根因

`TpHorizontalSelector`（`lib/ui/tp_horizontal_selector.dart:9-186`）刻意同時渲染 `actionOptions` 與 `tabOptions`。行程頁把「地圖」與 Day 放同一條，地圖頁把「行程」與 Day 放同一條（`trip_timeline_screen.dart:528-562`、`trip_map_screen.dart:630-654`）。外觀像 segmented control，但一部分是 action、一部分是 selection，選取狀態因此不明確。

另一個獨立根因是背景穿透：`TpRootScaffold` 讓 body 置於 Header 後方並持續捲動；`tpNavigationGlassSettings` 的一般底色目前只有 Light 0.58／Dark 0.68 alpha。聊天、行程、收藏的下層內容也是文字，字形經 blur 後仍可辨識，會與 Header title／Day label 形成雙層文字。現有 `showSoftEdge` 從 Header 下緣才開始，無法遮住 Header 範圍內的內容。

#### 導覽層級定版

| 層級 | 元件 | 只負責 |
|---|---|---|
| App 根層級 | `AppleRootTabBar` | 聊天／行程／地圖／收藏 |
| Root Header | `TpRootGlassHeader` | 行程名稱、返回、文件／帳號等 toolbar actions |
| 內容模式 | Header toolbar action | 行程列表 ↔ 地圖；使用 `list.bullet`／`map` 類標準圖示與語意標籤 |
| 當前資料範圍 | Day selector | DAY 1、DAY 2…的互斥選擇，不含任何 action |

要求：

- 從 `TpHorizontalSelector` 移除 `isAction`／跨頁 action 用法；若沒有其他合法用例，實作時一併刪除該分支，而不是保留未使用抽象。
- 聊天、行程、地圖、收藏不得在 Header 再複製一套根層級 tabs。
- Day 數量超出寬度時可水平滑動，但選中 Day 必須自動捲入可見區，selected／unselected 對比符合目前功能 tab 的清楚程度。

#### Header／tab 背景穿透定版

- 聊天、行程、收藏等文字型頁面使用 **regular navigation material**：保留玻璃質感，但必須有足以遮蔽下層字形的 neutral backer。下層文字可以提供模糊色彩，不得仍能讀出字詞。
- 地圖、照片等視覺型背景才可使用較透明版本；不得以同一組低 alpha 強套所有頁面。
- 直接調整既有 `TpRootGlassHeader`／`TpHorizontalSelector` 的共用材質入口，不在三個 feature 各加一層 Container。實作只需「文字內容」與「視覺內容」兩種語意，不建立可任意調十數個參數的 style system。
- 文字型頁面的 backer 建議起始值為 Light 0.88–0.92、Dark 0.84–0.90，再以實機最差背景驗證；最終標準是可讀性，不是固定 alpha。
- `Increase Contrast`／`Reduce Transparency` 時使用接近不透明的 system background；目前 high-contrast 0.96 行為保留。
- selected Day 必須同時以實心 pill／邊界與字重表示，不只改文字顏色；unselected label 對其實際合成後背景需達 4.5:1。
- `showSoftEdge` 可保留作 Header 下緣過渡，但不能拿它代替 Header 本身的 backer。
- 不使用 text shadow 修補；陰影無法消除後方第二層字形，且會讓繁體中文字緣更髒。

### 3.4 收藏搜尋對齊行程一覽

#### 現況

- 行程一覽：`lib/features/trips/trips_list_screen.dart:328-345` 在 Header 下方常駐 `AppSearchField`，輸入即篩選。
- 收藏：`lib/features/favorites/favorites_screen.dart:71-90,192-228` 進入 search mode 後，以搜尋欄取代 Header title，並同時擠壓排序、取消與帳號 actions。

#### 規格

- 收藏固定顯示 title「收藏」。
- 在 Header 下方放置與行程一覽同尺寸、同 margin、同互動的 `AppSearchField`，placeholder 為「搜尋收藏」。
- 移除 `_isSearching`、Header title swap、Header 搜尋 icon 與搜尋模式專用取消 action；排序／新增／帳號維持原工具列位置。
- 保留輸入即本地篩選、clear button、空結果與搜尋字詞 highlight。
- 必須重用 `AppSearchField`，不新增 Favorites 專用搜尋元件。

### 3.5 新增停留點 UI

目標檔案：`lib/features/trip_detail/entry_add_route_screen.dart`。

#### Header

- leading 必須完整顯示「取消」，不得只剩「取」。
- title「新增停留點」與 trailing「加入」在 320pt 寬及 200% text scale 仍可操作；若空間不足，title 可省略號，但 leading／primary action 不得截成單字。
- leading／trailing 以 intrinsic content width 加 44pt 最小 hit target 配置，不使用過小固定寬度。

#### 模式、Day 與分類

- 模式文案定版：「搜尋」、「收藏」、「自訂」；不再使用「搜尋景點」、「收藏景點」。
- 三個模式是同一內容區域的互斥狀態，可保留 `SegmentedButton`，每段必須單行。
- Day 是表單欄位，不是第二組 tabs：顯示一列「日期」＋目前值（例：`DAY 1 · 7/29（三）`）＋ chevron。點擊使用既有 `showAppSelectionSheet<int>`，以 checkmark 表示目前值；移除全部 Day `FilterChip` 的 `Wrap`。
- POI 分類改為單一水平捲動列；「為你推薦／景點／美食／住宿／購物」永不換到第二行。選中項使用 accent，其餘使用 neutral surface。
- 搜尋欄 placeholder 統一為「搜尋」；輸入不足最低字數時提供低干擾說明，不顯示錯誤態。

### 3.6 列表滑動刪除

#### 現況盤點

| 清單 | 現況 | 本次規格 |
|---|---|---|
| 行程停留點 | 已用 `SwipeToDelete` | 保留 |
| 筆記 | 已用 `SwipeToDelete` | 保留 |
| 行程列表 | More／長按 action sheet | 增加 trailing swipe delete |
| 收藏列表 | 愛心按鈕／action sheet | 增加 trailing swipe「移除收藏」 |
| Edit Trip 的 Day | 表單內明確刪除按鈕 | 保留，不強制 swipe |
| 批次刪除 | 顯式 selection mode | 保留，不改成逐列 swipe |

#### 規格

- 重用 `lib/features/trip_detail/widgets/reorderable_row.dart:176-204` 的 `SwipeToDelete`；若命名位置過度 feature-specific，實作時只搬到 `lib/ui/`，不建立第二份 Dismissible。
- 方向為 trailing → leading；背景使用 system destructive red、trash symbol 與清楚文字。
- 刪除整個行程屬不可復原高風險：完成 swipe 後仍顯示既有確認，未確認前 row 不得永久消失。
- 移除收藏可直接執行並顯示 6 秒「復原」；復原呼叫既有 restore API。
- 每個 swipe action 都保留 More／長按或可見按鈕作非手勢替代路徑，VoiceOver custom action 可觸發相同命令。

### 3.7 Bottom Sheet grabber 一致性

#### 稽核結論

所有 feature 目前皆透過 `lib/app/adaptive.dart` 的共用 helpers；直接的 `showCupertinoModalPopup`、`showModalBottomSheet`、`showGeneralDialog` 集中在該檔案。`_showAppSheet` 已以 `resizable` 決定 `showDragIndicator`。因此「有的有橫條、有的沒有」主要是既定語意差異，不代表大多數畫面漏用共用元件。

#### 定版矩陣

| Wrapper | 行為 | Grabber |
|---|---|---|
| `showAppSelectionSheet` | 固定 93%，點列立即選取 | 不顯示 |
| `showAppContentSheet` | 固定 93%，單頁內容／階層內容 | 不顯示 |
| `showAppScreenSheet` | 固定 93%，近滿版功能頁 | 不顯示 |
| `showAppFormSheet` | medium／large 可調整 | 顯示 |
| iOS `showAppActionSheet` | 系統 action sheet | 不加自訂 grabber |

要求：

- grabber 只在使用者真的可改變 detent 時顯示；不得為視覺一致而全部加上。
- 固定 Sheet 仍可依規格向下滑關閉；有未儲存表單時先確認。
- `lib/features/**` 不得直接呼叫平台 Sheet API。
- 列表拖曳排序的 handle 不算 Sheet grabber，兩者不得共用語意或測試 selector。

### 3.8 地圖 POI 卡牌與相機互動

#### 根因

`trip_map_screen.dart:748-769` 的 `PageView.onPageChanged` 直接呼叫 `_selectStop`；而 `_selectStop` 在 `:486-508` 無條件呼叫 `_focusStop`。所以使用者只是滑下一張卡，地圖相機也被移動。

#### 卡片內容

- 移除「停留 2 / 7」。
- 移除右側圓形箭頭與其 44pt 空間；整張卡片本身就是可點擊 affordance。
- 第一行：POI 名稱，單行省略號。
- 第二行：時間起訖，格式 `10:00–11:30`；只有開始時間時顯示開始時間，皆無則顯示「時間未設定」。
- 第三行：分類，單獨一行；透過既有 `poiCategoryLabel()` 顯示本地化名稱，不得露出 `sports_activity` 等 raw value。
- 保留左側編號，讓卡片與地圖 marker 可對照。
- 標準 text scale 使用既有 `TpBottomAccessory.height = 88pt` 為目標；移除目前 1.2 倍文字即跳到 144pt 的突變。Accessibility text size 可依內容增高，禁止以裁切換取 88pt。

#### 互動狀態

將「正在預覽的卡片」與「已選取／地圖置中的 POI」拆成兩個狀態：

1. 橫向滑動卡片：只更新 page indicator／preview index，不更新 `_activeEntryId`，不呼叫 `_mapController.move`。
2. 點卡片：提交選取、更新 active marker，並把地圖移到該 POI。
3. 點 marker：提交選取、移動卡片 pager 到對應頁，並置中該 marker。
4. 切 Day：更新該 Day 的 pager；若沒有明確點選 POI，只 fit／focus Day 範圍，不擅自選第一張卡。
5. 使用者手勢移動地圖後，滑卡片不搶回相機控制權。

### 3.9 離線機制與收藏刪除／恢復 API

#### 目前接線判定

| 能力 | 程式證據 | 判定 |
|---|---|---|
| SWR 離線讀 | `ApiClient.getStream` 先 cache 後 fresh，離線有 cache 時保留 stale | 已實作 |
| 離線 mutation queue | `ApiClient.sendMutation` 離線時 enqueue、樂觀 patch；`flushQueue` 重播 | 已實作 |
| 自動同步 | `lib/main.dart:94-127` 於冷啟動 post-frame 與 `onResume` 呼叫 sync | 部分完成 |
| 手動同步 | `OfflineStatusBanner` 提供 retry | 已實作 |
| 前景持續開啟時重連 | 未發現 connectivity stream／listener | 未完成 |
| Entry create／update／delete | `TripRepository` 使用 `sendMutation` | 支援離線寫 |
| Note create／update／delete | `TripRepository` 使用 `sendMutation` | 支援離線寫 |
| Entry reorder、Segment create／update | 仍直接 `patch`／`post` | 線上限定 |
| Trip／Day 結構操作 | 依原離線 scope 不進 queue | 線上限定 |
| Favorite delete／restore | `FavoritesRepository` 直接 `delete`／`post` | API 已接，但線上限定 |

「離線正常」的產品文案只能描述為：看過的核心資料可離線讀；Entry／Note 的新增、修改、刪除可排隊同步。不得暗示搜尋、AI、收藏、整個 Trip／Day、排序與交通段都能離線修改。

#### 前景重連缺口

- App 若一直停留前景，斷網後恢復連線，目前不會因 connectivity change 自動 `flushQueue`；使用者需按「立即重試」或讓 App 經歷 resume。
- 實作時新增單一 App-level connectivity observer；由 offline sync controller 做 debounce／重入保護，online transition 才觸發一次 `sync()`。
- 不在每個 screen 各自監聽；保留目前 `_flushing` 與 `state.isLoading` 防重入。
- observer 只負責觸發，不把「有網路介面」視為後端一定可用；5xx／401／403 與連線錯誤仍依現有 queue 保留政策處理。

#### 收藏 restore API 接線

App source 已完成以下接線：

- `FavoritesRepository.restoreFavorite` 呼叫 `POST /poi-favorites/:id/restore`。
- `_removeFavorite` 在 DELETE 成功後顯示復原通知；`_restoreFavorite` 處理成功、410 過期與一般錯誤。
- `favoriteRestoreEnabledProvider` 由 `FAVORITE_RESTORE_ENABLED` 控制。
- `.github/workflows/mobile.yml:199-203,292-295` 的 IPA／AAB release build 都傳入 `FAVORITE_RESTORE_ENABLED=true`。
- `tool/verify_favorite_restore_contract.sh` 已定義 staging create → delete → restore contract。

因此 Flutter「是否有接 API」的答案是**有**。但本機 source audit 不能取代 deployed backend 驗證；既有 `docs/mobile-e2e.md:221` 仍保留舊的 BLOCKED snapshot，而使用者已表示後端完成，交付前必須重新產生證據並更新該紀錄。

後端接線 Definition of Done：

1. 從 `master` 手動執行 Mobile CI / Releases，開啟 `run_optional_evidence`。
2. `favorite_restore_contract` job 在 protected `mobile-release` environment 通過。
3. 實測同一 favorite id：create → DELETE → GET active list 不可見 → restore 200 → GET 只出現一筆且原 timestamp 保留。
4. 第二使用者 restore 為 404；逾期 restore 為 410 `UNDO_EXPIRED`；重複 restore 符合後端契約。
5. iOS／Android release artifact 的 feature flag 都為 true，實機 DELETE 後顯示「復原」，點擊後收藏回到清單。
6. 更新 `docs/mobile-e2e.md` 的 Favorite restore staging contract 狀態、run URL、SHA 與日期。

收藏 delete／restore 本次不擴張進離線 queue：6 秒 undo 與跨重啟 queue 的時間語意容易衝突。離線時應阻止動作並保留原 row，顯示「需要網路連線才能移除收藏」；除非後續另立 offline favorite lifecycle 規格。

## 4. 實作順序

1. 共用基礎：Root Header leading、Header／Day selector 語意、Sheet audit tests。
2. 行程詳情：字級、返回、timeline ↔ map toolbar action。
3. 收藏／新增停留點：搜尋、Day field、分類單行、取消文字。
4. 刪除：行程與收藏接入既有 `SwipeToDelete`。
5. 地圖：卡片內容、preview／selection state 分離、相機互動測試。
6. 離線：App-level foreground reconnect observer、能力矩陣與 UX 文案。
7. Release evidence：staging restore contract、實機驗證、文件狀態更新。

## 5. 驗收條件

### UI／導覽

1. 單一行程頁的景點名為 15pt role、次要資訊 13pt role，Day 主標不超過 20pt role；100%／200% text scale 無裁切。
2. 任意方式進入 `/trips/:tripId` 都可一鍵回到 `/trips`。
3. Header／Day selector 中不存在把 action 與 selection 混在同一 segmented control 的畫面；聊天、行程、收藏的內容文字滑到其後方時，不再能辨識下層字詞，前景 15–17pt 文字對合成背景達 4.5:1，selected state 不只靠顏色。
4. 聊天／行程／地圖／收藏只有底部 root tab bar 表示根層級選取。
5. 收藏搜尋與行程一覽使用同一 `AppSearchField` 佈局與行為。
6. 新增停留點完整顯示「取消」；模式文字為「搜尋／收藏／自訂」；Day 與分類皆不產生第二行 chips。

### 刪除／Sheet

7. 行程、收藏、停留點、筆記列表列都支援 trailing swipe；VoiceOver／More 仍可執行同一動作。
8. 行程永久刪除仍需確認；收藏移除可在 6 秒內以 restore API 復原。
9. fixed selection／content／screen sheet 無 grabber；resizable form sheet 有 grabber且 medium／large 高度不同。
10. `lib/features/**` 內直接平台 Sheet presentation call 數量為 0。

### 地圖

11. POI 卡不再顯示「停留 n / total」與箭頭，且時間起訖、分類各有獨立行。
12. raw POI category 不出現在 UI 或 accessibility label。
13. 連續滑動多張 POI 卡時 map center／zoom 完全不變；點卡片後才移動。
14. 點 marker 會選中正確卡片並置中；頁面切 Day 後不殘留錯誤 active marker。

### 離線／restore

15. 有 cache 離線讀、無 cache 離線錯誤、stale → fresh、pending patch 不重複套用的 tests 全通過。
16. Entry／Note 離線 mutation 可跨 App 重啟保留，回前景、手動重試、前景 online transition 都只同步一次。
17. 線上限定操作在離線時提供明確 persistent／inline feedback，不假裝已成功。
18. staging restore contract 與實機 undo path 通過，並更新 `docs/mobile-e2e.md` 的舊 BLOCKED evidence。

## 6. 測試計畫

- Widget golden matrix：iPhone 320／390／430pt，Light／Dark，100%／200% text scale；加入高對比大字、黑白交錯文字滑到 Header／Day selector 後方的 worst-case fixture。
- Accessibility visual：Increase Contrast／Reduce Transparency 下 Header 接近不透明，前景與背景不出現雙層可讀文字。
- Widget interaction：返回、搜尋、Day picker、分類橫滑、swipe delete、Sheet grabber matrix。
- Map controller spy：PageView swipe 不呼叫 `move`；card／marker tap 各呼叫一次。
- Offline unit：`api_client_getstream_test.dart`、`api_client_sendmutation_test.dart`、`flush_queue_test.dart`、`offline_sync_test.dart`。
- Favorites widget／repository：feature flag true、DELETE、undo restore、410、一般錯誤、離線阻止。
- Release contract：`tool/verify_favorite_restore_contract.sh` 只在受保護的 staging environment 執行。

本次本機稽核中，純 cache 測試的前 14 個案例可在 `--no-pub` 下通過；完整 Flutter/widget suite 因目前本機 Flutter SDK 將 `meta` 固定為 1.17.0，而 `liquid_glass_widgets 0.22.1` 要求 `meta ^1.18.0`，無法完成 dependency resolution。另有 shell contract tests 依賴 `chmod`／bash，不適合直接以 Windows runner 判斷後端成功。實作 PR 必須在專案支援的 CI／Flutter SDK 與 Ubuntu contract runner 重新跑完整矩陣，不得把本次部分通過視為 release 證據。

## 7. 非目標

- 本規格不重做整套視覺品牌、底部 tab bar 或地圖 provider。
- 不把所有 mutation 擴張成離線可寫；能力以 §3.9 矩陣為準。
- 不建立第二套 Header、SearchField、Sheet、SwipeToDelete 或 POI card framework。
- 不在本次加入通用回收桶、Trip restore、Day restore 或跨裝置 undo。
- 不因追求卡片變短而關閉 Dynamic Type 或低於 44pt 操作區。
