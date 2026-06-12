# 離線快取(Offline Cache)設計 spec

> 狀態:設計定稿待 review。範圍涵蓋**讀取快取(SWR)+ 離線寫入(mutation queue + 同步 + 衝突)**完整離線能力。交付切成 4 個 PR。

## 1. 動機與目標

trip-planner 是旅遊 app,殺手情境是「人在國外、弱網或離線,要看自己的行程(哪天、幾點、去哪)」。因此離線能力的價值排序:

1. **離線讀**(最高價值、最低風險):看過的行程/天/筆記/地圖/最愛,離線仍能瀏覽。
2. **離線寫**(高價值、高複雜度):離線時編輯行程,連線後同步。

使用者決策(2026-06-12):範圍 = 讀 + 寫一起做;線上讀取策略 = Stale-while-revalidate。

### 目標

- 看過的 GET 資料在離線/弱網時可讀。
- 線上讀取走 SWR:先秒開本機舊資料,背景刷新後更新畫面。
- 離線時可編輯**核心行程內容**(timeline entries、5 區 notes、segments),編輯立即反映於 UI 且**重啟後仍在**。
- 重連後自動把離線編輯依序同步回後端,處理 OCC 409 衝突。

### 非目標(YAGNI / 列未來)

- 離線建立/刪除「整個 trip」、collab 邀請、share 連結(本質需要網路,不納入離線寫)。
- 完整衝突 merge UI(v1 衝突 = 重抓 rebase 重試一次,再不行上報並 drop)。
- `connectivity_plus` 主動連線偵測(v1 用 DioException 推斷 + app-resume/手動觸發)。
- POI 搜尋、AI chat requests 的離線(即時性查詢,離線無意義)。
- 後端不動(共用既有 API,本 spec 純 client 端)。

## 2. 既有資料層約束(設計依據)

- **41 個 model 中 39 個沒有 `toJson`** → 不在 model/repository 層做序列化,改在 **ApiClient 層快取原始 wire JSON**(Map/List),repositories/providers/models 對「儲存」零改動。
- **`ApiClient._send()` 是所有 request 單一入口** → 快取與離線判斷集中在此。
- **OCC 已備**:Trip/Day/Entry/Segment/Notes 都帶 `version`;PATCH 帶 `expectedVersion`,409 回 `STALE_ENTRY`。
- **持久化只有 flutter_secure_storage**(放密鑰,不適合快取 blob)→ 新增 sembast。
- **Provider 鏈 override 友善**:`sessionStore → apiClient → repositories → authState`,測試以 override list 替換。

## 3. 架構總覽

```
讀 (SWR):
  StreamProvider.family  →  Repository.watchX()  →  ApiClient.getStream(path, query)
                                                       1. 讀 CacheStore[key]，有就 yield(stale)
                                                       2. _send('GET') 抓網路
                                                          成功 → 套 pending patches → 寫 CacheStore → yield(fresh)
                                                          失敗(離線)→ 若已 yield stale 則吞掉；無 stale 則 rethrow

寫:
  Controller  →  ApiClient.sendMutation(method, path, body, query, optimistic)
                   線上 → _send() 直送 → 成功後 evict 相關 cache key → (provider invalidate 重新 SWR)
                   離線 → MutationQueue.enqueue() + 對相關 cache key 套樂觀 patch → invalidate provider(UI 立即更新)

同步 (重連 / app-resume / 手動重試):
  SyncEngine.flush()
    依序取 queue → _send() 重播
      成功 → 從 queue 移除 → evict/refresh 相關 cache key
      409 STALE → 重抓資源 → rebase expectedVersion → 重試一次
                  仍失敗 / 資源已不存在 → 標記 conflict、移出 queue、上報
      網路再次失敗 → 停止 flush(下次再試)
```

### 核心不變式

> **任一 cache key 的值 = 最新 server 真相,套用所有「尚未 flush 成功」的樂觀 patch。**

