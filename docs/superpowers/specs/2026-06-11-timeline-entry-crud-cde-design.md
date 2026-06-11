# 時間軸 Entry CRUD（C+D+E 合併）設計

> Entry CRUD 全範圍 A~E。A+B 已於 PR #7 完成。本 spec 涵蓋 **C（排序/搬移）+ D（POI 管理）+ E（交通）合併為單一 PR**，分支 `feat/timeline-entry-crud-cde` 疊在 `feat/timeline-entry-edit-delete-add`（A+B）之上。

**目標**：時間軸可拖曳排序與跨天搬移停留點（C）；可管理停留點的正選/備選 POI、per-POI 備註與分類、訂位（D，獨立全頁）；可編輯各段交通方式（E，driving/walking 後端打 Google 重算、transit 手動分鐘）。

**架構**：沿用 `tripDaysProvider` 讀取鏈。C 重構單日 entry 列表為 `ReorderableListView`（drag handle 觸發，與既有 tap=編輯／左滑=刪除共存）。D 新增 `EntryPoiScreen` 全頁 + `entryDetailProvider`（GET /entries/:eid 拿 master/alternates/entryPoisVersion）。E 新增 `tripSegmentsProvider`（GET /segments 拿 segment id/version）+ travel pill 點擊編輯。所有 mutation 後 invalidate 對應 provider 重抓。

**Tech：** flutter_riverpod 3.x / go_router（D 需新路由）/ dio mock + mocktail。

---

## 範圍與分階段執行

單一 PR，但**分三階段依序實作 + 驗證**（每階段 analyze+test 綠才進下一階）：

1. **階段 0：model + repository**（C/D/E 全部後端方法 + model 欄位，純資料層，最先做、最易測）。
2. **階段 C**：drag reorder + 跨天 move action。
3. **階段 D**：EntryPoiScreen 全頁 + 路由 + 入口。
4. **階段 E**：travel 編輯 sheet + segment 比對。

**不做**：POI 照片、Google Routes 失敗的進階重試 UI、segment 手動新增（後端由 recompute 自動產生）、跨天「拖曳」（跨天用 move action，drag 僅同天）。

---

## Model 變更（`lib/models/`）

### `entry.dart`
- **`TimelineEntry`** 加 `final String? entryPoisVersion;`（D 的 OCC token；wire `entryPoisVersion`，server 一律 string 化）。`fromJson`：`entryPoisVersion: json['entryPoisVersion']?.toString()`。
- **`EntryPoiInfo`** 加 `final String? reservation;`、`final String? reservationUrl;`、`final String? description;`。`fromJson` 對應 `reservation` / `reservationUrl` / `description`（皆 `as String?`）。

### 新檔 `lib/models/segment.dart`
```dart
class TripSegment {
  final int id;
  final int? fromEntryId;
  final int? toEntryId;
  final String mode;        // driving / walking / transit
  final int? min;
  final int? distanceM;
  final String? source;     // google / manual
  final int version;        // OCC（expectedVersion）
  // fromJson：id/version toInt；min/distanceM (num?)?.toInt；mode/source as String
}
```

> 既有 `Travel`（entry.travel，顯示用）不變；E 編輯時用 `TripSegment`（含 id/version）。

---

## 後端契約（C/D/E）

所有 mutation 經 `ApiClient`（自動 Cookie + Origin）。錯誤 `ApiError(status, code, ...)`；OCC 衝突 code 一律 `STALE_ENTRY`(409)。

### C — 排序/搬移
- `PATCH /api/trips/:id/entries/batch`，body `{ "updates": [ { "id": int, "sort_order": int, "day_id"?: int } ] }`（**snake_case**，**無 OCC**）。同天 reorder 只帶 `sort_order`；跨天搬移帶 `day_id`。成功 `200 { ok, updated }`。錯誤：某 id 不屬此 trip → 404；重複 (day_id,sort_order) → 400。
- reorder/move 後 fire-and-forget `POST /api/trips/:id/recompute-travel?day=all`（相鄰交通改變）。

### D — POI 管理（兩套 case 注意；OCC = `entryPoisVersion` string）
- `GET /api/trips/:id/entries/:eid` → entry meta + `{ master, alternates, stop_pois, entryPoisVersion }`（無 travel）。
- 設正選：`PATCH .../entries/:eid/master`，`{ poiId: int, entryPoisVersion?: string }` → `200 { entryId, masterPoiId, oldMasterPoiId, entryPoisVersion }`。
- 加備選：`POST .../entries/:eid/alternates`，`{ poiId, entryPoisVersion? }` 或 `{ name, lat, lng, type?, category?, address?, rating?, source?, entryPoisVersion? }`（**find-or-create 用 `type`**）→ `201 { entryId, poiId, sortOrder, entryPoisVersion }`。錯誤：DUPLICATE_POI 409 / MISSING_MASTER 400。
- 刪備選：`DELETE .../entries/:eid/alternates/:poiId?entryPoisVersion=<string>` → `200 { entryId, poiId, entryPoisVersion }`。
- 備選重排：`PATCH .../entries/:eid/alternates/reorder`，`{ order: int[]（poiId 陣列，不含 master）, entryPoisVersion? }` → `200 { entryId, order, entryPoisVersion }`。錯誤 INVALID_ORDER 422。
- per-POI 備註/分類/訂位：`PATCH .../entries/:eid/pois/:poiId`，`{ note?: string|null, poi_type?: string, reservation?: string|null }`（**LWW，不帶 OCC**）→ `200 { entryId, poiId, type, note, reservation }`。

