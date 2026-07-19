# Tripline HIG 共用架構、動作語意與地圖互動規格

日期：2026-07-18

狀態：已確認，實作中

適用：`trip-planner.flutter` App、`trip-planner` API

## 1. 目標

統一 Tripline 內「新增、加入、移除、刪除」的文字、圖示、確認層級與回饋，讓單筆取消收藏符合 iOS 的可復原操作習慣，並把 Root Header、Sheet、Navigation Glass、Timeline 與地圖互動收斂成可共用、可測試的正式架構。

本規格適用於整份後續實作計畫，不受「只做最小改動」限制。允許重整 Root Shell、頁面結構、共用元件邊界、地圖 adapter 與測試架構；保留使用者可見行為、API／資料契約與可存取性，不保留只為舊結構相容而存在的重複 UI 路徑。

單筆收藏復原改為後端 owner-scoped restore API 與 soft delete；Flutter 不再以 `poiId`／`note` 重建收藏。完整後端交付契約為 `docs/backend-tasks/2026-07-18-poi-favorites-undo-restore-api.md`。

## 2. 已決定的語意

| 用語 | 使用時機 | 標準圖示 | 顏色 |
|---|---|---|---|
| 新增 | 建立原本不存在的資料，例如行程、Day、筆記、自訂停留點 | `plus` | Tripline 主色 |
| 加入 | 把既有資料關聯到另一個範圍，例如收藏加入行程、POI 加入備選 | `plus`／`calendar_badge_plus` | Tripline 主色 |
| 移除 | 解除可重新建立的關聯，例如取消收藏、移除備選、移除共編成員 | 對應物件的移除圖示 | 一般移除使用標題色；造成權限喪失時使用 system red |
| 刪除 | 永久銷毀使用者資料，例如行程、Day、停留點、筆記、分享連結 | `trash` | system red |

唯讀的「異動紀錄：新增／刪除」是事件名稱，不屬於可點擊動作，不需要改名。

## 3. UI 情境盤點

| 功能 | 目前入口 | 定版 UI 行為 | 確認／復原 |
|---|---|---|---|
| 新增行程 | 行程 Header／空狀態 | 右上 `plus` 或空狀態主按鈕，進入建立行程頁 | 不確認；成功後顯示新行程 |
| 新增收藏 | 收藏 Header | 右上 `plus` 開啟既有 Google POI 探索／收藏流程；不得以搜尋圖示代表新增 | 不確認；成功後回到收藏並顯示新項目 |
| 新增停留點 | 每日行程底部 | 開啟 Google 地圖搜尋／收藏／自訂三種來源 | 不確認；按「完成」後加入 |
| 新增筆記 | 筆記區塊 | `新增{分類}` 開啟共用 Sheet | 不確認；按「新增」送出 |
| 新增 Day | 編輯行程 | 明確顯示加到最前或最後 | 不確認；完成後通知 |
| 加入收藏 | 探索 POI 卡片 | Heart 切換為已收藏 | 不確認；失敗時還原 Heart |
| 收藏加入行程 | 收藏卡片／功能選單 | 使用「加入行程」，選行程、Day 與時間 | 不確認；成功後通知 |
| 加入備選 | 地點管理 | 使用「加入備選」 | 不確認；成功後通知 |
| 取消收藏（單筆） | Heart／收藏卡片功能選單 | 立即移除卡片，底部顯示「已移除收藏」與「復原」 | 不先確認；可復原 |
| 移除收藏（批次） | 收藏選取工具列 | 顯示選取數量與紅色移除動作 | 執行前確認；本期不提供批次復原 |
| 移除備選 | 地點管理 | 使用「移除備選」，不顯示垃圾桶語意 | 不確認；完成後通知 |
| 移除共編成員 | 共編設定 | 使用 system red，說明成員會失去存取權 | 執行前確認 |
| 撤銷邀請／分享 | 共編／分享設定 | 使用「撤銷邀請」或「停用連結」；若資料會永久消失則使用「刪除分享連結」 | 依影響確認 |
| 刪除停留點 | 行程列左滑／功能 | system red `trash` | 執行前確認；後端未提供 restore |
| 刪除筆記 | 筆記列左滑／功能 | system red `trash` | 執行前確認；後端未提供 restore |
| 刪除 Day | 編輯行程 | 說明當日停留點會一併刪除且後續 Day 重新編號 | 執行前確認 |
| 刪除行程 | 行程功能選單最後一項 | system red，不能使用主要按鈕樣式 | 執行前確認，文案列出影響 |

## 4. 收藏單筆移除與復原流程

### 4.1 正常移除

1. 使用者點 Heart 或選單的「取消收藏」。
2. App 保留該筆 `PoiFavorite` snapshot 供 optimistic UI 失敗回復，不把 snapshot 當作 restore request。
3. App 呼叫 `DELETE /api/poi-favorites/:id`。
4. 成功收到 `204 No Content` 後，從畫面移除卡片。
5. 顯示 SnackBar：`已移除收藏`，動作為 `復原`。
6. SnackBar 建議顯示 6 秒；消失後不再提供復原入口。

刪除失敗時保留或還原卡片，顯示 `取消收藏失敗，請稍後再試`，不得顯示成功 SnackBar。

### 4.2 復原

使用者點 `復原` 時呼叫 owner-scoped restore endpoint：

```http
POST /api/poi-favorites/:id/restore
Content-Type: application/json

{}
```

成功回應保留原 favorite id 與資料：

```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "id": 7,
  "user_id": "user-id",
  "poi_id": 123,
  "note": "原收藏備註",
  "favorited_at": "2026-07-18 12:00:00",
  "deleted_at": null
}
```

Restore 重送必須 idempotent；成功後 App 重新整理收藏。`410 UNDO_EXPIRED` 顯示「復原期限已過」，其他錯誤顯示 `無法復原收藏，請稍後再試`，並重新整理伺服器狀態。

## 5. 後端契約與工作項目

### 5.1 端點

- `DELETE /api/poi-favorites/:id`
  - 僅收藏 owner 可操作。
  - 成功：soft delete 並回 `204 No Content`。
  - 不存在：`404 DATA_NOT_FOUND`。
  - 非 owner：`403`。
