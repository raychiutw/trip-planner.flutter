# 時間軸 Entry CRUD（Sub-project A+B）設計

> Entry CRUD 全範圍拆為 A~E（見文末）。本 spec 只涵蓋 **A（編輯+刪除 entry meta）+ B（在某天 timeline 內新增自訂停留點）**。

**目標**：讓使用者在行程時間軸上「編輯停留點的標題/描述/起訖時間」、「刪除停留點」、「在某天新增自訂停留點」。

**架構**：沿用現有讀取鏈（`tripDaysProvider` family）。新增 repository 變更方法 + 一個共用 bottom sheet；mutation 後 `ref.invalidate(tripDaysProvider(tripId))` 重抓刷新（不做樂觀更新，與既有 favorites/add-to-trip 一致）。

**技術**：Flutter + flutter_riverpod 3.x + go_router；dio mock / mocktail 測試。

---

## 範圍

**做（A+B）**
- 編輯 entry meta：`title` / `description` / `start_time` / `end_time`，帶 OCC `expectedVersion`。
- 刪除 entry。
- 在某天新增自訂停留點（title + 選填描述/時間，無座標、無 POI 指定）。

**不做（留給 C/D/E）**
- 排序、同天/跨天搬移（C）。
- 換 master POI、alternates 增刪排序、per-POI note/分類、reservation（D）。
- 交通 segments（E）。
- 不新增/不修改任何 model 欄位（A+B 用既有 `TimelineEntry.id` / `.version` / `.title` / `.description` / `.startTime` / `.endTime` 與 `TripDay.dayNum` 即足夠）。

---

## 後端契約（A+B 用到的端點）

所有 mutation 經 `ApiClient`（自動帶 Cookie + `Origin` CSRF header）。錯誤 body：`{ "error": { "code", "message", "detail" } }`，`ApiClient` 解析為 `ApiError(status, code, message, payload)`。

### 1. 編輯 entry — `PATCH /api/trips/:id/entries/:eid`
- Body（白名單欄位皆選填；**欄位 snake_case，OCC token camelCase**）：
  - `title: String`（送出前 trim 非空）
  - `description: String`
  - `start_time: String?`（`HH:MM`，可為 `null`）
  - `end_time: String?`（`HH:MM`，可為 `null`）
  - `expectedVersion: int`（= 該 entry 目前 `version`）
- 成功：`200`，body 為更新後的 entry meta row（不含 master/alternates）。**本功能不消費回應內容**，靠 invalidate 重抓。
- OCC 衝突：`409`，`code == "STALE_ENTRY"`（CAS 失敗）。

### 2. 刪除 entry — `DELETE /api/trips/:id/entries/:eid`
- 無 body。
- 成功：**`200` + `{ "ok": true }`**（非 204）。`ApiClient` 會回傳該 Map，本功能忽略。
- 失敗：`409 DATA_CONFLICT`（FK 相依）/ `404 DATA_NOT_FOUND`。

### 3. 新增 entry — `POST /api/trips/:id/days/:num/entries`（`:num` = day_num）
- 已有 `TripRepository.addEntryToDay`。本功能擴充一個選填 `description` 參數。
- 自訂停留點送出：`title` + 選填 `start_time`/`end_time` + `description`，`lat`/`lng`/`poi_type` 省略（後端 `poi_type` 預設 `attraction`），`source: 'custom'`。
- 成功：`201`（忽略回應，靠 invalidate）。

> 契約細節出處：`docs/superpowers/specs/`（本次調查）對應 web `functions/api/trips/[id]/entries/[eid].ts`、`days/[num]/entries.ts`。

---

## 元件與檔案

### A. `lib/api/trip_repository.dart`（修改）
新增：
```dart
/// PATCH /trips/:id/entries/:eid（meta 編輯，OCC expectedVersion）。
Future<void> updateEntry({
  required String tripId,
  required int entryId,
  required int expectedVersion,
  required String title,
  String? description,
  String? startTime,
  String? endTime,
}) {
  return _client.patch(
    '/trips/${Uri.encodeComponent(tripId)}/entries/$entryId',
    body: {
      'title': title,
      'description': description,
      'start_time': startTime,
      'end_time': endTime,
      'expectedVersion': expectedVersion,
    },
  );
}

/// DELETE /trips/:id/entries/:eid（回 200 {ok:true}，忽略 body）。
Future<void> deleteEntry({required String tripId, required int entryId}) {
  return _client.delete(
    '/trips/${Uri.encodeComponent(tripId)}/entries/$entryId',
  );
}
```
擴充 `addEntryToDay`：加 `String? description` 參數，body 多 `'description': description`。既有呼叫（add-to-trip direct mode）不傳 → null，相容。

