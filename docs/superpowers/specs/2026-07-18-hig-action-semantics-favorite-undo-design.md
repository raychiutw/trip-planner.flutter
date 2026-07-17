# Tripline HIG 動作語意與收藏復原規格

日期：2026-07-18

狀態：待使用者審閱

適用：`trip-planner.flutter` App、`trip-planner` API

## 1. 目標

統一 Tripline 內「新增、加入、移除、刪除」的文字、圖示、確認層級與回饋，並讓單筆取消收藏符合 iOS 的可復原操作習慣。

本次不改資料模型、不新增 restore endpoint、不導入 soft delete。收藏復原沿用現有 API：先刪除收藏，使用者點「復原」時以原本的 `poiId` 與 `note` 重新建立收藏。

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
2. App 保留該筆 `PoiFavorite` snapshot，至少包含 `poiId`、`note` 與顯示資料。
3. App 呼叫 `DELETE /api/poi-favorites/:id`。
4. 成功收到 `204 No Content` 後，從畫面移除卡片。
5. 顯示 SnackBar：`已移除收藏`，動作為 `復原`。
6. SnackBar 建議顯示 6 秒；消失後不再提供復原入口。

刪除失敗時保留或還原卡片，顯示 `取消收藏失敗，請稍後再試`，不得顯示成功 SnackBar。

### 4.2 復原

使用者點 `復原` 時呼叫：

```http
POST /api/poi-favorites
Content-Type: application/json

{
  "poiId": 123,
  "note": "原收藏備註"
}
```

成功回應維持現有契約：

```http
HTTP/1.1 201 Created
Content-Type: application/json

{
  "id": 987,
  "user_id": "user-id",
  "poi_id": 123,
  "note": "原收藏備註",
  "favorited_at": "2026-07-18 12:00:00"
}
```

復原後的 `id` 可以與刪除前不同；App 必須重新整理收藏並採用伺服器回傳的新資料，不得繼續使用舊 `id`。

若 `POST` 回傳 `409 DATA_CONFLICT`，代表同一使用者與 `poiId` 已經存在。App 重新整理收藏後視為最終狀態已復原，不重複顯示錯誤。

其他錯誤顯示 `無法復原收藏，請稍後再試`，並重新整理伺服器狀態。

## 5. 後端契約與工作項目

### 5.1 沿用的端點

- `DELETE /api/poi-favorites/:id`
  - 僅收藏 owner 可操作。
  - 成功：`204 No Content`。
  - 不存在：`404 DATA_NOT_FOUND`。
  - 非 owner：`403`。
- `POST /api/poi-favorites`
  - Request：`{ poiId: number, note?: string | null }`。
  - 成功：`201 Created` 並回傳新收藏 row。
  - 同一使用者已收藏相同 POI：`409 DATA_CONFLICT`。
  - POI 不存在：`404 DATA_NOT_FOUND`。
  - 保留既有驗證、companion containment、rate limit 與 audit log。

### 5.2 後端需要完成

不需新增 migration 或 route。後端開發只需補強並鎖定以下整合測試：

1. 建立含 `note` 的收藏，刪除後以相同 `poiId`／`note` 重建，回傳新的有效 `id`。
2. 復原後 `GET /api/poi-favorites` 只出現一筆相同 `poiId`，且 `note` 完整保留。
3. 重複 `POST` 維持 `409 DATA_CONFLICT`，不建立重複 row。
4. 非 owner 刪除維持 `403`；不存在的收藏維持 `404`。
5. DELETE 與復原 POST 都寫入既有 audit log；不能繞過 rate limit 或 companion gate。
6. 刪除收藏不得刪除 POI、行程停留點或 `trip_entry_pois` 關聯；收藏只是使用者層級關聯。

後端對應檔案：

- `trip-planner/functions/api/poi-favorites.ts`
- `trip-planner/functions/api/poi-favorites/[id].ts`
- `trip-planner/tests/api/poi-favorites-post.integration.test.ts`
- `trip-planner/tests/api/poi-favorites-delete.integration.test.ts`

### 5.3 不做的項目

- 不新增 `POST /poi-favorites/:id/restore`。
- 不新增 `deleted_at` 或回收桶。
- 不要求保留舊 favorite `id`。
- 不為單筆取消收藏增加確認 Alert。
- 不讓永久刪除使用 Tripline 主色；破壞性動作固定使用 system red。

只有未來需要跨裝置長時間復原、最近刪除清單或稽核還原時，才考慮 soft delete。

