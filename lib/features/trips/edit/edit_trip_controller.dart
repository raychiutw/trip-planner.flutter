/// 編輯行程狀態機:一次性 fetchTrip 帶入初值 → 使用者改 → diff-only PUT。
/// destinations 載入自 GET(無 country)→ 不重算 countries(避免誤判)。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/providers.dart';
import '../../../api/cache/cache_read_policy.dart';
import '../../../api/trip_repository.dart';
import '../../../models/day.dart';
import '../../../models/destination_input.dart';
import '../../trip_detail/trip_providers.dart';
import '../trips_list_screen.dart';

class EditTripState {
  const EditTripState({
    this.loading = true,
    this.title = '',
    this.description = '',
    this.lang = 'zh-TW',
    this.published = false,
    this.startDate,
    this.endDate,
    this.days = const [],
    this.destinations = const [],
    this.saving = false,
    this.shifting = false,
    this.daysMutating = false,
    this.error,
    this.saved = false,
  });

  final bool loading;
  final String title;
  final String description;
  final String lang;
  final bool published;
  final String? startDate;
  final String? endDate;
  final List<TripDay> days;
  final List<DestinationInput> destinations;
  final bool saving;
  final bool shifting;
  final bool daysMutating;
  final String? error;
  final bool saved;

  EditTripState copyWith({
    bool? loading,
    String? title,
    String? description,
    String? lang,
    bool? published,
    Object? startDate = _sentinel,
    Object? endDate = _sentinel,
    List<TripDay>? days,
    List<DestinationInput>? destinations,
    bool? saving,
    bool? shifting,
    bool? daysMutating,
    Object? error = _sentinel,
    bool? saved,
  }) {
    return EditTripState(
      loading: loading ?? this.loading,
      title: title ?? this.title,
      description: description ?? this.description,
      lang: lang ?? this.lang,
      published: published ?? this.published,
      startDate: startDate == _sentinel ? this.startDate : startDate as String?,
      endDate: endDate == _sentinel ? this.endDate : endDate as String?,
      days: days ?? this.days,
      destinations: destinations ?? this.destinations,
      saving: saving ?? this.saving,
      shifting: shifting ?? this.shifting,
      daysMutating: daysMutating ?? this.daysMutating,
      error: error == _sentinel ? this.error : error as String?,
      saved: saved ?? this.saved,
    );
  }

  static const _sentinel = Object();
}

enum DayDeletionResolution {
  committed,
  targetStillPresent,
  verificationRequired,
}

typedef DayDeletionResult = ({
  DayDeletionResolution resolution,
  int? removedEntryCount,
});

class _PendingDayDeletion {
  const _PendingDayDeletion({
    required this.targetId,
    required this.commitKnown,
    this.removedEntryCount,
  });

  final int targetId;
  final bool commitKnown;
  final int? removedEntryCount;
}

class EditTripController extends Notifier<EditTripState> {
  EditTripController(this.tripId);

  final String tripId;

  bool _disposed = false;
  _PendingDayDeletion? _pendingDayDeletion;
  bool _dayDeletionResolutionInFlight = false;
  // 原始值(算 diff)。
  String _origTitle = '';
  String _origDescription = '';
  String _origLang = 'zh-TW';
  bool _origPublished = false;
  List<String> _origDestNames = const [];

  @override
  EditTripState build() {
    ref.onDispose(() => _disposed = true);
    unawaited(_load());
    return const EditTripState(loading: true);
  }

  TripRepository get _repo => ref.read(tripRepositoryProvider);

  Future<void> _load() async {
    try {
      // 表單種子用一次性 fetch(非 SWR stream),避免依賴會 autoDispose 的
      // tripDetailProvider.future(無 listener 時 stream 未 emit 即被回收)。
      // 仍享 ApiClient 透明快取/離線回退。
      final trip = await _repo.fetchTrip(tripId);
      final days = await _repo.fetchDaySummaries(tripId);
      if (_disposed) return;
      _origTitle = trip.title ?? '';
      _origDescription = trip.description ?? '';
      _origLang = trip.lang ?? 'zh-TW';
      _origPublished = trip.published;
      final dests = [
        for (final d in trip.destinations)
          DestinationInput(name: d.name, lat: d.lat, lng: d.lng),
      ];
      _origDestNames = [for (final d in dests) d.name];
      state = EditTripState(
        loading: false,
        title: _origTitle,
        description: _origDescription,
        lang: _origLang,
        published: _origPublished,
        startDate: trip.startDate ?? _firstDate(days),
        endDate: trip.endDate ?? _lastDate(days),
        days: days,
        destinations: dests,
      );
    } on Exception {
      if (_disposed) return;
      state = state.copyWith(loading: false, error: '載入失敗,請稍後再試');
    }
  }

