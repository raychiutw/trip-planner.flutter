import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api_error.dart';
import '../../../api/providers.dart';
import '../../../app/adaptive.dart';
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
  String? _tripId;
  int? _dayNum;
  TimeOfDay _start = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 11, minute: 0);
  bool _submitting = false;
  bool _dirty = false;

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

  Future<void> _pickTime(bool isStart) async {
    final picked = await showAppTimePicker(
      context,
      initialTime: isStart ? _start : _end,
    );
    if (picked != null) {
      setState(() {
        isStart ? _start = picked : _end = picked;
        _dirty = true;
      });
    }
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
    final trips = switch (tripsAsync) {
      AsyncData<List<TripSummary>>(:final value) => value,
      _ => const <TripSummary>[],
    };
    final tripId = _tripId ?? (trips.isEmpty ? null : trips.first.tripId);
    final daysAsync = tripId == null
        ? null
        : ref.watch(tripDaysProvider(tripId));
    final days = switch (daysAsync) {
      AsyncData<List<TripDay>>(:final value) => value,
      _ => const <TripDay>[],
    };
    final dayNum = _dayNum ?? (days.isEmpty ? null : days.first.dayNum);
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
        body: tripsAsync.when(
          loading: () => const AppListLoadingSkeleton(
            key: ValueKey('add-to-trip-loading'),
          ),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(TpSpacing.s6),
              child: Text('無法載入行程清單:$e', textAlign: TextAlign.center),
            ),
          ),
          data: (trips) => _form(
            context,
            trips: trips,
            tripId: tripId,
            daysAsync: daysAsync,
            days: days,
            dayNum: dayNum,
          ),
        ),
      ),
    );
  }

  Widget _form(
    BuildContext context, {
    required List<TripSummary> trips,
    required String? tripId,
    required AsyncValue<List<TripDay>>? daysAsync,
    required List<TripDay> days,
    required int? dayNum,
  }) {
    return ListView(
      padding: const EdgeInsets.all(TpSpacing.s4),
      children: [
        DropdownButtonFormField<String>(
          key: const ValueKey('add-to-trip-trip'),
          initialValue: tripId,
          decoration: const InputDecoration(labelText: '行程'),
          items: [
            for (final t in trips)
              DropdownMenuItem(value: t.tripId, child: Text(t.displayTitle)),
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
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('無法載入日程:$e'),
            data: (_) => DropdownButtonFormField<int>(
              key: const ValueKey('add-to-trip-day'),
              initialValue: dayNum,
              decoration: const InputDecoration(labelText: '日期'),
              items: [
                for (final d in days)
                  DropdownMenuItem(
                    value: d.dayNum,
                    child: Text('DAY ${d.dayNum} · ${d.displayTitle}'),
                  ),
              ],
              onChanged: (v) => setState(() {
                _dayNum = v;
                _dirty = true;
              }),
            ),
          ),
        const SizedBox(height: TpSpacing.s4),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('add-to-trip-start'),
                onPressed: () => _pickTime(true),
                child: Text('開始 ${_fmt(_start)}'),
              ),
            ),
            const SizedBox(width: TpSpacing.s3),
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('add-to-trip-end'),
                onPressed: () => _pickTime(false),
                child: Text('結束 ${_fmt(_end)}'),
              ),
            ),
          ],
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
