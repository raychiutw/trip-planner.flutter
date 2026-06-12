# PR-4 同步引擎(重連 flush + 衝突上報) — 實作 plan

> 總綱 spec §4.7、§7(PR-4)。讓 PR-3a 入佇列的離線寫入在重連後真正同步(目前佇列只進不出)。

**Goal:** 重連/app-resume/手動觸發時依序重播佇列 → 成功移除 + evict(server 真相取代樂觀 patch);連線錯誤中止(保留佇列);HTTP 錯誤(含 409)上報衝突 + 移除(v1 不 rebase,列 PR-4b)。

## File Structure
- Modify `lib/api/api_client.dart` — `FlushResult` + `Future<FlushResult> flushQueue()`(+ 再進入 guard)。
- Create `lib/features/offline/offline_sync.dart` — `offlinePendingCountProvider`(待同步筆數)、`syncConflictsProvider`(StateProvider 衝突清單)、`OfflineSyncController`(sync():flush → 設 conflicts/count → invalidate 讀取 providers)。
- Modify `lib/main.dart`(或 root widget)— `AppLifecycleListener` resume → 觸發 sync。
- Tests:`flush_queue_test`(data 層核心)、`offline_sync_test`(controller/providers)。

## Task 1: flushQueue（TDD,data 層核心）
- [ ] `FlushResult{int synced, List<QueuedMutation> conflicts}` + `empty`。
- [ ] `flushQueue()`:cacheStore null → empty;readQueue 依序:
  - `_send(m.method, m.path, body:m.body, query:m.query)` 成功 → `removeMutation(m.id)`(_send 已 evict 受影響快取)、synced++。
  - `on ApiError`(server 拒絕,含 409)→ conflicts.add + removeMutation(v1 drop)。
  - `on DioException` 且 `_isOfflineError` → break(仍離線,保留剩餘);其餘 rethrow。
  - 再進入 guard(`_flushing`)。
- [ ] 測試:全成功移除、成功後 evict days、409 上報+移除+續跑、中途離線停且保留、空佇列。

## Task 2: riverpod 層
- [ ] `offlinePendingCountProvider = FutureProvider((ref) => readQueue().length)`。
- [ ] `syncConflictsProvider`(暫存最後一次 flush 的 conflicts)。
- [ ] `OfflineSyncController.sync()`:呼叫 `apiClient.flushQueue()` → 更新 conflicts/count → 對受影響 trip 的讀取 providers `invalidate`(讓 server 真相上畫面)。重入保護。
- [ ] 測試:flush 後 count 歸零、衝突進 provider。

## Task 3: 觸發
- [ ] root widget 加 `AppLifecycleListener(onResume: () => ref.read(offlineSyncControllerProvider.notifier).sync())`。
- [ ] (opportunistic/手動「立即重試」按鈕屬 PR-5 UI。)

## Task 4: 驗收
- [ ] `flutter analyze` 0;`flutter test` 全綠。format、commit、PR、review、merge。

## Self-Review
- flush 重用 _send → 重播自動帶 auth/Origin/evict;成功後 removeMutation + _send 的 evict 共同確保「pending patch 被 server 真相取代」。
- 連線錯誤 break 保留佇列 → 部分同步可續;HTTP 錯誤 drop+上報避免卡死佇列。
- OCC rebase(409 重抓 rebase 重試)複雜,v1 先上報+drop,列 PR-4b。
