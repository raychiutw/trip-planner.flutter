# 行程筆記 CRUD 實作計畫

> executing-plans 逐 task TDD。分支 `feat/notes-crud`（自 master）。
> spec：`docs/superpowers/specs/2026-06-11-notes-crud-design.md`。

**Goal:** 筆記 5 區 create/update(OCC)/delete/每區拖曳 reorder,bottom-sheet 表單。
**Tech:** flutter_riverpod 3.x / dio mock + mocktail。單一 PR、3 階段。

---

# 階段 0：NoteSection + repository + toEditFields

## Task 0.1：NoteSection enum + repository 4 方法

**Files:** 新 `lib/models/note_section.dart`；`lib/api/trip_repository.dart`；test `test/api/trip_repository_test.dart`。

- [ ] 測試（trip_repository_test 擴,import note_section）：
  - createNote：`POST /trips/okinawa/notes/flights`，data `{'airline':'IT','flight_no':'IT232'}` → 201 completes。
  - updateNote：`PATCH /trips/okinawa/notes/reservations/5`，data `{'title':'晚餐','expectedVersion':2}` → 200 completes。
  - updateNote 409：reply 409 `{error:{code:'STALE_ENTRY'}}` → throwsA ApiError(409, code STALE_ENTRY)。
  - deleteNote：`DELETE /trips/okinawa/notes/emergency/7` → 200 `{ok:true}` completes。
  - reorderNotes：`PATCH /trips/okinawa/notes/flights/reorder`，data `{'items':[{'id':11,'sortOrder':0},{'id':12,'sortOrder':1}]}` → 200 completes。
- [ ] 跑 → 失敗。
- [ ] 實作 `lib/models/note_section.dart`：
  ```dart
  /// 筆記 5 區;`name` 即 API URL 段（flights/lodgings/reservations/pretrip/emergency）。
  library;

  enum NoteSection { flights, lodgings, reservations, pretrip, emergency }
  ```
- [ ] `trip_repository.dart`：import `'../models/note_section.dart';`,在 fetchNotes 之後加：
  ```dart
  Future<void> createNote(
    NoteSection section, {
    required String tripId,
    required Map<String, dynamic> fields,
  }) {
    return _client.post(
      '/trips/${Uri.encodeComponent(tripId)}/notes/${section.name}',
      body: fields,
    );
  }

  Future<void> updateNote(
    NoteSection section, {
    required String tripId,
    required int rowId,
    required Map<String, dynamic> fields,
    int? expectedVersion,
  }) {
    return _client.patch(
      '/trips/${Uri.encodeComponent(tripId)}/notes/${section.name}/$rowId',
      body: {...fields, 'expectedVersion': ?expectedVersion},
    );
  }

  Future<void> deleteNote(
    NoteSection section, {
    required String tripId,
    required int rowId,
  }) {
    return _client.delete(
      '/trips/${Uri.encodeComponent(tripId)}/notes/${section.name}/$rowId',
    );
  }

  Future<void> reorderNotes(
    NoteSection section, {
    required String tripId,
    required List<({int id, int sortOrder})> items,
  }) {
    return _client.patch(
      '/trips/${Uri.encodeComponent(tripId)}/notes/${section.name}/reorder',
      body: {
        'items': [
          for (final it in items) {'id': it.id, 'sortOrder': it.sortOrder},
        ],
      },
    );
  }
  ```
- [ ] 跑 → 綠。commit `feat: NoteSection + TripRepository 筆記 CRUD（create/update/delete/reorder）`。

## Task 0.2：各 row model toEditFields()

**Files:** `lib/models/notes.dart`；test `test/models/notes_test.dart`(擴)。