  void setTitle(String v) => state = state.copyWith(title: v);
  void setDescription(String v) => state = state.copyWith(description: v);
  void setLang(String v) => state = state.copyWith(lang: v);
  void setPublished(bool v) => state = state.copyWith(published: v);

  void addDestination(DestinationInput d) =>
      state = state.copyWith(destinations: [...state.destinations, d]);
  void removeDestination(int index) => state = state.copyWith(
    destinations: [...state.destinations]..removeAt(index),
  );
  void reorderDestination(int oldIndex, int newIndex) {
    final list = [...state.destinations];
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = state.copyWith(destinations: list);
  }

  bool get _destChanged =>
      !listEquals([for (final d in state.destinations) d.name], _origDestNames);

  /// 有任何欄位變更。
  bool get hasChanges =>
      state.title != _origTitle ||
      state.description != _origDescription ||
      state.lang != _origLang ||
      state.published != _origPublished ||
      _destChanged;

  /// diff-only PUT;無變更則直接視為已存(不打空 body 觸發 400)。
  Future<void> save() async {
    if (state.loading || state.saving) return;
    if (!hasChanges) {
      state = state.copyWith(saved: true);
      return;
    }
    state = state.copyWith(saving: true, error: null);
    try {
      await _repo.updateTrip(
        tripId,
        title: state.title != _origTitle ? state.title : null,
        description: state.description != _origDescription
            ? state.description
            : null,
        lang: state.lang != _origLang ? state.lang : null,
        published: state.published != _origPublished
            ? (state.published ? 1 : 0)
            : null,
        destinations: _destChanged ? state.destinations : null,
      );
      if (_disposed) return;
      ref.invalidate(myTripsProvider);
      ref.invalidate(tripDetailProvider(tripId));
      state = state.copyWith(saving: false, saved: true);
    } on Exception {
      if (_disposed) return;
      state = state.copyWith(saving: false, error: '儲存失敗,請稍後再試');
    }
  }

  /// POST /trips/:id/days/shift，整體平移所有 day/date。
  Future<bool> shiftStartDate(String startDate) async {
    if (state.loading || state.shifting) return false;
    final nextStartDate = startDate.trim();
    if (!_isIsoDate(nextStartDate)) {
      state = state.copyWith(error: '請輸入 YYYY-MM-DD 日期');
      return false;
    }
    state = state.copyWith(shifting: true, error: null);
    try {
      final result = await _repo.shiftDays(
        tripId: tripId,
        startDate: nextStartDate,
      );
      final days = await _repo.fetchDaySummaries(tripId);
      if (_disposed) return false;
      ref.invalidate(myTripsProvider);
      ref.invalidate(tripDetailProvider(tripId));
      ref.invalidate(tripDaysProvider(tripId));
      state = state.copyWith(
        shifting: false,
        days: days,
        startDate: result.newStartDate,
        endDate: result.newEndDate,
        error: null,
      );
      return true;
    } on Exception {
      if (_disposed) return false;
      state = state.copyWith(shifting: false, error: '平移失敗,請稍後再試');
      return false;
    }
  }

  /// POST /trips/:id/days，在最前或最後新增一天。
  Future<bool> addDay(String position) async {
    if (state.loading || state.daysMutating || state.shifting) return false;
    if (position != 'start' && position != 'end') return false;
    state = state.copyWith(daysMutating: true, error: null);
    try {
      await _repo.createDay(tripId: tripId, position: position);
      final days = await _repo.fetchDaySummaries(tripId);
      if (_disposed) return false;
      _invalidateTripDays();
      state = state.copyWith(
        daysMutating: false,
        days: days,
        startDate: _firstDate(days) ?? state.startDate,
        endDate: _lastDate(days) ?? state.endDate,
        error: null,
      );
      return true;
    } on Exception {
      if (_disposed) return false;
      state = state.copyWith(daysMutating: false, error: '新增天數失敗,請稍後再試');
      return false;
    }
  }

  /// POST /trips/:id/days，以 insert/date 新增中間缺少的日期。
  Future<bool> addMissingDay(String date) async {
    if (state.loading || state.daysMutating || state.shifting) return false;
    final missingDate = date.trim();
    if (!_isIsoDate(missingDate)) {
      state = state.copyWith(error: '請輸入 YYYY-MM-DD 日期');
      return false;
    }
    state = state.copyWith(daysMutating: true, error: null);
    try {
      await _repo.createDay(
        tripId: tripId,
        position: 'insert',
        date: missingDate,
      );
      final days = await _repo.fetchDaySummaries(tripId);
      if (_disposed) return false;
      _invalidateTripDays();
      state = state.copyWith(
        daysMutating: false,
        days: days,
        startDate: _firstDate(days) ?? state.startDate,
        endDate: _lastDate(days) ?? state.endDate,
        error: null,
      );
      return true;
    } on Exception {
      if (_disposed) return false;
      state = state.copyWith(daysMutating: false, error: '新增缺少日期失敗,請稍後再試');
      return false;
    }
  }

