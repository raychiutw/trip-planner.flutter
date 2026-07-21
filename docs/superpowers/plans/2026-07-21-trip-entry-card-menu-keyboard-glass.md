# Tripline 行程景點卡、操作選單、鍵盤與 Liquid Glass 修改規劃

> 狀態：IMPLEMENTED — App 程式與自動化測試已完成；iOS Simulator／實機視覺與 VoiceOver 驗收仍須在 macOS／實機執行。本文件不授權 commit、push 或 release。
>
> 規格日期：2026-07-21
>
> 視覺參考：使用者提供的 Tripline Web 行程列、地圖連結與備選景點畫面；App 端依 Apple HIG、Dynamic Type 與觸控操作調整，不逐像素複製 Web。

## 目標

把行程時間軸改成「卡片本身就能讀、常用操作就近、編輯入口明確」的 iOS 慣用互動，同時修正跨行程 Day 狀態、全 App 鍵盤收合、Root Account 導覽與目前過度不透明的 Liquid Glass。

## 本輪產品原則

- 卡片點擊負責展開備選景點，不再等同「編輯」。
- 編輯、移動、複製、刪除等命令集中在卡片右上 `…`，並以分隔線分組。
- 重新排序使用單一短按拖曳 handle，且同一次拖曳可以跨到其他 Day；不要求使用者先用「移動到其他天」再做第二次排序。
- 左滑只揭露紅色「刪除」按鈕；任何滑動距離都不能直接刪除。
- Liquid Glass 只用於 Header、Day selector、Root tab、menu／sheet 等功能層；景點卡與備選內容維持實色 surface。
- 沿用既有 routes、repository 與共用元件，不新增第二套景點管理流程，也不先增加 UI 套件。
- Light／Dark、320pt 寬螢幕、100%／200% Dynamic Type、Reduce Motion、Reduce Transparency／High Contrast 與 VoiceOver 都是完成條件。

## Apple HIG 對標結論