- [ ] 測試：TripFlight/TripReservation 的 `toEditFields()` 鍵值（snake_case）正確（flight 含 flight_no/depart_at...;reservation 含 kind/party_size...）。
- [ ] 跑 → 失敗。
- [ ] 各 class 加方法（key 對齊後端白名單 + spec）：
  ```dart
  // TripFlight
  Map<String, dynamic> toEditFields() => {
        'airline': airline, 'flight_no': flightNo, 'cabin_class': cabinClass,
        'depart_airport': departAirport, 'arrive_airport': arriveAirport,
        'depart_at': departAt, 'arrive_at': arriveAt, 'note': note,
      };
  // TripLodging
  Map<String, dynamic> toEditFields() => {
        'name': name, 'address': address, 'check_in_at': checkInAt,
        'check_out_at': checkOutAt, 'booking_no': bookingNo, 'phone': phone,
        'note': note,
      };
  // TripReservation
  Map<String, dynamic> toEditFields() => {
        'kind': kind, 'title': title, 'reserved_at': reservedAt,
        'party_size': partySize, 'reservation_no': reservationNo,
        'phone': phone, 'note': note,
      };
  // TripPretripNote
  Map<String, dynamic> toEditFields() =>
      {'section': section, 'title': title, 'content': content};
  // TripEmergencyContact
  Map<String, dynamic> toEditFields() => {
        'name': name, 'relationship': relationship, 'phone': phone,
        'email': email, 'kind': kind,
      };
  ```
- [ ] 跑 → 綠。commit `feat: 筆記 row model toEditFields（edit 預填用）`。

---

# 階段 1：spec-driven NoteEditSheet

## Task 1.1：欄位規格

**Files:** 新 `lib/features/trip_detail/notes/note_field_spec.dart`（無測試,常數;由 sheet 測試間接覆蓋）。

- [ ] 實作（完整內容見 spec「階段 1」表格）：`NoteFieldType` enum、`NoteFieldSpec` class、`noteSectionTitles`、`noteSectionSpecs`（5 區欄位）。enum 選項：reservation kind 5 值(預設 restaurant)、emergency kind 7 值(預設 other)。
- [ ] commit 併入 Task 1.2（規格 + sheet 一起）。

## Task 1.2：NoteEditSheet

**Files:** 新 `lib/features/trip_detail/notes/note_edit_sheet.dart`；test 新 `test/features/trip_detail/notes/note_edit_sheet_test.dart`。

- [ ] 測試（mock TripRepository + override tripNotesProvider）：
  - create（reservations,無 initialFields）：填 `note-field-title`「晚餐」+ 點 `note-enum-kind-experience` + 點 `note-edit-submit` → verify `createNote(NoteSection.reservations, fields: 含 title=晚餐, kind=experience)`。
  - edit（reservations,initialFields {title:'舊',kind:'restaurant',party_size:2,...},rowId 5,version 3）：改 title → submit → verify `updateNote(rowId:5, expectedVersion:3, fields: title=新)`。
  - integer：`note-field-party_size` 輸入 '4' → fields['party_size']==4（int）。
  - create 預設 enum：reservations create 未動 kind → fields['kind']=='restaurant'。
  - （用 captureAny 取 fields map 斷言內容;registerFallbackValue NoteSection + Map。）
- [ ] 跑 → 失敗。
- [ ] 實作 `note_edit_sheet.dart`：
  - `showNoteEditSheet(context, {required String tripId, required NoteSection section, Map<String,dynamic>? initialFields, int? rowId, int? version})` → showModalBottomSheet（isScrollControlled + viewInsets padding）。
  - `NoteEditSheet`（ConsumerStatefulWidget，`isEdit => rowId != null`）：
    - initState：依 `noteSectionSpecs[section]` 建狀態。text/multiline/integer → `Map<String,TextEditingController> _ctrls`（初值 `initialFields?[key]?.toString() ?? spec.defaultValue`）;enumChoice → `Map<String,String> _enums`;datetime → `Map<String,String> _dts`。
    - build：SafeArea + Padding，標題「新增/編輯+sectionTitle」，逐 spec 渲染：
      - text → TextField(key `note-field-<key>`)
      - multiline → TextField(maxLines:3, key 同)
      - integer → TextField(keyboardType number, key 同)
      - enumChoice → Wrap[ChoiceChip(key `note-enum-<key>-<value>`, selected _enums[key]==value, onSelected setState)]
      - datetime → Row[label + OutlinedButton(key `note-datetime-<key>`, 顯示 _dts[key] 或「設定」, onTap _pickDateTime) + 若有值 IconButton(key `note-datetime-clear-<key>`)]
    - `_pickDateTime(key)`：showDatePicker(initialDate: DateTime.tryParse(現值) ?? DateTime.now(), first 2020 last 2035) → showTimePicker → set `YYYY-MM-DDTHH:mm`。
    - submit（`note-edit-submit` FilledButton，`_submitting` 時 disable）：收集 fields（integer `int.tryParse(..)??0`,其餘字串/enum），create→`createNote`、edit→`updateNote(expectedVersion: version)` → `invalidate(tripNotesProvider(tripId))` → pop + snackbar;409→invalidate+pop+「此筆記已更新，請重新編輯」;其他→留 sheet + snackbar。
    - dispose 所有 controller。