維持時機:(a) mutation 入隊時 patch、(b) flush 成功移除 mutation 後重算、(c) getStream 收到新 server 資料時先套 pending patch 再寫入。這保證離線編輯在「重啟」「背景刷新成功但尚未 flush」等狀況下都不會消失,直到該 mutation 真正同步完成。

## 4. 元件設計

### 4.1 `CacheStore`(持久化抽象)

檔案:`lib/api/cache/cache_store.dart`

```dart
/// 離線快取的鍵值持久化抽象（沿用 SessionStore/SettingsStore 慣例）。
abstract class CacheStore {
  // 回應快取
  Future<Map<String, dynamic>?> readResponse(String key);   // {data, cachedAt}
  Future<void> writeResponse(String key, Object? data, String cachedAt);
  Future<void> evictResponse(String key);
  Future<void> evictByPrefix(String pathPrefix);            // 依路徑前綴批次失效

  // mutation 佇列
  Future<List<Map<String, dynamic>>> readQueue();           // 依 seq 排序
  Future<void> appendMutation(Map<String, dynamic> m);
  Future<void> removeMutation(String id);
  Future<void> updateMutation(String id, Map<String, dynamic> patch);

  Future<void> clear();                                     // 登出時清空
}
```

實作:
- `SembastCacheStore`(`lib/api/cache/sembast_cache_store.dart`)— 兩個 store:`response_cache`(key→{data,cachedAt})、`mutation_queue`(自增 seq→envelope)。DB 檔放 app documents dir,目錄由 `path_provider` 的 `getApplicationDocumentsDirectory()` 取得(在 `main()` 開好 DB 後注入,override `cacheStoreProvider`)。
- `InMemoryCacheStore`(同檔或 `_inmemory.dart`)— 測試用純 `Map`(沿用 `InMemorySessionStore` 慣例),不碰 sembast/IO/path_provider。

新增依賴:`sembast`(純 Dart 持久化)+ `path_provider`(取 app 可寫目錄;官方 plugin,測試走 InMemory 不觸及)。

> 登出時 `CacheStore.clear()`,避免帳號間資料外洩。

### 4.2 cache key 規則

```
key = "GET " + path + (query 為空 ? "" : "?" + 依 key 排序後序列化的 query)
```

- 只快取 GET。
- query 需正規化(key 排序),確保同義請求命中同一格。

### 4.3 失效對照表(mutation path → 受影響 GET key 前綴)

mutation 成功(線上直送或 flush)後,依路徑前綴 evict:

| mutation 路徑樣式 | evict 的 GET key 前綴 |
|---|---|
| `/trips/:id/entries…`、`/trips/:id/days…` | `GET /trips/:id/days`、`GET /trips/:id/segments`、`GET /trips/:id/entries` |
| `/trips/:id/notes…` | `GET /trips/:id/notes` |
| `/trips/:id/segments…`、`/trips/:id/recompute-travel` | `GET /trips/:id/segments`、`GET /trips/:id/days` |
| `/trips`、`/trips/:id`(create/update/delete) | `GET /my-trips`、`GET /trips/:id`、`GET /trips` |
| `/poi-favorites…` | `GET /poi-favorites` |
| `/poi-favorites/:id/add-to-trip` | `GET /trips/:tripId/days` |

evict 後 provider invalidate → SWR 重抓 fresh(線上),不會用到剛失效的舊格。

### 4.4 `ApiClient` 擴充

- 注入 `CacheStore?`(null = 不啟用快取,維持現狀;測試與漸進導入友善)。
- 既有 `get/post/put/patch/delete` 行為不變(內部 `_send`)。
- 新增:
  - `Stream<dynamic> getStream(String path, {query})` — SWR(見 §3 讀流程)。
  - `Future<dynamic> sendMutation(method, path, {body, query, OfflineOp? optimistic})` — 寫(見 §3 寫流程)。線上等同直送 + 成功後 evict;`optimistic == null`(不支援離線的 mutation)時,離線直接 throw(維持現狀,不入隊)。