  /// DELETE /trips/:id/days/:num，並以 stable Day id 解決 response ambiguity。
  ///
  /// request 例外不代表 server 未 commit；此時只以 network-only summaries 驗證
  /// target id 是否仍存在，不會自動重送 positional dayNum DELETE。
  Future<DayDeletionResult?> deleteDay(TripDay target) async {
    if (state.loading || state.daysMutating || state.shifting) return null;
    state = state.copyWith(daysMutating: true, error: null);
    try {
      final removed = await _repo.deleteDay(
        tripId: tripId,
        dayNum: target.dayNum,
      );
      _pendingDayDeletion = _PendingDayDeletion(
        targetId: target.id,
        commitKnown: true,
        removedEntryCount: removed,
      );
      _invalidateTripDays();
    } on Exception {
      _pendingDayDeletion = _PendingDayDeletion(
        targetId: target.id,
        commitKnown: false,
      );
    }
    if (_disposed) return null;
    return resolvePendingDayDeletion();
  }

  /// 只用 network-only summaries 解決待確認刪除；絕不重送 DELETE。
  Future<DayDeletionResult?> resolvePendingDayDeletion() async {
    final pending = _pendingDayDeletion;
    if (pending == null || _dayDeletionResolutionInFlight) {
      return null;
    }
    _dayDeletionResolutionInFlight = true;
    if (!_disposed) {
      state = state.copyWith(daysMutating: true, error: null);
    }
    try {
      final days = await _repo.fetchDaySummaries(
        tripId,
        policy: CacheReadPolicy.networkOnly,
      );
      if (_disposed) return null;
      final targetStillPresent = days.any((day) => day.id == pending.targetId);
      if (pending.commitKnown && targetStillPresent) {
        state = state.copyWith(
          daysMutating: true,
          error: '行程日已刪除，但 server 尚未回傳更新後的行程日',
        );
        return (
          resolution: DayDeletionResolution.verificationRequired,
          removedEntryCount: pending.removedEntryCount,
        );
      }

      _pendingDayDeletion = null;
      state = state.copyWith(
        daysMutating: false,
        days: days,
        startDate: _firstDate(days) ?? state.startDate,
        endDate: _lastDate(days) ?? state.endDate,
        error: null,
      );
      if (targetStillPresent) {
        return (
          resolution: DayDeletionResolution.targetStillPresent,
          removedEntryCount: null,
        );
      }
      if (!pending.commitKnown) _invalidateTripDays();
      return (
        resolution: DayDeletionResolution.committed,
        removedEntryCount: pending.removedEntryCount,
      );
    } on Exception {
      if (_disposed) return null;
      state = state.copyWith(
        daysMutating: true,
        error: pending.commitKnown
            ? '行程日已刪除，但重新整理失敗，請再試一次'
            : '無法確認行程日是否已刪除，請再試一次',
      );
      return (
        resolution: DayDeletionResolution.verificationRequired,
        removedEntryCount: pending.removedEntryCount,
      );
    } finally {
      _dayDeletionResolutionInFlight = false;
    }
  }

  TripDay? dayById(int id) {
    for (final day in state.days) {
      if (day.id == id) return day;
    }
    return null;
  }

  /// 重新確認 stable Day id 時只讀取 server 最新狀態，不送出 DELETE。
  Future<bool> refreshDaysForDeletionRetry() async {
    if (state.loading || state.daysMutating || state.shifting) return false;
    state = state.copyWith(daysMutating: true, error: null);
    try {
      final days = await _repo.fetchDaySummaries(
        tripId,
        policy: CacheReadPolicy.networkOnly,
      );
      if (_disposed) return false;
      state = state.copyWith(
        daysMutating: false,
        days: days,
        startDate: _firstDate(days) ?? state.startDate,
        endDate: _lastDate(days) ?? state.endDate,
        error: null,
      );
      return true;
    } on Exception {
      if (_disposed) return false;
      state = state.copyWith(daysMutating: false, error: '無法重新確認行程日，請再試一次');
      return false;
    }
  }

  void _invalidateTripDays() {
    ref.invalidate(myTripsProvider);
    ref.invalidate(tripDetailProvider(tripId));
    ref.invalidate(tripDaysProvider(tripId));
  }
}

final editTripControllerProvider = NotifierProvider.autoDispose
    .family<EditTripController, EditTripState, String>(EditTripController.new);

bool _isIsoDate(String value) => RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value);

String? _firstDate(List<TripDay> days) {
  for (final day in days) {
    final date = day.date;
    if (date != null && date.isNotEmpty) return date;
  }
  return null;
}

String? _lastDate(List<TripDay> days) {
  for (final day in days.reversed) {
    final date = day.date;
    if (date != null && date.isNotEmpty) return date;
  }
  return null;
}
