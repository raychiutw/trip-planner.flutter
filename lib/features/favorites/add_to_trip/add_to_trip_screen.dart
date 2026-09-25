/// 收藏或外部地點加入行程：選擇目的行程、日期與時間，並保留可恢復的表單狀態。
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api_error.dart';
import '../../../api/providers.dart';
import '../../../app/adaptive.dart';
import '../../../app/adaptive_content.dart';
import '../../../app/app_feedback.dart';
import '../../../app/app_loading_skeleton.dart';
import '../../../models/add_to_trip.dart';
import '../../../models/day.dart';
import '../../../models/poi_note.dart';
import '../../../models/poi_search_result.dart';
import '../../../models/poi_type.dart';
import '../../../models/trip.dart';
import '../../../theme/tokens.dart';
import '../../../ui/tp_app_bar.dart';
import '../../../ui/tp_compact_time_field.dart';
import '../../../ui/tp_state_view.dart';
import '../../trip_detail/trip_providers.dart';
import '../../trips/trip_card.dart';
import '../../trips/trips_list_screen.dart';
import '../explore/explore_controller.dart' show poiRepositoryProvider;
import '../favorites_providers.dart';

/// 時間區間有效性：結束須晚於開始。抽為頂層純函式以利單元測試。
bool isAddToTripTimeValid(TimeOfDay start, TimeOfDay end) =>
    end.hour * 60 + end.minute > start.hour * 60 + start.minute;

final addToTripFavoriteArgsProvider =
    FutureProvider.family<AddToTripFavorite, int>((ref, favoriteId) async {
      final favorites = await ref
          .read(favoritesRepositoryProvider)
          .fetchFavorites();
      for (final favorite in favorites) {
        if (favorite.id == favoriteId) {
          return AddToTripFavorite(
            favoriteId: favorite.id,
            displayName: favorite.displayName,
          );
        }
      }
      throw StateError('找不到該收藏（可能已被刪除）');
    });

/// 加入行程 route loader：支援 extra、favorite id 深連結與 direct query。
class AddToTripRouteScreen extends ConsumerWidget {
  const AddToTripRouteScreen({
    super.key,
    this.args,
    this.favoriteId,
    this.favoriteMode = false,
    required this.uri,
  });

  final AddToTripArgs? args;
  final int? favoriteId;
  final bool favoriteMode;
  final Uri uri;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providedArgs = args;
    if (providedArgs != null) return AddToTripScreen(args: providedArgs);

    if (favoriteMode) {
      final id = favoriteId;
      if (id == null || id <= 0) {
        return const _AddToTripRouteState(message: '收藏 ID 無效');
      }
      final favoriteArgs = ref.watch(addToTripFavoriteArgsProvider(id));
      return favoriteArgs.when(
        loading: () => const _AddToTripRouteState(loading: true),
        error: (error, _) =>
            _AddToTripRouteState(message: _routeErrorMessage(error)),
        data: (value) => AddToTripScreen(args: value),
      );
    }

    final directArgs = _directArgsFromUri(uri);
    if (directArgs != null) return AddToTripScreen(args: directArgs);

    return const _AddToTripRouteState(message: '景點資料缺漏，請從探索頁重新進入');
  }
}

/// 加入行程（fullpage）：選 trip/day/時間 → 送出（favorite / direct mode）。
class AddToTripScreen extends ConsumerStatefulWidget {
  const AddToTripScreen({super.key, required this.args});

  final AddToTripArgs args;

  @override
  ConsumerState<AddToTripScreen> createState() => _AddToTripScreenState();
}

class _AddToTripScreenState extends ConsumerState<AddToTripScreen> {
  final _dismissController = AppUnsavedChangesController();