- `POST /api/poi-favorites`
  - Request：`{ poiId: number, note?: string | null }`。
  - 成功：`201 Created` 並回傳新收藏 row。
  - 同一使用者已收藏相同 POI：`409 DATA_CONFLICT`。
  - POI 不存在：`404 DATA_NOT_FOUND`。
  - 保留既有驗證、companion containment、rate limit 與 audit log。
- `POST /api/poi-favorites/:id/restore`
  - Request：空 JSON body。
  - 成功：`200 OK`，回傳同一 favorite row 並令 `deleted_at = null`。
  - 重送：idempotent `200`。
  - 超過取消後 10 分鐘：`410 UNDO_EXPIRED`。
  - 只能由 owner 操作，保留既有 containment、rate limit、CSRF、audit 與 cache invalidation。

### 5.2 後端需要完成

後端新增 `deleted_at` migration、active-only unique index、restore route 與完整 race／ownership／expiry tests；Definition of Done 與所有檔案範圍以獨立後端任務文件為準。

後端對應檔案：

- `trip-planner/functions/api/poi-favorites.ts`
- `trip-planner/functions/api/poi-favorites/[id].ts`
- `trip-planner/functions/api/poi-favorites/[id]/restore.ts`
- `trip-planner/tests/api/poi-favorites-post.integration.test.ts`
- `trip-planner/tests/api/poi-favorites-delete.integration.test.ts`
- `trip-planner/tests/api/poi-favorites-restore.integration.test.ts`

### 5.3 不做的項目

- 不做通用回收桶、最近刪除頁或批次 restore。
- 不把 restore API 擴張到行程、Day、停留點或筆記。
- 不為單筆取消收藏增加確認 Alert。
- 不讓永久刪除使用 Tripline 主色；破壞性動作固定使用 system red。

## 6. 徹底共用的 UI 架構

本次允許擴大 Flutter 重構範圍。驗收目標不是讓各頁「看起來接近」，而是讓相同職責只剩一個實作來源。

### 6.1 Header 單一來源

公開入口維持兩個，但依導覽層級分工，不再依「一般頁／Sliver 頁」分工：

- 四個 Root 目的地：`TpRootScaffold`＋`TpRootGlassHeader`。
- Detail route／Sheet 子頁：具明確 role 的 `TpAppBar`／`TpSheetHeader`。

`TpRootScrollScaffold` 與各 feature 自製 Root AppBar 在遷移完成後退場。Root 頁不再使用 pinned `SliverAppBar` 模擬玻璃 Header；捲動頁與地圖頁都由 `TpRootScaffold` 建立同一個全版內容 Stack，再把固定 Header 疊在內容上方。

所有 Header 入口必須委派同一組內部共用元件與 token：

- `TpHeaderGeometry`：唯一管理 toolbar 高度、44pt target、8pt action gap、左右 16pt inset。
- `TpHeaderTitle`：唯一管理標題字級、字重、顏色、單行省略與對齊。
- `TpHeaderActionRow`：唯一管理 leading／trailing action 尺寸、間距與安全邊距。
- `TpToolbarGlassButton`：唯一的返回、關閉、一般功能與帳號圓形按鈕材質。
- `TpAccountAvatarButton`：只負責取得帳號首字與開啟帳號 Sheet，不得重複按鈕外觀。

`TpRootGlassHeader` 的定版幾何如下：

- 位於 `safeArea.top + 8pt`，左右各 `16pt`，視覺高度 `64pt`，外圓角 `32pt`。
- 整條 Header 是**單一** Liquid Glass 膠囊；標題與右側 actions 不各自再包第二層 glass。
- 標題靠左、單行省略；圖示 action 固定 44×44pt，文字 action 採內容寬度且至少 44pt 高，actions 間距 `8pt`。一般 Root 頁維持最多兩個 actions；收藏因標題固定且短，可在同一膠囊內顯示搜尋、排序、新增與帳號四個明確動作，並以 200% Dynamic Type 測試證明不破版。
- Header 固定浮在內容上方；聊天、Timeline、收藏清單與地圖本體皆延伸到 Header 下方。
- 可捲動內容的第一筆需有足夠初始 top inset，進入捲動後可從 Header 下方通過；交界只允許一層 soft scroll edge。
- 地圖頁不得在 Header 後方另加不透明漸層或假 toolbar，讓地圖直接成為 glass 的背景內容。
- Header 與 Root Tab 分屬頂部／底部 navigation glass，兩者不得重疊，也不得由頁面自行計算互相矛盾的 safe-area padding。

Root 標題語意固定如下：

- 聊天、行程內容、地圖：顯示目前行程名稱；標題本身可點，開啟 `showAppSelectionSheet<String>` 切換行程。
- 收藏：顯示「收藏」，不可偽裝成行程選擇器。
- 尚未有已選行程的 `/trips` 清單 fallback：顯示「我的行程」；選取行程後進入以行程名稱為標題的內容頁。
- 底部 Tab 已識別目前功能，不在 Header 再顯示「聊天／行程／地圖」副標題。

除上述公開入口外，`lib/features/**` 不得直接建立 `AppBar`、`SliverAppBar` 或 `GlassAppBar`。返回、關閉與帳號也不得以裸 `IconButton`、`CircleAvatar` 或各頁 `Container` 模擬。

收藏頁一般狀態固定為「收藏｜搜尋｜排序｜新增｜帳號」。搜尋使用 `CupertinoIcons.search`；排序按鈕使用 Apple 圖庫同語意的 `CupertinoIcons.line_horizontal_3_decrease`，點擊後由 `TpMoreMenuButton` 顯示錨定選單，當前排序以 checkmark 表示。新增使用 `CupertinoIcons.add` 並開啟既有收藏探索流程；帳號維持最右側。

點搜尋後，搜尋欄在同一條 Root Glass Header 膠囊內取代「收藏」標題並自動聚焦；排序與帳號維持可見，新增暫時隱藏，另提供最小 44pt 的文字「取消」動作。搜尋欄的清除只清空文字；取消搜尋會清空查詢、收起鍵盤並恢復一般狀態。頁內不得再保留第二條搜尋欄，清單拖曳使用 `onDrag` 收起鍵盤。收藏名稱、地址與備註中的符合字串使用 `onSurface`＋Semibold 加深，其餘字串維持 `onSurfaceVariant`，不得用整列 accent 背景標記。

