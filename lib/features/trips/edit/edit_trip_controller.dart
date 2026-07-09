/// 編輯行程狀態機:一次性 fetchTrip 帶入初值 → 使用者改 → diff-only PUT。
/// destinations 載入自 GET(無 country)→ 不重算 countries(避免誤判)。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/providers.dart';
import '../../../api/trip_repository.dart';
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
    this.destinations = const [],
    this.saving = false,
    this.shifting = false,
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
  final List<DestinationInput> destinations;
  final bool saving;
  final bool shifting;
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
    List<DestinationInput>? destinations,
    bool? saving,
    bool? shifting,
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
      destinations: destinations ?? this.destinations,
      saving: saving ?? this.saving,
      shifting: shifting ?? this.shifting,
      error: error == _sentinel ? this.error : error as String?,
      saved: saved ?? this.saved,
    );
  }

  static const _sentinel = Object();
}

class EditTripController extends Notifier<EditTripState> {
  EditTripController(this.tripId);

  final String tripId;

  bool _disposed = false;
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
        startDate: trip.startDate,
        endDate: trip.endDate,
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
      if (_disposed) return false;
      ref.invalidate(myTripsProvider);
      ref.invalidate(tripDetailProvider(tripId));
      ref.invalidate(tripDaysProvider(tripId));
      state = state.copyWith(
        shifting: false,
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
}

final editTripControllerProvider = NotifierProvider.autoDispose
    .family<EditTripController, EditTripState, String>(EditTripController.new);

bool _isIsoDate(String value) => RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value);
