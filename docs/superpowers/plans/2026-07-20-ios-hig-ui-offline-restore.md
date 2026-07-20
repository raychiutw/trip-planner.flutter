# Tripline iOS HIG UI、地圖 POI 與離線／Restore Implementation Tasks

> 狀態：TASK-00～09 完成；TASK-10 等待 staging protected environment；TASK-11 本機 gate 完成、CI／上架待執行
> 規格來源：`docs/superpowers/specs/2026-07-20-ios-hig-ui-offline-restore-audit.md`
> 原則：逐 TASK 實作、逐 TASK 驗證；重用現有共用元件，不新增 UI dependency。

## 文件優先序

本文件是 2026-07-20 規格的執行拆解。若以下舊 plan 與本文件衝突，以 2026-07-20 spec／本文件為準：

- `2026-07-18-hig-navigation-sheet-semantics.md`：保留架構背景，但「地圖 action 與 Day 混在同一 selector」的舊決策已失效。
- `2026-07-19-hig-visual-search-polish.md`：保留已完成的視覺基礎，但 Favorites Header search mode 與大型 Timeline 字級的舊決策已失效。

## 全域限制

- 不建立第二套 Header、SearchField、Sheet、SwipeToDelete、POI card 或離線 queue。
- 不新增設計系統；Navigation material 只允許「文字內容」與「視覺內容」兩種語意。
- `platformViewBackdrop` 只表示平台視圖相容路徑，不拿來代表內容是否為文字。
- 所有 15–17pt 導覽文字對實際合成背景達 4.5:1；支援 100%／200% Dynamic Type。
- 每個 TASK 先更新最小失敗測試，再改 production code，再跑該 TASK focused tests。
- 本機 Flutter 若仍因 `meta 1.17.0`／`liquid_glass_widgets 0.22.1` 無法解依賴，不得為了跑測試擅自降版套件；改用專案支援的 Flutter／CI runner 驗證。
- 本文件不授權 push、release 或修改後端；TASK-10 的 external verification 需使用既有 protected environment。

## 任務對照

| 原需求 | TASK |
|---|---|
| 1. 單一行程字級 | TASK-03 |
| 2. 返回行程列表 | TASK-01 |
| 3. Root Header／tab 語意與背景穿透 | TASK-01、TASK-02 |
| 4. 收藏搜尋對齊行程一覽 | TASK-04 |
| 5. 新增停留點 UI | TASK-05 |
| 6. 滑動刪除 | TASK-06 |
| 7. Sheet grabber | TASK-07 |
| 8. 地圖 POI 卡與相機互動 | TASK-08 |
| 9. 離線與 restore 接線 | TASK-09、TASK-10 |

## 執行狀態（2026-07-20）

| TASK | 狀態 | 證據／阻擋 |
|---|---|---|
| 00–09 | DONE | Flutter 3.44.6；focused tests 與 1,284 個產品測試通過；analyzer 0 issue |
| 10 | BLOCKED（外部設定） | App route／release flag 已接；`mobile-release` 無真實 staging secrets／variables，allowlist 只有 `.test` fixture，不能安全執行 mutation contract |
| 11 | LOCAL PASS | Dart format、analyzer、產品 suite、Android debug APK 皆通過；Linux workflow、iOS signed build 與 store upload 待 commit 後執行 |

## 執行順序

```text
TASK-00
  ├─ TASK-01 ─ TASK-02 ─┐
  ├─ TASK-03 ───────────┤
  ├─ TASK-04 ───────────┤
  ├─ TASK-05 ───────────┤
  ├─ TASK-06 ───────────┤─ TASK-11
  ├─ TASK-07 ───────────┤
  ├─ TASK-08 ───────────┤
  └─ TASK-09 ─ TASK-10 ─┘
```

TASK-03～08 在 TASK-01 的共用 API 定稿後可各自進行；TASK-10 是 external evidence，不阻擋其他 UI TASK。

---

## TASK-00：建立可重現基線

**目的：** 在改 UI 前鎖定目前行為、工具鏈與截圖，不把環境錯誤誤判成產品 regression。

**檔案：**