Google POI 等遠端搜尋共用 `AppSearchField`：輸入少於 2 個字元不發 request，達門檻後以 300ms debounce 即時查詢，清空立即清除結果；每次查詢以 sequence/token 忽略過期 response，鍵盤 Search submit 取消 debounce 並立即送出。畫面只顯示細線 loading feedback，不再保留重複的搜尋 icon button。

排序選單至少提供「最近加入、最早加入、名稱、地區」，下方以 separator 分組提供「篩選條件」並沿用既有篩選 Sheet。沒有第二種收藏版面，因此不實作參考圖的「顯示方式選項」。收藏頁不再設定 Header padding；共用 Root Header 仍讓最右側 action 固定保留 16pt、所有 action 固定間距 8pt。

聊天作者識別沿用既有 `submittedBy` 與 `submittedByDisplayName`，不新增 API 或第二份參與者模型：

- 自己的訊息顯示目前帳號 display name；缺少時依序 fallback 到自己的 email local part（`@` 前）與「你」。
- 協作者訊息顯示該訊息的 `submittedByDisplayName`；缺少時依序 fallback 到 `submittedBy` 的 email local part 與「協作者」。
- AI 訊息固定顯示「Tripline AI」。
- 自己維持 Tripline 柔褐 accent，AI 使用中性 surface；協作者只用 HIG dynamic system Indigo（Light `#5856D6`、Dark `#5E5CE6`）做作者文字與低透明度 bubble tint。這是單一作者識別色，不可擴張成已退場的三色內容分類。

### 6.2 動作資料與選單單一來源

目前 `TpMenuAction<T>` 與 `AppSheetAction<T>` 表達的是同一種資料，必須合併為一個 `TpActionItem<T>`：

```dart
enum TpActionRole { normal, destructive }

class TpActionItem<T> {
  const TpActionItem({
    required this.value,
    required this.label,
    required this.icon,
    this.role = TpActionRole.normal,
    this.dividerBefore = false,
  });

  final T value;
  final String label;
  final IconData icon;
  final TpActionRole role;
  final bool dividerBefore;
}
```

同一份 `TpActionItem<T>` 可交給：

- `TpMoreMenuButton<T>`：右上錨定 Liquid Glass 選單。
- `showAppActionSheet<T>`：iOS Action Sheet／Android bottom sheet。

各功能頁只宣告動作內容與選取後行為，不得自行決定文字顏色、圖示顏色、列高、分隔線或 destructive 樣式。

### 6.3 顏色單一來源

選單的一般文字與圖示改用標題同階的主題色：

- Light：`colorScheme.onSurface`（Tripline 暖深色，不是純黑）
- Dark：`colorScheme.primary`
- Destructive：`colorScheme.error`

不得使用低對比的 `onSurfaceVariant`，也不得硬寫純黑。選單觸發鈕與面板繼續共用相同 Liquid Glass 設定。

`TpActionItem.role == destructive` 時由共用 renderer 自動使用 `colorScheme.error`，功能頁不得個別覆寫。

### 6.4 確認與回饋單一來源

- 所有不可逆確認使用 `showAppConfirm`；移除各頁直接建立的 `AlertDialog`／`showDialog<bool>`。
- 所有一般結果使用 `showAppNotice`，錯誤使用 `showAppError`。
- 新增 `showAppUndoNotice`，只負責顯示訊息、`復原` action 與顯示時間；收藏頁不得自行組 Snackbar。
- `showAppUndoNotice` 不包裝 API 或 repository，避免 UI 共用元件持有業務資料。

確認視窗的按鈕順序、system red、取消文案與 Dynamic Type 行為由 `showAppConfirm` 統一。功能頁只提供標題、說明、明確動詞與 callback。

### 6.5 Sheet 單一來源

所有由下往上出現的視窗必須由同一個 Sheet presentation engine 呈現。共用的意思是共用材質與行為，不是把所有任務強制做成同一個固定高度、同一組按鈕。

底層唯一入口為 `showAppSheet<T>`，只在 `lib/app/adaptive.dart` 內接觸 `GlassModalSheetScaffold`、`showModalBottomSheet`、`showCupertinoModalPopup` 或 `showGeneralDialog`。Feature 不得直接呼叫這些平台 API。

`showAppSheet<T>` 統一負責：

- Light／Dark Liquid Glass、Reduce Transparency fallback 與主題切換。
- barrier、圓角、safe area、鍵盤 inset、拖曳動畫與 Reduce Motion。
- fixed／resizable 高度、初始 detent、依可調整性顯示 grabber、向下滑動關閉。
- 標題列幾何、標題、取消／返回／關閉／完成按鈕與 44pt target。
- 單一 Sheet 內的 Navigator、返回結果與防止重複關閉。
- 未儲存表單的互動關閉攔截；內容與立即選取 Sheet 不需攔截。

Feature 只能使用以下有語意的 wrapper：

| Wrapper | 使用情境 | HIG 標題列 | 高度與選取 |
|---|---|---|---|
| `showAppSelectionSheet<T>` | 切換行程、移到 Day、POI／分類選擇 | 置中任務標題；leading `取消`；無 `完成` | 固定 93% 近滿版且無 grabber；點列立即選取並關閉，現在值顯示 checkmark |
| `showAppFormSheet<T>` | 新增／編輯停留點、交通、筆記、篩選 | leading `取消`；trailing `完成`／明確動詞 | medium＋large 或依鍵盤擴展；有未儲存內容時攔截 swipe dismiss |
| `showAppContentSheet<T>` | 帳號、同步衝突、功能說明 | 單頁用 `關閉`；階層子頁用 `返回`，不得把返回當關閉 | 固定 93% 且無 grabber；子頁沿用同一個 Sheet Navigator，不再疊第二張 Sheet |
| `showAppScreenSheet<T>` | 行程功能開啟的近滿版功能頁 | 共用 Sheet Header／`TpAppBar`；第一層可關閉，後續層返回 | 固定 93% 且無 grabber；不得以 `go()` 替換原頁而失去退出路徑 |
| `showAppActionSheet<T>` | 使用者剛發起的一個動作需要 2–3 個短選項 | 系統 action sheet 語意，含取消 | 不得捲動；最多 3 個動作加取消；destructive 固定 system red |