### B. `lib/features/trip_detail/widgets/entry_edit_sheet.dart`（新增）
- Sealed 導航/模式參數：
  ```dart
  sealed class EntryEditArgs { const EntryEditArgs(); }
  class EntryEditExisting extends EntryEditArgs {
    const EntryEditExisting(this.entry);
    final TimelineEntry entry;
  }
  class EntryEditNew extends EntryEditArgs {
    const EntryEditNew(this.dayNum);
    final int dayNum;
  }
  ```
- `EntryEditSheet`（`ConsumerStatefulWidget`，`{required String tripId, required EntryEditArgs args}`）：
  - 欄位 state：`title`（`TextEditingController`，預填 existing.title）、`description`（controller，預填）、`TimeOfDay? start`、`TimeOfDay? end`（existing 由 `_parseHm(entry.startTime/endTime)` 解析，新增則 `null`）、`bool submitting`。
  - 時間列：兩個 chip（開始/結束）。未設顯「—」可點 `showTimePicker` 設定；已設顯時間並帶 ✕ 清除為 null。
  - 驗證：`title.trim()` 非空；若 `start` 與 `end` 皆非 null 則需 `end > start`（分鐘比較）。不符 → 顯提示 + disable 儲存。
  - 送出：
    - existing → `updateEntry(tripId, entryId: entry.id, expectedVersion: entry.version, title, description, startTime: _fmt(start), endTime: _fmt(end))`。
    - new → `addEntryToDay(tripId, dayNum: args.dayNum, title, description, startTime: _fmt(start), endTime: _fmt(end), source: 'custom')`。
    - 成功 → `ref.invalidate(tripDaysProvider(tripId))` → `Navigator.pop` → snackbar（編輯「已儲存」/新增「已新增」）。
  - 錯誤：
    - `ApiError` status 409 → `ref.invalidate(tripDaysProvider(tripId))` + pop + snackbar「此停留點已更新，已重新載入，請再編輯一次」。
    - 其他 → 留在 sheet + `submitting=false` + snackbar「儲存失敗，請稍後再試」。
- 對外輔助：`Future<void> showEntryEditSheet(BuildContext, {required String tripId, required EntryEditArgs args})` 包 `showModalBottomSheet`（`isScrollControlled: true`，避免鍵盤遮擋）。
- 時間 helper：`String? _fmt(TimeOfDay?)` → `HH:MM` 或 null；`TimeOfDay? _parseHm(String?)`；`bool entryTimeRangeValid(TimeOfDay? start, TimeOfDay? end)`（皆非 null 時 end>start，否則 true）— 後者頂層純函式以利單元測試。

ValueKey 規範（測試探針）：`entry-edit-title` / `entry-edit-desc` / `entry-edit-start` / `entry-edit-end` / `entry-edit-start-clear` / `entry-edit-end-clear` / `entry-edit-submit`。

### C. `lib/features/trip_detail/widgets/timeline_entry_tile.dart`（修改）
- 加 `final VoidCallback? onTap;`，將內容卡（`Expanded → _EntryCard`）包進 `InkWell(onTap: onTap)`（onTap 為 null 時不可點）。其餘版面/既有 `entry-dot-<id>` 測試不變。

### D. `lib/features/trip_detail/trip_timeline_screen.dart`（修改）
- `_TimelineBody` 增 `final String tripId;`，往下傳給 `_DaySection`。
- `_DaySection` 由 `StatelessWidget` 改 `ConsumerWidget`，新增 `final String tripId;`：
  - 每個 entry 的 `TimelineEntryTile` 包進 `Dismissible`：
    - `key: ValueKey('entry-dismiss-<entry.id>')`，`direction: DismissDirection.endToStart`，紅底 + 刪除 icon 的 `background`。
    - `confirmDismiss`：showDialog 確認 →（確認）`deleteEntry` → 成功 `ref.invalidate(tripDaysProvider(tripId))` + snackbar「已刪除」→ **return false**（不靠 Dismissible 自身移除，避免與 provider 資料來源不同步；refetch 後該 tile 自然消失）；失敗 snackbar「刪除失敗，請稍後再試」+ return false。
    - tile `onTap` → `showEntryEditSheet(context, tripId: tripId, args: EntryEditExisting(entry))`。
  - 該日 entries 之後加「+ 新增停留點」鈕（`key: ValueKey('add-entry-<day.dayNum>')`）→ `showEntryEditSheet(context, tripId: tripId, args: EntryEditNew(day.dayNum))`。
- `TripTimelineScreen.build` 傳 `tripId` 給 `_TimelineBody`。

---