- Read：`pubspec.yaml`、`.github/workflows/mobile.yml`
- Run：既有 focused tests；不修改 production code

**步驟：**

- [x] 確認工作分支以最新 `master` 為基底，記錄起始 SHA 與既有 dirty files。
- [x] 使用專案支援的 Flutter SDK 執行 `flutter pub get`；記錄版本。
- [x] 跑現有 root、timeline、favorites、entry-add、sheet、map、offline focused tests。
- [x] 擷取需求中的三張畫面作 before evidence；另補聊天／行程／收藏文字滑到 Header 後方的最差案例。
- [x] 若 dependency resolution 失敗，只建立獨立工具鏈 blocker；不得混入 UI diff。

**完成條件：** baseline SHA、Flutter version、focused test 結果與 before screenshots 均可追溯。

---

## TASK-01：修正共用 Root Header 可讀性與返回能力

**覆蓋：** 需求 2、3。

**修改檔案：**

- `lib/ui/tp_glass_surface.dart`
- `lib/ui/tp_root_scaffold.dart`
- `lib/features/chat/chat_screen.dart`
- `lib/features/trips/trips_list_screen.dart`
- `lib/features/favorites/favorites_screen.dart`
- `lib/features/trip_detail/trip_timeline_screen.dart`
- 地圖 Root 呼叫端（只標示 visual background）

**測試：**

- `test/ui/tp_glass_surface_test.dart`
- `test/ui/tp_root_scaffold_test.dart`
- `test/features/chat/chat_screen_test.dart`
- `test/features/trips/trips_list_screen_test.dart`
- `test/features/favorites/favorites_screen_test.dart`
- `test/app/router_test.dart`

**步驟：**

- [x] 在既有 navigation material 入口加入單一兩態語意：文字內容預設 regular／strong backer，地圖等視覺內容明確 opt in 較透明版本。
- [x] 文字背景起始以 Light 0.88–0.92、Dark 0.84–0.90 驗證；依實際合成對比微調，不把 alpha 散落到 feature。
- [x] `Increase Contrast`／`Reduce Transparency` 使用接近不透明的 system background。
- [x] `TpRootHeaderConfig` 增加可選 leading；`TpRootGlassHeader` 以 44pt hit target 排版，不建立行程專用 Header。
- [x] 單一行程第一層加入「返回行程列表」，固定導向 `/trips`，深連結也可用。
- [x] 保留 `showSoftEdge` 作下緣過渡，但測試證明它不是 Header 內部遮罩。
- [x] 以高對比黑白文字捲過 Header，確認下層字詞不可辨識且前景達 4.5:1。

**完成條件：** 聊天／行程／收藏不再出現雙層可讀文字；地圖仍保留背景辨識；任何入口進入單一行程都能回 `/trips`。

---

## TASK-02：拆開跨頁 action 與 Day selection

**覆蓋：** 需求 3。

**修改檔案：**

- `lib/ui/tp_horizontal_selector.dart`
- `lib/features/trip_detail/trip_timeline_screen.dart`
- `lib/features/trip_detail/trip_map_screen.dart`

**測試：**

- `test/ui/tripline_ui_test.dart`
- `test/features/trip_detail/trip_timeline_screen_test.dart`
- `test/features/trip_detail/trip_map_screen_test.dart`
- `test/flows/hig_regression_matrix_test.dart`

**步驟：**

- [x] 先加測試：Day selector 只能收到 selection options，不能渲染 action divider。
- [x] 從 timeline selector 移除「地圖」，從 map selector 移除「行程」。
- [x] timeline ↔ map 改為 Root Header 的單一 toolbar action，分別使用 map／list symbol 與完整語意標籤。
- [x] `TpHorizontalSelector` 不再處理 `isAction`；`TpScopeOption` 若仍被其他元件使用，不做無關模型重構。
- [x] selected Day 使用實心 pill／邊界／字重；unselected label 對合成背景達 4.5:1。
- [x] Day 超寬時維持水平捲動與 selected auto-reveal。

**完成條件：** Bottom tab bar 是唯一根導覽；Header 是 command；Day selector 是純互斥 selection。

---

## TASK-03：行程詳情字級對標收藏

