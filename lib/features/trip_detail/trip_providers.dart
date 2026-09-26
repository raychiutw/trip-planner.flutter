import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_error.dart';
import '../../api/providers.dart';
import '../../app/stream_retry_coordinator.dart';
import '../../models/day.dart';
import '../../models/entry.dart';
import '../../models/notes.dart';
import '../../models/segment.dart';
import '../../models/trip.dart';
import 'trip_days_lookup.dart';

/// 同一行程的詳情、日程、筆記共用此 scope（對應 web TripLayout 的共用 fetch），
/// timeline / map / notes 三個分頁 watch 同一 family 實例即不會重複抓取。
/// SWR:先 emit 本機快取(stale),再 emit 網路(fresh)。
final tripDetailProvider = StreamProvider.family<Trip, String>((ref, tripId) {
  return ref.watch(tripRepositoryProvider).watchTrip(tripId);
});

final tripDaysRetryProvider = Provider.family<StreamRetryCoordinator, String>(
  _daysRetry,
);

StreamRetryCoordinator _daysRetry(Ref ref, String tripId) {
  final retry = StreamRetryCoordinator(
    () => ref.invalidate(tripDaysProvider(tripId)),
  );
  ref.onDispose(retry.dispose);
  return retry;
}

final tripDaysProvider = StreamProvider.family<List<TripDay>, String>((
  ref,
  tripId,
) {
  final repository = ref.watch(tripRepositoryProvider);
  return ref
      .read(tripDaysRetryProvider(tripId))
      .track(() => repository.watchDays(tripId));
});

/// 與 days family 同生命週期的查找索引，stale／fresh 各衍生一次供畫面共用。
final tripDaysIndexProvider =
    Provider.family<AsyncValue<TripDaysIndex>, String>(
      (ref, tripId) =>
          ref.watch(tripDaysProvider(tripId)).whenData(TripDaysIndex.new),
    );

final tripNotesProvider = StreamProvider.family<TripNotes, String>((
  ref,
  tripId,
) {
  return ref.watch(tripRepositoryProvider).watchNotes(tripId);
});

/// 單筆 entry 詳情（地點管理用;含 master/alternates/entryPoisVersion,無 travel）。
final entryDetailProvider =
    StreamProvider.family<TimelineEntry, ({String tripId, int entryId})>((
      ref,
      key,
    ) {
      return ref
          .watch(tripRepositoryProvider)
          .watchEntry(tripId: key.tripId, entryId: key.entryId);
    });

/// 編輯表單要的停留點來源:比種子(打開表單時那一版)新的 detail 才採用 ——
/// SWR 會先吐舊快取,不能讓它把 OCC version 倒退;404 表示這個停留點已被刪除。
typedef EntryEditSource = ({
  TimelineEntry? fresher,
  bool deleted,
  Object? error,
});

class EntryEditSourceController extends Notifier<EntryEditSource> {
  EntryEditSourceController(this.key);

  final ({String tripId, int entryId, int seedVersion}) key;

  @override
  EntryEditSource build() {
    final detail = entryDetailProvider((
      tripId: key.tripId,
      entryId: key.entryId,
    ));
    ref.listen(detail, (_, next) {
      state = _newerSource(state, next);
    });
    return _newerSource((
      fresher: null,
      deleted: false,
      error: null,
    ), ref.read(detail));
  }

  EntryEditSource _newerSource(
    EntryEditSource previous,
    AsyncValue<TimelineEntry> next,
  ) {
    final value = next.value;
    final error = next.error;
    final newer =
        value != null &&
        value.version >= key.seedVersion &&
        (previous.fresher == null ||
            value.version >= previous.fresher!.version);
    final deleted =
        previous.deleted || error is ApiError && error.status == 404;
    return (
      fresher: newer ? value : previous.fresher,
      deleted: deleted,
      error: deleted && error == null ? previous.error : error,
    );
  }
}

final entryEditSourceProvider = NotifierProvider.autoDispose
    .family<
      EntryEditSourceController,
      EntryEditSource,
      ({String tripId, int entryId, int seedVersion})
    >(EntryEditSourceController.new);

/// 行程交通段（交通編輯用;含 segment id/version,供 travel pill 比對與 PATCH）。
final tripSegmentsProvider = StreamProvider.family<List<TripSegment>, String>((
  ref,
  tripId,
) {
  return ref.watch(tripRepositoryProvider).watchSegments(tripId: tripId);
});
