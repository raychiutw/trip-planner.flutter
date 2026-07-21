# Tripline 帳號、未登入首頁、Day 導覽、滑動刪除與聊天體驗 Implementation Tasks

> 狀態：IMPLEMENTED；TASK-01～06 已完成自動化驗證，iOS 實機矩陣待有裝置時執行
>
> 規格日期：2026-07-20
>
> 2026-07-20 執行決策：TASK-02 採用 `trip-planner/docs/design-sessions/2026-07-20-landing-page-FINAL-variantB.html` 為 Welcome 首頁定稿並開始實作。
>
> 2026-07-20 版型補充：功能說明在同一頁直接呈現，不設「往下點」或第二層展開；主標是一個句子，不強制斷行。隱私權與刪除帳號內容由產品後續提供。
>
> 2026-07-21 導覽更正：行程／地圖切換保留在 Root Header；Day tab 只放 scope options；地圖恢復「總覽」。
>
> 驗證基底：`master` / `c82c75b032e3f5b26e87fd62455bf703b8ab94cb`
>
> 範圍：本文件只規劃本輪 8 項需求與「景點刪除後不提供復原」補充，不授權 push、release 或後端修改。

## 文件優先序

本文件是 2026-07-20 UI 規格的後續修正。若與 `docs/superpowers/plans/2026-07-20-ios-hig-ui-offline-restore.md` 衝突，只覆蓋以下決策：

1. 「地圖／行程」是跨頁切換，保留在 Root Header；Day 導覽列只放可選範圍。
2. 舊 TASK-06 使用 `Dismissible.confirmDismiss`，滑過門檻會直接執行刪除。本輪改成左滑只揭露右側紅色按鈕，必須再點按鈕才進入既有刪除流程。
3. 地圖保留「總覽」與實際 DAY；「總覽」以 sentinel index 0 聚合所有日期的 pins、routes 與 POI cards。

其他已完成的字級、返回行程列表、收藏搜尋、Sheet、離線與 Restore 接線規格維持不變。

## 全域限制

- 不修改 API contract、資料庫、離線 queue 或後端 Restore API。
- 景點管理的備選景點刪除成功後不顯示 Undo，也不呼叫 Restore API。
- 收藏既有的 Undo／Restore feature flag、行程／停留點／筆記既有確認流程不得被共用滑動元件改寫。
- 左滑不得直接刪除，也不得設定 full-swipe dismiss；滑動只負責揭露 action。
- Day 導覽與 POI 卡滑動是兩種不同手勢。前者是互斥選擇，後者是自由水平捲動。
- 未登入首頁以程式繪製的內嵌向量插畫呈現，不依賴遠端下載，也不包含真實帳號、私人行程或即時定位資料。
- 所有新 UI 支援 Light／Dark、100%／200% Dynamic Type、VoiceOver 與至少 44pt 觸控目標。
- 本輪允許新增兩個已驗證相容的 dependency：`package_info_plus: ^10.2.1`、`flutter_slidable: ^4.0.3`。目前工具鏈 Flutter 3.41.5、Dart 3.11.3、AGP 8.13.2、Gradle 8.14 符合套件需求。
- 每個 TASK 先調整最小失敗測試，再改 production code，再跑 focused tests。

## HIG 與平台行為決策

