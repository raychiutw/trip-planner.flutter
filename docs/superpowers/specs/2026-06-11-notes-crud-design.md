# 行程筆記 CRUD 設計

**目標**：讓筆記 5 區（航班 / 住宿 / 預訂 / 行前須知 / 緊急聯絡）從唯讀變成可新增 / 編輯 / 刪除 / 拖曳排序。

**架構**：吃後端「5 區共用泛型 CRUD 引擎」的紅利 — 一個 `NoteSection` enum + 一組泛型 repository 方法 + 一個 spec-driven `NoteEditSheet`（用每區欄位規格驅動，不寫 5 個 bespoke 表單）。沿用既有 `tripNotesProvider`（GET /notes 聚合），mutation 後 invalidate 重抓。

**Tech**：flutter_riverpod 3.x / dio mock + mocktail。單一 PR，分 3 階段。

---

## 範圍
**做**：5 區各自的 create / update（OCC）/ delete / 每區拖曳 reorder。bottom-sheet 表單編輯。
**不做**：lodging 的 `dayId` link（CRUD 白名單不含，後端無端點）、AI 生成（另有 async job 端點，本次不碰）、inline 逐欄 autosave（採整列 sheet 表單）、`aiGenerated`/`aiSource` 編輯（手動建立固定 0/null）。

---

## 後端契約（5 區一致；權威來自 web `functions/api/trips/[id]/notes/_shared.ts`）

所有 mutation 經 `ApiClient`（自動 Cookie + Origin）。錯誤 `{error:{code,message,detail}}` → `ApiError`。

- **section URL 段**：`flights` / `lodgings` / `reservations` / `pretrip` / `emergency`
  （注意：`pretrip`/`emergency` 與 GET 聚合 response key `pretripNotes`/`emergencyContacts` 不同）。
- **CREATE**：`POST /api/trips/:id/notes/{section}`，body = snake_case 欄位子集（可一次帶齊；`trip_id`/`version` 不可帶；`sort_order` 省略→自動排最後）→ **201** 回完整 row。
- **UPDATE**：`PATCH /api/trips/:id/notes/{section}/:rowId`，body = snake_case 欄位 + **`expectedVersion`(camelCase, int, 選填)** → **200** 回更新後 row。OCC：version 欄名 `version`（起始 0，每次 +1）；不符 → **409 `STALE_ENTRY`**（`{error:{code:"STALE_ENTRY",...}}`）。
- **DELETE**：`DELETE /api/trips/:id/notes/{section}/:rowId` → **200 `{ok:true}`**（非 204，忽略 body）。
- **REORDER**：`PATCH /api/trips/:id/notes/{section}/reorder`，body `{ "items": [ {"id": int, "sortOrder": int}, ... ] }`（**camelCase**）→ **200 `{ok:true, updated:N}`**。
- **enum**（後端 + DB CHECK 雙重驗，違反 → 400）：
  - reservation `kind`：`restaurant|experience|ticket|transport|other`（預設 restaurant）
  - emergency `kind`：`personal|embassy|police|medical|insurance|hotel|other`（預設 other）
- 型別：`party_size`/`sort_order`/`version` = int；時間欄（`depart_at` 等）= 字串（ISO-local 或空）。

---

## 階段 0：NoteSection + repository

### `lib/models/note_section.dart`（新，純 Dart）
```dart
enum NoteSection { flights, lodgings, reservations, pretrip, emergency }
// path = section.name（剛好等於 URL 段）
```

### `lib/api/trip_repository.dart`（修改，+4 泛型方法）
```dart
Future<void> createNote(NoteSection section, {required String tripId, required Map<String, dynamic> fields})
  // POST /trips/:id/notes/{section.name}，body = fields

Future<void> updateNote(NoteSection section, {required String tripId, required int rowId, required Map<String, dynamic> fields, int? expectedVersion})
  // PATCH /trips/:id/notes/{section.name}/$rowId，body = {...fields, 'expectedVersion': ?expectedVersion}

Future<void> deleteNote(NoteSection section, {required String tripId, required int rowId})
  // DELETE /trips/:id/notes/{section.name}/$rowId

Future<void> reorderNotes(NoteSection section, {required String tripId, required List<({int id, int sortOrder})> items})
  // PATCH /trips/:id/notes/{section.name}/reorder，body = {'items':[{'id':..,'sortOrder':..},...]}
```
`fields` 由 UI 層以 snake_case key 組好；repository 不關心型別。