**覆蓋：** 需求 1。

**修改檔案：**

- `lib/features/trip_detail/widgets/day_header.dart`
- `lib/features/trip_detail/widgets/timeline_entry_tile.dart`
- `lib/features/trip_detail/widgets/travel_pill.dart`

**測試：**

- `test/features/trip_detail/widgets/day_header_test.dart`
- `test/features/trip_detail/widgets/timeline_entry_tile_test.dart`
- `test/features/trip_detail/widgets/travel_pill_test.dart`
- `test/features/trip_detail/trip_timeline_screen_test.dart`

**步驟：**

- [x] 加 typography role tests，不以 pixel screenshot 單獨判斷。
- [x] Day 顯示標題改 `headlineSmall` 20pt；DAY／日期／摘要改 13pt role。
- [x] 停留時間改 15pt tabular role；景點名改 15pt／600，分類與說明改 13pt。
- [x] 交通 pill 改 13pt／600。
- [x] 移除被取代的局部 hard-coded font size，不變更全域 theme token。
- [x] 100%／200% text scale 檢查不裁切；內容可增高，關鍵文字不可縮小隱藏。

**完成條件：** 行程內容與收藏 15／13pt 層級一致，Day 主標不超過 20pt。

---

## TASK-04：收藏搜尋改為行程一覽模式

**覆蓋：** 需求 4。

**修改檔案：**

- `lib/features/favorites/favorites_screen.dart`

**測試：**

- `test/features/favorites/favorites_screen_test.dart`

**步驟：**

- [x] 先改測試要求 Header 固定顯示「收藏」。
- [x] 在 Header 下方常駐既有 `AppSearchField`，placeholder「搜尋收藏」，間距對齊行程一覽。
- [x] 移除 `_searching`、Header title swap、搜尋 icon 與 search-only cancel action。
- [x] 保留輸入即篩選、clear、highlight、empty result、排序與篩選。
- [x] 刪除失去用途的 search-mode branches，不新增 Favorites search wrapper。

**完成條件：** 收藏與行程一覽的搜尋位置、尺寸、清除與鍵盤行為一致。

---

## TASK-05：重排新增停留點表單

**覆蓋：** 需求 5。

**修改檔案：**

- `lib/features/trip_detail/entry_add_route_screen.dart`
- 必要時只調整既有 `TpAppBar` 的共用 action sizing

**測試：**

- `test/features/trip_detail/entry_add_route_screen_test.dart`
- `test/ui/tp_app_bar_test.dart`（只有共用 sizing 變更時）

**步驟：**

- [x] 模式文案改為「搜尋／收藏／自訂」，三段永遠單行。
- [x] 把全部 Day chips 改成單一「日期」欄位；點擊重用 `showAppSelectionSheet<int>`，目前值用 checkmark。
- [x] POI 分類從 `Wrap` 改為單一水平捲動列，五個分類不得折行。
- [x] 搜尋 placeholder 改「搜尋」，保留 2 字門檻、300ms debounce 與 stale-response guard。
- [x] 修正 leading action sizing，320pt／200% text scale 完整顯示「取消」；title 可 ellipsis，「取消／加入」不可只剩單字。
- [x] 「加入」在未選 POI／資料不足時維持 disabled，不改 API flow。

**完成條件：** 指定文案正確；Day／分類無第二行 chips；「取消」完整且 hit target ≥44pt。

---

## TASK-06：補齊列表滑動刪除

**覆蓋：** 需求 6。

**修改檔案：**

- `lib/features/trip_detail/widgets/reorderable_row.dart`
- `lib/features/trip_detail/trip_timeline_screen.dart`
- `lib/features/trip_detail/trip_notes_screen.dart`
- `lib/features/trips/trips_list_screen.dart`
- `lib/features/favorites/favorites_screen.dart`
- 若跨 feature import 不合理：只把 `SwipeToDelete` 搬到一個 `lib/ui/` 檔案，既有四個 consumers 共用

**測試：**

- `test/features/trip_detail/widgets/reorderable_row_test.dart`
- `test/features/trip_detail/trip_timeline_screen_test.dart`
- 筆記既有 screen test
- `test/features/trips/trips_list_screen_test.dart`
- `test/features/favorites/favorites_screen_test.dart`