原生時間／日期 picker 不包裝成自製 Tripline picker，繼續使用平台元件。由 `...` 按鈕展開、選項超過三個的功能清單應使用共用 `TpMoreMenuButton`，不是 action sheet。

#### 6.5.1 「切換行程」定版

目前 `TripTitleButton` 直接呼叫 `showAppLargeSheet`；該入口同時供帳號使用，因此「切換行程」被套成帳號／內容型 Sheet。

| 項目 | 現在實際實作 | HIG／定版 |
|---|---|---|
| 任務類型 | 與帳號共用同一個泛用 large content sheet | 行程切換是立即選取清單，改走 `showAppSelectionSheet<String>` |
| 高度 | `mediumSize` 與 `largeSize` 都是 `0.93`，`resizable=false` | 固定近滿版，內容本身可捲動，不以假 detent 暗示高度可調整 |
| Grabber | 固定高度不建立 resize affordance | 不顯示 grabber；只有表單等實際具有不同 detent 的 Sheet 才顯示 |
| 標題列 | 20pt 標題靠左，右上圓形 X | 任務標題置中，leading `取消`；立即選取不顯示多餘的 `完成` |
| 選取回饋 | 目前行程有 trailing checkmark，點列立即 `pop(tripId)` | 保留；符合 option list 的短暫 highlight＋checkmark 語意 |
| 搜尋與長清單 | Sheet 內搜尋框＋可捲動 ListView | 保留；長清單不應改成 action sheet |
| 關閉 | barrier、右上 X、向下拖到 hidden 都能關閉 | 保留 barrier／swipe dismiss；可見出口改由 selection variant 統一提供 |
| 導航 | 泛用 Sheet 預先建立巢狀 Navigator | 行程選擇是單一步驟，不建立不需要的子頁；只有內容／多步驟 Sheet 啟用內部 Navigator |
| 動畫 | `showGeneralDialog` 再包一層 500ms 自訂 SlideTransition | 動畫只由共用 engine 管理，避免 dialog transition 與 glass sheet 拖曳各做一次 |

近滿版高度本身不是問題；真正不符合的是「固定 93% 卻顯示可調整的 grabber」，以及把內容型右上關閉 Header 套到立即選取任務。

#### 6.5.2 Sheet 導航規則

- 單頁 selection：`取消`關閉；點選成功直接回傳值並關閉。
- 單頁 form：`取消`放棄、`完成`儲存；兩者不可只留其一。
- 多步驟第一頁：leading `取消`；需要提交時 trailing `完成`可先 disabled。
- 多步驟後續頁：leading `返回`取代`取消`；返回只退一層，不得關閉整張 Sheet。
- 純內容階層若產品需要「返回」與「關閉全部」同時存在，可用 leading 返回＋trailing 關閉；不得再同時加入完成。
- 主介面一次只顯示一張 Sheet。若動作必須開另一張 Sheet，先關閉目前 Sheet，再開下一張。
- 所有 Sheet 必須支援 swipe down；若會遺失輸入，先顯示共用確認，不得默默捨棄。

#### 6.5.3 現有呼叫點遷移

| 現有情境 | 定版共用入口 |
|---|---|
| `TripTitleButton` 切換行程 | `showAppSelectionSheet<String>` |
| Timeline 移到其他 Day | `showAppSelectionSheet<int>` |
| POI 加入備選／更換正選 | `showAppSelectionSheet<_EntryPoiPick>` |
| 探索更多分類 | 類別超過三個時使用 `showAppSelectionSheet<String>` |
| 收藏篩選 | `showAppFormSheet<void>`，取消／套用明確分開 |
| 停留點、交通、筆記新增／編輯 | `showAppFormSheet<void>` |
| 帳號入口 | `showAppContentSheet<void>` |
| 行程功能打開筆記、資料、列印、異動、分享、共編、健檢 | `showAppScreenSheet<void>` |
| 同步衝突、AI 授權、工作階段詳情 | 依是否有提交分別使用 content／form variant |
| 收藏卡、行程卡的短情境動作 | 最多三項才用 `showAppActionSheet`；`...` 展開或超過三項改 `TpMoreMenuButton` |

遷移完成後，`lib/features/**` 對 `showModalBottomSheet`、`showCupertinoModalPopup`、`showGeneralDialog` 的搜尋結果必須為零。

### 6.6 必須遷移的現有例外

- `favorites_screen.dart` 的批次刪除 `showDialog<bool>` 改用 `showAppConfirm`。
- `edit_trip_screen.dart` 的刪除 Day `AlertDialog` 改用 `showAppConfirm`。
- `favorites_screen.dart` 的單筆取消收藏改用 `showAppUndoNotice`。
- 行程卡與行程內容頁的功能選單共用 `TpActionItem`＋`TpMoreMenuButton`。
- 收藏、聊天、行程、地圖的 Header actions 全部由 `TpHeaderActionRow` 排版。
- 所有 feature 內自行設定的 Header action padding、圓形尺寸與 action gap 必須刪除。
- 所有 feature 內自行建立的 drag handle、sheet 圓角、高度、barrier、safe area 與鍵盤 padding 必須改由 `showAppSheet` 管理。
- `showAppLargeSheet`／`showAppLargeScreenSheet` 舊入口完成遷移後退場，避免泛用名稱繼續掩蓋任務語意。

### 6.7 Navigation Glass 單一來源

底部 Root Tab 與行程／地圖的「模式＋Day」切換器保留各自的導覽語意，不合併成一個帶大量條件的 Widget：

- `AppleRootTabBar`：聊天、行程、地圖、收藏四個頂層目的地。
- `TpHorizontalSelector`：行程／地圖互切與 Day 的一階水平選擇；行程頁不再提供「總覽」。