- 「離線」判定:`DioException` 且 `type ∈ {connectionError, connectionTimeout, sendTimeout, receiveTimeout}` 或無回應。HTTP 4xx/5xx **不算離線**(那是 server 有回應)。

### 4.5 `MutationQueue` envelope

```dart
PendingMutation {
  String id;             // 本機產生：'${micros}-${counter}'
  int seq;               // 入隊序，flush 依此排序
  String method;         // POST/PUT/PATCH/DELETE
  String path;
  Map<String,dynamic>? query;
  Object? body;
  String createdAt;      // ISO8601
  String opType;         // 'entry.add' | 'entry.update' | 'note.delete' | ... 對應一個樂觀 patcher
  Map<String,dynamic> opArgs; // patcher 所需參數（如 tripId, dayNum, 臨時 id, 欄位…）
  int attempts;          // flush 重試計數
}
```

### 4.6 樂觀 patcher(離線寫入可見性的核心)

檔案:`lib/api/cache/optimistic_patchers.dart`

每個支援的離線操作對應一個純函式:`(cachedJson, opArgs) → patchedJson`。涵蓋:

- `entry.add` / `entry.update` / `entry.delete` / `entry.reorder` → patch `GET /trips/:id/days` 內對應 day 的 entries。
- `note.create` / `note.update` / `note.delete` / `note.reorder` → patch `GET /trips/:id/notes` 對應 section。
- `segment.update` → patch `GET /trips/:id/segments`。

要點:
- 新增類(add/create)用**本機臨時 id**(負數或 `tmp-` 前綴),flush 成功後以 server 回應替換(透過 evict + refetch)。
- patcher 是純函式 → 易測;在「入隊」與「getStream 收到新 server 資料」兩處重用(維持核心不變式)。
- `applyPendingPatches(key, baseJson, queue)`:對某 key 依序套用 queue 中所有 opType 命中該 key 的 patcher。

### 4.7 `SyncEngine`

檔案:`lib/api/cache/sync_engine.dart`(或併入一個 `OfflineController` riverpod Notifier)

- `flush()`:依 seq 取 queue,逐筆 `_send` 重播。
  - 成功 → `removeMutation` → 依失效表 evict → 受影響 provider invalidate。
  - 409 → 依 opArgs 重抓資源、rebase `expectedVersion`、重試一次;再失敗或資源已不存在 → 標記 conflict 後移出 queue,記錄到「衝突清單」provider 供 UI 上報。
  - 連線錯誤 → 中止本輪 flush(保留 queue,下次觸發再試)。
- 觸發點:app `resumed`(WidgetsBindingObserver / AppLifecycleListener)、任一 GET 成功後(opportunistic)、UI 手動「立即重試」。
- 暴露 `offlineQueueProvider`(待同步筆數)、`syncConflictsProvider`(衝突清單)供 UI。

## 5. Provider / 畫面改動

- 讀取 providers 由 `FutureProvider.family` → `StreamProvider.family`,內部改呼叫 `repository.watchX()`(回 `Stream`)。受影響:`tripDetailProvider`、`tripDaysProvider`、`tripNotesProvider`、`tripSegmentsProvider`、`entryDetailProvider`、my-trips、favorites。
- 畫面對 `AsyncValue` 的消費**幾乎不變**(StreamProvider 也給 `AsyncValue`);差別是會收到兩次 data(stale→fresh),Flutter rebuild 自然處理。
- 寫入 controllers:呼叫端從 `repository.mutate()` 改為經 `ApiClient.sendMutation(..., optimistic: op)`;離線時不再 throw,而是樂觀更新 + 入隊。

## 6. 測試策略(三層鏡像 lib/)