| 主題 | 規格決策 | 依據 |
|---|---|---|
| 未登入首頁 | 使用一頁式、可立即理解的 welcome page，不做多頁強制教學；3 張內嵌向量插畫各搭一段短文，底部提供主要 CTA「登入後開始使用」 | [Apple HIG: Onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding) 建議流程簡短、聚焦產品體驗，避免要求使用者記住大量內容 |
| 列表刪除 | 左滑揭露 action，紅色按鈕被點擊後才刪除；保留可見選單與 VoiceOver action | [Apple HIG: Gestures](https://developer.apple.com/design/human-interface-guidelines/gestures) 將 swipe 的常見用途定義為揭露 actions／controls；[Lists and tables](https://developer.apple.com/design/human-interface-guidelines/lists-and-tables) 將 delete／reorder 視為列表操作 |
| 不可復原的景點刪除 | 點擊紅色刪除後再顯示確認；成功後只顯示完成訊息，不提供 Undo | [Apple HIG: Alerts](https://developer.apple.com/design/human-interface-guidelines/alerts) 建議對不常見且無法復原的破壞性動作提供確認 |
| 自由水平捲動 | 保留現有 `PageView` 與 0.74 viewport，但設 `pageSnapping: false`；滑動只更新預覽卡，不移動地圖 | [Flutter `PageView.pageSnapping`](https://api.flutter.dev/flutter/widgets/PageView/pageSnapping.html) 明確支援關閉吸附 |
| 鍵盤收合 | 訊息清單開始拖曳即收鍵盤；點輸入區外也收鍵盤；點麥克風／送出仍視為 composer 內操作 | [Flutter `ScrollViewKeyboardDismissBehavior.onDrag`](https://api.flutter.dev/flutter/widgets/ScrollViewKeyboardDismissBehavior.html)、[`EditableText.onTapOutside`](https://api.flutter.dev/flutter/widgets/EditableText/onTapOutside.html) |
| 內容捲過玻璃控制列 | 聊天訊息 viewport 延伸到 Header、composer 與 Root Tab 下方；初始位置仍保留安全淨空 | [Apple HIG: Scroll views](https://developer.apple.com/design/human-interface-guidelines/scroll-views) 與 [Layout](https://developer.apple.com/design/human-interface-guidelines/layout) 支援內容在控制區後方捲動並以 scroll-edge／safe area 維持清楚層級 |

Apple HIG 定義的是互動與層級，不指定 Flutter 元件。`flutter_slidable` 用於實作「揭露後停留、再點擊」；`Dismissible` 不再適合此需求。[`flutter_slidable` 官方說明](https://pub.dev/packages/flutter_slidable) 支援 end action pane、點擊後關閉與捲動時關閉，且未設定 `DismissiblePane` 時不會 full-swipe 刪除。

## 需求對照

| 原需求 | TASK | 可觀察結果 |
|---|---|---|
| 1. 帳號頁面底部增加版本資訊 | TASK-01 | 帳號完整頁與 avatar 帳號 Sheet 底部顯示 App 版本與 build number |
| 2. 未登入首頁含功能圖片與登入 CTA | TASK-02 | 未登入進 App 先看到 welcome page；CTA 進入登入並保留 deep link |
| 3. 行程 Day tab 間距對齊地圖，還原地圖按鈕 | TASK-03 | 兩頁 Day rail 距 Header 一致；Root Header 顯示「地圖」action |
| 4. 管理景點使用 iOS 左滑刪除 | TASK-04 | 備選景點左滑揭露紅色「刪除」，不再用 inline trash 直接執行 |
| 5. 2026-07-21 更正：地圖保留 Header「行程」與「總覽」；POI 自由滑動 | TASK-03、TASK-05 | 跨頁 action 不進 Day tab；總覽與 DAY 可選；POI 不吸附 |
| 6. AI 聊天可滑動／點畫面收鍵盤 | TASK-06 | drag 或 tap outside 皆 unfocus，composer 回到一行休息狀態 |
| 7. 共用刪除先揭露紅色按鈕 | TASK-04 | 行程、收藏、停留點、筆記、備選景點使用相同 reveal interaction |
| 8. AI 訊息可捲到輸入框／功能 tab 下方 | TASK-06 | 訊息在 glass composer／root tab 後方仍可見，初始最新訊息不被遮住 |
| 補充：景點刪除後不用復原 | TASK-04 | 備選景點刪除成功不出現 Undo，也沒有 Restore 呼叫 |

## 已驗證的目前狀態

以下行號以本文件基底 SHA 為準，實作前若 `master` 已前進須重新定位。

| 區域 | 目前實作 | 根因／缺口 |
|---|---|---|
| 帳號 | `lib/features/account/account_screen.dart:82-176` 的完整頁與 embedded Sheet 都只在內容尾端放登出；`pubspec.yaml:30-59` 沒有 package info dependency | 無 runtime app metadata，也沒有共用 version footer |
| 未登入入口 | `lib/app/router.dart:59-78` 初始 `/trips`，未登入受保護頁直接 redirect `/login`；repo 沒有 onboarding image assets | 沒有 public welcome route，也無法先說明 App 價值 |
| Timeline Day rail | `trip_timeline_screen.dart:525-595` 使用 `initialContentTop + 64pt header delegate`，selector 內又加 8pt top padding；地圖 action 位於 Header `:157-170` | 只需修正 Day rail top gap；Header action 應保留 |
| Map Day rail | `trip_map_screen.dart:685-703` 第一個 option 是「總覽」；「行程」action 位於 Header `:111-124` | 此結構符合 2026-07-21 更正，需與新的 POI 自由滑動行為並存 |
| 管理景點 | `entry_poi_screen.dart:179-229` 的備選景點用 inline trash `IconButton` 直接呼叫 `removeEntryAlternate` | 沒有 swipe reveal；刪除也沒有不可復原確認 |
| 共用刪除 | `lib/ui/swipe_to_delete.dart:29-37` 使用 `Dismissible.confirmDismiss`，跨過門檻立即 `await onDelete()` | 背景雖顯示紅色按鈕，但它不是可停留、可點擊的 action |
| 共用刪除 consumers | `TripsListScreen`、`FavoritesScreen`、Timeline 停留點、Trip notes 共 4 類；備選景點尚未接入 | 共用外觀已存在，互動模型錯誤且覆蓋不完整 |
| 地圖 POI | `trip_map_screen.dart:797-818` 使用預設吸附的 `PageView.builder`；`onPageChanged` 只呼叫 `_previewStop` | 地圖不會因預覽滑動而移動已正確，但卡片仍有 page snapping 段落感 |
| AI 聊天鍵盤 | `chat_screen.dart:275-306` 的 `ListView` 未設定 `keyboardDismissBehavior`；`TextField` `:547-566` 未設定 `onTapOutside` | drag 與 tap outside 都不會主動 unfocus |
| AI 聊天層級 | `chat_screen.dart:253-307` 用 `Column` 排列 `Expanded(ListView)` 與 `_Composer` | List viewport 在 composer 上方就結束，訊息不可能出現在 composer 後方 |

## 執行順序

```text
TASK-00
  ├─ TASK-01
  ├─ TASK-02
  ├─ TASK-03 ─> TASK-05
  ├─ TASK-04
  └─ TASK-06
               └─> TASK-07
```

TASK-03 先定稿 Header 跨頁 action、Map overview sentinel 與 Day rail API，TASK-05 才改 POI pager，避免同一份 map test fixture 重複重寫。TASK-04 先改共用 reveal 元件，再接入管理景點。

---

## TASK-00：鎖定基線與測試探針

**目的：** 避免把既有完成項目或工具鏈問題誤算成本輪 regression。

**步驟：**

- [ ] 確認以最新 `master` 為基底，記錄 SHA 與 dirty files；不得清理無關變更。
- [ ] 先跑 8 個 focused test files：router、account、timeline、map、entry POI、shared swipe、chat、app shell。
- [ ] 保存 iPhone 直向 Light／Dark 的 account、login、timeline、map、entry POI、chat 基線截圖。
- [ ] 記錄目前 Header bottom、timeline selector top、map selector top 的 logical pixel rect。

**完成條件：** 基線測試結果、截圖與幾何值可重現；production code 尚未改動。

---

## TASK-01：帳號頁底部版本資訊

**狀態：DONE。** 完整頁與 embedded Sheet 共用實際 bundle 版本 provider。

**修改檔案：**

- `pubspec.yaml`、`pubspec.lock`
- New：`lib/app/app_version.dart`
- `lib/features/account/account_screen.dart`
- `test/features/account/account_screen_test.dart`

**實作決策：**

- [x] 加入相容版本 `package_info_plus: ^10.2.0`，以 `PackageInfo.fromPlatform()` 讀取 `version` 與 `buildNumber`，不得 hard-code `pubspec.yaml` 的 `0.9.1+12`。
- [ ] `app_version.dart` 提供可在 test override 的 `FutureProvider<AppVersion>`；model 只含 `version`、`buildNumber` 與 display label。
- [ ] 帳號完整頁與 `AccountScreen(embedded: true)` 共用 `_VersionFooter`，放在登出群組之後、scroll content 最末端、Safe Area 之前。
- [ ] 顯示格式固定為 `版本 0.9.1（12）`；build number 為空時顯示 `版本 0.9.1`。
- [ ] 使用 `labelSmall`／`onSurfaceVariant`、置中、單行；loading 顯示 `版本 …`，失敗顯示 `版本資訊無法取得`，不跳 modal 或 toast。

**測試情境（3）：** 完整頁格式、embedded Sheet 格式、build number 空值 fallback。

**完成條件：** 使用者從 `/account` 或 root avatar Sheet 進入帳號頁，捲到內容底部都能讀到同一份實際 bundle version。

---

## TASK-02：未登入 Welcome 首頁

**狀態：DONE。** 依 `2026-07-20-landing-page-FINAL-variantB.html` 完成響應式 Welcome 首頁、登入導流與安全 deep link。

**修改檔案：**

- New：`lib/features/auth/welcome_screen.dart`
- `lib/app/router.dart`
- New：`test/features/auth/welcome_screen_test.dart`
- `test/app/router_test.dart`
- `integration_test/support/app_flow_fixture.dart`
- `test/flows/app_owned_release_flow_artifacts_test.dart`

**內容與版型：**

- [x] Shell 外使用 pinned navigation + `CustomScrollView`，品牌為 `Tripline`，主標 `行程排壞了，講一句話就好`；窄螢幕可自然換行，但不插入強制斷行。
- [x] Hero 與三張功能卡使用 `CustomPainter` 內嵌向量插畫，不增加圖片資產或載入依賴。
- [x] 三項功能依序為 `說一句話就改好`、`每天的路線一眼看完`、`出發前先健檢`，內容直接顯示於同一頁；卡片不可點擊，也沒有「了解更多」。
- [x] 插畫提供 VoiceOver semantics，且不含 email、真實姓名、私人地址或目前定位。
- [x] Hero、頁尾均提供主要按鈕 `登入後開始使用`；不加 carousel、skip 或權限要求。
- [x] 目前頁尾只顯示版權。隱私權內容尚未提供，不能先建立空白頁或失效連結。

**路由決策：**

- [x] 新增 public `/welcome`，保留原本 shell 外登入、註冊、驗證與公開分享 routes。
- [x] 未登入造訪 protected route 改到 `/welcome?redirect_after=<站內路徑>`；首次啟動由 `/trips` redirect 到 welcome。
- [x] CTA 前往 `/login` 並攜帶經安全驗證的 `redirect_after`；登入成功後回原 deep link，沒有 deep link 時回 `/trips`。
- [x] 已登入造訪 `/welcome` 直接回安全站內目的地或 `/trips`。
- [x] 共用既有 safe internal redirect 判斷，拒絕外部目的地與 `/login`、`/welcome` auth loop。

**測試情境（6）：** 未登入首次啟動、welcome 三圖與 CTA、CTA 到 login、deep link round trip、已登入略過 welcome、惡意外部 redirect fallback。

**完成條件：** 未登入使用者不會先看到空白或直接撞登入表單；一頁內看懂 3 個核心功能並可開始登入。

**待內容提供後續作：** 新增單一 public `/privacy` 聲明頁；Welcome 頁尾與帳號頁都直接開啟同一路由。刪除帳號頁面與文案同樣等產品提供，不在本輪先放 placeholder。

### 建立帳號的個資同意流程（PLANNED）

此流程與 `/privacy`、signup API 同意紀錄一起實作；在正式告知內容與 API contract 完成前，不顯示無法閱讀的假同意框，也不先寫死 payload。

1. `SignupScreen` 在建立帳號按鈕前顯示一個預設未勾選的必要 checkbox：`我已閱讀並同意《隱私權聲明與個人資料蒐集告知事項》`。
2. 條款名稱是可點擊文字，使用 `push('/privacy')` 開啟完整聲明；返回註冊頁時保留已填 Email、名稱與密碼。
3. 使用者未勾選仍可點「建立帳號」，但表單內就地顯示 `請先閱讀並同意個資條款`；不使用 toast，也不呼叫建立帳號。
4. checkbox 不得預先勾選，不因曾開啟聲明自動勾選，也不把同意狀態寫入本機偏好。
5. `_submit()` 必須先驗證 checkbox；通過後才呼叫 `AuthRepository.signup()`。signup API 同時接收條款同意與條款版本，並由後端以伺服器時間保存可稽核紀錄。
6. payload 欄位名稱、條款版本格式、儲存 schema、錯誤碼與舊版本處理由後續 API／個資規格定義，本文件不先假設。
7. API 失敗沿用既有註冊錯誤呈現；不得因重試而自動改變 checkbox 狀態。若後端回報條款版本失效，必須取消同意並要求重新閱讀最新版。

**驗收：** 未勾選不會呼叫建立帳號；條款可讀且返回不清空表單；勾選後 signup payload 帶目前條款版本；後端可查到帳號、版本與伺服器接受時間；200% Dynamic Type 與 VoiceOver 可辨識 checkbox、必要狀態及條款連結。

**已先完成（2026-07-20）：** `SignupScreen` 使用原生 `FormField<bool>`／`CheckboxListTile`；未同意顯示 inline validation 且 repository 零呼叫，勾選後才走既有 signup，API 失敗仍保留勾選。focused widget tests 已覆蓋三條行為，尚未改 API contract。

**等待規格：** `/privacy` 正式內容與標題、signup payload 欄位與條款版本格式、後端儲存 schema／交易／錯誤碼、條款改版後是否要求重新同意，以及首頁與帳號頁正式入口；正式連結完成後再跑 200% Dynamic Type／VoiceOver 驗收。上述未定前不得宣告流程完成或上線。

---

## TASK-03：統一 Timeline／Map Day 導覽列

**狀態：DONE（2026-07-21 更正）。** Timeline／Map 的跨頁 action 位於 Root Header；Day rail 只含可捲 options，Map 保留總覽。

**修改檔案：**

- `lib/ui/tp_horizontal_selector.dart`
- `lib/features/trip_detail/trip_timeline_screen.dart`
- `lib/features/trip_detail/trip_map_screen.dart`
- `test/ui/tripline_ui_test.dart`
- `test/features/trip_detail/trip_timeline_screen_test.dart`
- `test/features/trip_detail/trip_map_screen_test.dart`
- `test/app/router_test.dart`

**共用元件決策：**

- [x] `TpHorizontalSelector<T>` 只接受 selection options；跨頁 action 放 Root Header。
- [x] Day options 使用互斥 selected semantics，長列表維持水平捲動與 selected auto-reveal。

**Timeline：**

- [x] Day rail top 改成 `TpRootGeometry.headerBottom(context) + TpSpacing.s2`，與 map 的 +8pt 完全一致。
- [x] `_selectorExtent` 改為 `TpSpacing.tapMin + TpSpacing.s1`，移除 selector 內額外的 8pt top padding；捲到 Day 的 offset 使用同一個 rail bottom 計算，不留 magic number。
- [x] Root Header 保留 `trip-timeline-map`；Day rail 不顯示跨頁 action，編輯排序模式隱藏 Header action。
- [x] 點 Header `地圖` 保留目前 active Day，前往 `/map?tripId=...&day=...`。

**Map：**

- [x] Root Header 保留 `trip-map-itinerary`；Day rail 不顯示跨頁 action，點擊回 `/trips/:tripId?day=<activeDay>`。
- [x] 恢復「總覽」option 與 sentinel index 0；實際 DAY 使用 index + 1。
- [x] deep-link entry 優先選其所屬 Day，其次 valid `initialDayNum`，最後第一天；使用者可再切到總覽。
- [x] 總覽聚合所有日期的 pins、routes、POI cards；單日只顯示 selected Day。

**測試情境（8）：** Header action 不在 Day selector、兩頁 top rect 差 ≤1px、timeline action 路由、map action 路由、總覽跨日 POI、預設 DAY 1、deep-link Day、無 Day empty state。

**完成條件：** Timeline 與 Map 的 Day rail 距 Header 相同；左右互切 action 位於 Root Header 且不污染 Day selection；Map 保留可聚合所有日期的總覽。

---

## TASK-04：共用左滑揭露刪除，並接入管理景點

**狀態：DONE。** 手勢只揭露紅色動作，點擊後才進入各 feature 的既有 policy。

**修改檔案：**

- `pubspec.yaml`、`pubspec.lock`
- `lib/main.dart`
- `lib/ui/swipe_to_delete.dart`
- `lib/features/trips/trips_list_screen.dart`
- `lib/features/favorites/favorites_screen.dart`
- `lib/features/trip_detail/trip_timeline_screen.dart`
- `lib/features/trip_detail/trip_notes_screen.dart`
- `lib/features/trip_detail/entry_poi_screen.dart`
- `test/features/trip_detail/widgets/reorderable_row_test.dart`
- 上述 5 個 feature 的既有 screen tests

**共用互動：**

- [ ] 加入 `flutter_slidable: ^4.0.3`；`SwipeToDelete` 內部改用 `Slidable + endActionPane + ScrollMotion + SlidableAction`。
- [ ] 不設定 `DismissiblePane`，因此任何滑動距離都不得呼叫 `onDelete`。
- [ ] 左滑後 action pane 停留，右側顯示 destructive red、trash icon 與客製 `actionLabel`；點 action 才呼叫 `onDelete`，完成後自動收合。
- [ ] list 開始垂直捲動時自動收合；同一列表最多一列保持開啟。使用同一 `groupTag` 與 `SlidableAutoCloseBehavior`，不自行寫 gesture recognizer。
- [ ] 保留 `CustomSemanticsAction`。VoiceOver 可直接選「刪除／移除收藏」；非手勢使用者仍可用既有 More、長按或可見按鈕。
- [ ] 共用元件只負責 reveal 與 callback，不內建確認、API、optimistic update 或 Undo。

**各資料類型 policy：**

| 資料 | 點紅色 action 後 | Undo／Restore |
|---|---|---|
| 行程 | 沿用「刪除行程」確認，確認後 delete | 無，維持現況 |
| 收藏 | 沿用立即移除與 `favoriteRestoreEnabledProvider` | feature flag 開啟時保留既有 Undo |
| Timeline 停留點 | 只在管理／排序模式可左滑；沿用確認 | 無，維持現況 |
| 筆記 | 沿用「刪除筆記」確認 | 無，維持現況 |
| 備選景點 | 新增「移除備選景點？」確認，確認後 `removeEntryAlternate` | **無 Undo、無 Restore，依使用者補充** |

**管理景點細節：**

- [ ] `EntryPoiScreen` 每張備選 `_PoiCard` 接 `SwipeToDelete(actionLabel: '刪除')`。
- [ ] 移除 trailing row 的 inline trash `IconButton`；上移、下移、設為正選與編輯資訊維持。
- [ ] 確認取消時不呼叫 repository；成功後使用既有 `_run` refresh 與成功訊息，但不得呼叫 `showAppUndoNotice`。
- [ ] API 失敗時 row 留在資料源並顯示既有 persistent error／notice，不顯示假成功。
- [ ] 正選景點仍用「置換正選」，本輪不新增移除 master 的 API 或 UI。

**測試情境（至少 12）：** 小幅滑動不刪除、完整左滑也不刪除、點紅色 action 才 callback、垂直捲動收合、同組只開一列、VoiceOver action、四個既有 consumer policy 各一、備選取消、備選成功無 Undo、備選失敗保留。

**完成條件：** 所有單列刪除看起來與操作方式一致；手勢只揭露控制；備選景點刪除必須經按鈕與確認，成功後不可復原。

---

## TASK-05：地圖 POI 卡自由水平滑動

**狀態：DONE。** POI pager 可自由停留；預覽滑動不改地圖中心。

**修改檔案：**

- `lib/features/trip_detail/trip_map_screen.dart`
- `test/features/trip_detail/trip_map_screen_test.dart`
- `integration_test/support/app_flow_fixture.dart`
- `test/flows/app_owned_release_flow_test.dart`

**步驟：**

- [ ] 現有 `PageController(viewportFraction: 0.74)`、card 尺寸、指示器與 marker → card animate 行為保留。
- [ ] `PageView.builder` 設 `pageSnapping: false`；不加自訂分段 physics。
- [ ] 水平 drag／fling 的 `onPageChanged` 只呼叫 `_previewStop`，只更新卡片強調與指示器，不呼叫 `_focusStop`、`fitCamera` 或 `move`。
- [ ] 點卡片才呼叫 `_selectStop` 並移動地圖；點 marker 可移動地圖並 animate 到對應卡片，維持現況。
- [ ] 切換 Day 後 pager 回該 Day 第一張卡，仍不因普通 POI 滑動改地圖中心。

**測試情境（5）：** `pageSnapping == false`、release 可停在非整頁 offset、drag 不 move camera、tap card move camera、tap marker animate pager。

**完成條件：** 使用者可連續、自由地水平瀏覽 POI；只有明確點選才改地圖座標。

---

## TASK-06：AI 聊天鍵盤收合與玻璃下層捲動

**狀態：DONE。** 有訊息與空對話內容層均可點擊收鍵盤，拖曳列表亦會收合。

**修改檔案：**

- `lib/features/chat/chat_screen.dart`
- `test/features/chat/chat_screen_test.dart`
- `test/features/shell/app_shell_test.dart`
- `integration_test/support/app_flow_fixture.dart`
- `test/flows/app_owned_release_flow_test.dart`

**鍵盤：**

- [ ] `chat-list` 加 `keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag`。
- [ ] `chat-input` 加 `onTapOutside`，呼叫 `FocusManager.instance.primaryFocus?.unfocus()`。
- [ ] composer 的 TextField、mic、send 包在同一 `TextFieldTapRegion`；點 mic／send 不被誤判為 outside。
- [ ] drag 或 tap outside 只收鍵盤，不清空草稿、不送出、不停止已在進行的 request；TextField 回到最少 1 行、最多 4 行的既有尺寸規則。

**訊息與玻璃層級：**

- [ ] `_ChatBodyState.build` 由 `Column` 改為 `Stack`：訊息／empty／error viewport `Positioned.fill`，composer 對齊底部並保留現有 glass。
- [ ] 用 `SizeChangedLayoutNotifier + GlobalKey` 取得 composer 實際高度；chat list physical bottom 延伸到畫面底部，但 resting padding 使用 `composerHeight + TpSpacing.s2`，確保最新訊息預設不被遮住。
- [ ] composer 由 1 行增長到 4 行、鍵盤開關或 Dynamic Type 改變時，bottom padding 同步更新，誤差 ≤1 logical pixel。
- [ ] 列表 viewport 維持 top=0 與既有 `contentTop` 起始 padding，因此訊息上捲可經過 Root Header 後方；下方可經過 composer 與 Root Tab 後方。
- [ ] composer／Root Tab 以 glass 提供前景層級；不得新增一整塊 opaque scaffold background 把下方訊息遮掉。
- [ ] 既有 reverse pagination、送出後 `jumpTo(0)`、AI consent、語音輸入、markdown link 與錯誤 banner 行為不得變更。

**測試情境（8）：** drag unfocus、tap outside unfocus、tap mic/send 不先被 outside 攔截、草稿保留、list bottom 超過 composer top、resting 最新訊息在 composer 上方、4 行 composer padding 更新、上捲分頁不 regression。

**實機視覺驗收：** Light／Dark 各錄一段：鍵盤展開 → 拖曳收合 → 訊息捲過 Header、composer、Root Tab；前景控制文字持續可讀，後方訊息可辨識但不與控制文字形成雙層可讀干擾。

**完成條件：** 聊天的鍵盤能以 iOS 慣用 drag 與 tap 收合；訊息像收藏／行程一樣在浮動玻璃元件後方連續捲動。

---

## TASK-07：整體回歸、可及性與交付檢查

**目前證據：** 本次 18 個 Dart 檔格式檢查通過；`flutter analyze --no-pub` 0 issue；11 組 focused tests 共 259 項通過；共用 app-owned flow、artifact flow 與新增 swipe/chat 回歸通過。完整 `flutter test` 有 1,308 項通過，僅 12 項 POSIX workflow script 在 Windows 因 `chmod`／shell 環境失敗；`integration_test/app_smoke_test.dart` 因未連接支援的 iOS／Android 裝置而未執行。

**自動化：**

- [ ] `dart format --output=none --set-exit-if-changed lib test integration_test`
- [ ] `flutter analyze`
- [ ] 跑 TASK-01～06 全部 focused tests。
- [ ] `flutter test`
- [ ] 更新並執行 `test/flows/app_owned_release_flow_test.dart`，讓同一條 app-owned flow 覆蓋 welcome、trip day rail、map POI、delete 與 chat；不得建立五條重複 fixture。
- [ ] 執行 `integration_test/app_smoke_test.dart`；實機環境可用時再跑同一 fixture 的 Patrol 包裝。
- [ ] dependency license／lockfile diff 只包含 `package_info_plus` 與 `flutter_slidable` 及其必要 transitive packages。

**實機矩陣：**

| 尺寸／模式 | 必查項目 |
|---|---|
| iPhone 小尺寸直向 | Welcome 三圖與 CTA 可捲完；Day action／DAY 不折行；delete action 完整顯示 |
| iPhone 一般直向 | Timeline／Map rail top 對齊；POI free scroll；chat glass underlay |
| iPhone 橫向 | Welcome、Day rail、chat composer 不溢位 |
| Light／Dark | 圖片卡、destructive red、version footer、glass 前後景可讀 |
| Dynamic Type 200% | 版本資訊不截斷；Day 可水平捲；delete 44pt；composer 最多 4 行後內部捲動 |
| VoiceOver | Welcome 閱讀順序、Day action vs selected Day、delete custom action、chat composer controls |

**完成條件：** analyzer 0 issue、產品 test suite 通過、實機矩陣無 overflow／誤刪／鍵盤卡住／地圖誤移動；只提交本文件定義的檔案。

## 驗收條件總表

1. 帳號完整頁與 embedded Sheet 都顯示實際 `version + buildNumber`。
2. 未登入首次啟動顯示一頁式 welcome，包含 3 張 bundled product images 與 `登入後開始使用`。
3. 未登入 deep link 經 welcome → login 後回安全站內目的地；外部 redirect 被拒絕。
4. Timeline 與 Map Day rail 距 Header 的 top gap 都是 `TpSpacing.s2`，幾何差 ≤1px。
5. Timeline Root Header action 是 `地圖`；Map Root Header action 是 `行程`，兩者都不進 Day rail。
6. Map Day rail 提供「總覽」與實際 DAY；總覽聚合所有日期的 pins、routes 與 POI cards。
7. POI PageView `pageSnapping == false`，拖曳 POI 不移動相機，點選才移動。
8. 所有 `SwipeToDelete` 左滑只揭露右側紅色按鈕；放手或 full swipe 均不呼叫 delete callback。
9. 管理景點的備選景點刪除需點紅色按鈕並確認；成功後沒有 Undo／Restore。
10. 收藏既有 Undo feature flag、其他資料的確認與替代刪除入口維持原行為。
11. Chat list drag 與 tap outside 都能收鍵盤，草稿內容保留。
12. Chat 訊息 viewport 延伸到 composer／Root Tab 下方，resting 最新訊息仍不被遮住。
13. 100%／200% Dynamic Type、Light／Dark、VoiceOver 與 44pt 目標通過。
14. 本輪不產生 API、資料庫、離線 queue、Restore contract 或 release workflow 變更。

## 測試層級與預計數量

| 層級 | 範圍 | 最少新增／更新情境 |
|---|---|---:|
| Unit / widget | version provider/footer、welcome、selector action、swipe reveal、map pager、chat focus/layout | 42 |
| Router / integration | welcome auth redirect、Day route preservation、delete callback、map camera、chat keyboard | 14 |
| 實機視覺／手勢 | 6 個畫面 × Light／Dark／Dynamic Type 重點矩陣 | 18 captures |

## 預估工時

| TASK | 人工程時 | 說明 |
|---|---:|---|
| 00 | 0.25 天 | 基線與截圖 |
| 01 | 0.25 天 | metadata provider + footer |
| 02 | 1.0 天 | 內嵌向量插畫、welcome、router、安全 redirect tests |
| 03 | 1.0 天 | selector API、兩頁 Day state／geometry |
| 04 | 1.25 天 | dependency、5 類 consumer、刪除 policy tests |
| 05 | 0.25 天 | free-scroll 與 map camera tests |
| 06 | 1.0 天 | focus、動態 composer 尺寸、overlay layout |
| 07 | 0.5 天 | full suite 與實機矩陣 |
| **合計** | **5.5 天** | 不含隱私權／刪除帳號內容與後端工作 |

## Rollback

- TASK-01、02：移除 Welcome route／畫面與 version provider／dependency，router 回復未登入直達 `/login`。
- TASK-03、05：回復 Day state 或 `pageSnapping` 時不得移除 Root Header 跨頁 action，也不得只改 Timeline／Map 其中一邊。
- TASK-04：可回復 `SwipeToDelete` implementation 與 dependency，但管理景點 inline delete 必須一起回復，避免刪除入口消失。
- TASK-06：回復 chat `Column` 與 focus callbacks；不影響 message API 或資料。
- 所有變更均是 client UI／routing，無資料 migration；正常 rollback 為 revert 對應 commit。

## Out of Scope

- 移除正選景點、刪除整個 POI 資料庫項目或新增後端 Restore API。
- 重做登入／註冊表單、權限 onboarding、教學 carousel、App Store 行銷頁。
- 隱私權聲明與刪除帳號內容；待產品提供後，Welcome 頁尾與帳號頁共用 `/privacy`。
- 重做地圖卡牌內容、路線演算法、marker clustering 或 Google Maps adapter。
- 改變收藏 Restore feature flag 或其他既有資料刪除政策。
- 重做全 App Root Header、Root Tab、Sheet grabber 或設計 token。
- 本文件階段不修改 production code、不 commit、不 push、不 release。