### 各 row model 加 `toEditFields()`（`lib/models/notes.dart`，回 snake_case 可編欄位 map，供 edit 預填）
```dart
// TripFlight: {'airline':airline,'flight_no':flightNo,'cabin_class':cabinClass,
//   'depart_airport':departAirport,'arrive_airport':arriveAirport,
//   'depart_at':departAt,'arrive_at':arriveAt,'note':note}
// TripLodging: {'name','address','check_in_at','check_out_at','booking_no','phone','note'}
// TripReservation: {'kind','title','reserved_at','party_size','reservation_no','phone','note'}
// TripPretripNote: {'section','title','content'}
// TripEmergencyContact: {'name','relationship','phone','email','kind'}
```
（key 須與下方欄位規格一致。）

---

## 階段 1：spec-driven NoteEditSheet

### `lib/features/trip_detail/notes/note_field_spec.dart`（新）
```dart
enum NoteFieldType { text, multiline, integer, enumChoice, datetime }

class NoteFieldSpec {
  final String key;        // snake_case，與 toEditFields/白名單一致
  final String label;
  final NoteFieldType type;
  final List<(String value, String label)> options; // enumChoice 用
  final String defaultValue;                          // create 預設（enum 用）
}
```
+ `Map<NoteSection, List<NoteFieldSpec>> noteSectionSpecs`：

| section | 欄位（key:label:type） |
|---|---|
| flights | airline:航空公司:text · flight_no:航班編號:text · cabin_class:艙等:text · depart_airport:出發機場:text · arrive_airport:抵達機場:text · depart_at:出發時間:datetime · arrive_at:抵達時間:datetime · note:備註:multiline |
| lodgings | name:名稱:text · address:地址:text · check_in_at:入住:datetime · check_out_at:退房:datetime · booking_no:訂房編號:text · phone:電話:text · note:備註:multiline |
| reservations | kind:類型:enum(restaurant 餐廳/experience 體驗/ticket 票券/transport 交通/other 其他,預設 restaurant) · title:名稱:text · reserved_at:預約時間:datetime · party_size:人數:integer · reservation_no:預約編號:text · phone:電話:text · note:備註:multiline |
| pretrip | section:分類:text · title:標題:text · content:內容:multiline |
| emergency | name:名稱:text · relationship:關係:text · phone:電話:text · email:Email:text · kind:類型:enum(personal 個人/embassy 大使館/police 警察/medical 醫療/insurance 保險/hotel 飯店/other 其他,預設 other) |

+ `Map<NoteSection, String> noteSectionTitles`（航班/住宿/預訂/行前須知/緊急聯絡）。

### `lib/features/trip_detail/notes/note_edit_sheet.dart`（新）
- `showNoteEditSheet(context, {required String tripId, required NoteSection section, Map<String,dynamic>? initialFields, int? rowId, int? version})`：modal bottom sheet。
- `NoteEditSheet`（ConsumerStatefulWidget）：依 `noteSectionSpecs[section]` 建欄位狀態（每欄一個 controller 或選值）；初值來自 `initialFields`（edit）或 spec.defaultValue（create）。
  - 渲染：text/multiline=TextField、integer=number TextField、enumChoice=ChoiceChips、datetime=按鈕顯示值 + date+time picker（→ `YYYY-MM-DDTHH:mm`）+ 清除。
  - 送出：收集成 snake_case map（integer 轉 int，datetime/text 為字串，enum 為選值）→ `_isEdit` ? `updateNote(section, rowId, fields, expectedVersion: version)` : `createNote(section, fields)` → `invalidate(tripNotesProvider(tripId))` → pop + snackbar。
  - 標題必要性：不強制（後端欄位皆可空，預設 ''）。送出鈕一律可按（除 submitting）。
  - ValueKey：`note-field-<key>`、`note-enum-<key>-<value>`、`note-datetime-<key>`、`note-datetime-clear-<key>`、`note-edit-submit`。
