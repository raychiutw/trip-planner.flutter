# PR-2 SWR(stale→fresh)— 實作 plan

> 總綱 spec §3、§7(PR-2)。建構在 PR-1 透明快取之上。

**Goal:** 線上讀取走 Stale-while-revalidate — 先秒開本機快取(stale),背景抓網路(fresh)到了再更新。讀取 providers 由 `FutureProvider` 改 `StreamProvider`。

**關鍵洞察:** `ApiClient.get()` 已封裝「網路成功 write-through / 離線回退快取 / 否則 throw」。故 `getStream` 只需:先 yield 本機快取(若有),再 yield `get()`。無需 try/catch——
- 有快取線上:yield stale → get() 回 fresh(並寫快取)→ yield fresh
- 有快取離線:yield stale → get() 回退同一快取 → yield(同值,無害)
- 無快取線上:get() 回 fresh → yield
- 無快取離線:get() throw → stream error(無快取可顯示,正確)
- 線上 HTTP 錯誤(404/500):get() throw ApiError → stream error(正確 surface,不卡舊資料)

## File Structure

- Modify `lib/api/api_client.dart` — 加 `Stream<dynamic> getStream(path,{query})`。
- Modify `lib/api/trip_repository.dart` — 加 `watchTrip/watchDays/watchNotes/watchEntry/watchSegments/watchMyTrips`(回 Stream;`fetchX` 保留,trip_repository_test 仍測)。
- Modify `lib/api/favorites_repository.dart` — 加 `watchFavorites`。
- Modify `lib/features/trip_detail/trip_providers.dart` — 5 個 provider 改 `StreamProvider.family`。
- Modify `lib/features/trips/trips_list_screen.dart` — `myTripsProvider` 改 StreamProvider + pull-to-refresh。
- Modify `lib/features/favorites/favorites_providers.dart` — `favoritesProvider` 改 StreamProvider。
- Create `test/api/cache/api_client_getstream_test.dart`。
- Modify 受影響的 widget/flow 測試(stub `fetchX`→`watchX` 回 `Stream.value`;直接 override 改回 Stream)。

## Task 1: getStream（TDD）

- [ ] **Step 1**:寫 `test/api/cache/api_client_getstream_test.dart`:
  - 無快取線上 → emit 單一 fresh
  - 有快取線上 → emit [stale, fresh]
  - 無快取離線(connectionError)→ `emitsError`
  - 有快取離線 → 第一個值為 stale 且不報錯
- [ ] **Step 2**:run（red）
- [ ] **Step 3**:實作 `getStream`:

```dart
/// SWR 讀取:先 emit 本機快取(stale),再 emit get()(fresh/離線回退/或 throw)。
Stream<dynamic> getStream(String path, {Map<String, dynamic>? query}) async* {
  final store = _cacheStore;
  if (store != null) {
    final cached = await store.readResponse(cacheKeyFor('GET', path, query));
    if (cached != null) yield cached.data;
  }
  yield await get(path, query: query);
}
```

- [ ] **Step 4**:run（green）

## Task 2: repository watchX

- [ ] TripRepository 加(inline parse,對齊既有 fetchX 解析):watchTrip / watchDays(query all=1)/ watchNotes / watchEntry / watchSegments / watchMyTrips。
- [ ] FavoritesRepository 加 watchFavorites。
- [ ] `flutter analyze` 0。

## Task 3: 轉 providers 為 StreamProvider

- [ ] trip_providers.dart 5 個 + favorites_providers.dart 1 個 + trips_list_screen.dart myTripsProvider 1 個 → `StreamProvider(.family)`,body 改呼叫對應 `watchX`。
- [ ] trips_list_screen pull-to-refresh:若 `StreamProvider.future` 可用則沿用;否則改 `ref.invalidate` + 回 `Future.value()`(以 analyze 為準)。

## Task 4: 修測試(依失敗逐檔)

- [ ] `flutter test` → 收集失敗清單。
- [ ] repo-stub 測試:`when(()=>repo.fetchX()).thenAnswer((_) async => v)` → `when(()=>repo.watchX()).thenAnswer((_) => Stream.value(v))`(原 fetchX 若仍被該測試直接驗證則保留)。
- [ ] 直接 override:`provider.overrideWith((ref) => Future/value)` → 回 `Stream.value(...)`。
- [ ] 逐檔修到全綠。

## Task 5: 驗收

- [ ] `flutter analyze` 0;`flutter test` 全綠。
- [ ] dart format、commit、PR、review、merge。

## Self-Review
- getStream 重用 get() → 不重複 auth/retry/fallback 邏輯。
- fetchX 保留(trip_repository_test/favorites_repository_test 仍直接測);watchX 為 SWR 新增。
- StreamProvider 同回 `AsyncValue` → 畫面 `.when/.value` 消費不變,僅多一次 stale→fresh rebuild。
