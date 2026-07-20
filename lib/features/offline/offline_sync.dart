/// 離線同步:重連 / app-resume / 手動觸發 flush 佇列,暴露待同步筆數與衝突清單。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/cache/cache_store.dart';
import '../../api/providers.dart';
import '../favorites/favorites_providers.dart';
import '../trip_detail/trip_providers.dart';
import '../trips/trips_list_screen.dart';

/// 待同步(離線佇列)筆數;隨佇列變動(入隊/同步/清空)反應式更新,供 banner badge。
final offlinePendingCountProvider = StreamProvider<int>((ref) async* {
  final store = ref.watch(cacheStoreProvider);
  yield (await store.readQueue()).length;
  await for (final _ in store.changes) {
    yield (await store.readQueue()).length;
  }
});

/// 待解決衝突(持久化 conflict store);store 變動反應式刷新。
/// 真相源是 conflict store(flushQueue / resolveConflict 寫入),非記憶體。
final syncConflictRecordsProvider = StreamProvider<List<ConflictRecord>>((
  ref,
) async* {
  final store = ref.watch(cacheStoreProvider);
  yield await store.readConflicts();
  await for (final _ in store.changes) {
    yield await store.readConflicts();
  }
});

/// 同步控制器:sync() 觸發 flush、更新衝突/筆數、invalidate 讀取以套 server 真相。
final offlineSyncControllerProvider =
    NotifierProvider<OfflineSyncController, AsyncValue<void>>(
      OfflineSyncController.new,
    );

class OfflineSyncController extends Notifier<AsyncValue<void>> {
  bool? _wasOnline;

  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// 平台連線型態從離線恢復時立即重試同步。首次線上事件不重複冷啟動同步。
  /// [isOnline] 只是重試訊號，不是可上網保證；真正錯誤仍由 [sync] 處理。
  void handleNetworkAvailability(bool isOnline) {
    final reconnected = _wasOnline == false && isOnline;
    _wasOnline = isOnline;
    if (reconnected) unawaited(sync());
  }

  /// 重播離線佇列;成功有同步則 invalidate 受影響讀取(讓 server 真相上畫面)。
  Future<void> sync() async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    try {
      final result = await ref.read(apiClientProvider).flushQueue();
      // 衝突已由 flushQueue 寫進 conflict store,syncConflictRecordsProvider
      // 透過 store.changes 反應式刷新,這裡不需手動 set。
      // offlinePendingCountProvider 由 cacheStore.changes 反應式更新,flush 的
      // removeMutation 會自動讓 badge 歸零,不需在此手動 invalidate。
      if (result.synced > 0 || result.conflicts.isNotEmpty) {
        // _send 已 evict 受影響快取;這裡讓讀取 providers 重跑取 server 真相
        //(臨時 id 的樂觀資料換成真實資料)。保守起見 invalidate 行程相關家族 + 清單
        //(family 不帶參數 = 全實例);精準 per-tripId 失效列為後續優化。
        ref.invalidate(tripDetailProvider);
        ref.invalidate(tripDaysProvider);
        ref.invalidate(tripNotesProvider);
        ref.invalidate(tripSegmentsProvider);
        ref.invalidate(entryDetailProvider);
        ref.invalidate(myTripsProvider);
        ref.invalidate(favoritesProvider);
      }
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}