  /// 起訖兩顆共用一個群組：展開其中一顆，另一顆自動收起。
  final _timeFieldGroup = TpTimeFieldGroup();
  String? _tripId;
  int? _dayNum;
  TimeOfDay _start = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 11, minute: 0);
  bool _submitting = false;
  bool _dirty = false;

  @override
  void dispose() {
    _timeFieldGroup.dispose();
    super.dispose();
  }

  String get _title => switch (widget.args) {
    AddToTripFavorite(:final displayName) => displayName,
    AddToTripDirect(:final poi) => poi.name,
  };

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// 結束須晚於開始（避免零長度或負區間 entry）。
  bool get _timeValid => isAddToTripTimeValid(_start, _end);

  Future<void> _recomputeDay(String tripId, int dayNum) async {
    try {
      await ref
          .read(tripRepositoryProvider)
          .recomputeTravel(tripId: tripId, day: '$dayNum');
    } on Exception {
      // 交通重算失敗不影響加入行程結果。
    }
  }

  void _pickTime(bool isStart, TimeOfDay picked) {
    setState(() {
      isStart ? _start = picked : _end = picked;
      _dirty = true;
    });
  }

  Future<void> _submit(String tripId, int dayNum) async {
    setState(() => _submitting = true);
    try {
      switch (widget.args) {
        case AddToTripFavorite(:final favoriteId):
          await ref
              .read(favoritesRepositoryProvider)
              .addFavoriteToTrip(
                favoriteId: favoriteId,
                tripId: tripId,
                dayNum: dayNum,
                startTime: _fmt(_start),
                endTime: _fmt(_end),
              );
        case AddToTripDirect(:final poi):
          String? note;
          try {
            final details = await ref
                .read(poiRepositoryProvider)
                .resolvePlace(poi.placeId);
            note = buildPoiNote(
              hoursRaw: details.hours,
              priceLevel: details.priceLevel,
              address: poi.address ?? details.address,
            );
          } on Exception {
            note = buildPoiNote(address: poi.address);
          }
          await ref
              .read(tripRepositoryProvider)
              .addEntryToDay(
                tripId: tripId,
                dayNum: dayNum,
                title: poi.name,
                note: note,
                poiType: mapGooglePrimaryTypeToPoiType(poi.category),
                lat: poi.lat,
                lng: poi.lng,
                startTime: _fmt(_start),
                endTime: _fmt(_end),
                source: 'google',
              );
      }
      await _recomputeDay(tripId, dayNum);
      if (!mounted) return;
      HapticFeedback.lightImpact();
      showAppNotice(context, '已加入行程');
      setState(() => _dirty = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      if (error is ApiError && error.status == 409) {
        final raw = error.payload?['conflictWith'];
        if (raw is Map) {
          await _showConflict(
            TripEntryConflict.fromJson(Map<String, dynamic>.from(raw)),
          );
          return;
        }
      }
      showAppError(context, '加入行程失敗，請稍後再試');
    }
  }

  Future<void> _showConflict(TripEntryConflict conflict) {
    final timeLabel = conflict.time == null ? '' : '（${conflict.time}）';
    return showAppAlert(
      context,
      title: '時段衝突',
      message: '該時段已有「${conflict.title}」$timeLabel。請改選其他時間後再試。',
      actionLabel: '知道了',
    );
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(myTripsProvider);
    final trips = tripsAsync.hasValue
        ? tripsAsync.requireValue
        : const <TripSummary>[];
    final tripId = trips.any((trip) => trip.tripId == _tripId)
        ? _tripId
        : trips.firstOrNull?.tripId;
    final daysAsync = tripId == null
        ? null
        : ref.watch(tripDaysProvider(tripId));
    final days = daysAsync?.hasValue ?? false
        ? daysAsync!.requireValue
        : const <TripDay>[];
    // 日期選擇只屬於原行程；清單刷新移除該行程時不能帶到另一個 family。
    final dayNum = _tripId == tripId && days.any((day) => day.dayNum == _dayNum)
        ? _dayNum
        : days.firstOrNull?.dayNum;
    final canSubmit =
        !_submitting && _timeValid && tripId != null && dayNum != null;

    return AppUnsavedChangesGuard(
      controller: _dismissController,
      hasChanges: _dirty,
      dismissalEnabled: !_submitting,
      child: Scaffold(
        appBar: TpAppBar(
          role: TpAppBarRole.modalForm,
          title: Text('加入行程：$_title'),
          onCancel: _dismissController.requestPop,
          primaryActionLabel: '加入',
          primaryActionKey: const ValueKey('add-to-trip-submit'),
          primaryActionEnabled: canSubmit,
          onPrimaryAction: () => _submit(tripId!, dayNum!),
        ),
        body: AppAdaptiveContent(
          maxWidth: AppContentWidth.form,
          child: tripsAsync.when(
            skipLoadingOnReload: tripsAsync.retrying,
            skipError: tripsAsync.hasValue,
            loading: () => const AppListLoadingSkeleton(
              key: ValueKey('add-to-trip-loading'),
            ),
            error: (e, _) => SingleChildScrollView(
              child: Semantics(
                liveRegion: true,
                child: _RetryState(
                  title: '無法載入行程清單',
                  onRetry: () => ref.read(myTripsRetryProvider).retry(),
                ),
              ),
            ),
            data: (trips) => _form(
              context,
              trips: trips,
              tripsError: tripsAsync.hasError,
              tripId: tripId,
              daysAsync: daysAsync,
              days: days,
              dayNum: dayNum,
            ),
          ),
        ),
      ),
    );
  }

  Widget _form(
    BuildContext context, {
    required List<TripSummary> trips,
    required bool tripsError,
    required String? tripId,
    required AsyncValue<List<TripDay>>? daysAsync,
    required List<TripDay> days,
    required int? dayNum,
  }) {
    return ListView(
      padding: const EdgeInsets.all(TpSpacing.s4),
      children: [
        if (tripsError)
          Semantics(
            liveRegion: true,
            child: _RetryState(
              title: '無法載入行程清單',
              onRetry: () => ref.read(myTripsRetryProvider).retry(),
            ),
          ),
        _SelectionField<String>(
          key: const ValueKey('add-to-trip-trip'),
          label: '行程',
          value: tripId,
          options: [
            for (final t in trips) (value: t.tripId, label: t.displayTitle),
          ],
          onChanged: (v) => setState(() {
            _tripId = v;
            _dayNum = null;
            _dirty = true;
          }),
        ),
        const SizedBox(height: TpSpacing.s4),
        if (daysAsync != null)
          daysAsync.when(
            skipLoadingOnReload: daysAsync.retrying,
            skipError: daysAsync.hasValue,
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Semantics(
              liveRegion: true,
              child: _RetryState(
                key: ValueKey(tripId),
                title: '無法載入日期',
                onRetry: () => ref.read(tripDaysRetryProvider(tripId!)).retry(),
              ),
            ),
            data: (_) => Column(
              children: [
                if (daysAsync.hasError)
                  Semantics(
                    liveRegion: true,
                    child: _RetryState(
                      key: ValueKey(tripId),
                      title: '無法載入日期',
                      onRetry: () =>
                          ref.read(tripDaysRetryProvider(tripId!)).retry(),
                    ),
                  ),
                _SelectionField<int>(
                  key: const ValueKey('add-to-trip-day'),
                  label: '日期',
                  value: dayNum,
                  options: [
                    for (final d in days)
                      (
                        value: d.dayNum,
                        label: 'DAY ${d.dayNum} · ${d.displayTitle}',
                      ),
                  ],
                  onChanged: (v) => setState(() {
                    _tripId = tripId;
                    _dayNum = v;
                    _dirty = true;
                  }),
                ),
              ],
            ),
          ),
        const SizedBox(height: TpSpacing.s4),
        // compact picker 就地展開會把下方內容往下推，兩顆必須各佔一列。
        TpCompactTimeField(
          key: const ValueKey('add-to-trip-start-group'),
          buttonKey: const ValueKey('add-to-trip-start'),
          label: '開始',
          value: _start,
          group: _timeFieldGroup,
          onChanged: (picked) => _pickTime(true, picked),
        ),
        const SizedBox(height: TpSpacing.s2),
        TpCompactTimeField(
          key: const ValueKey('add-to-trip-end-group'),
          buttonKey: const ValueKey('add-to-trip-end'),
          label: '結束',
          value: _end,
          group: _timeFieldGroup,
          onChanged: (picked) => _pickTime(false, picked),
        ),
        if (!_timeValid)
          Padding(
            padding: const EdgeInsets.only(top: TpSpacing.s2),
            child: Text(
              '結束時間需晚於開始時間',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 11,
              ),
            ),
          ),
        const SizedBox(height: TpSpacing.s6),
      ],
    );
  }
}

