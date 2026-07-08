/// 收藏 POI 加入行程 fast-path 表單。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/providers.dart';
import '../../models/day.dart';
import '../../models/poi.dart';
import '../../models/trip.dart';
import '../../theme/tokens.dart';
import 'favorites_screen.dart';
import '../trip_detail/trip_providers.dart';

/// add-to-trip 表單使用的行程清單。
final favoriteTargetTripsProvider = FutureProvider<List<TripSummary>>((ref) {
  return ref.watch(tripRepositoryProvider).fetchMyTrips();
});

/// add-to-trip 表單使用的目標行程 day 清單。
final favoriteTargetDaysProvider = FutureProvider.family<List<TripDay>, String>(
  (ref, tripId) {
    return ref.watch(tripRepositoryProvider).fetchDays(tripId);
  },
);

/// `/favorites/:favoriteId/add-to-trip`。
class AddPoiFavoriteToTripScreen extends ConsumerStatefulWidget {
  const AddPoiFavoriteToTripScreen({
    super.key,
    this.favoriteId,
    this.directPoi,
  });

  final int? favoriteId;
  final PoiSearchResult? directPoi;

  @override
  ConsumerState<AddPoiFavoriteToTripScreen> createState() =>
      _AddPoiFavoriteToTripScreenState();
}