**步驟：**

- [x] 先鎖定共用 trailing → leading swipe、destructive red、trash label 與 semantics。
- [x] 行程列表接入 swipe；完成手勢後沿用既有永久刪除確認，取消時 row 回位。
- [x] 收藏列表接入 swipe；直接 DELETE 並沿用 6 秒 restore undo。
- [x] 停留點／筆記保持既有行為，只更新共用 import（若搬檔）。
- [x] 保留 More／長按／可見按鈕與 VoiceOver custom action，不把 swipe 當唯一入口。
- [x] Day 表單與批次刪除不套 swipe。

**完成條件：** 四種列表皆能 swipe；高風險行程刪除仍確認；收藏可復原；非手勢入口仍存在。

---

## TASK-07：稽核 Sheet grabber，不做無效重構

**覆蓋：** 需求 7。

**主要檔案：**

- `lib/app/adaptive.dart`
- Feature call sites 只讀盤點；只有發現錯用 wrapper 才修改

**測試：**

- `test/app/adaptive_sheet_test.dart`
- `test/ui/shared_ui_usage_test.dart`

**步驟：**

- [x] 加 matrix test：selection／content／screen 固定 0.93 且無 grabber。
- [x] 加 form test：0.62／0.93 detents 不同且有 grabber。
- [x] iOS action sheet 不加自訂 grabber。
- [x] 靜態檢查 `lib/features/**` 無直接 `showModalBottomSheet`、`showCupertinoModalPopup`、`showGeneralDialog`。
- [x] 實機逐張確認；符合矩陣者標 PASS，不為了視覺一致全部加橫條。
- [x] 只有 runtime 與 wrapper 語意不符時才改 `adaptive.dart` 或 call site。

**完成條件：** 共用 wrapper 覆蓋率 100%；grabber 只表示真的可 resize。

---

## TASK-08：重做地圖 POI 卡內容與選取狀態

**覆蓋：** 需求 8。

**修改檔案：**

- `lib/features/trip_detail/trip_map_screen.dart`
- 必要時 `lib/ui/tp_bottom_accessory.dart`（僅共用高度不符時）

**測試：**

- `test/features/trip_detail/trip_map_screen_test.dart`
- 地圖 controller／canvas 既有 focused tests

**步驟：**

- [x] 先建立 map controller spy：PageView swipe 不得呼叫 `move`，card／marker tap 各只呼叫一次。
- [x] 拆開 preview page index 與 `_activeEntryId`；`onPageChanged` 只更新 preview／indicator。
- [x] card tap 才提交 active selection 並 focus map；marker tap 同時選卡、移 pager、focus map。
- [x] 移除「停留 n / total」與右箭頭；保留編號 marker 對照。
- [x] 顯示 `startTime–endTime`；缺值依 spec fallback。
- [x] 分類獨立一行並使用 `poiCategoryLabel()`，不顯示 raw snake_case。
- [x] 一般字級目標維持 88pt accessory；移除 text scale 1.2 即跳 144pt 的突變，Accessibility 可按內容增高。
- [x] 切 Day 與手動移圖後再滑卡，不得搶回 map camera。

**完成條件：** POI 可自由滑；滑卡 map center／zoom 不變；點卡或 marker 才移動；卡片內容與高度符合規格。

---

## TASK-09：補前景恢復網路的自動同步

**覆蓋：** 補充需求 9 的離線缺口。

**修改檔案：**

- `pubspec.yaml`／`pubspec.lock`（只有確認現有 dependency 無法提供 connectivity stream 時，加入最小 `connectivity_plus`）
- `lib/features/offline/offline_sync.dart`
- `lib/main.dart`

**測試：**

- `test/features/offline/offline_sync_test.dart`
- `test/api/cache/api_client_getstream_test.dart`
- `test/api/cache/api_client_sendmutation_test.dart`
- `test/api/cache/flush_queue_test.dart`

**步驟：**