- [ ] 跑 → 綠。commit `feat: spec-driven NoteEditSheet + 5 區欄位規格`。

---

# 階段 2：notes 畫面接線

**Files:** `lib/features/trip_detail/trip_notes_screen.dart`；test `test/features/trip_detail/trip_notes_screen_test.dart`(新/擴)。

- [ ] 測試（override tripRepositoryProvider mock + tripNotesProvider 假資料）：
  - 點 flight row（`note-row-flights-<id>`）→ 開編輯 sheet（`note-edit-submit` 存在 + 預填航班）。
  - 左滑 flight row → 確認 → `deleteNote(NoteSection.flights, rowId)`。
  - 點「新增航班」（`note-add-flights`）→ 開 create sheet。
  - 每 row 有 drag handle（`note-drag-flights-<id>`）。
  - 既有唯讀 count badge 測試（notes-count-*）保持綠。
- [ ] 跑 → 失敗。
- [ ] 實作：`TripNotesScreen` 仍 ConsumerWidget;`_buildSections` 每區改傳 `tripId` + `NoteSection` + `List<_NoteRowData>`（`_NoteRowData{int id; int version; Map<String,dynamic> editFields; Widget display}`,由 model map 而來,如 `for (final f in notes.flights) _NoteRowData(id:f.id, version:f.version, editFields:f.toEditFields(), display:_FlightRow(f))`）。
  - `_NotesSection` 改 `ConsumerWidget`,加 `tripId`/`section`/`rows(List<_NoteRowData>)`。ExpansionTile children =
    - `ReorderableListView`（shrinkWrap, NeverScrollableScrollPhysics, buildDefaultDragHandles:false, onReorderItem → 計算 `List<({int id,int sortOrder})>` → `reorderNotes` → invalidate）;每 item key `ValueKey('note-row-<section.name>-<id>')` = Dismissible(`note-dismiss-...`,左滑→確認 dialog→`deleteNote`→invalidate,return false) 包 Row[Expanded(InkWell onTap→`showNoteEditSheet` edit,帶 editFields/id/version), drag handle `ReorderableDragStartListener`(Icon key `note-drag-<section.name>-<id>`)] 內容為 `display`。
    - 空區仍顯示「尚無資料」。
    - 底部 `TextButton.icon`（key `note-add-<section.name>`）→ `showNoteEditSheet` create。
  - reorder 計算可用小函式 `List<({int id,int sortOrder})> _noteReorder(List<int> ids, int oldI, int newI)`（remove+insert+重編,onReorderItem 已調整索引,不 -1）。
- [ ] 跑 → 綠。commit `feat: notes 畫面接 CRUD（新增/編輯/左滑刪除/每區拖曳排序）`。

---

# 收尾
- [ ] 全 `flutter analyze` 0 + `flutter test` 全綠。
- [ ] finishing-a-development-branch：push + PR（base master）。
- [ ] （選配,使用者授權）iOS smoke。

## 自我審查（plan vs spec）
- 5 區 CRUD + reorder → 階段 0 repository + 階段 2 畫面;sheet → 階段 1。
- 欄位 key 三方一致：spec 表 ↔ toEditFields(Task 0.2) ↔ noteSectionSpecs(Task 1.1) ↔ 後端白名單。
- OCC：update 帶 expectedVersion(=row.version),409 STALE_ENTRY。
- ValueKey 命名一致（note-field/enum/datetime/edit-submit/row/drag/dismiss/add-<section>）。
- 無 placeholder。
