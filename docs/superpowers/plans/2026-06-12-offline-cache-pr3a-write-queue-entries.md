# PR-3a 離線寫佇列框架 + entry 樂觀 patch — 實作 plan

> 總綱 spec §3-4、§7(PR-3)。本 PR 建「佇列 + 樂觀 patcher」框架,先在 entries(add/update/delete)證明;notes/segments/reorder 屬 PR-3b。同步/flush 屬 PR-4。

**Goal:** 離線時 entry 的新增/編輯/刪除 → 入持久化佇列 + 樂觀 patch 快取 → UI 立即反映且重啟後仍在。維持核心不變式(快取 = server 真相 + 未 flush 的 patch)。

**核心流程:**
```
repo.addEntryToDay/updateEntry/deleteEntry → ApiClient.sendMutation(method, path, body, optimistic: OfflineOp)
  線上 → _send()(成功即 evict,與現狀同)
  離線(connectionError)且有 optimistic+cacheStore → appendMutation(持久化)+ 對 op.cacheKey 套 patcher 寫回快取 → 回 null(樂觀成功)
  其餘 → rethrow
getStream(讀)→ yield 快取 → yield get();fresh 到達時先 applyPendingPatches(該 key 的待 flush patch)再寫回/yield → 不變式
```

## File Structure
- Modify `lib/api/cache/cache_store.dart` — `QueuedMutation` envelope + 佇列方法(readQueue/appendMutation/removeMutation);InMemory 實作。
- Modify `lib/api/cache/sembast_cache_store.dart` — 佇列方法(intMapStore,auto-inc key 保序)。
- Create `lib/api/cache/offline_op.dart` — `OfflineOp{type,cacheKey,args}`。
- Create `lib/api/cache/optimistic_patchers.dart` — 純函式 patcher registry + `applyOptimisticPatch` + entry.add/update/delete。
- Modify `lib/api/api_client.dart` — `sendMutation`、getStream 接 `applyPendingPatches`。
- Modify `lib/api/trip_repository.dart` — addEntryToDay/updateEntry/deleteEntry 改走 sendMutation + 帶 OfflineOp。
- Tests:`cache_store`(佇列)、`optimistic_patchers`(各 patcher edge case)、`api_client`(sendMutation 線上/離線、getStream applyPendingPatches)。

## Task 1: CacheStore 佇列(TDD)
- [ ] `QueuedMutation{id,method,path,query,body,type,cacheKey,args,createdAt}` + toMap/fromMap。
- [ ] CacheStore 介面加 `readQueue()/appendMutation(m)/removeMutation(id)`;InMemory 用 List 保序。
- [ ] 測試:append→read 保序、removeMutation、clear 一併清佇列。

## Task 2: OfflineOp + 樂觀 patcher(TDD,純函式)
- [ ] `OfflineOp{String type, String cacheKey, Map<String,dynamic> args}`。
- [ ] `applyOptimisticPatch(type, cached, args)`:registry 查不到 → 回 cached 原值。
- [ ] entry patchers(操作 `GET /trips/:id/days?all=1` 的 `List<day>`,各 day 有 `dayNum`+`timeline`):
  - `entry.add`:找 dayNum 的 day,timeline 末端插入新 entry(臨時負 id、title/desc/time、master 由 lat/lng/poiType 選擇性建、alternates:[]、version:0)。**回新結構不就地改**(改動的 day/timeline 重建,其餘 day 共用 ref)。
  - `entry.update`:跨 day 找 entryId,merge 欄位(title/desc/startTime/endTime)。
  - `entry.delete`:跨 day 移除 entryId。
  - base 為 null(未快取)→ 回 null(無從 patch,mutation 仍入佇列待 PR-4 flush)。
- [ ] 測試:add 插入正確 day、update 改對 entry、delete 移除、null base、找不到 dayNum/entryId 時不爆。

## Task 3: ApiClient sendMutation + getStream 不變式(TDD)
- [ ] `Future<dynamic> sendMutation(method, path, {body, query, OfflineOp? optimistic})`:
  - try `_send(...)`(線上,含 evict);
  - on DioException:`optimistic!=null && _cacheStore!=null && _isOfflineError(e)` → appendMutation + 讀 op.cacheKey 現值 → applyOptimisticPatch → 寫回 → 回 null;否則 rethrow。
- [ ] getStream 改:fresh 到達後 `final patched = await _applyPendingPatches(key, fresh); writeResponse(key, patched); yield patched;`(`_applyPendingPatches`:讀佇列、filter cacheKey==key、依序套 patcher)。
- [ ] id 產生:`'${DateTime.now().microsecondsSinceEpoch}-${_counter++}'`。
- [ ] 測試:
  - sendMutation 線上成功 → 呼叫 _send、未入佇列。
  - sendMutation 離線 + optimistic → 入佇列 + 快取被 patch(讀 cacheKey 反映)+ 回 null 不丟。
  - sendMutation 離線 + optimistic=null → rethrow。
  - getStream:佇列有該 key 的 pending patch → fresh 到達後 yield 的是 server+patch(不變式)。

## Task 4: 接線 entry repo 方法
- [ ] addEntryToDay/updateEntry/deleteEntry 改 `return _client.sendMutation('POST'|'PATCH'|'DELETE', path, body:..., optimistic: OfflineOp('entry.xxx', daysKey, {...}))`。daysKey = `cacheKeyFor('GET','/trips/<enc>/days',{'all':'1'})`。
- [ ] 線上行為不變(sendMutation 線上 == 原 post/patch/delete 經 _send);既有 trip_repository_test 應仍綠。

## Task 5: 驗收
- [ ] `flutter analyze` 0;`flutter test` 全綠。
- [ ] format、commit、PR、review、merge。

## Self-Review
- patcher 純函式 → 易測、是最高風險處的隔離。
- sendMutation 線上重用 _send → 線上零行為變更。
- 不變式靠 getStream 的 applyPendingPatches:離線 patch 的編輯在重連 refetch(尚未 flush)後仍可見。
- 臨時 id 為負數;PR-4 flush 成功後 evict+refetch 以 server id 取代。