- **cache 單元**:cache key 正規化、失效前綴、樂觀 patcher 純函式(各 opType 的 add/update/delete/reorder edge case)、`applyPendingPatches` 疊套順序、核心不變式。
- **api**:用 `http_mock_adapter` + `InMemoryCacheStore`。
  - `getStream` SWR:無快取(只 emit fresh)、有快取(emit stale→fresh)、離線有快取(只 emit stale 不報錯)、離線無快取(報錯)。
  - `sendMutation`:線上成功 evict;離線入隊 + patch;不支援離線的 mutation 離線時 throw。
  - `SyncEngine.flush`:依序重播、409 rebase 重試、連線錯誤中止、衝突上報。
- **screens**:既有 widget test 以 `StreamProvider` override(回 `Stream.value`)替代 `FutureProvider` override;新增離線橫幅/待同步標示測試。

## 7. PR 拆解

> 細化原則:離線「讀」可在 `ApiClient.get()` 做透明 write-through + 失敗回退,**不需動 providers**;SWR(emit stale→fresh)需把 provider 改 StreamProvider,波及測試,獨立成一個 PR 較易 review。故將原 PR-1 拆為「透明讀(PR-1)」與「SWR(PR-2)」。

1. **PR-1 透明離線讀**:`CacheStore`(response 方法 + clear)+`SembastCacheStore`+`InMemoryCacheStore`、cache key 正規化、失效前綴對照(純函式)、`ApiClient` 注入 `CacheStore`、GET write-through + 網路失敗回退快取、mutation 成功後 evict、登出清快取、`main()` 開 sembast DB 並 override。**零 provider/screen 改動**。**驗收**:離線可讀已快取資料;既有測試全綠;`flutter analyze` 0。
2. **PR-2 SWR(stale→fresh)**:`ApiClient.getStream`、repository 新增 `watchX()` Stream 方法、讀取 providers(tripDetail/tripDays/tripNotes/tripSegments/entryDetail/myTrips/favorites)由 `FutureProvider` 改 `StreamProvider`、更新對應 widget test overrides、pull-to-refresh 配合。**驗收**:線上先 stale 後 fresh;畫面消費 `AsyncValue` 行為一致。
3. **PR-3 寫入佇列(離線寫可見)**:`MutationQueue` envelope + sembast 持久化、`ApiClient.sendMutation` 離線入隊、樂觀 patcher 集合(entries/notes/segments)、`applyPendingPatches` 接入 getStream、核心不變式。**驗收**:離線編輯立即反映且重啟後仍在。
4. **PR-4 同步與衝突**:`SyncEngine.flush`、OCC 409 rebase 重試、衝突上報 provider、app-resume/opportunistic/手動觸發。**驗收**:重連後自動同步;模擬 409 走 rebase 路徑;衝突進清單。
5. **PR-5 離線 UI affordance**:離線橫幅、stale/pending 標示、待同步筆數、衝突提示與「立即重試」。**驗收**:UI 正確反映連線/同步狀態。

每個 PR 各自 plan → TDD 實作 → review → PR,沿用既有流程。本 spec 為總綱。

## 8. 風險與緩解

- **SWR 改 StreamProvider 波及面**:逐 provider 改 + widget test 同步調整;StreamProvider 同樣回 `AsyncValue`,畫面改動小。
- **樂觀 patcher 與 server 真相分歧**:核心不變式 + flush 成功後 evict+refetch 以 server 為準收斂;patcher 僅需「夠好的暫態呈現」。
- **sembast 體積/效能**:本 app 資料量小(數個 trip),純 Dart 無 native channel,且測試可用 in-memory factory。
- **快取跨帳號外洩**:登出 `CacheStore.clear()`。
- **臨時 id 與 server id 對接**:新增類 flush 成功後一律 evict 該 key + refetch,讓 server id 取代臨時 id,不在本機做 id 對映表(YAGNI)。
