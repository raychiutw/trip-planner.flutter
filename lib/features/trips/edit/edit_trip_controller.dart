/// 編輯行程狀態機:讀 tripDetailProvider 帶入初值 → 使用者改 → diff-only PUT。
/// 不動日期/name;destinations 載入自 GET(無 country)→ 不重算 countries(避免誤判)。
library;

import 'dart:async';

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
    this.destinations = const [],
    this.saving = false,
    this.error,
    this.saved = false,
  });

  final bool loading;
  final String title;
  final String description;
  final String lang;
  final bool published;
  final List<DestinationInput> destinations;
  final bool saving;
  final String? error;
  final bool saved;

  EditTripState copyWith({
    bool? loading,
    String? title,
    String? description,
    String? lang,
    bool? published,
    List<DestinationInput>? destinations,
    bool? saving,
    Object? error = _sentinel,
    bool? saved,
  }) {
    return EditTripState(
      loading: loading ?? this.loading,
      title: title ?? this.title,
      description: description ?? this.description,
      lang: lang ?? this.lang,
      published: published ?? this.published,
      destinations: destinations ?? this.destinations,
      saving: saving ?? this.saving,
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
      final trip = await ref.read(tripDetailProvider(tripId).future);
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
  void removeDestination(int index) =>
      state = state.copyWith(destinations: [...state.destinations]..removeAt(index));
  void reorderDestination(int oldIndex, int newIndex) {
    final list = [...state.destinations];
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = state.copyWith(destinations: list);
  }

  bool get _destChanged =>
      !_listEq([for (final d in state.destinations) d.name], _origDestNames);

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
        description:
            state.description != _origDescription ? state.description : null,
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

  static bool _listEq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

final editTripControllerProvider =
    NotifierProvider.autoDispose.family<EditTripController, EditTripState, String>(
  EditTripController.new,
);