### E — 交通
- `GET /api/trips/:id/segments` → `[{ id, from_entry_id, to_entry_id, mode, min, distance_m, source, version, ... }]`（camelCase 化後讀 camelCase）。
- `PATCH /api/trips/:id/segments/:sid`，`{ mode: 'driving'|'walking'|'transit', min?: int, expectedVersion?: int }`。transit 必填 min（存 manual、不打 Google）；driving/walking 忽略 min、後端打 Google 重算。OCC `expectedVersion`(number) 不符 → 409。成功 `200` segment row。

---

## 階段 0：Repository 方法（`lib/api/trip_repository.dart`）

新增（簽名摘要；body case 依上）：
- `fetchEntry({tripId, entryId}) → TimelineEntry`（GET /entries/:eid）。
- `reorderEntries({tripId, List<EntryOrderUpdate> updates})`（PATCH /entries/batch）。`EntryOrderUpdate{ int id; int sortOrder; int? dayId; }`（新 model `lib/models/entry_order.dart` 或併入 segment.dart）。
- `recomputeTravel({tripId, String day = 'all'})`（POST /recompute-travel?day=）。
- `setEntryMaster({tripId, entryId, poiId, entryPoisVersion}) → void`。
- `addEntryAlternate({tripId, entryId, required PoiSearchResult poi, entryPoisVersion}) → void`（find-or-create 變體，body name/lat/lng/type…）。
- `removeEntryAlternate({tripId, entryId, poiId, entryPoisVersion}) → void`（DELETE，token 走 query）。
- `reorderEntryAlternates({tripId, entryId, List<int> order, entryPoisVersion}) → void`。
- `updateEntryPoi({tripId, entryId, poiId, note, poiType, reservation}) → void`（無 OCC；只送有值欄位）。
- `fetchSegments({tripId}) → List<TripSegment>`（GET /segments）。
- `updateSegment({tripId, segmentId, mode, min, expectedVersion}) → TripSegment`（PATCH /segments/:sid）。

> repository 變大（A+B 已加 3 個 + 本階段 ~10 個）。**評估抽 `EntryMutationRepository`**：階段 0 先就地加（與既有 entry 方法同檔），若 analyze/可讀性惡化再抽。決策記於 plan。

---

## 階段 C：拖曳排序 + 跨天搬移

- `_DaySection` 的 entry 區改 `ReorderableListView`（`shrinkWrap: true`、`physics: NeverScrollableScrollPhysics`，因外層已是 scroll view）。
- 每個 reorderable item key = `ValueKey('entry-<id>')`，內容 = 既有 `Dismissible(左滑刪除) → TimelineEntryTile(tap 編輯)`，**右側加 drag handle**（`ReorderableDragStartListener` 包一個 `≡` icon，`index: i`）。長按 handle 才啟動拖曳 → 不與 tap/swipe 衝突。
- `onReorder`：計算新順序 → `reorderEntries(updates: 新 sort_order 列表)` → `invalidate(tripDaysProvider)` + fire-and-forget `recomputeTravel`。樂觀：可先本地重排再送（v1 採「送出後 invalidate 重抓」，簡單一致）。
- travel pill：reorder 期間每個 entry 仍顯示其 leading travel（視覺暫時不準，refetch + recompute 後正確）。
- **跨天搬移**：entry 選單（tile 上的 `⋮` 或長按）→「移到其他天」→ 選目標日（bottom sheet 列 day）→ `reorderEntries(updates:[{id, sort_order: 末位, day_id: 目標 day.id}])` → invalidate + recompute。需要 day.id（`TripDay.id` 已有）。
- 入口：drag handle 圖示在 tile trailing；`⋮` 選單放「移到其他天」（也可放 reorder 提示）。ValueKey：`entry-drag-<id>`、`entry-menu-<id>`、`move-day-<dayId>`。

## 階段 D：地點管理全頁

- 新 `EntryPoiScreen`（`lib/features/trip_detail/entry_poi_screen.dart`，ConsumerStatefulWidget，`{tripId, entryId}`）。
- 資料：`entryDetailProvider = FutureProvider.family<TimelineEntry, ({String tripId, int entryId})>` → `fetchEntry`。畫面 watch 它；每次 POI mutation 後 `invalidate(entryDetailProvider((tripId, entryId)))` + `invalidate(tripDaysProvider(tripId))`。OCC token 取自最近 `entryDetailProvider` 的 `entryPoisVersion`。
- 版面（對齊核准的 preview）：
  - **正選**：master 卡（名稱/分類/評分）+「換成新地點」（POI 搜尋 → `setEntryMaster` 或 poi-id）。
  - **備選清單**：每個 alternate 一列，含「設為正選」（`setEntryMaster(poiId)`）、刪除（`removeEntryAlternate`）；清單可重排（`ReorderableListView` → `reorderEntryAlternates(order: poiId[])`）。
  - **加入備選**：POI 搜尋（reuse `poiRepositoryProvider.searchPois`）→ 選結果 → `addEntryAlternate(poi)`。
  - **per-POI**：對 master（或選定 POI）編輯 備註（note）、分類（poi_type，8 白名單 chips）、訂位（reservation）→ `updateEntryPoi`（debounce/儲存鈕）。