/// 僅呈現此錯誤入口的操作進度；資料與請求去重仍由原 provider 負責。
class _RetryState extends StatefulWidget {
  const _RetryState({super.key, required this.title, required this.onRetry});

  final String title;
  final Future<void> Function() onRetry;

  @override
  State<_RetryState> createState() => _RetryStateState();
}

class _RetryStateState extends State<_RetryState> {
  bool _pending = false;

  Future<void> _retry() async {
    if (_pending) return;
    setState(() => _pending = true);
    try {
      await widget.onRetry();
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) => TpStateView(
    kind: TpStateKind.error,
    title: widget.title,
    message: _pending ? '重試中…' : null,
    actionLabel: _pending ? null : '重試',
    onAction: _pending ? null : _retry,
  );
}

/// 行程與日期共用選擇呈現，資料和目前值仍由表單持有。
class _SelectionField<T> extends StatelessWidget {
  const _SelectionField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<({T value, String label})> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = options
        .where((option) => option.value == value)
        .firstOrNull;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(TpSpacing.tapMin),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.all(TpSpacing.s3),
      ),
      onPressed: options.isEmpty
          ? null
          : () async {
              final result = await showAppSelectionSheet<T>(
                context,
                title: '選擇$label',
                builder: (sheetContext, select) => ListView(
                  children: [
                    for (final option in options)
                      ListTile(
                        title: Text(option.label),
                        selected: option.value == value,
                        trailing: option.value == value
                            ? const Icon(CupertinoIcons.check_mark)
                            : null,
                        onTap: () => select(option.value),
                      ),
                  ],
                ),
              );
              if (result != null && context.mounted && result != value) {
                onChanged(result);
              }
            },
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelLarge),
                Text(selected?.label ?? '尚無$label'),
              ],
            ),
          ),
          const Icon(CupertinoIcons.chevron_down),
        ],
      ),
    );
  }
}