兩者使用同一種 navigation glass optics，但保留不同導覽幾何：Root Tab 高 64pt、水平 margin 16pt；行程／地圖 selector 高 44pt。兩者必須共用 `tpNavigationGlassSettings(BuildContext)`；唯一來源放在 `lib/ui/tp_glass_surface.dart`，統一 Light／Dark 的 glass color、thickness、blur、light intensity、ambient strength、refractive index、saturation、opacity multiplier 與 PlatformView fallback color。

`platformViewBackdrop` 只決定 Google Map PlatformView 上方的相容渲染路徑，不得再改變 blur、厚度、折射率、亮邊或透明度。行程頁與地圖頁使用相同的 optics；背景內容造成的自然明暗差異可以保留。

選中項目使用同一個 `navigationSelection` 柔褐 tint：

- Light：Tripline accent 18%。
- Dark：Tripline accentDeep 22%。
- `rootTabSelection` 與 `dayThumb` 都 alias 到 `navigationSelection`，不得再分別硬寫不透明底色。
- 選中 thumb 可以是共用 glass group 內的 tint indicator，但不得覆寫另一組 blur 或 refractive index，避免形成第二片獨立折射玻璃。

大型 POI accessory、Sheet、Menu 與內容卡的尺寸和材質厚度不同，不套用 `tpNavigationGlassSettings`；它們繼續由既有 `TpGlassSurface` 或 Sheet engine 管理。共用的是同職責的 navigation capsule，不是讓全 App 只剩一種玻璃厚度。

### 6.8 地圖引擎與套件中立邊界

Mobile 地圖引擎由 `google_maps_flutter` 全面更換為 `google_navigation_flutter ^0.10.0`。只使用不含導航 UI 的 `GoogleMapsMapView`；本期不建立 `GoogleMapsNavigator`、不初始化 navigation session，也不要求背景導航權限。

由於 `google_navigation_flutter` 在 1.0 前仍可能有 breaking changes，Feature 層不得直接 import 套件。`lib/features/map/map_adapter.dart` 重構為 app-owned boundary：

- `TripMapController`：公開 `fitPoints`、`move`、`setPadding`、`dispose`，不暴露 `GoogleMapViewController`。
- `TripMapCanvasConfig`：保留 `TripMapPoint`、`TripMapRoute`、`TripMapMarker`、camera、padding 與 appearance 等 app-owned 值；新增 `onGooglePoiSelected`，不暴露 plugin event。
- `GoogleMapPoiSelection`：只含 `placeId`、`name`、`TripMapPoint point`，由 adapter 將 `PointOfInterest` 轉成此 DTO。
- `_GoogleNavigationTripMapCanvas`：唯一可以 import `google_navigation_flutter` 的 mobile renderer，使用 `GoogleMapsMapView`、`GoogleMapViewController.addMarkers`／`addPolylines` 與 `onPoiClicked`／`onMarkerClicked`／`onMapClicked`。
- `TripMapMarkerIconRegistry`：把既有 `renderTripMapChip` PNG bytes 交給 `registerBitmapImage`，依 glyph、style、pixel ratio 快取 `ImageDescriptor`，保留 Tripline 編號 marker 外觀。
- `TripMapOverlaySynchronizer`：保存 app marker／route ID 與 plugin handle 的對照，只差量 add、update、remove；不得每次 build 直接 clear 全圖造成閃爍。

現有 `google_maps_flutter.ClusterManager` 不可穿透新 boundary。當可見 Tripline pin 大於等於 12 時，由純 Dart、套件中立的 `TripMapClusterProjector` 依 Web Mercator zoom grid 產生 cluster view models；cluster 仍使用 Tripline marker style 顯示數量，點擊後 fit 該群組。camera idle 時才重算，拖曳／縮放中的每個 frame 不重建 overlays。個別 POI、使用者位置與 route 的互動語意保持不變。

外觀規則：

- Light／Dark appearance 都使用 `MapColorScheme.light` 日間底圖；Dark App 只改變覆蓋在 PlatformView 上方的 navigation glass，不切換 Google 夜間地圖。
- 原生 Google POI、道路、車站與地名必須保持可見與可點；自訂 map style／Map ID 不得隱藏 POI feature layer。
- Tripline 行程 marker、加粗 route 與底部卡片維持現有產品樣式；預設進入、切換行程、切換 Day 與 Tripline POI focus zoom 都固定為 `13.0`。
- Header、Day selector、定位按鈕、POI accessory 與 Root Tab 都以 map padding／safe-area token 避讓；不得由各層分別硬加 magic numbers。

平台條件：

- Android `minSdk` 提升為 API 24，Kotlin／AGP 需符合 `google_navigation_flutter 0.10.x` 的實際建置要求。
- iOS deployment target 提升為 16.0；Podfile、Xcode project 與 CI build target 必須一致。
- Google Cloud project 必須已啟用 billing、Navigation SDK for Android 與 Navigation SDK for iOS，API key 依 bundle ID／package name 限制。
- 套件僅支援 Android／iOS。Flutter Web 不保留第二套 embedded Google Maps SDK；地圖位置改顯示明確 fallback，使用相同 Google Maps Universal URL 在瀏覽器開啟。
- 遷移完成後 `pubspec.yaml`、`lib/**` 與 `test/**` 不得再引用 `google_maps_flutter`，避免兩套 Google Maps SDK 版本衝突。

### 6.9 Google 原生 POI 選取與外開

Google 原生底圖 POI 與 Tripline 行程 POI 是兩種來源，不能混用 marker ID 或資料模型：

1. 使用者點 Google 原生 POI 時，`onPoiClicked` 轉成 `GoogleMapPoiSelection`，不更動目前 Day、Tripline active entry 或固定 zoom 13。
2. Bottom accessory 的**同一個 slot**暫時從 Tripline `PageView` 換成 `GooglePoiAccessoryCard`；不得在原卡片上再堆第二張卡或開 modal sheet。
3. Google 卡顯示 POI 名稱、Google 地點識別、關閉按鈕，以及明確標示的「在 Google 地圖開啟」secondary action；主要 Tripline 色只作小比例 accent。
4. 點 Google 卡的關閉、點地圖空白，或點任一 Tripline marker 時，清除 Google selection 並恢復原本 Tripline POI 卡與頁次。
5. 點 Tripline marker 仍走 `onMarkerClicked` 對照 app marker ID，維持橫滑卡片同步與 zoom 13；不得誤觸 Google POI 流程。

