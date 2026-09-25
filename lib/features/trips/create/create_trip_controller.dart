/// 建立行程狀態機:目的地清單 + 日期模式(固定/彈性)+ 每地天數 + 送出。
/// 送出時衍生 name/id/countries(見 trip_form_logic)。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api_error.dart';
import '../../../api/providers.dart';
import '../../../app/draft_session.dart';
import '../../../models/destination_input.dart';
import '../trip_form_logic.dart';

enum TripDateMode { fixed, flexible }

class CreateTripState {
  CreateTripState({
    List<DestinationInput> destinations = const [],
    this.dateMode = TripDateMode.fixed,
    this.fixedStart,
    this.fixedEnd,
    required this.flexYear,
    required this.flexMonth,
    this.flexDayCount = 5,
    this.description = '',
  }) : destinations = List.unmodifiable(destinations);

  final List<DestinationInput> destinations;
  final TripDateMode dateMode;
  final String? fixedStart; // YYYY-MM-DD
  final String? fixedEnd;
  final int flexYear;
  final int flexMonth;
  final int flexDayCount;
  final String description;

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
      isTripDatesValid(startDate!, endDate!);

  CreateTripState copyWith({
    List<DestinationInput>? destinations,
    TripDateMode? dateMode,
    String? fixedStart,
    String? fixedEnd,
    int? flexYear,
    int? flexMonth,
    int? flexDayCount,
    String? description,
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
    );
  }

  /// 比較目的地、日期與描述，判斷是否仍為同一份行程草稿。
  bool equivalent(CreateTripState other) =>
      listEquals(destinations, other.destinations) &&
      dateMode == other.dateMode &&
      fixedStart == other.fixedStart &&
      fixedEnd == other.fixedEnd &&
      flexYear == other.flexYear &&
      flexMonth == other.flexMonth &&
      flexDayCount == other.flexDayCount &&
      description == other.description;
}

class CreateTripController extends Notifier<CreateTripState> {
  late DraftSession<CreateTripState, String> _session;

  @override
  CreateTripState build() {
    final now = DateTime.now();
    _session = DraftSession<CreateTripState, String>(
      initial: CreateTripState(flexYear: now.year, flexMonth: now.month),
      equivalent: (a, b) => a.equivalent(b),
      write: (snapshot) async {
        final draft = snapshot.draft;
        final result = await ref
            .read(tripRepositoryProvider)
            .createTrip(
              name: deriveTripName(draft.destinations),
              startDate: draft.startDate!,
              endDate: draft.endDate!,
              description: draft.description.isEmpty ? null : draft.description,
              countries: deriveCountries(draft.destinations),
              destinations: draft.destinations,
            );
        return DraftAccepted(draft: draft, result: result.tripId);
      },
      describeError: (error) => error is ApiError && error.status == 409
          ? '行程新增衝突，請再試一次'
          : '新增失敗，請稍後再試',
    );
    // Riverpod 只呈現 session 的草稿，提交與錯誤也由同一 owner 發出通知。
    _session.addListener(() => state = _session.draft);
    ref.onDispose(_session.dispose);
    return _session.draft;
  }

  @override
  bool updateShouldNotify(CreateTripState previous, CreateTripState next) =>
      true;

  bool get hasChanges => _session.dirty;
  bool get submitting => _session.submitting;
  bool get isSaved => _session.isSaved;
  bool get editingEnabled => !submitting && !isSaved;
  String? get error => _session.error;
  bool get canSubmit => state.canSubmit && _session.canSubmit;

  void _edit(CreateTripState next) {
    if (editingEnabled) _session.edit(next);
  }

  void addDestination(DestinationInput d) =>
      _edit(state.copyWith(destinations: [...state.destinations, d]));

  void removeDestination(int index) => _edit(
    state.copyWith(destinations: [...state.destinations]..removeAt(index)),
  );

  void reorderDestination(int oldIndex, int newIndex) {
    final list = [...state.destinations];
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    _edit(state.copyWith(destinations: list));
  }

  void setDateMode(TripDateMode m) => _edit(state.copyWith(dateMode: m));
  void setFixedStart(String d) => _edit(state.copyWith(fixedStart: d));
  void setFixedEnd(String d) => _edit(state.copyWith(fixedEnd: d));
  void setFlexMonth(int year, int month) =>
      _edit(state.copyWith(flexYear: year, flexMonth: month));
  void setFlexDayCount(int n) =>
      _edit(state.copyWith(flexDayCount: n.clamp(1, 30)));
  void setDescription(String s) => _edit(state.copyWith(description: s));

  void setQuota(int index, int n) {
    final list = [...state.destinations];
    list[index] = list[index].copyWith(dayQuota: n);
    _edit(state.copyWith(destinations: list));
  }

  /// 送出當下草稿；只有仍有效的 session 憑證能完成導頁。
  Future<DraftSaved<String>?> submit() async {
    if (!canSubmit) return null;
    return _session.submit();
  }

  /// 憑證必須仍屬於目前 session 的已接受草稿，才能導航。
  bool canFinish(DraftSaved<String> saved) => _session.canFinish(saved);
}

final createTripControllerProvider =
    NotifierProvider.autoDispose<CreateTripController, CreateTripState>(
      CreateTripController.new,
    );
