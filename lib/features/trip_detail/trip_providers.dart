import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/providers.dart';
import '../../models/day.dart';
import '../../models/entry.dart';
import '../../models/notes.dart';
import '../../models/segment.dart';
import '../../models/trip.dart';

/// 同一行程的詳情、日程、筆記共用此 scope（對應 web TripLayout 的共用 fetch），
/// timeline / map / notes 三個分頁 watch 同一 family 實例即不會重複抓取。
final tripDetailProvider = FutureProvider.family<Trip, String>((ref, tripId) {
  return ref.watch(tripRepositoryProvider).fetchTrip(tripId);
});

final tripDaysProvider = FutureProvider.family<List<TripDay>, String>((ref, tripId) {
  return ref.watch(tripRepositoryProvider).fetchDays(tripId);
});

final tripNotesProvider = FutureProvider.family<TripNotes, String>((ref, tripId) {
  return ref.watch(tripRepositoryProvider).fetchNotes(tripId);
});

/// 單筆 entry 詳情（地點管理用;含 master/alternates/entryPoisVersion,無 travel）。
final entryDetailProvider =
    FutureProvider.family<TimelineEntry, ({String tripId, int entryId})>(
        (ref, key) {
  return ref
      .watch(tripRepositoryProvider)
      .fetchEntry(tripId: key.tripId, entryId: key.entryId);
});

/// 行程交通段（交通編輯用;含 segment id/version,供 travel pill 比對與 PATCH）。
final tripSegmentsProvider =
    FutureProvider.family<List<TripSegment>, String>((ref, tripId) {
  return ref.watch(tripRepositoryProvider).fetchSegments(tripId: tripId);
});