## 6. 徹底共用的 UI 架構

本次允許擴大 Flutter 重構範圍。驗收目標不是讓各頁「看起來接近」，而是讓相同職責只剩一個實作來源。

### 6.1 Header 單一來源

公開入口維持兩個，以配合 Flutter 的一般頁與 Sliver 捲動頁：

- Root 頁：`TpRootScrollScaffold`
- 一般／Sheet 子頁：`TpAppBar`

兩個入口的 Header 內容必須委派同一組內部共用元件與 token：

- `TpHeaderGeometry`：唯一管理 toolbar 高度、44pt target、8pt action gap、左右 16pt inset。
- `TpHeaderTitle`：唯一管理標題字級、字重、顏色、單行省略與對齊。
- `TpHeaderActionRow`：唯一管理 leading／trailing action 尺寸、間距與安全邊距。
- `TpToolbarGlassButton`：唯一的返回、關閉、一般功能與帳號圓形按鈕材質。
- `TpAccountAvatarButton`：只負責取得帳號首字與開啟帳號 Sheet，不得重複按鈕外觀。

除上述兩個公開入口外，`lib/features/**` 不得直接建立 `AppBar`、`SliverAppBar` 或 `GlassAppBar`。返回、關閉與帳號也不得以裸 `IconButton`、`CircleAvatar` 或各頁 `Container` 模擬。

收藏頁右側排列固定為「探索、帳號」。收藏頁不再設定自己的 padding；共用 `TpHeaderActionRow` 讓所有 Root Header 的最右側固定保留 16pt、兩顆圓形按鈕固定間距 8pt。

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

- Light：`colorScheme.onPrimaryContainer`
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

- 行程、帳號與功能內容頁：`showAppLargeSheet`／`showAppLargeScreenSheet`。
- 短動作清單：`showAppActionSheet`。
- 新增／編輯表單可保留既有 form widget，但外層 Sheet 必須走共用入口，不得在 feature 內重複 drag handle、關閉鈕與 93% 高度。

原生時間／日期 picker 不包裝成自製 Tripline picker，繼續使用平台元件。

### 6.6 必須遷移的現有例外

- `favorites_screen.dart` 的批次刪除 `showDialog<bool>` 改用 `showAppConfirm`。
- `edit_trip_screen.dart` 的刪除 Day `AlertDialog` 改用 `showAppConfirm`。
- `favorites_screen.dart` 的單筆取消收藏改用 `showAppUndoNotice`。
- 行程卡與行程內容頁的功能選單共用 `TpActionItem`＋`TpMoreMenuButton`。
- 收藏、聊天、行程、地圖的 Header actions 全部由 `TpHeaderActionRow` 排版。
- 所有 feature 內自行設定的 Header action padding、圓形尺寸與 action gap 必須刪除。

## 7. Flutter 驗收條件

1. 全專案可點擊文案符合「新增／加入／移除／刪除」定義。
2. 單筆取消收藏沒有 Alert，成功後出現含 `復原` 的 SnackBar。
3. 復原會送出原 `poiId` 與 `note`，並接受伺服器的新 favorite `id`。
4. 批次移除收藏、共編成員、分享連結、停留點、筆記、Day、行程等不可逆操作仍有明確確認。
5. 收藏、聊天、行程、地圖等 Root Header 的 action 尺寸、間距與右側邊距一致。
6. 選單一般文字在 Light／Dark 都與 Header 標題色系一致；破壞性動作維持 system red。
7. 文字放大 200%、Bold Text、Reduce Motion、Reduce Transparency 下仍可辨識並操作。
8. `lib/features/**` 不再直接建立 `AppBar`、`SliverAppBar`、`GlassAppBar` 或 Header 圓形外框。
9. `TpMenuAction` 與 `AppSheetAction` 退場；所有選單使用 `TpActionItem`。
10. 收藏頁與其他 Root 頁的最右 action 位置一致，不能再以頁面級 padding 修補。
11. 不可逆確認全部走 `showAppConfirm`；可復原通知全部走 `showAppUndoNotice`。

## 8. 參考

- Apple HIG: Buttons — <https://developer.apple.com/design/human-interface-guidelines/buttons>
- Apple HIG: Alerts — <https://developer.apple.com/design/human-interface-guidelines/alerts>
- Apple HIG: Undo and redo — <https://developer.apple.com/design/human-interface-guidelines/undo-and-redo>
- Apple HIG: Toolbars — <https://developer.apple.com/design/human-interface-guidelines/toolbars>