- 錯誤：`ApiError` 409 → invalidate + pop + snackbar「此筆記已更新，請重新編輯」；其他 → 留 sheet + 重新啟用 + snackbar「儲存失敗，請稍後再試」。

---

## 階段 2：notes 畫面接線

`lib/features/trip_detail/trip_notes_screen.dart`（改 ConsumerWidget；需 ref 做 mutation/invalidate）：
- 每個 `_NotesSection` 帶 `tripId` + `NoteSection` + 該區 rows 的 `(id, version, toEditFields)`。
- section children 改 **`ReorderableListView`**（shrinkWrap + NeverScrollableScrollPhysics + buildDefaultDragHandles:false）：
  - 每 row = `Dismissible`(左滑刪除→確認→`deleteNote`) 包 row 卡（點擊→`showNoteEditSheet` edit）+ 尾端 drag handle（`ReorderableDragStartListener`）。
  - `onReorderItem` → `reorderNotes(section, items)` → invalidate（沿用 timeline 的 `computeReorderUpdates` 同邏輯，抽共用或各自小函式）。
- section 底部「**+ 新增[標題]**」按鈕（key `note-add-<section.name>`）→ `showNoteEditSheet` create。
- 刪除/排序/新增/編輯後 `invalidate(tripNotesProvider(tripId))`。
- 既有唯讀 row 卡片樣式保留（_FlightRow 等），只是包進可點/可滑/可拖的容器。
- ValueKey：row 容器 `note-row-<section.name>-<id>`、drag `note-drag-<section.name>-<id>`、dismiss `note-dismiss-<section.name>-<id>`。

---

## 錯誤處理（統一）
| 情境 | 行為 |
|---|---|
| create/update/reorder/delete 成功 | invalidate(tripNotesProvider) + snackbar |
| update 409 STALE_ENTRY | invalidate + pop sheet + 「此筆記已更新，請重新編輯」 |
| 其他錯誤 | snackbar「操作失敗，請稍後再試」，UI 不破壞 |

---

## 測試（TDD，逐階段）
- **階段 0**（`test/api/trip_repository_test.dart` 擴 + `test/models/notes_test.dart` 擴）：createNote（POST path/section/body）、updateNote（PATCH + expectedVersion + 409）、deleteNote（200 {ok:true}）、reorderNotes（items camelCase）；各 row `toEditFields()` 鍵值正確。用 reservation + flight 兩型涵蓋 enum/datetime/integer。
- **階段 1**（`test/features/trip_detail/notes/note_edit_sheet_test.dart` 新）：create 模式填欄位→`createNote(section, fields)`；edit 模式預填（initialFields）→送出 `updateNote(rowId, expectedVersion)`；enum chips 切換進 fields；integer 轉型；datetime picker 設值。
- **階段 2**（`trip_notes_screen_test.dart` 擴/新）：點 row 開編輯 sheet（預填）；左滑刪除→`deleteNote`；「新增」開 create sheet；drag handle 存在 + reorder→`reorderNotes`。既有唯讀計數測試保持綠。

**完成定義**：每階段 `flutter analyze` 0 + `flutter test` 全綠。

---

## 風險 / 注意
- **section 段名 vs 聚合 key 不一致**：URL 用 `pretrip`/`emergency`，refetch 讀 `pretripNotes`/`emergencyContacts`。client 以 `NoteSection.name` 當路徑、`tripNotesProvider` 取聚合,兩者分開,不混。
- **DELETE 回 200 {ok:true} 非 204**：忽略 body 即可。
- **OCC opt-in**：update 一律帶 `expectedVersion`（= row.version）才會在衝突拿 409。
- **datetime 既有值格式不一**（可能空/HH:MM/完整）：picker 解析失敗則起始 now；保留「文字顯示既有值 + 可清除」避免破壞既有資料。
- **toEditFields key 必須與 spec key、後端白名單三者一致**（plan 自審會逐欄對照）。
- **reorder 與 provider 同步**：`onReorderItem` 後送出 + invalidate 重抓（沿用 timeline 模式,confirmDismiss return false 不靠 widget 自身移除）。