「在 Google 地圖開啟」是明確的使用者動作，不先顯示確認 Alert，也不在點 POI 時自動切離 App。共用 `GoogleMapsExternalLauncher` 建立：

```text
https://www.google.com/maps/search/?api=1&query={name-or-lat,lng}&query_place_id={placeId}
```

- `api=1` 與 `query` 必填；有 `placeId` 時加上 `query_place_id`，讓 Google Maps 精準識別地點。
- 使用標準 `Uri` 編碼，不手動拼接空白、逗號或非 ASCII 地名。
- 經 `url_launcher` 的 external application mode 開啟 Universal URL；Google Maps App 可承接時進 App，否則由瀏覽器開啟 Google Maps Web。
- App／Web 外開失敗時只顯示非阻塞 `showAppError`／`showAppNotice`，保持 selection 卡可再次操作。
- 按鈕 VoiceOver label 包含地點名稱與「將離開 Tripline」提示；44×44pt target、Dynamic Type、Reduce Motion／Transparency 全部沿用共用元件規格。

Google POI selection 只保存目前畫面狀態，不寫入收藏、行程或後端。若未來要加入行程，必須由明確「加入」流程取得／建立正式 POI 資料，不可把原生 POI click 當成資料寫入。

## 7. 行程 Timeline 呈現、捲動與移動

### 7.1 天氣示意與真實資料

`DayWeatherPreview` 與 `DayWeatherCard` 不再是兩條互斥的畫面路徑。Timeline 固定掛載 `DayWeatherCard`，由它在同一位置依資料狀態切換內容：

1. 尚未進入預報範圍、缺少可用預報或等待第一筆資料時，顯示既有天氣示意卡。
2. 示意卡必須明確標示「天氣示意」；超過預報範圍時另顯示「天氣預報將於出發前 16 天開放」，不得讓示意溫度看起來像真實預報。
3. 正在讀取時保留卡片幾何，只加入小型 loading 狀態，不能先縮成訊息列再突然撐高 Timeline。
4. 取得有效逐時資料後，在原位置直接渲染 `_WeatherForecastPanel`。
5. 切換只使用約 200ms 淡化；不使用上下位移、縮放或反覆 shimmer。Reduce Motion 下直接換內容。
6. 載入失敗時保留示意卡並顯示「暫時無法取得預報」，不得把錯誤字串直接顯示給一般使用者。

### 7.2 景點時間與 Google 分類

- Timeline 採 D1 單一 rail＋堆疊內容：左側 rail 固定 32pt，時間與景點卡位於右側同一內容欄，交通列也使用完全相同的內容起點。有 `startTime` 與 `endTime` 時固定單行 `09：30 - 11：00`，禁止折行；畫面使用全形冒號改善中文節奏，資料與 VoiceOver 保留 ASCII 時間。
- D1 幾何固定為：rail/content gap 10pt、停留點圓點 22pt、卡片圓角 18pt／內距 16pt、交通列最低 64pt。每個 1／2 圓點頂端必須與同列時間第一行頂端對齊；直線在圓點後方銜接交通列，不得以額外 top spacer 把圓點下推。時間使用 HIG Title 3（20pt），景點名使用最接近 mockup 23pt 的 HIG Title 2（22pt），摘要與交通使用 Body 17pt；Dynamic Type 只向下增高，不切回獨立時間欄。
- 只有開始時間時只顯示開始時間；不得自行推算結束時間。`startTime` 缺少時才沿用相容欄位 `time`。
- 時間使用 tabular figures；VoiceOver 語意為「09:30 到 11:00」。內容卡可以保留停留時長，但不得再重複完整起訖時間。
- Google `primaryType` 分類固定放在景點名稱下方第一個次要位置，使用小型分類圖示＋可縮放的 `labelMedium`，不做另一顆高彩度膠囊。
- 分類來源依序為 `poiCategoryLabel(entry.master?.category)`、既有 Tripline POI type label；兩者皆缺少時省略視覺分類。不得把推測值宣稱成 Google 分類。
- Flutter 已有 `EntryPoiInfo.category` 與 `poiCategoryLabel`，本期不新增顯示用資料模型。若正式 API 未回傳 `category`，應修正既有 projection／serializer 並以契約測試鎖定，不得在 App 端猜測。

### 7.3 Day selector 與新版連續捲動

行程頁採用 section-linked sticky scroll：

- 整頁只有一個垂直 `CustomScrollView`；不得使用垂直 `PageView`、每 Day 整頁吸附或巢狀可捲動 ListView。
- Day selector 使用 `SliverPersistentHeader(pinned: true)`；每日內容以 Sliver 分組。先沿用既有 `_DaySection` 職責，只有確實拆成多個 Sliver 時才使用 `SliverMainAxisGroup`，不為名稱一致先建立空抽象。
- selector 選項只保留「地圖」與 `DAY 1...DAY N`，移除「總覽」。行程／地圖頁繼續共用 `TpHorizontalSelector` 與同一 navigation glass recipe。
- 使用者上下捲動時，以 Day header 通過 selector 下緣的穩定 activation line 作為 active Day；active Day 同步回 `TpHorizontalSelector`，並讓選中 Day 自動保持在橫向可視區。
- 點擊 Day 時以同一個 `ScrollController` 平滑捲到該 Day header 正下方；程式捲動期間不得在相鄰 Day 之間來回選取。
- active glass thumb 使用 180–220ms 的短動畫。快速 fling 時合併同一 frame 的中間狀態，不排隊播放經過每一天的動畫。
- 只有直接點擊 Day 時提供一次 selection haptic；被動捲動切 Day 不震動。Reduce Motion 下只改 tint／亮邊，不平移玻璃 thumb。
- selector 與 Timeline 重疊處只使用一層 iOS `soft` scroll edge effect；它用來說明浮動控制與內容的邊界，不是裝飾性深色遮罩。Light／Dark 都沿用同一幾何與 blur recipe。
- iOS 使用平台預設彈性捲動，Android 使用平台預設捲動物理；不得為視覺一致強迫 Android 模仿 iOS bounce。
- 使用 Flutter 原生 Sliver 與現有 `liquid_glass_widgets` 即可，本期不新增 scroll-spy／positioned-list 套件。
- 捲動通知可以更新本地 `_activeDayNum`，但不得在 Sliver layout／widget build 階段 invalidation Riverpod provider。