- [x] 保留冷啟動、`onResume`、手動 retry 三個既有入口。
- [x] 提供一個可測試的 App-level connectivity stream；只監聽 offline → online transition。
- [x] online transition 呼叫既有 `OfflineSyncController.sync()`；沿用 `state.isLoading`／`_flushing` 防重入。
- [x] 連續相同 online events 不重複 flush；observer dispose 後不再觸發。
- [x] connectivity 只當 retry trigger，不把「有網卡」當作後端成功；錯誤與 queue 保留政策不變。
- [x] 不把 Favorite、Trip／Day、reorder、segment 擴張進 offline queue；UI 清楚標示其線上限定。

**完成條件：** 冷啟動、resume、手動、前景重連各有測試；同一 transition 只 flush 一次；既有 queue／SWR tests 全通過。

---

## TASK-10：確認收藏 DELETE／Restore 的部署接線

**覆蓋：** 補充需求 9 的後端 restore 驗證。

**預期 source code：** 不修改；目前 repository、screen 與 release flag 已接線。

**證據／文件：**

- `tool/verify_favorite_restore_contract.sh`
- `.github/workflows/mobile.yml`
- `docs/mobile-e2e.md`

**步驟：**

- [ ] 確認 protected `mobile-release` environment 的 staging URL、兩組帳號、fixture POI 與 guard secrets 已配置。
- [ ] 從 `master` 手動執行 Mobile CI / Releases，開啟 `run_optional_evidence`。
- [ ] `favorite_restore_contract` 驗證 create → delete → active-list exclusion → cross-user containment → restore → single active row → cleanup。
- [ ] 驗證 restore 保留 favorite id／原 timestamp；第二使用者 404；過期 410。
- [ ] 以 release artifact 實機驗證 DELETE 後顯示 6 秒「復原」，點擊後回到清單。
- [ ] 更新 `docs/mobile-e2e.md` 舊 BLOCKED snapshot，記錄 run URL、SHA、日期與 PASS／實際 blocker。

**完成條件：** staging contract 與實機 undo 都有可追溯證據；失敗時 release evidence 明確標 blocker，不宣稱後端已驗證。

---

## TASK-11：整體回歸與交付檢查

**依賴：** TASK-01～10 完成或有明確 external blocker。

**步驟：**

- [x] `dart format` 所有變更 Dart 檔。
- [x] `flutter analyze` 0 error。
- [ ] 逐 TASK focused tests 全通過，再跑 `flutter test`。
- [ ] `flutter build ios --simulator`；Android 至少完成既有 CI build gate。
- [x] Golden／實機矩陣：320／390／430pt、Light／Dark、100%／200%、Increase Contrast／Reduce Transparency。
- [x] 重拍聊天、行程、收藏、地圖、新增停留點、四種 swipe、五種 Sheet 狀態。
- [x] 驗證 Header 背後最差文字 fixture、POI swipe camera invariant、offline foreground reconnect。
- [ ] 對照 spec §5 的 18 項驗收條件逐一打勾；未通過不得標完成。
- [ ] 檢查 diff：沒有新 UI framework、沒有 feature-local sheet/header/search duplicate、沒有未使用 compatibility branch。

**完成條件：** spec 18 項驗收全數 PASS；external restore 若受阻，僅 TASK-10 標 BLOCKED 並附證據，其餘不得被誤標完成。

## TASK 狀態表

| TASK | 狀態 | 備註 |
|---|---|---|
| TASK-00 | DONE | 基線與工具鏈 |
| TASK-01 | DONE | Header material／Back |
| TASK-02 | DONE | Action／Day selector |
| TASK-03 | DONE | Typography |
| TASK-04 | DONE | Favorites search |
| TASK-05 | DONE | Add stop UI |
| TASK-06 | DONE | Swipe delete |
| TASK-07 | DONE | Sheet audit |
| TASK-08 | DONE | Map POI card／camera |
| TASK-09 | DONE | Foreground reconnect |
| TASK-10 | BLOCKED（外部設定） | App route／release flag 已接；缺少真實 staging protected environment 與 allowlist |
| TASK-11 | LOCAL PASS | 本機 regression 已通過；Linux CI、iOS signed build 與 store upload 由 ship 階段執行 |
