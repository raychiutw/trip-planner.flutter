/// 離線同步:重連 / app-resume / 手動觸發 flush 佇列,暴露待同步筆數與衝突清單。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/cache/cache_store.dart';
import '../../api/providers.dart';
import '../favorites/favorites_providers.dart';
import '../trip_detail/trip_providers.dart';
import '../trips/trips_list_screen.dart';

/// 待同步(離線佇列)筆數;flush 後 invalidate 以刷新(入隊端的刷新待 PR-5 UI 接上)。
final offlinePendingCountProvider = FutureProvider<int>(
  (ref) async => (await ref.watch(cacheStoreProvider).readQueue()).length,
);

/// 最後一次 flush 的衝突清單(供 UI 上報;PR-5 顯示)。
final syncConflictsProvider =
    NotifierProvider<SyncConflictsController, List<QueuedMutation>>(
      SyncConflictsController.new,
    );

class SyncConflictsController extends Notifier<List<QueuedMutation>> {
  @override
  List<QueuedMutation> build() => const [];

  void set(List<QueuedMutation> conflicts) => state = conflicts;
  void clear() => state = const [];
}

/// 同步控制器:sync() 觸發 flush、更新衝突/筆數、invalidate 讀取以套 server 真相。
final offlineSyncControllerProvider =
    NotifierProvider<OfflineSyncController, AsyncValue<void>>(
      OfflineSyncController.new,
    );

class OfflineSyncController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// 重播離線佇列;成功有同步則 invalidate 受影響讀取(讓 server 真相上畫面)。
  Future<void> sync() async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    try {
      final result = await ref.read(apiClientProvider).flushQueue();
      ref.read(syncConflictsProvider.notifier).set(result.conflicts);
      ref.invalidate(offlinePendingCountProvider);
      if (result.synced > 0 || result.conflicts.isNotEmpty) {
        // _send 已 evict 受影響快取;這裡讓讀取 providers 重跑取 server 真相
        //(臨時 id 的樂觀 entry 換成真實資料)。離線寫目前只動 trip 內容,故 invalidate
        // trip 詳情家族 + 清單。family 不帶參數 = invalidate 全部實例。
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