### 7.4 移動景點的 HIG 回饋

- 拖曳仍由 44pt reorder handle 發起，並保留「移到其他 Day」selection sheet 作為非拖曳替代操作。
- 拖起後顯示完整景點卡片的半透明 representation，不再只顯示標題文字；來源卡片降至約 35% opacity。
- 合法目的地只在游標／手指進入時顯示 2–3pt insertion indicator，並讓插入位置展開；不得替整個 Day 加外框。
- 靠近上下邊緣時以距離邊緣決定速度並平順自動捲動，不再固定每次 `jumpTo(32px)`。
- 放下後先在本地 presentation state 顯示新順序，再送出既有 reorder API；成功後以伺服器資料對齊，失敗則動畫回復 snapshot 並顯示錯誤。
- 拖起與成功放下各一次 haptic；經過候選位置時不連續震動。
- 無效 drop 讓 representation 返回來源。Reduce Motion 下取消 scale／位移裝飾，只保留 opacity 與 insertion indicator。

### 7.5 Dynamic Type 下維持 Timeline

- 不關閉 Dynamic Type、不限制全 App text scale，也不以縮小字體解決破版。
- 所有 Dynamic Type 尺寸都維持 D1「rail｜單一內容欄」：時間在卡片上方，時間、卡片與交通列共用同一 leading；編號、標題、分類與控制都使用主題 text style，不再分散硬寫 11／12px。
- 進入 accessibility text size 時改成較少欄的堆疊 layout：rail 繼續沿 leading 側延伸，單行起訖時間在內容上方，卡片使用剩餘完整寬度，時間、卡片與交通列使用同一 leading，編輯／拖曳控制移到卡片尾端或 footer。
- 一般字級標題可顯示兩行；accessibility size 允許卡片增高，不得因 Timeline 位於可捲動區就固定單行截斷主要資訊。
- Day selector 是導覽 label，可維持受控的 label hierarchy；景點名稱、時間與內容必須完整跟隨 Dynamic Type。
- 所有可點擊區維持至少 44×44pt，字級放大後圖示與語意也必須可辨識。

### 7.6 Timeline 驗收

1. 未進入預報範圍顯示明確標示的天氣示意；有效預報取得後原位換成真實資料。
2. 每個有起訖時間的景點同時顯示開始與結束時間，VoiceOver 讀出完整範圍。
3. 有 Google category 的景點在標題下方顯示本地化分類；raw snake_case 不直接露出。
4. 行程 Day selector 找不到「總覽」，上下連續捲動會更新 active Day，點 Day 會回到正確 section。
5. selector 是 pinned navigation glass，內容通過下方時只有一層 soft edge effect。
6. 快速 fling 不會累積 Day thumb 動畫；被動切 Day 不產生連續 haptic。
7. 同日與跨日拖曳都有完整卡片 representation、局部 insertion indicator、平順 edge auto-scroll 與失敗 rollback。
8. 200% 文字、Bold Text、Reduce Motion、Reduce Transparency 下 Timeline rail、起訖時間、分類與 44pt 控制仍可操作。

## 8. Flutter 驗收條件