class _AddPoiFavoriteToTripScreenState
    extends ConsumerState<AddPoiFavoriteToTripScreen> {
  final _startTimeController = TextEditingController(text: '09:00');
  final _endTimeController = TextEditingController(text: '10:00');
  String? _selectedTripId;
  int? _selectedDayNum;
  bool _isSubmitting = false;
  String? _submitError;

  static final _timePattern = RegExp(r'^\d{2}:\d{2}$');

  @override
  void dispose() {
    _startTimeController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final directPoi = widget.directPoi;
    if (directPoi == null && widget.favoriteId == null) {
      return const Scaffold(
        appBar: _AddToTripAppBar(title: '加入行程'),
        body: _CenteredMessage(message: '景點資料缺漏，請從探索頁重新進入'),
      );
    }
    final tripsAsync = ref.watch(favoriteTargetTripsProvider);

    return Scaffold(
      appBar: _AddToTripAppBar(
        title: directPoi == null ? '加入收藏到行程' : '加入景點到行程',
      ),
      body: directPoi != null
          ? tripsAsync.when(
              data: (trips) => _buildWithTarget(
                _PoiTarget.fromSearchResult(directPoi),
                trips,
              ),
              error: (error, stackTrace) => _LoadErrorState(
                message: '無法取得行程清單',
                onRetry: () => ref.invalidate(favoriteTargetTripsProvider),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
            )
          : ref
                .watch(poiFavoritesProvider)
                .when(
                  data: (favorites) => tripsAsync.when(
                    data: (trips) => _buildWithFavoriteData(favorites, trips),
                    error: (error, stackTrace) => _LoadErrorState(
                      message: '無法取得行程清單',
                      onRetry: () =>
                          ref.invalidate(favoriteTargetTripsProvider),
                    ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, stackTrace) => _LoadErrorState(
                    message: '無法取得收藏資料',
                    onRetry: () => ref.invalidate(poiFavoritesProvider),
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                ),
    );
  }

  Widget _buildWithFavoriteData(
    List<PoiFavorite> favorites,
    List<TripSummary> trips,
  ) {
    final favoriteId = widget.favoriteId;
    final favorite = favoriteId == null
        ? null
        : _findFavorite(favorites, favoriteId);
    if (favorite == null) {
      return const _CenteredMessage(message: '找不到這筆收藏');
    }
    return _buildWithTarget(_PoiTarget.fromFavorite(favorite), trips);
  }

  Widget _buildWithTarget(_PoiTarget target, List<TripSummary> trips) {
    if (trips.isEmpty) {
      return const _CenteredMessage(message: '還沒有可加入的行程');
    }

    final effectiveTripId = _selectedTripId ?? trips.first.tripId;
    final daysAsync = ref.watch(favoriteTargetDaysProvider(effectiveTripId));

    return daysAsync.when(
      data: (days) => _buildForm(
        target: target,
        trips: trips,
        days: days,
        effectiveTripId: effectiveTripId,
      ),
      error: (error, stackTrace) => _LoadErrorState(
        message: '無法取得行程日期',
        onRetry: () =>
            ref.invalidate(favoriteTargetDaysProvider(effectiveTripId)),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildForm({
    required _PoiTarget target,
    required List<TripSummary> trips,
    required List<TripDay> days,
    required String effectiveTripId,
  }) {
    if (days.isEmpty) {
      return const _CenteredMessage(message: '這個行程還沒有 day 可以加入');
    }
    final effectiveDayNum = _resolveDayNum(days);

    return ListView(
      padding: const EdgeInsets.all(TpSpacing.s4),
      children: [
        _FavoriteSummaryCard(target: target),
        const SizedBox(height: TpSpacing.s4),
        DropdownButtonFormField<String>(
          initialValue: effectiveTripId,
          decoration: const InputDecoration(
            labelText: '行程',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final trip in trips)
              DropdownMenuItem(
                value: trip.tripId,
                child: Text(_tripTitle(trip)),
              ),
          ],
          onChanged: _isSubmitting
              ? null
              : (tripId) {
                  if (tripId == null) return;
                  setState(() {
                    _selectedTripId = tripId;
                    _selectedDayNum = null;
                    _submitError = null;
                  });
                },
        ),
        const SizedBox(height: TpSpacing.s3),
        DropdownButtonFormField<int>(
          initialValue: effectiveDayNum,
          decoration: const InputDecoration(
            labelText: '日期',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final day in days)
              DropdownMenuItem(value: day.dayNum, child: Text(_dayTitle(day))),
          ],
          onChanged: _isSubmitting
              ? null
              : (dayNum) {
                  setState(() {
                    _selectedDayNum = dayNum;
                    _submitError = null;
                  });
                },
        ),
        const SizedBox(height: TpSpacing.s3),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _startTimeController,
                decoration: const InputDecoration(
                  labelText: '開始時間',
                  border: OutlineInputBorder(),
                ),
                enabled: !_isSubmitting,
                keyboardType: TextInputType.datetime,
              ),
            ),
            const SizedBox(width: TpSpacing.s3),
            Expanded(
              child: TextFormField(
                controller: _endTimeController,
                decoration: const InputDecoration(
                  labelText: '結束時間',
                  border: OutlineInputBorder(),
                ),
                enabled: !_isSubmitting,
                keyboardType: TextInputType.datetime,
              ),
            ),
          ],
        ),
        if (_submitError != null) ...[
          const SizedBox(height: TpSpacing.s3),
          _InlineError(message: _submitError!),
        ],
        const SizedBox(height: TpSpacing.s5),
        FilledButton.icon(
          icon: _isSubmitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_location_alt_outlined),
          label: const Text('加入行程'),
          onPressed: _isSubmitting
              ? null
              : () => _submit(
                  target: target,
                  tripId: effectiveTripId,
                  dayNum: effectiveDayNum,
                ),
        ),
      ],
    );
  }

  PoiFavorite? _findFavorite(List<PoiFavorite> favorites, int favoriteId) {
    for (final favorite in favorites) {
      if (favorite.id == favoriteId) return favorite;
    }
    return null;
  }

  int _resolveDayNum(List<TripDay> days) {
    final selectedDayNum = _selectedDayNum;
    if (selectedDayNum != null &&
        days.any((day) => day.dayNum == selectedDayNum)) {
      return selectedDayNum;
    }
    return days.first.dayNum;
  }

  Future<void> _submit({
    required _PoiTarget target,
    required String tripId,
    required int dayNum,
  }) async {
    final startTime = _startTimeController.text.trim();
    final endTime = _endTimeController.text.trim();
    if (!_timePattern.hasMatch(startTime) || !_timePattern.hasMatch(endTime)) {
      setState(() {
        _submitError = '時間格式需為 HH:MM';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });
    try {
      final repository = ref.read(tripRepositoryProvider);
      final directPoi = target.directPoi;
      if (directPoi != null) {
        await repository.createEntryFromPoiSearchResult(
          tripId: tripId,
          dayNum: dayNum,
          poi: directPoi,
          startTime: startTime,
          endTime: endTime,
        );
        unawaited(
          repository
              .recomputeTravel(tripId, dayNum: dayNum)
              .catchError((Object _) {}),
        );
      } else {
        await repository.addPoiFavoriteToTrip(
          target.favoriteId!,
          tripId: tripId,
          dayNum: dayNum,
          startTime: startTime,
          endTime: endTime,
        );
      }
      ref.invalidate(tripDaysProvider(tripId));
      ref.invalidate(favoriteTargetDaysProvider(tripId));
      ref.invalidate(poiFavoritesProvider);
      if (!mounted) return;
      context.go('/trips/$tripId');
    } on Exception {
      if (!mounted) return;
      setState(() {
        _submitError = '加入行程失敗，請確認時間沒有衝突後再試一次';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _tripTitle(TripSummary trip) {
    final title = trip.title?.trim();
    if (title != null && title.isNotEmpty) return title;
    return trip.name;
  }

  String _dayTitle(TripDay day) => 'Day ${day.dayNum} · ${day.displayTitle}';
}

class _AddToTripAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _AddToTripAppBar({required this.title});

  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(title: Text(title));
  }
}

class _PoiTarget {
  const _PoiTarget({
    required this.name,
    this.address,
    this.type,
    this.rating,
    this.favoriteId,
    this.directPoi,
  });

  final String name;
  final String? address;
  final String? type;
  final double? rating;
  final int? favoriteId;
  final PoiSearchResult? directPoi;

  factory _PoiTarget.fromFavorite(PoiFavorite favorite) {
    return _PoiTarget(
      name: favorite.displayName,
      address: favorite.poiAddress,
      type: favorite.poiType,
      rating: favorite.poiRating,
      favoriteId: favorite.id,
    );
  }

  factory _PoiTarget.fromSearchResult(PoiSearchResult result) {
    return _PoiTarget(
      name: result.name,
      address: result.address,
      type: result.category,
      rating: result.rating,
      directPoi: result,
    );
  }
}

class _FavoriteSummaryCard extends StatelessWidget {
  const _FavoriteSummaryCard({required this.target});

  final _PoiTarget target;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metaStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(target.name, style: theme.textTheme.titleMedium),
            const SizedBox(height: TpSpacing.s1),
            Text(poiTypeLabel(target.type), style: metaStyle),
            if (target.rating != null) ...[
              const SizedBox(height: TpSpacing.s1),
              Text(target.rating!.toStringAsFixed(1), style: metaStyle),
            ],
            if (target.address != null &&
                target.address!.trim().isNotEmpty) ...[
              const SizedBox(height: TpSpacing.s2),
              Text(target.address!, style: metaStyle),
            ],
          ],
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: const BorderRadius.all(Radius.circular(TpRadius.md)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s3),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: colorScheme.error),
            const SizedBox(width: TpSpacing.s2),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadErrorState extends StatelessWidget {
  const _LoadErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: TpSpacing.s3),
          FilledButton(onPressed: onRetry, child: const Text('重試')),
        ],
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s6),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
