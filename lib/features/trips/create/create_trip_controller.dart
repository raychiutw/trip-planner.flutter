/// 建立行程狀態機:目的地清單 + 日期模式(固定/彈性)+ 每地天數 + 送出。
/// 送出時衍生 name/id/countries(見 trip_form_logic)。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api_error.dart';
import '../../../api/providers.dart';
import '../../../api/trip_repository.dart';
import '../../../models/destination_input.dart';
import '../trip_form_logic.dart';

enum TripDateMode { fixed, flexible }

class CreateTripState {
  const CreateTripState({
    this.destinations = const [],
    this.dateMode = TripDateMode.fixed,
    this.fixedStart,
    this.fixedEnd,
    required this.flexYear,
    required this.flexMonth,
    this.flexDayCount = 5,
    this.description = '',
    this.submitting = false,
    this.error,
  });

  final List<DestinationInput> destinations;
  final TripDateMode dateMode;
  final String? fixedStart; // YYYY-MM-DD
  final String? fixedEnd;
  final int flexYear;
  final int flexMonth;
  final int flexDayCount;
  final String description;
  final bool submitting;
  final String? error;

  String? get startDate => dateMode == TripDateMode.fixed
      ? fixedStart
      : flexibleRange(flexYear, flexMonth, flexDayCount).$1;
  String? get endDate => dateMode == TripDateMode.fixed
      ? fixedEnd
      : flexibleRange(flexYear, flexMonth, flexDayCount).$2;

  int get totalDays {
    final s = startDate;
    final e = endDate;
    if (s == null || e == null || !isTripDatesValid(s, e)) return 0;
    return tripDayCount(s, e);
  }

  bool get canSubmit =>
      destinations.isNotEmpty &&
      destinations.length <= 30 &&
      startDate != null &&
      endDate != null &&
      isTripDatesValid(startDate!, endDate!) &&
      !submitting;

  CreateTripState copyWith({
    List<DestinationInput>? destinations,
    TripDateMode? dateMode,
    String? fixedStart,
    String? fixedEnd,
    int? flexYear,
    int? flexMonth,
    int? flexDayCount,
    String? description,
    bool? submitting,
    Object? error = _sentinel,
  }) {
    return CreateTripState(
      destinations: destinations ?? this.destinations,
      dateMode: dateMode ?? this.dateMode,
      fixedStart: fixedStart ?? this.fixedStart,
      fixedEnd: fixedEnd ?? this.fixedEnd,
      flexYear: flexYear ?? this.flexYear,
      flexMonth: flexMonth ?? this.flexMonth,
      flexDayCount: flexDayCount ?? this.flexDayCount,
      description: description ?? this.description,
      submitting: submitting ?? this.submitting,
      error: error == _sentinel ? this.error : error as String?,
    );
  }

  static const _sentinel = Object();
}

class CreateTripController extends Notifier<CreateTripState> {
  bool _disposed = false;
  late int _initialFlexYear;
  late int _initialFlexMonth;

  @override
  CreateTripState build() {
    ref.onDispose(() => _disposed = true);
    final now = DateTime.now();
    _initialFlexYear = now.year;
    _initialFlexMonth = now.month;
    return CreateTripState(flexYear: now.year, flexMonth: now.month);
  }

  TripRepository get _repo => ref.read(tripRepositoryProvider);

  bool get hasChanges =>
      state.destinations.isNotEmpty ||
      state.dateMode != TripDateMode.fixed ||
      state.fixedStart != null ||
      state.fixedEnd != null ||
      state.flexYear != _initialFlexYear ||
      state.flexMonth != _initialFlexMonth ||
      state.flexDayCount != 5 ||
      state.description.isNotEmpty;

  void reset() {
    state = CreateTripState(
      flexYear: _initialFlexYear,
      flexMonth: _initialFlexMonth,
    );
  }

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

  void setDateMode(TripDateMode m) => state = state.copyWith(dateMode: m);
  void setFixedStart(String d) => state = state.copyWith(fixedStart: d);
  void setFixedEnd(String d) => state = state.copyWith(fixedEnd: d);
  void setFlexMonth(int year, int month) =>
      state = state.copyWith(flexYear: year, flexMonth: month);
  void setFlexDayCount(int n) =>
      state = state.copyWith(flexDayCount: n.clamp(1, 30));
  void setDescription(String s) => state = state.copyWith(description: s);

  void setQuota(int index, int n) {
    final list = [...state.destinations];
    list[index] = list[index].copyWith(dayQuota: n);
    state = state.copyWith(destinations: list);
  }

  /// 送出;成功回 tripId,失敗回 null(error 設於 state)。
  Future<String?> submit() async {
    if (!state.canSubmit) return null;
    final dests = state.destinations;
    final name = deriveTripName(dests);
    final id = genTripId(name, DateTime.now().millisecondsSinceEpoch);
    state = state.copyWith(submitting: true, error: null);
    try {
      final r = await _repo.createTrip(
        id: id,
        name: name,
        startDate: state.startDate!,
        endDate: state.endDate!,
        description: state.description.isEmpty ? null : state.description,
        countries: deriveCountries(dests),
        destinations: dests,
      );
      if (!_disposed) reset();
      return r.tripId;
    } on ApiError catch (e) {
      if (_disposed) return null;
      state = state.copyWith(
        submitting: false,
        error: e.status == 409 ? '行程建立衝突,請再試一次' : '建立失敗,請稍後再試',
      );
      return null;
    } on Exception {
      if (_disposed) return null;
      state = state.copyWith(submitting: false, error: '建立失敗,請稍後再試');
      return null;
    }
  }
}

final createTripControllerProvider =
    NotifierProvider.autoDispose<CreateTripController, CreateTripState>(
      CreateTripController.new,
    );