1. 全專案可點擊文案符合「新增／加入／移除／刪除」定義。
2. 單筆取消收藏沒有 Alert，成功後出現含 `復原` 的 SnackBar。
3. 復原呼叫 `POST /api/poi-favorites/:id/restore`，不送 `poiId`／`note`，成功後保留同一 favorite id 與原資料。
4. 批次移除收藏、共編成員、分享連結、停留點、筆記、Day、行程等不可逆操作仍有明確確認。
5. 收藏、聊天、行程、地圖等 Root Header 的 action 尺寸、間距與右側邊距一致。
6. 選單一般文字在 Light／Dark 都與 Header 標題色系一致；破壞性動作維持 system red。
7. 文字放大 200%、Bold Text、Reduce Motion、Reduce Transparency 下仍可辨識並操作。
8. `lib/features/**` 不再直接建立 `AppBar`、`SliverAppBar`、`GlassAppBar` 或 Header 圓形外框。
9. `TpMenuAction` 與 `AppSheetAction` 退場；所有選單使用 `TpActionItem`。
10. 收藏頁與其他 Root 頁的最右 action 位置一致，不能再以頁面級 padding 修補。
11. 不可逆確認全部走 `showAppConfirm`；可復原通知全部走 `showAppUndoNotice`。
12. `lib/features/**` 不再直接呼叫 `showModalBottomSheet`、`showCupertinoModalPopup` 或 `showGeneralDialog`。
13. 切換行程使用 selection variant：標題置中、leading 取消、現在值 checkmark、點列立即回傳，不顯示完成。
14. 可調整 Sheet 的 medium 與 large 是不同高度；selection／content／screen 固定 93% 且不得顯示暗示可 resize 的 grabber。
15. 表單 Sheet 具取消／完成與未儲存內容保護；返回只退內部一層，關閉才退出整張 Sheet。
16. Action sheet 不可捲動且最多三個動作加取消；長功能清單改用 `TpMoreMenuButton`。
17. `AppleRootTabBar` 與 `TpHorizontalSelector` 共用 `tpNavigationGlassSettings`，Feature 不得自行複製 navigation glass 數值。
18. `platformViewBackdrop` 開關前後的 navigation blur、thickness、refractive index、light intensity 與 opacity multiplier 相同。
19. Root Tab indicator 與 Day thumb 共用 `navigationSelection`，且不得覆寫另一組 blur／refractive index。
20. Light、Dark、Google Map PlatformView 與 Reduce Transparency fallback 都要實機／模擬器擷圖比對；允許背景造成自然差異，不允許元件配方不同。
21. 行程 Timeline 符合第 7.6 節全部驗收項目，且沒有新增捲動套件或第二套 Day selector。
22. 聊天、行程、地圖、收藏全部使用 `TpRootScaffold`＋單一 `TpRootGlassHeader`；`TpRootScrollScaffold`、`_MapRootAppBar` 與 Root `TpAppBar` 退場。
23. Root Header 位於 safe area 下 8pt、左右 16pt、高 64pt、外圓角 32pt；所有 action 為 44pt 且間距 8pt。Chat／行程／地圖標題可切換目前行程；收藏一般狀態顯示「收藏｜搜尋｜排序｜新增｜帳號」，搜尋狀態在同一膠囊內顯示搜尋欄並保持帳號最右。
24. Mobile 只保留 `google_navigation_flutter`，Feature 不直接 import plugin，`google_maps_flutter` dependency／import／controller／cluster types 全部為零。
25. Android API 24、Kotlin 2.3.0、iOS 16.0、CI 與本機 build target 一致；Android debug APK 與 iOS simulator build 都通過。
26. Google 原生 POI 可點，選取後在既有 bottom accessory slot 顯示 Google 卡；關閉、點空白或點 Tripline marker 會回復原 Tripline 卡與頁次。
27. Google POI selection 不移動 camera、不改 Day／active entry／PageController，也不寫入收藏或後端；預設／切行程／Day／Tripline POI focus zoom 維持 `13.0`。
28. 「在 Google 地圖開啟」只由使用者明確按鈕觸發，使用含 `api=1`、`query`、可用時 `query_place_id` 的 Universal URL；App 不存在時由 browser fallback。
29. Flutter Web 不載入 mobile plugin 或第二套 embedded Google Maps SDK；使用同一 URI builder 顯示明確外開 fallback。
30. Tripline 編號 marker、使用者 marker、加粗 route、12+ POI clustering 與橫滑卡片在套件遷移後維持功能與視覺；overlay 更新不得 clear 全圖閃爍。
31. Map-only 實作不初始化 navigation session，不為未使用的背景導航擴張權限；若套件實際要求背景定位，必須先回到依賴決策，不可直接加入不實用途說明。
32. 遠端 push 前完成 scoped simplification、完整 merge-base diff code review、全量測試／analyze／雙平台 build、Light／Dark screenshot QA、gstack `/review` 與 Codex gate；P0／P1 必須清零，已接受問題修正後必須重跑受影響的 review／verification gate。
33. 聊天訊息與行程 Timeline 的唯一垂直捲動面必須和地圖／收藏一樣延伸到固定 Root Header 後方；初始內容避開 Header，捲動後內容可從 glass 下方通過，Header 本身不移動。
34. 收藏排序按鈕使用 `line_horizontal_3_decrease`，由共用 `TpMoreMenuButton` 顯示最近加入／最早加入／名稱／地區及既有篩選入口；目前排序有 checkmark，沒有未實作的顯示方式選單。
35. 每則自己與協作者聊天訊息都顯示正確作者名稱；display name 缺少時 fallback 到該帳號 email 的 `@` 前文字。協作者使用 dynamic system Indigo 的單一語意 tint，自己維持 Tripline accent，AI 維持中性 surface。
36. 進入調整順序模式後 Header 顯示任務標題「調整順序」與完整 trailing「完成」；文字 action 寬度大於 44pt 且支援 200% Dynamic Type，不得截成「完」。
37. 停留點的 `folder` 移到其他 Day 與 `line_horizontal_3` 拖曳排序共用同一套 44pt inline control 規格；單一動作 ellipsis menu 退場，兩者的 semantics 分別為「移到其他 Day」與「拖曳調整順序」。
38. Root Tab 使用 16pt 水平 margin、64pt 套件預設高度與 `max(16pt, safe area - 24pt)` 底部位移；Feature 不得重新覆寫 indicator、padding 或 label 幾何。
39. 收藏搜尋以文字「取消」退出；遠端 POI 搜尋具 2 字門檻、300ms debounce、過期結果保護與鍵盤立即 submit，所有清單拖曳可收起鍵盤。
40. Google 地圖在 Light／Dark App appearance 下都回傳 `MapColorScheme.light`，上層 Glass 則正確跟隨 App appearance。

## 9. 參考

- Apple HIG: Buttons — <https://developer.apple.com/design/human-interface-guidelines/buttons>
- Apple HIG: Alerts — <https://developer.apple.com/design/human-interface-guidelines/alerts>
- Apple HIG: Undo and redo — <https://developer.apple.com/design/human-interface-guidelines/undo-and-redo>
- Apple HIG: Toolbars — <https://developer.apple.com/design/human-interface-guidelines/toolbars>
- Apple HIG: Sheets — <https://developer.apple.com/design/human-interface-guidelines/sheets>
- Apple HIG: Modality — <https://developer.apple.com/design/human-interface-guidelines/modality>
- Apple HIG: Action sheets — <https://developer.apple.com/design/human-interface-guidelines/action-sheets>
- Apple HIG: Lists and tables — <https://developer.apple.com/design/human-interface-guidelines/lists-and-tables>
- Apple HIG: Tab bars — <https://developer.apple.com/design/human-interface-guidelines/tab-bars>
- Apple HIG: Materials — <https://developer.apple.com/design/human-interface-guidelines/materials>
- Apple HIG: Loading — <https://developer.apple.com/design/human-interface-guidelines/loading>
- Apple HIG: Motion — <https://developer.apple.com/design/human-interface-guidelines/motion>
- Apple HIG: Drag and drop — <https://developer.apple.com/design/human-interface-guidelines/drag-and-drop>
- Apple HIG: Typography — <https://developer.apple.com/design/human-interface-guidelines/typography>
- Apple HIG: Scroll views — <https://developer.apple.com/design/human-interface-guidelines/scroll-views>
- Flutter: Using slivers to achieve fancy scrolling — <https://docs.flutter.dev/ui/layout/scrolling/slivers>
- Apple Developer: Adopting Liquid Glass — <https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass>
- Google Navigation for Flutter package — <https://pub.dev/packages/google_navigation_flutter>
- Google Navigation Flutter API — <https://pub.dev/documentation/google_navigation_flutter/latest/google_navigation_flutter/>
- GoogleMapViewController API — <https://pub.dev/documentation/google_navigation_flutter/latest/google_navigation_flutter/GoogleMapViewController-class.html>
- Google Maps URLs — <https://developers.google.com/maps/documentation/urls/get-started>
