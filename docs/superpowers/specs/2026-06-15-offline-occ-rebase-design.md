# 離線寫 OCC 409 三方 merge rebase — 設計

> 來源:offline-cache 可選後續 PR-4b 的「OCC rebase」部分。
> 前置:離線快取主體(PR #18~#24)已完成。本設計只動 flush 衝突處理 + 新增衝突解決 UI。

## 問題

目前 `ApiClient.flushQueue`(`lib/api/api_client.dart:186`)重連重播離線佇列時,對 HTTP 4xx(含 409 `STALE_ENTRY`)一律「上報 + 從佇列移除」。

`entry.update` / `note.update` 帶 `expectedVersion`(OCC token)。離線編輯期間若他人改過同一筆,server version 前進,重播 PATCH 帶舊 `expectedVersion` → 409 `STALE_ENTRY` → **離線編輯被直接丟棄**。這是唯一有資料遺失風險的離線缺口。

## 目標

flush 遇 `STALE_ENTRY` 時自動 rebase 到 server 最新版本;只有「同一欄位離線與 server 都改了」的真衝突才中斷,交由使用者整筆二選一解決。其餘情況靜默套用,不丟失離線編輯。

## 範圍

| 類型 | 帶 expectedVersion | 走 sendMutation(離線佇列) | 納入 rebase |
|---|---|---|---|
| `entry.update` | ✅ | ✅ | **是** |
| `note.update` | ✅ | ✅ | **是** |
| `entry.add` / `note.create` | ❌ | ✅ | 否(無 version;其 409 是時段衝突 `conflictWith`,維持上報) |
| `entry.delete` / `note.delete` | ❌ | ✅ | 否(無 version) |
| `updateSegment` | ✅ | ❌(用 `_client.patch`,無佇列) | 否(離線寫本就未支援) |

**觸發條件**:`e.status == 409 && e.code == 'STALE_ENTRY'` 且 `m.type ∈ {entry.update, note.update}`。其他 409 / 5xx / 401 / 403 / 連線錯誤維持現有 `flushQueue` 邏輯不變。

## 核心洞察(簡化實作)

後端 PATCH 是 **diff-only**(body 只含有改的欄位)。因此:

1. **重送 body 永遠是「原始離線欄位 + 新 expectedVersion」**(全 ours)。無衝突欄位 server 沒動(套 ours 安全);使用者選「你的」時衝突欄位本就要覆蓋。重送內容不變,只換 version。
2. 三方 merge 純函式因此**只需判斷「有無真衝突 + 哪些欄位衝突」**(供 UI 顯示),不需重組 merged body。
3. 三方比對只看 **ours 的欄位集合**(離線實際改的欄位);server 改了「離線沒碰的欄位」由 diff-only 天然保留,不算衝突。

## 資料流

```
入佇列(sendMutation,entry.update / note.update):
  從 op.cacheKey 快取讀該 entry/note 當下 row
  → 擷取 ours 各欄位的「離線當下值」存進 QueuedMutation.base
  (資源未快取 → base = null,降級為 last-write-wins)

flush 遇 STALE_ENTRY:
  ① 重抓 server → theirs(各欄位新值) + newVersion
       entry: 解析 tripId → GET /trips/:id/days?all=1 整包 → 依 entryId 跨 day 找 timeline row
       note : 解析 tripId → GET /trips/:id/notes 整包 → 依 sectionKey/rowId 找 row
       (theirs 與 base/樂觀 patch 同源最一致;重抓順便刷新該快取;連線錯誤 → break 保留佇列)
  ② conflictFields = rebaseMerge(base, ours, theirs)
  ③ conflictFields 空 → 重送原 body(expectedVersion=newVersion)
       成功 → removeMutation, synced++
       再 409(罕見 race)→ break 保留待下次
  ④ conflictFields 非空 → appendConflict(record);removeMutation(移出主佇列);conflicts++
```

## 三方 merge 純函式(新 `lib/api/cache/rebase_merge.dart`)

```
List<String> rebaseMerge(
  Map<String,dynamic>? base,   // 離線當下值;null → 視為「server 沒動」全採 ours
  Map<String,dynamic> ours,    // 離線改成的值(camelCase 欄位)
  Map<String,dynamic> theirs,  // server 最新值(camelCase 欄位)
)
```

逐 `f in ours.keys`:
- `base == null` → 跳過(降級 last-write-wins,無衝突)
- `theirs[f] == base[f]` → server 沒動 → 安全採 ours,**非**衝突
- `ours[f] == theirs[f]` → 剛好同值 → 非衝突
- 否則(base/ours/theirs 三方不同)→ **衝突欄位**

回傳 `conflictFields`(空 = 可自動 rebase)。純函式、可獨立測,對齊 `optimistic_patchers` 慣例。

**欄位命名統一在 camelCase**:
- `entry.update` 的 args 已是 camelCase(`title`/`description`/`startTime`/`endTime`),wire 同名,直接比對。
- `note.update` 的 args.fields 是 snake_case(request),比對前用 `_snakeToCamel` 轉成 camelCase,對齊 wire 的 theirs/base。

## 資料結構改動

### `QueuedMutation`(`lib/api/cache/offline_op.dart` 對應的佇列模型)
新增 `final Map<String,dynamic>? base;`(被改欄位的離線當下值)。Sembast 持久化序列化加上 `base`。讀取舊資料缺 `base` → `null`(降級,不崩)。

### Conflict store(決策 1A — 獨立衝突區)
`CacheStore` 新增衝突區操作(沿用 queue 的 Sembast intMapStore 模式):
- `Future<List<ConflictRecord>> readConflicts()`
- `Future<void> appendConflict(ConflictRecord)`
- `Future<void> removeConflict(String id)`
- `changes` 事件涵蓋 conflict 變更(讓 banner reactive 刷新,沿用 PR #24 機制)

`ConflictRecord`(新 model):
- `id`、`type`、`path`、`body`(原始離線 body)、`args`、`cacheKey`
- `theirs: Map<String,dynamic>`(server 最新值快照,供 UI「對方版本」)
- `ours: Map<String,dynamic>`(離線值,供 UI「你的版本」)
- `newVersion: int`(重抓到的 server version,選「你的」重送時用)
- `conflictFields: List<String>`(highlight 用)
- `createdAt`

### `FlushResult`
`conflicts` 既有欄位語意不變(仍回上報筆數);衝突明細改由 conflict store 持有,UI 讀 store。

## flush 整合(`flushQueue` 改動)

`catch (ApiError e)` 分支:
```
if (e.status == 409 && e.code == 'STALE_ENTRY' && _rebasable(m.type)) {
  final rebased = await _tryRebase(m);   // 重抓 + merge + (無衝突)重送
  switch (rebased) {
    case _RebaseSynced():   removeMutation(m.id); synced++;
    case _RebaseConflict(): appendConflict(...); removeMutation(m.id); conflicts.add(m);
    case _RebaseOffline():  return ...;   // 重抓時離線 → break 保留
    case _RebaseRetryLater():return ...;  // 重送再 409 → break 保留
  }
} else if (e.status >= 500 || e.status == 401 || e.status == 403) {
  break;                                  // 現有:暫時失敗保留
} else {
  conflicts.add(m); removeMutation(m.id); // 現有:其他 4xx 上報+drop
}
```

`_tryRebase` 重抓細節(`tripId` 由 `m.path` 以 `/trips/([^/]+)/` 解析):
- entry:`get('/trips/:tripId/days', query:{all:1})` → 依 `args.entryId` 跨 day 找 timeline row → 取 `title/description/startTime/endTime` + `version`
- note :`get('/trips/:tripId/notes')` → 依 `args.sectionKey`(已映射的 response 段名)+ `args.rowId` 找 row → 取對應欄位 + `version`

## 衝突解決 UI(決策 2B — Banner 點開 bottom sheet)

- 新 provider `syncConflictRecordsProvider`(StreamProvider,讀 conflict store + `CacheStore.changes` 反應式刷新),沿用 `lib/features/offline/offline_sync.dart` 既有 provider 風格。
- `OfflineStatusBanner`(`lib/features/offline/`)衝突態文案改「N 筆同步衝突 ・檢視」,點擊 → `showModalBottomSheet`。
- bottom sheet 逐筆呈現:
  - 標題(entry 標題 / note 摘要)
  - 衝突欄位並排「你的版本 / 對方版本」(`conflictFields` highlight,欄位名 → 人話標籤)
  - 兩顆鈕:
    - **保留你的** → `ApiClient.resolveConflictKeepOurs(record)`:重送原 body(expectedVersion=newVersion)→ 成功 `removeConflict`
    - **用對方的** → `ApiClient.resolveConflictKeepTheirs(record)`:`removeConflict`(丟棄離線改動)
  - 解一筆移除一筆;清空關閉 sheet。
- 解決後 invalidate trip 家族(畫面更新),沿用 `OfflineSyncController` 既有 invalidate。

## 測試(TDD)

**`test/api/rebase_merge_test.dart`(純函式)**
- server 沒動該欄(theirs==base)→ 無衝突
- 離線與 server 同值(ours==theirs)→ 無衝突
- 三方不同 → 衝突
- 多欄位混合(部分衝突)→ 只回衝突欄位
- base==null → 無衝突(降級)
- note snake↔camel 對齊

**`test/api/api_client_test.dart` / `trip_repository_test.dart`**
- flush STALE_ENTRY 無衝突 → 重抓 + 重送(verify 帶新 expectedVersion)+ removeMutation + synced
- flush STALE_ENTRY 有衝突 → appendConflict、不重送、移出主佇列、上報
- 重抓時連線錯誤 → break 保留佇列
- 重送再 409 → break 保留
- 非 STALE 的 409(時段衝突)→ 維持上報+drop(回歸)
- `resolveConflictKeepOurs` → 重送帶 newVersion + removeConflict
- `resolveConflictKeepTheirs` → 僅 removeConflict
- 入佇列時擷取 base(entry/note)

**widget**
- banner 顯示衝突數 + 點開 bottom sheet
- 二選一 → 正確呼叫 resolve、清單更新

## 邊界 / gotcha

- **base 缺失**(舊佇列升級 / 入佇列時資源未快取)→ `rebaseMerge` 回無衝突 → 降級為「重抓 version 直接重送」(last-write-wins),不崩。
- **note 段名**:`args.sectionKey` 已是 response 段名(`pretripNotes`/`emergencyContacts`…,PR #22 的映射),重抓找 row 直接用它。
- **重送再 409**:不無限重試;break 保留待下次 flush 再 rebase。
- **跨帳號清理**:conflict store 與 queue 一樣納入登出 / 換帳號清理(沿用 PR #24 `__cache_owner__` owner-check)。
- **delete 不涉及**:無 version,不會 STALE_ENTRY。
- **entry 重抓 version**:用 days timeline row 的 entry meta `version`(對齊 `updateEntry` 的 `expectedVersion` 語意),非 `entryPoisVersion`。

## 不在範圍(維持現狀)

- segments / reorder 離線寫(前置未做)。
- flush 與 getStream 並發 writeback 互斥、sync invalidate per-tripId(PR-4b 其餘項,獨立處理)。
- device-offline 橫幅(需 connectivity_plus)。