| 主題 | 規劃結論 | HIG 依據 |
|---|---|---|
| Root Account | Account 是頂層目的地，可成為第 5 個 tab；固定顯示、單字 label，不再在各頁 Header 重複 avatar | [Tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars) 建議 tab 只承接頂層導覽，維持穩定，預設五項以內 |
| `…` 命令 | 使用靠近景點卡的 pull-down menu；共通命令使用熟悉 icon，刪除標記 destructive 並獨立在末組 | [Menus](https://developer.apple.com/design/human-interface-guidelines/menus)、[Pull-down buttons](https://developer.apple.com/design/human-interface-guidelines/pull-down-buttons) |
| 起訖時間 | 以緊湊時間欄位開啟鄰近／底部的原生 time picker；不在表單中永久放大型自製控制 | [Pickers](https://developer.apple.com/design/human-interface-guidelines/pickers) 建議 picker 在欄位附近或底部呈現，空間有限時使用 compact style |
| 左滑刪除 | 紅色背景、trash icon、完整「刪除」label、再次點擊才觸發；不可 full-swipe 執行 | [SwiftUI destructive role](https://developer.apple.com/documentation/swiftui/buttonrole/destructive) 展示 destructive swipe action 的 system red、icon 與 label |
| 不可復原刪除 | 點擊 destructive action 後才顯示明確確認；成功後不提供 Undo／Restore | [Alerts](https://developer.apple.com/design/human-interface-guidelines/alerts) 建議少見且不可復原的破壞性操作確認，按鈕使用具體動詞 |
| Liquid Glass | 導覽浮在內容上方並讓內容可透出；一般背景使用 regular glass，不把內容卡玻璃化；無障礙設定需有實色 fallback | [Materials](https://developer.apple.com/design/human-interface-guidelines/materials)、[Adopting Liquid Glass](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass) |
| 鍵盤收合 | 可捲動表單拖曳即收鍵盤；點欄位以外收鍵盤，但不清空文字或送出 | [UIScrollView keyboardDismissMode](https://developer.apple.com/documentation/uikit/uiscrollview/keyboarddismissmode-swift.property) |

## What already exists

### 可直接重用的 App 能力

- `TpRootScaffold` 已讓內容與 Root Header 使用同一個 `Stack`，具備內容從玻璃下方捲過的結構。
- `TpGlassSurface`、`tpNavigationGlassSettings`、`TpHorizontalSelector`、`AppleRootTabBar` 已統一使用 `liquid_glass_widgets`。
- `TpMoreMenuButton` 與 `TpActionItem.dividerBefore` 已支援錨定選單、分隔線、icon 與 destructive role。
- `SwipeToDelete` 已使用 `flutter_slidable`，目前左滑揭露右側紅色 action，沒有 `DismissiblePane`，不會 full-swipe 直接刪除。
- `EntryEditRouteScreen`、`EntryActionRouteScreen`、`EntryPoiScreen` 已有編輯、移動、複製與景點管理畫面。
- `TripRepository` 已有 `reorderEntries`、`changeEntryPoi`、`updateEntry`、`moveEntry`、`copyEntry`、`deleteEntry`、`setEntryMaster` 等 API 接線；其中 `reorderEntries` batch payload 已支援同時送 `day_id` 與 `sort_order`，跨天拖曳不需新增 endpoint。
- `TimelineEntry` 已包含 `description`、`note`、`master` 與 `alternates`；`EntryPoiInfo` 已包含座標、分類、營業時間、星等、價位、備註、訂位與說明。
- Web `TimelineRail` 已提供本次要求的 menu 分組、MapLinks、正選／備選呈現與「設為正選」行為，可作資料優先序參考。

### 已確認的現況落差

| 現況 | 原因／影響 |
|---|---|
| 切換行程後 Timeline 可能保留舊的 Day number | `_TimelineBodyState.didUpdateWidget` 在新行程也有相同 Day 時不會重設 `_activeDayNum`；Header state 與 body state 可能不同步 |
| 景點卡點擊直接開編輯 Sheet | `_DaySection` 將 `TimelineEntryTile.onTap` 綁到 `showEntryEditSheet`，沒有展開備選的 resting state |
| 時間在卡片上方、編號貼齊時間列 | `TimelineEntryTile` 把 `_EntryTimeRange` 與 `_EntryCard` 分成兩段；rail badge 固定 top alignment |
| 卡片沒有 `…` | 非排序模式 `trailing` 為 null；編輯／移動／複製入口分散在其他頁或模式 |
| 排序只能在同一 Day 內移動 | 每個 `_DaySection` 各自建立一個 `ReorderableListView`，`_previewReorder` 也只更新單一 `dayId`；目前無法把卡片直接拖進另一日 |
| App 只有 Google Maps 外開 helper | 尚無 Google／Apple 共用導航列與 Apple Maps URL builder |
| 編輯表單只部分支援鍵盤收合 | 目前只有 5 個 scroll view 設定 `onDrag`，少數 TextField 有 `onTapOutside`；共 18 個含輸入欄位的 App 檔案需要一致性盤點 |
| Header／Day selector 看起來接近實色 | `tpNavigationGlassSettings(visualContent: false)` 使用約 88–90% tint 並設定同色 `backerColor`，背景內容幾乎無法透出 |
| Root tab 仍是四項且各 Root Header 放 avatar | `AppleRootTabBar` 只有聊天／行程／地圖／收藏，`/account` 仍是 shell 外 route |

## 資訊架構與畫面規格

### 1. 跨行程與 Day 狀態

建議規則：

1. 同一行程在「行程 ↔ 地圖」切換時保留目前 Day。
2. 由 Header 行程選擇器切到另一個行程時，預設回新行程 `DAY 1`，不得沿用舊行程的 Day number。
3. 只有明確 deep link `?day=N` 或 `entry` focus 可以覆蓋預設 Day。
4. 新行程沒有任何 Day 時顯示既有 empty state，不保留舊 selector 狀態。

實作時要讓 `tripId` 成為 Day state reset 條件，並以 router query 作唯一外部初始來源；不得只重設 Header 的 `_activeDayNum`。

> 已核准 D1：切換到不同 Trip 回到 `DAY 1`；同一 Trip 的行程／地圖切換保留目前 Day。

### 2. 景點卡 resting state

```text
      ┌──────────────────────────────────────────────┐
  2   │ 景點名稱                                …   │
      │ 12:00–13:30 ✎ · 用餐 · 1.5 hr · ★ 4.6       │
      │ [Google 地圖] [Apple 地圖]                  │
      │ 水族館附近覓食，本部町在地美食               │
      │ 備註：靠窗座位／已訂位 18:30                 │
      └──────────────────────────────────────────────┘
```

- 編號圓圈以「主景點卡」垂直中心對齊；timeline 線獨立貫穿前後交通列，不因卡片增高而中斷。
- 第一行：景點名稱，尾端固定 44×44pt `…` hit target。
- 第二行：可點的起訖時間 chip、細分類、停留時間、星等；使用 `Wrap`，200% Dynamic Type 可換行，禁止縮字。
- 第三行：導航 pills。缺座標時可用景點名稱／地址 query；完全無可用位置時不顯示導航列並提供 VoiceOver 說明「尚無位置」。
- 第四行：依序顯示 entry 說明、master POI 說明、master POI 備註，再顯示價位／濃縮營業時間／訂位資訊；空欄位不保留空白列。
- `entry.description` 與 `master.note` 是不同語意，不合併寫回同一欄位。
- 卡片為內容層，維持 `surfaceContainerLow` 實色，不套 Liquid Glass。

### 3. 起訖時間替代方案

| 方案 | 操作 | 優點 | 代價 |
|---|---|---|---|
| A — 兩個 compact time chips（建議） | 卡片第二行或編輯頁顯示「開始」「結束」兩個值；各自點擊開平台自適應 time picker | 最接近 iOS Calendar，操作直接，仍沿用現有 `startTime`／`endTime` API | 需兩次點擊完成完整區間 |
| B — 單一「起訖時間」bottom sheet | 點一列後在同一 sheet 內同時編輯開始／結束兩組 wheels | 一次看完整區間，驗證錯誤就地顯示 | 自製組合控制較重，Dynamic Type／鍵盤／橫向測試較多 |
| C — 開始時間＋停留時間 | 只選開始時間，再從 30m／1h／1.5h／自訂選 duration，自動算結束 | 對行程規劃很快，直接對應卡片的停留時間 | 會改變現有資料心智模型，跨午夜與自訂分鐘較複雜 |

建議採 A：iOS 使用 bottom sheet 內 `CupertinoDatePicker(mode: time)`，Android 沿用 Material time picker；兩平台共用驗證與 `HH:mm` 序列化。開始／結束可清除，兩者皆空時第二行顯示單一「未設定時間」chip，不保留空白或 `--:--`。結束不得早於或等於開始；跨午夜是否支援需由 D5 核准，不由工程規格默認排除。

> 已核准 D2：採方案 A，兩個 compact time chips＋平台自適應 picker。

### 4. 景點卡 `…` 選單

選單只放以下 6 項，順序與分隔線固定：

```text
重新排序
換景點
────────────
編輯景點
移動到其他天
────────────
複製到其他天
刪除景點       （destructive red）
```

- `重新排序`：進入 timeline 層級的 reorder mode；仍只保留短按拖曳 handle，不恢復長按第二模式。
- 排序模式開始時強制收合所有備選 accordion，停用卡片展開、左滑刪除與其他卡片按鈕，只保留名稱及拖曳 handle。
- 拖曳可在同一 Day 內排序，也可直接跨 Day。拖到相鄰 Day／畫面邊緣時自動捲動；每張卡片前後與空 Day 都必須有明確 drop target，目標 Day 顯示高亮但不得跳動整個 layout。
- 現有每 Day 一個 `ReorderableListView` 無法跨列表拖曳；實作改由 timeline parent 管理單一 drag state，使用 Flutter 既有 `Draggable`／`DragTarget` 與目前的短按 handle，不新增套件。
- drop 後先更新 source／target Day 的本地 snapshot，再以既有 `reorderEntries` 一次送出受影響 entry 的 `day_id + sort_order`；失敗時還原兩日 snapshot 並顯示 persistent error，成功後重算 source／target Day 的交通。
- `移動到其他天` menu 仍保留，作為不便拖曳、鍵盤與 VoiceOver 使用者的等價入口；不是跨天排序的唯一方法。
- `換景點`：開既有 `EntryPoiScreen`／change master 流程。
- `編輯景點`：push 既有 `EntryEditRouteScreen`，不使用整張卡片 tap。
- `移動到其他天`、`複製到其他天`：push 既有 `EntryActionRouteScreen`；只有一日行程時 disabled，並提供原因語意。
- `刪除景點`：先進既有不可復原確認，再呼叫 `deleteEntry`；成功後不提供 Undo／Restore。
- 選單 icon 使用既有 Cupertino／Material familiar symbols；每項至少 44pt 高，刪除項需有 destructive role 與 VoiceOver label。
- 卡片仍保留左滑刪除作直接操作；menu 中的刪除是可發現、可由鍵盤／VoiceOver 使用的替代入口，兩者進同一個 confirm handler。

### 5. 直接點卡片展開備選景點

- 卡片 tap 改成 accordion toggle；一次最多展開一個景點，避免長行程同時展開造成定位迷失。
- 使用 `AnimatedSize`／既有 `TpMotion.resolve`；Reduce Motion 時立即切換。
- 展開區使用內容 surface，不使用 glass，順序如下：

```text
備選景點
  名稱 + 細分類
  Google／Apple 地圖
  ★ 星等 · 價位 · 濃縮營業時間 · 訂位資訊
  POI 說明
  POI 備註
  [設為正選]
```

- `TimelineEntry.alternates` 已隨 days payload 載入，展開不新增網路 request；設為正選後沿用既有 OCC、refresh 與交通重算。
- 無備選時展開顯示「尚無備選景點」與「換景點」action，不用空白區或 toast。
- loading／409／API error 沿用 `EntryPoiScreen._run` 的重新載入與 persistent error 原則；不得先移除 UI 再假裝成功。
- `…`、時間 chip、地圖 pill 與「設為正選」都必須阻止事件冒泡，不能誤觸 accordion。
- 卡片 `Semantics` 改為「展開／收合備選景點」，提供 expanded／collapsed state；不得沿用目前「點兩下編輯停留點」提示。
- 不得用包住整張卡片的 `ExcludeSemantics` 排除內部 controls；`…`、時間、地圖與「設為正選」都需保有獨立 VoiceOver focus、label 與正確閱讀順序。

### 6. 導航 pills

- 建立共用 `EntryMapLinks`，重用既有 `url_launcher`；不新增 dependency。
- Google Maps 使用座標優先、名稱／地址 fallback；Apple Maps 使用 `maps.apple.com` query／coordinate URL。
- 每個 pill 可見高度可小於 44pt，但 hit target 必須至少 44pt；icon 需有文字 label，不能只放 pin icon。
- `canLaunchUrl`／`launchUrl` 失敗時保留原卡片並顯示 persistent error；不得無反應、關閉展開區或假裝成功。iOS Apple Maps 不可用時可 fallback 到同一 `maps.apple.com` 網頁，Android 行為依 D3。

> 已核准 D3：Android 只顯示 Google；iOS／macOS 顯示 Google＋Apple，Apple App 無法開啟時允許網頁 fallback。

### 7. Account 改為第 5 個 Root tab

- Root tab 固定：聊天、行程、地圖、收藏、帳號。
- `AppleRootTabBar._destinations` 加入帳號 icon／label，router 的 `StatefulShellRoute` 新增第 5 branch `/account`。
- 移除 Chat、Timeline、Map、Favorites Root Header 的 `TpAccountAvatarButton`；因此 Header 騰出一個 action 位置。
- `/account` deep link 保留且改落到第 5 branch；帳號設定子頁仍 push 在 account branch 上，切 tab 後保留各 branch 導覽狀態。
- 登出後由現有 auth redirect 回 Welcome；Account tab 不 disabled／hidden。
- 320pt 與 200% Dynamic Type 下 5 個單字 label 必須完整可讀，不落入 More tab。

此項會覆蓋 `docs/discovery/design.md` 與 `docs/reference-theme.md` 目前「固定四項＋Header avatar」規則；實作完成時兩份文件必須同步更新。

### 8. 全 App 共用鍵盤收合

建立單一 keyboard dismissal policy，不建立每頁不同 helper：

1. 所有可捲動表單／搜尋結果設定 `keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag`。
2. 表單內容外層使用共用 `AppKeyboardDismissRegion`（名稱可在實作時簡化），點非輸入區呼叫 `FocusManager.instance.primaryFocus?.unfocus()`。
3. `TextFieldTapRegion` 包住欄位附屬的清除、麥克風、送出、日期／時間按鈕，避免操作 control 時先誤收鍵盤。
4. 收鍵盤不得清空文字、觸發 submit、改 dirty state、關閉 sheet 或取消正在進行的 request。
5. form sheet 高度必須隨 `viewInsets.bottom` 正常調整；鍵盤收合後回到原 detent，不留下空白。

盤點範圍至少包含：`adaptive.dart`、Account／Auth、Chat、Favorites Explore、Entry Add／Edit／POI、Notes、Travel Edit、Trip create／edit／share／collab 與 Trip picker，共 18 個目前含 `TextField`／`TextFormField` 的檔案。

優先把行為放進 `TpRootScrollView`、共用 sheet scaffold 與共用 form shell；只有不是上述容器的畫面才在 feature 層接入，避免包兩層 gesture listener。

### 9. Liquid Glass 修正

現況不是「沒有使用 glass 套件」，而是共用 recipe 太不透明：非地圖 Header／selector 使用約 88–90% tint 與同色 backer，深色內容又與 glass tint 接近，實機看起來像實色膠囊。

規劃調整：

- 把 `tpNavigationGlassSettings` 的語意由 `visualContent` 拆成明確 recipe：`regularNavigation`、`platformViewNavigation`、`opaqueAccessibilityFallback`；仍由同一共用函式產生。
- Header、Day selector、Root tab 使用 regular navigation：降低 tint、移除非必要 opaque backer，讓捲動內容可透出；文字多的 Header 不使用 clear variant。
- Map 上方 Header／Day selector／Root tab 使用 platform-view backdrop 相容模式；若套件只能 fallback，色彩仍需和 regular recipe 同層級，不能退成完全實色。
- selected tab／selected DAY 允許柔褐 tint，但未選 track 不可用 90% 實色遮住背景。
- 保留 High Contrast／Reduce Transparency 的 96% 實色 fallback；無障礙設定下變不透明是正確行為，不視為 bug。
- 不在 timeline 卡片、備選卡或設定 group 套 glass，避免整頁都在折射。
- 不先更換套件；只有 `liquid_glass_widgets 0.22.1` 在 iOS／Android PlatformView 實機驗證無法達到 backdrop、且有可重現證據時，才另開 dependency decision。

視覺驗收必須用有內容在下方滑動的錄影／連續截圖，不能只截靜止同色背景；至少比對 Header、Day selector、底部 5-tab 在 Light／Dark 與 Map PlatformView 上的透出、對比和字體可讀性。

### 10. 紅色刪除按鈕 HIG 判定

目前共用 `SwipeToDelete` 的方向是符合 HIG 的：右側 system error red、trash icon、完整「刪除」文字、使用者點按後才執行，而且沒有 full-swipe dismiss。

尚需在本輪驗收的條件：

- action 可停留且最小 44×44pt；200% Dynamic Type 不截成單字。
- 滑動放手、滑到最底或垂直捲動都不呼叫 `onDelete`。
- 同一列表最多一列保持開啟；開始捲動會自動關閉。
- VoiceOver 提供「刪除景點」custom action，不要求使用者一定要做 swipe。
- 點擊後進不可復原確認；取消零 API 呼叫，成功後無 Undo／Restore。
- menu delete 與 swipe delete 共用相同 handler、文案、錯誤與 refresh 行為。

通過以上矩陣後才標記「HIG 驗收完成」；只看紅色外觀不能單獨判定完成。

## Interaction state table

| 區域 | Resting | Pressed／Active | Loading | Empty | Error | Disabled |
|---|---|---|---|---|---|---|
| 景點卡 | 四列摘要＋`…` | 卡片展開備選；focus rim 不等於 edit | 設為正選顯示局部 progress | 顯示「尚無備選景點」＋換景點 | 保留原資料並顯示 persistent error | 無 entry id 時 menu commands 不可用 |
| 時間 chip | 顯示起訖或「未設定」 | 開啟 time picker | 儲存 action busy | 兩者皆空允許 | 結束不晚於開始就地顯示 | submitting 時不可再開 picker |
| `…` menu | 44pt hit target | 六項三組 | action route 自己管理 loading | 一日行程仍顯示 move/copy 但 disabled | route／API error 不關閉資料畫面 | 依 entry id／days 數量 disable |
| Reorder | 卡片正常可展開 | 只顯示名稱＋短按 handle；同日／跨日 drop target 高亮 | batch reorder 提交中鎖住第二次拖曳 | 空 Day 仍可接收 drop | 還原 source／target snapshot 並顯示 persistent error | 一日行程仍可同日排序；無 entry id 不可拖 |
| Swipe delete | 卡片正常 | 左滑揭露紅色按鈕 | confirm 後按鈕 busy，防重複 | 不適用 | 列保留並顯示錯誤 | submitting 時收合且停用 |
| Glass | regular translucent | selected item 柔褐 tint | 不改材質 | 仍保留導覽 | 不以玻璃傳達錯誤 | Reduce Transparency 用實色 fallback |

## User journey

| Step | 使用者操作 | 預期感受 | 規格支援 |
|---|---|---|---|
| 1 | 進入行程並掃讀一天 | 一眼知道名稱、時間、類別與備註 | 卡片四列資訊、編號置中、交通 rail 不跳動 |
| 2 | 點卡片查看備選 | 不離開時間軸也能比較 | inline accordion、導航與設為正選 |
| 3 | 點 `…` 找命令 | 操作位置可預期且不擠壓卡片 | 六項三組 menu、44pt target |
| 4 | 編輯時間／說明 | 鍵盤與 picker 可隨時收合 | compact time picker、drag／tap outside dismissal |
| 5 | 刪除景點 | 清楚知道是破壞性操作，不會一滑誤刪 | reveal → tap → confirm，無 full swipe |
| 6 | 切換 Root destination | Account 和其他功能一樣可預期 | 固定 5-tab、各 branch 保留 navigation state |

## 實作結果（2026-07-21）

| Task | 狀態 | 實作／驗證結果 |
|---|---|---|
| TASK-01 狀態與測試基線 | 完成 | 不同 Trip 回 DAY 1；同 Trip 行程／地圖保留 Day；同日與跨日實際拖曳 widget tests 已覆蓋 |
| TASK-02 Account／Day state | 完成 | Account 為第 5 個 root tab；Root Header avatar 已移除；設定子頁保留 branch navigation |
| TASK-03 鍵盤收合 | 完成 | App root 共用 tap-outside 與 user-scroll dismissal；收合不送出、不清除草稿 |
| TASK-04 起訖時間 | 完成 | compact chips；iOS／macOS Cupertino wheel，其他平台 Material picker；沿用既有 payload／驗證 |
| TASK-05 Timeline 卡片／排序 | 完成 | 四列摘要、marker 置中、單一短按 handle、同日／跨日 drop；batch 同步受影響兩日並支援失敗回滾 |
| TASK-06 MapLinks／備選 | 完成 | 平台適用 Google／Apple links、外開錯誤、accordion、empty state、設為正選 |
| TASK-07 `…` menu | 完成 | 六項三組、固定順序與 stable keys；move/copy disabled 狀態與原因語意；刪除為 destructive |
| TASK-08 Liquid Glass | 完成（待實機視覺驗收） | regular／PlatformView recipe 與 High Contrast fallback 已完成；Light／Dark widget tests 通過 |
| TASK-09 刪除 | 完成 | swipe 只揭露、點擊才確認；無 full swipe／Undo；menu 與 swipe 共用 confirm handler |
| TASK-10 文件／交付 | 完成（平台驗收待辦已寫入 handoff） | design、theme、navigation、舊計畫 superseded note 與 handoff 已同步 |

### 跨 Day 排序確認

- 排序模式只有一種：短按拖曳 handle 立即開始；卡片長按不會啟動第二套排序。
- 同一次拖曳可從來源 Day 放到另一 Day 的卡片前／後或空 Day；不必先執行「移動到其他天」。
- drop 後先更新本地 source／target snapshot，再以單一 `reorderEntries` batch 傳送所有受影響 entry 的 `day_id` 與 `sort_order`。
- request 期間鎖定下一次拖曳；失敗時同時還原來源與目標 Day、顯示 persistent error；成功後重算兩日交通。
- 「移動到其他天」仍留在 `…` menu，作為 VoiceOver、鍵盤及不便拖曳使用者的等價操作。

## Implementation tasks

### TASK-01：鎖定狀態規則與測試基線

**修改檔案：**

- `test/features/trip_detail/trip_timeline_screen_test.dart`
- `test/app/router_test.dart`
- `test/features/shell/app_shell_test.dart`

**內容：**

1. 增加跨行程 Day reset／保留 query deep link 測試。
2. 增加卡片 tap 不開 edit、`…` 才開 action 的失敗測試。
3. 增加 5-tab 與 `/account` branch route 測試。
4. 增加排序模式收合 accordion、同日排序與跨 Day 拖放的失敗測試；跨天 case 必須同時驗證 source／target 順序與 batch payload 的 `day_id + sort_order`。

### TASK-02：重構 Root Account 與 Day state

**修改檔案：**

- `lib/app/router.dart`
- `lib/features/shell/apple_root_tab_bar.dart`
- `lib/features/shell/app_shell.dart`
- `lib/features/chat/chat_screen.dart`
- `lib/features/trip_detail/trip_timeline_screen.dart`
- `lib/features/trip_detail/trip_map_screen.dart`
- `lib/features/favorites/favorites_screen.dart`
- `test/features/shell/app_shell_test.dart`
- `test/app/router_test.dart`

**內容：** 加入 Account 第 5 branch、移除四頁 Header avatar、修正 trip change reset Day；同一 trip 的 timeline／map 仍保留 Day。

### TASK-03：建立共用 keyboard dismissal policy

**修改檔案：**

- `lib/app/adaptive.dart`
- `lib/ui/tp_root_scaffold.dart`
- 盤點後需要接入的 feature form／search files
- `test/app/adaptive_sheet_test.dart`
- `test/ui/tp_root_scaffold_test.dart`
- 各輸入畫面的 focused widget tests

**內容：** 先擴充共用 scroll／sheet，再補 feature exception；測試 drag、tap outside、tap control、draft 保留與 viewInsets。

### TASK-04：時間欄位改為核准方案

**修改檔案：**

- `lib/features/trip_detail/widgets/entry_edit_sheet.dart`
- `lib/features/trip_detail/entry_edit_route_screen.dart`
- `test/features/trip_detail/widgets/entry_edit_sheet_test.dart`
- `test/features/trip_detail/entry_edit_route_screen_test.dart`

**內容：** 依 D2 核准方案替換目前兩個整列 OutlinedButton；共用 formatter、validation 與平台 picker，不改 API payload。

### TASK-05：重排 Timeline 景點卡資料層級

**修改檔案：**

- `lib/features/trip_detail/widgets/timeline_entry_tile.dart`
- `lib/features/trip_detail/trip_timeline_screen.dart`
- `lib/features/trip_detail/reorder_helpers.dart`（只放 source／target reorder 的純資料計算，不建立新 service）
- `lib/models/entry.dart`（只有 payload 已有但 model 缺欄位時才改）
- `test/features/trip_detail/widgets/timeline_entry_tile_test.dart`
- `test/features/trip_detail/trip_timeline_screen_test.dart`

**內容：** 時間移入卡片、未設定時間 chip、marker 垂直置中、四列資訊、200% wrapping；sorting compact mode 強制收合 accordion，只留名稱＋單一短按 drag handle，並把目前 per-Day reorder 改為 timeline parent 管理的同日／跨日 drag state。跨日 drop 以既有 `reorderEntries` batch 同步兩日排序、失敗還原兩日 snapshot，不新增 API 或 dependency。

### TASK-06：加入 MapLinks 與 inline alternates

**修改檔案：**

- 新增 `lib/features/trip_detail/widgets/entry_map_links.dart`
- `lib/features/map/google_maps_external_launcher.dart`
- `lib/features/trip_detail/widgets/timeline_entry_tile.dart`
- `lib/features/trip_detail/trip_timeline_screen.dart`
- `test/features/map/google_maps_external_launcher_test.dart`
- 新增 `test/features/trip_detail/widgets/entry_map_links_test.dart`
- `test/features/trip_detail/trip_timeline_screen_test.dart`

**內容：** Google／Apple URL、外開失敗 fallback／persistent error、卡片 accordion、備選 cards、empty／error／set-master；互動 control 阻止卡片 toggle，並重建卡片 Semantics，讓 accordion 與內部 controls 都能被 VoiceOver 獨立操作。

### TASK-07：加入每張卡片的 `…` menu

**修改檔案：**

- `lib/features/trip_detail/trip_timeline_screen.dart`
- 必要時小幅擴充 `lib/ui/tp_app_bar.dart`，但優先直接重用 `TpMoreMenuButton`
- `test/features/trip_detail/trip_timeline_screen_test.dart`
- `test/features/trip_detail/entry_action_route_screen_test.dart`
- `test/features/trip_detail/entry_edit_route_screen_test.dart`

**內容：** 六項三組、routes、disabled state、destructive role；`重新排序` 進入 TASK-05 的同日／跨日單一短按 drag 模式，`移動到其他天` 保留為非拖曳替代入口。

### TASK-08：Liquid Glass recipe 修正

**修改檔案：**

- `lib/ui/tp_glass_surface.dart`
- `lib/ui/tp_root_scaffold.dart`
- `lib/ui/tp_horizontal_selector.dart`
- `lib/features/shell/apple_root_tab_bar.dart`
- `lib/features/trip_detail/trip_map_screen.dart`
- `test/ui/tp_glass_surface_test.dart`
- `test/ui/tp_root_scaffold_test.dart`
- `test/ui/tp_horizontal_selector_test.dart`
- `test/features/shell/app_shell_test.dart`

**內容：** regular／PlatformView／accessibility recipes、降低 opaque backer、5-tab 指標與實機 PlatformView 驗證；不新增套件。

### TASK-09：統一刪除與回歸驗收

**修改檔案：**

- `lib/ui/swipe_to_delete.dart`（只在驗收發現問題時修改）
- `lib/features/trip_detail/trip_timeline_screen.dart`
- `test/ui/swipe_to_delete_test.dart`
- `test/features/trip_detail/trip_timeline_screen_test.dart`
- `test/flows/app_owned_release_flow_test.dart`

**內容：** swipe／menu 共用 confirm handler；驗證 reveal 不 delete、取消零呼叫、成功無 undo、錯誤保留 row、VoiceOver action。

### TASK-10：文件與交付

**修改檔案：**

- `docs/discovery/design.md`
- `docs/reference-theme.md`
- `docs/reference-navigation.md`
- `docs/superpowers/plans/2026-07-20-account-welcome-trip-map-chat-follow-up.md`（加 superseded note，不重寫歷史）
- `HANDOFF.md`

**內容：** 已更新四項→五項 Root tab、Header avatar 退場、卡片互動、keyboard policy、Glass recipes 與刪除驗收結果。

### 實作相依順序

依序執行 `TASK-01 → TASK-02 → TASK-05 → TASK-06 → TASK-07 → TASK-09`；這些 task 會共同修改 `trip_timeline_screen.dart` 與同一組 widget tests，不並行拆 PR。`TASK-03`、`TASK-04`、`TASK-08` 可在 TASK-02 後獨立進行，最後統一執行 TASK-10。

## 測試與驗收矩陣

### 自動化

- `dart format --output=none --set-exit-if-changed`：本輪變更 Dart 檔案須為乾淨格式。
- `flutter analyze`：通過，0 issue。
- focused widget tests：timeline tile／screen、同日／跨日 drag、entry edit、entry action、entry POI、router、app shell、glass、selector、swipe、keyboard forms，通過 172 tests。
- `flutter test --no-pub -r failures-only`：1,341 tests 全部通過，包含 27 個 POSIX workflow contract tests；Windows 使用 Git for Windows Bash，避免誤呼叫 WSL `bash.exe`。
- `flutter build apk --debug --no-pub`：通過，產出 `build/app/outputs/flutter-apk/app-debug.apk`。
- `flutter build ios --simulator`：Windows 無法執行，列入 macOS handoff 必跑項目。

### 實機／Simulator

| 矩陣 | 驗收重點 |
|---|---|
| iPhone 320pt／390pt／430pt | 5-tab label、`…`、時間 chip、導航 pills、刪除 label 不溢位 |
| 100%／200% Dynamic Type | 第二列可 wrap；卡片增高；編號仍置中；menu 與 delete 44pt |
| Light／Dark | Header／Day／Root tab 背景內容可透出，文字對比持續清楚 |
| Reduce Transparency／High Contrast | Glass 轉實色 fallback，仍可分辨 selected state |
| Reduce Motion | accordion、scroll-to-day、glass animation 不造成多餘 motion |
| VoiceOver | 卡片摘要與 expanded／collapsed state、內部時間／地圖／menu focus、非拖曳跨天入口、刪除與 Account tab 閱讀順序正確 |
| 同日／跨日排序 | 短按 handle 即可拖曳；畫面邊緣自動捲動；可 drop 到另一 Day 的任意位置或空 Day；送出中不可重複拖；失敗還原兩日 |
| Google Map PlatformView | map gestures 不被 Header／Day／Root tab 攔截；玻璃 fallback 不凍結、不閃爍 |

## 需求 1–10 對照

| 使用者需求 | 規劃位置 | 完成判準 |
|---|---|---|
| 1. 切換行程不能跨天 | §1、TASK-01/02、D1 | trip change 的 Day policy 有測試且 Header/body 同步 |
| 2. 所有鍵盤可收合並共用 | §8、TASK-03 | drag＋tap outside 全 App 一致，草稿不變 |
| 3. 起訖時間換控制 | §3、TASK-04、D2 | 核准方案完成平台 picker 與驗證 |
| 4. 卡片後方加 `…` | §2/4、TASK-07 | 每張非排序卡有 44pt More button |
| 5. 六項三組 menu | §4、TASK-07 | 順序、separator、routes、destructive 完整 |
| 6. Account 改第 5 tab | §7、TASK-02 | Header avatar 移除，Account branch 穩定存在 |
| 7. 編號與四列欄位 | §2/6、TASK-05/06 | marker 置中、time/meta/maps/info 完整 |
| 8. 卡片展開備選 | §5、TASK-06 | tap 不 edit；顯示 alternates／empty 並可設正選 |
| 9. Glass 透明度 | §9、TASK-08 | 三層導航可看見下方內容且可讀 |
| 10. 紅色刪除 HIG | §10、TASK-09 | reveal→tap→confirm，無 full swipe／undo |
| 補充：滑動換順序可跨天 | §4、TASK-01/05/07 | 同日／跨日皆使用單一短按 handle；batch 同步 source／target Day，失敗完整還原 |

## NOT in scope

- 不變更後端 schema／endpoint；現有 API 已涵蓋本輪命令與備選資料。若實作時發現 days payload 缺少 Web 已有欄位，另列 backend contract，不在 client 猜欄位。
- 不改地圖路線演算法、POI 搜尋 ranking、交通重算規則或離線 mutation queue。
- 不新增景點刪除 Restore／Undo；產品已明確要求不要復原。
- 不重做 EntryPoiScreen 的完整管理功能；本輪只讓 timeline 展開常用備選摘要與設正選。
- 不新增跨天拖曳後端 API；沿用 `PATCH /trips/:id/entries/batch` 的 `day_id + sort_order`。若實際 backend contract 不接受跨 Day batch，才回報 contract blocker，不在 App 串接兩個非原子 request 假裝完成。
- 不把 timeline 卡片、備選卡、設定 group 玻璃化。
- 不更換 `liquid_glass_widgets`；先修共用 recipe 並實機驗證。
- 本輪未執行 commit、push 或發布；需由使用者另行授權。

## 已核准產品決策

| 決策 | 核准結果 | 實作狀態 |
|---|---|---|
| D1：切換行程後的 Day | 不同 Trip 回 DAY 1；同 Trip 行程／地圖互切保留 Day | 完成並有 widget tests |
| D2：起訖時間控制 | A：兩個 compact time chips＋平台 picker | 完成 |
| D3：Android 是否顯示 Apple 地圖 | Android 只顯示 Google；iOS／macOS 顯示 Google＋Apple | 完成 |
| D4：無備選時卡片 tap | 展開 empty state＋「換景點」 | 完成 |
| D5：起訖時間是否允許跨午夜 | 本輪不支援；結束時間必須晚於開始時間 | 完成 |

## Design review summary

| Pass | 初始 | 草案後 | 說明 |
|---|---:|---:|---|
| Information architecture | 5/10 | 9/10 | 卡片 tap、menu、edit 與 Root Account 職責已分離 |
| Interaction states | 4/10 | 9/10 | 已補 resting／expanded／loading／empty／error／disabled |
| User journey | 6/10 | 9/10 | 從掃讀、比較、編輯到刪除形成連續動線 |
| AI-slop risk | 8/10 | 9/10 | 沿用 Web 資料層級與 App primitives，沒有新增裝飾性卡片系統 |
| Design-system alignment | 5/10 | 9/10 | design、theme、navigation SoT 已統一為五 tab 與共用 glass recipe |
| Responsive／accessibility | 6/10 | 9/10 | 已納入 320pt、200%、VoiceOver 與透明度／動態設定 |
| Unresolved decisions | — | 0 項 | D1–D5 已核准並實作；只剩平台驗收，不是產品決策 |

整體設計評分：`5.7/10 → 9.0/10`。規格與程式實作已對齊；macOS／iOS Simulator、實機 glass、VoiceOver 與 Reduce Transparency 是交付前的剩餘驗收。

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|---|---|---|---:|---|---|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | 未執行 |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | — | 本輪未重跑；以自動化回歸與既有 Eng／Design review 收斂 |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | CLEAR (DIFF，較 HEAD 舊 2 commits) | 0 issues、0 critical gaps |
| Design Review | `/plan-design-review` | UI/UX gaps | 1 | ISSUES OPEN | score: 6/10 → 9/10；本次增補後 11 decisions、5 unresolved |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | 未執行 |

- **UNRESOLVED:** 無產品決策；剩餘 macOS／iOS／實機驗收已寫入 `HANDOFF.md`。
- **VERDICT:** 規格與程式已完成；未經使用者授權，不 commit、push 或 release。