class _AddToTripRouteState extends StatelessWidget {
  const _AddToTripRouteState({this.message, this.loading = false});

  final String? message;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TpAppBar(
        role: TpAppBarRole.modalForm,
        title: const Text('加入行程'),
        onCancel: () => Navigator.of(context).maybePop(),
        primaryActionLabel: '加入',
        primaryActionEnabled: false,
        onPrimaryAction: () {},
      ),
      body: loading
          ? const AppListLoadingSkeleton(
              key: ValueKey('add-to-trip-route-loading'),
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(TpSpacing.s6),
                child: Text(message ?? '載入失敗', textAlign: TextAlign.center),
              ),
            ),
    );
  }
}

AddToTripDirect? _directArgsFromUri(Uri uri) {
  final query = uri.queryParameters;
  final placeId =
      _queryValue(query, 'place_id') ?? _queryValue(query, 'placeId');
  final name = _queryValue(query, 'name');
  final lat = double.tryParse(query['lat'] ?? '');
  final lng = double.tryParse(query['lng'] ?? '');
  if (placeId == null || name == null || lat == null || lng == null) {
    return null;
  }
  return AddToTripDirect(
    poi: PoiSearchResult(
      placeId: placeId,
      name: name,
      address: _queryValue(query, 'address'),
      lat: lat,
      lng: lng,
      category: _queryValue(query, 'category'),
    ),
  );
}

String? _queryValue(Map<String, String> query, String key) {
  final value = query[key]?.trim();
  if (value == null || value.isEmpty) return null;
  return value;
}

String _routeErrorMessage(Object error) {
  final message = error.toString();
  const prefix = 'Bad state: ';
  return message.startsWith(prefix)
      ? message.substring(prefix.length)
      : message;
}