- 路由：go_router 在 `/trips/:tripId/:entryId... ` 不適合（既有 :tripId 下是 timeline）。改在 timeline 之外加 `/trips/:tripId/entries/:eid/pois`，或從 edit sheet 用 `Navigator.push(MaterialPageRoute(EntryPoiScreen))`。**採 go_router 子路由** `trips/:tripId` → `entries/:eid/pois`（pathParam）。
- 入口：A+B 的 `EntryEditSheet` 加「管理地點 ▸」按鈕 → `context.push('/trips/$tripId/entries/${entry.id}/pois')`（編輯 sheet 先 pop）。
- OCC 409：任一 POI op 撞 STALE_ENTRY → invalidate entryDetail（載回最新 entryPoisVersion）+ snackbar「地點已更新,已重新載入」。

## 階段 E：交通編輯

- `tripSegmentsProvider = FutureProvider.family<List<TripSegment>, String tripId>` → `fetchSegments`。
- `_DaySection` watch segments（或在 `_TravelRow` 接收已比對的 segment）。比對：travel pill 顯示於 entry[i] 前，對應 segment = `seg.fromEntryId == timeline[i-1].id && seg.toEntryId == timeline[i].id`（用兩端 id，避免 from/to 慣例歧義）。
- travel pill 加 onTap → bottom sheet：mode 三選一（開車/步行/大眾運輸）；選大眾運輸顯示分鐘輸入（必填 0–1440）。送出 `updateSegment(segmentId, mode, min, expectedVersion: seg.version)` → invalidate days + segments。
- 找不到對應 segment（資料未同步）→ pill 不可點（onTap null）。
- OCC 409 → invalidate segments + snackbar「交通已更新,已重新載入」。

---

## 錯誤處理（統一）
| 情境 | 行為 |
|---|---|
| 成功 mutation | invalidate 對應 provider + snackbar |
| OCC 409（D entryPoisVersion / E expectedVersion） | invalidate（載回最新 token）+ snackbar「已更新，已重新載入」 |
| 其他錯誤 | snackbar「操作失敗，請稍後再試」，UI 不破壞 |
| C reorder/move 失敗 | invalidate 重抓還原順序 + snackbar |

---

## 測試（TDD，逐階段）

- **階段 0**（`test/api/trip_repository_test.dart` 擴 + `test/models/segment_test.dart`、entry_test 擴）：每個新 repository 方法的 path/case/OCC（含 batch snake、alternates camel+find-or-create type、DELETE query token、per-POI 無 OCC、segment PATCH expectedVersion 409）；TripSegment.fromJson；TimelineEntry.entryPoisVersion / EntryPoiInfo.reservation 解析。
- **階段 C**（`trip_timeline_screen_test` 擴）：拖曳觸發 `reorderEntries`（用 `ReorderableDragStartListener` + drag）；「移到其他天」action 呼叫 reorderEntries 帶 day_id；既有 tap/swipe 測試保持綠。
- **階段 D**（`test/features/trip_detail/entry_poi_screen_test.dart` 新）：載入顯示 master/alternates；設正選→setEntryMaster；刪備選→removeEntryAlternate；加備選（mock search）→addEntryAlternate；per-POI 存→updateEntryPoi；OCC token 帶入。
- **階段 E**（segment widget/repo 測試）：travel pill 點擊開 sheet；選 transit 填分鐘送出 updateSegment；driving 送出不帶 min；找不到 segment → pill 不可點。

**完成定義**：每階段 `flutter analyze` 0 + `flutter test` 全綠；全部完成後整體再跑一次。

---

## 風險 / 注意
- **疊在 PR #7**：本分支自 `feat/timeline-entry-edit-delete-add` 分出。若 #7 先 merge master，本 PR base 設 master（diff 乾淨）；若未 merge，base 設該分支（stacked）。開 PR 時依狀態決定。
- **ReorderableListView 巢狀於 scroll**：需 `shrinkWrap + NeverScrollableScrollPhysics`；drag handle 用 `ReorderableDragStartListener` 避免與 tap/swipe 衝突。
- **E segment 比對**：以兩端 entry id 比對，避免 from/to 慣例不確定；smoke 驗證。
- **兩套 OCC**：D 用 `entryPoisVersion`(string)、E 用 `expectedVersion`(number)，勿混。
- **D POI 搜尋複用**：`poiRepositoryProvider`（探索已建）可直接 reuse。
- **repository 肥大**：階段 0 後評估抽 `EntryMutationRepository`。
- **smoke 對 prod 測試帳號**：reorder/POI/交通皆改真實資料；smoke 由使用者授權後再跑（自建自刪清乾淨）。