## 資料流

```
tap tile / add 鈕
  → showEntryEditSheet（modal）
    → EntryEditSheet 填表 → 送出
      → ref.read(tripRepositoryProvider).updateEntry / addEntryToDay
      → ref.invalidate(tripDaysProvider(tripId))
      → pop + snackbar
  → TripTimelineScreen watch tripDaysProvider 重抓 → timeline 重繪

swipe tile
  → Dismissible.confirmDismiss → 確認 dialog
    → deleteEntry → invalidate → snackbar → return false
```

---

## 錯誤處理

| 情境 | 行為 |
|---|---|
| 編輯/新增成功 | invalidate + pop + snackbar |
| 編輯 409 STALE_ENTRY | invalidate（載回最新）+ pop + snackbar「已更新，請再編輯一次」 |
| 編輯/新增其他錯誤 | 留 sheet + 重新啟用送出 + snackbar「儲存失敗，請稍後再試」 |
| 刪除成功 | invalidate + snackbar「已刪除」 |
| 刪除失敗 | snackbar「刪除失敗，請稍後再試」（tile 不移除） |

OCC：編輯一律帶 `expectedVersion = entry.version`（來自最近一次 days 抓取）。409 採「重抓 + 請重試」而非自動重送，避免覆寫他人變更。

---

## 測試（TDD）

### `test/api/trip_repository_test.dart`（擴充）
- `updateEntry`：`PATCH /trips/okinawa/entries/11`，body 含 snake_case 欄位 + `expectedVersion`，200 完成。
- `updateEntry` 409：reply 409 `{error:{code:'STALE_ENTRY'...}}` → `throwsA(isA<ApiError>()...status 409)`。
- `deleteEntry`：`DELETE /trips/okinawa/entries/11` reply `200 {ok:true}` → completes。
- `addEntryToDay` 帶 `description`：body 含 `description`。

### `test/features/trip_detail/widgets/entry_edit_sheet_test.dart`（新增）
- `entryTimeRangeValid`：兩者 null→true、僅一者→true、end>start→true、end<=start→false。
- 編輯模式：預填 title；改 title → 點送出 → verify `updateEntry(entryId, expectedVersion, title=...)`。
- 新增模式：填 title → 送出 → verify `addEntryToDay(dayNum, title, source:'custom')`。
- 標題清空 → 送出鈕 disabled。
- 起訖皆設且 end<=start → 送出鈕 disabled + 顯提示。
- （以 mocktail mock `TripRepository`，`tripRepositoryProvider.overrideWithValue` + `tripDaysProvider` override，避免真網路。）

### `test/features/trip_detail/trip_timeline_screen_test.dart`（擴充）
- 點 entry tile → 開 `EntryEditSheet`（找得到 `entry-edit-title` 並預填該 entry 標題）。
- 左滑 tile → 確認 dialog → 確認 → verify `deleteEntry(entryId)`。
- 點「+ 新增停留點」→ 開新增 sheet。
- 既有 timeline 測試（tone 圓點、travel pill、day pills…）保持綠。

**完成定義**：`flutter analyze` 0 issue + `flutter test` 全綠。

---

## 邊界 / 風險

- **Dismissible 與 provider 資料同步**：`confirmDismiss` 一律 return false，刪除靠 invalidate 重抓移除，避免「dismissed widget still in tree」與 stale 資料雙重移除。
- **時間可為 null**：entry 允許無時間；顯示層 `displayTime = startTime ?? time ?? ''` 已處理空字串。新增的自訂停留點可完全無時間。
- **`addEntryToDay` 既有呼叫**：擴 `description` 為選填具預設 null，add-to-trip direct mode 不受影響（其測試不變）。
- **modal 內 ref/invalidate**：`EntryEditSheet` 自身為 Consumer，於 pop 前完成 invalidate；mutation 用其 ref.read。
- **與 PR #6 無重疊**：本功能僅動 trip_detail/* 與 trip_repository.dart，PR #6 動 favorites/* 與 router，合併無衝突。

---

## Entry CRUD 全範圍拆解（脈絡）

| | 範圍 | OCC | model 改動 |
|---|---|---|---|
| **A**（本 spec） | 編輯 + 刪除 entry meta | `version` | 無 |
| **B**（本 spec） | timeline 內新增自訂停留點 | — | 無 |
| C | 排序 / 同天·跨天搬移（batch sort_order / day_id） | 無 | 無 |
| D | POI 管理（換 master、alternates 增刪排序、per-POI note/分類、reservation） | `entryPoisVersion`(string) | 加欄位 |
| E | 交通（segments mode/min + recompute-travel） | segment `version` | 加 segment model |
