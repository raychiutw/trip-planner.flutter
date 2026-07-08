/// 新增景點到行程 day 的 fast-path 表單。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/providers.dart';
import '../../api/trip_repository.dart';
import '../../models/day.dart';
import '../../models/entry.dart';
import '../../models/poi.dart';
import '../../models/trip.dart';
import '../../theme/tokens.dart';
import '../favorites/favorites_screen.dart';
import '../map/map_adapter.dart';
import 'trip_providers.dart';

class AddEntryScreen extends ConsumerStatefulWidget {
  const AddEntryScreen({
    super.key,
    required this.tripId,
    this.initialDayNum,
    this.initialSource,
  });

  final String tripId;
  final int? initialDayNum;
  final String? initialSource;

  @override
  ConsumerState<AddEntryScreen> createState() => _AddEntryScreenState();
}

class _AddEntryScreenState extends ConsumerState<AddEntryScreen> {
  final _queryController = TextEditingController();
  final _startTimeController = TextEditingController(text: '09:00');
  final _endTimeController = TextEditingController(text: '10:00');
  final _customTitleController = TextEditingController();
  final _customLatController = TextEditingController();
  final _customLngController = TextEditingController();
  final _customNoteController = TextEditingController();
  AsyncValue<List<PoiSearchResult>>? _searchState;
  int? _selectedDayNum;
  String _source = 'search';
  String _customPoiType = 'attraction';
  String? _submitError;
  String? _submittingKey;

  static final _timePattern = RegExp(r'^\d{2}:\d{2}$');

  @override
  void initState() {
    super.initState();
    _selectedDayNum = widget.initialDayNum;
    _source = _normalizeSource(widget.initialSource);
  }

  @override
  void dispose() {
    _queryController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _customTitleController.dispose();
    _customLatController.dispose();
    _customLngController.dispose();
    _customNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(tripDetailProvider(widget.tripId));
    final daysAsync = ref.watch(tripDaysProvider(widget.tripId));
    final tripTitle = _tripTitle(tripAsync.value);

    return Scaffold(
      appBar: AppBar(
        title: Text(tripTitle == null ? '新增景點' : '新增景點 · $tripTitle'),
      ),
      body: daysAsync.when(
        data: (days) => _buildWithDays(days, tripAsync.value),
        error: (error, stackTrace) => _LoadErrorState(
          message: '無法取得行程日期',
          onRetry: () => ref.invalidate(tripDaysProvider(widget.tripId)),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildWithDays(List<TripDay> days, Trip? trip) {
    if (days.isEmpty) {
      return const _CenteredMessage(message: '這趟行程還沒有 day 可以加入');
    }
    final effectiveDayNum = _resolveDayNum(days);

    return ListView(
      padding: const EdgeInsets.all(TpSpacing.s4),
      children: [
        _DayAndTimeFields(
          days: days,
          effectiveDayNum: effectiveDayNum,
          startTimeController: _startTimeController,
          endTimeController: _endTimeController,
          enabled: _submittingKey == null,
          onDayChanged: (dayNum) {
            setState(() {
              _selectedDayNum = dayNum;
              _submitError = null;
            });
          },
        ),
        const SizedBox(height: TpSpacing.s4),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'search',
              icon: Icon(Icons.search),
              label: Text('搜尋'),
            ),
            ButtonSegment(
              value: 'favorites',
              icon: Icon(Icons.favorite_border),
              label: Text('收藏'),
            ),
            ButtonSegment(
              value: 'custom',
              icon: Icon(Icons.add_location_alt_outlined),
              label: Text('自訂'),
            ),
          ],
          selected: {_source},
          onSelectionChanged: _submittingKey == null
              ? (selection) => setState(() {
                  _source = selection.single;
                  _submitError = null;
                })
              : null,
        ),
        if (_submitError != null) ...[
          const SizedBox(height: TpSpacing.s3),
          _InlineError(message: _submitError!),
        ],
        const SizedBox(height: TpSpacing.s4),
        switch (_source) {
          'favorites' => _buildFavoritesTab(effectiveDayNum),
          'custom' => _buildCustomTab(days, effectiveDayNum, trip),
          _ => _buildSearchTab(effectiveDayNum),
        },
      ],
    );
  }

  Widget _buildSearchTab(int dayNum) {
    final searchState = _searchState;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('add-entry-search-input'),
                controller: _queryController,
                decoration: const InputDecoration(
                  labelText: '搜尋景點',
                  border: OutlineInputBorder(),
                ),
                enabled: _submittingKey == null,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _runSearch(),
              ),
            ),
            const SizedBox(width: TpSpacing.s2),
            IconButton.filledTonal(
              tooltip: '搜尋',
              icon: const Icon(Icons.search),
              onPressed: _submittingKey == null ? _runSearch : null,
            ),
          ],
        ),
        const SizedBox(height: TpSpacing.s4),
        if (searchState == null)
          const _CenteredMessage(message: '輸入關鍵字後，選一個景點加入這一天')
        else
          searchState.when(
            data: (results) {
              if (results.isEmpty) {
                return const _CenteredMessage(message: '找不到符合的景點');
              }
              return Column(
                children: [
                  for (var index = 0; index < results.length; index++) ...[
                    _AddSearchResultCard(
                      result: results[index],
                      isSubmitting:
                          _submittingKey == 'search:${results[index].placeId}',
                      onAdd: () => _addSearchResult(results[index], dayNum),
                    ),
                    if (index != results.length - 1)
                      const SizedBox(height: TpSpacing.s3),
                  ],
                ],
              );
            },
            error: (error, stackTrace) =>
                const _CenteredMessage(message: '搜尋失敗，請確認至少輸入 2 個字'),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(TpSpacing.s6),
                child: CircularProgressIndicator(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFavoritesTab(int dayNum) {
    return ref
        .watch(poiFavoritesProvider)
        .when(
          data: (favorites) {
            if (favorites.isEmpty) {
              return const _CenteredMessage(message: '還沒有收藏景點');
            }
            return Column(
              children: [
                for (var index = 0; index < favorites.length; index++) ...[
                  _AddFavoriteCard(
                    favorite: favorites[index],
                    isSubmitting:
                        _submittingKey == 'favorite:${favorites[index].id}',
                    onAdd: () => _addFavorite(favorites[index], dayNum),
                  ),
                  if (index != favorites.length - 1)
                    const SizedBox(height: TpSpacing.s3),
                ],
              ],
            );
          },
          error: (error, stackTrace) => _LoadErrorState(
            message: '無法取得收藏資料',
            onRetry: () => ref.invalidate(poiFavoritesProvider),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
        );
  }

  Widget _buildCustomTab(List<TripDay> days, int dayNum, Trip? trip) {
    final pickedPoint = _customPointFromFields();
    final mapCenter =
        pickedPoint ?? _initialCustomMapCenter(days, dayNum, trip);
    final enabled = _submittingKey == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: const ValueKey('add-entry-custom-title'),
          controller: _customTitleController,
          decoration: const InputDecoration(
            labelText: '景點名稱',
            border: OutlineInputBorder(),
          ),
          enabled: enabled,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: TpSpacing.s3),
        DropdownButtonFormField<String>(
          key: const ValueKey('add-entry-custom-type'),
          initialValue: _customPoiType,
          decoration: const InputDecoration(
            labelText: '類型',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'attraction', child: Text('景點')),
            DropdownMenuItem(value: 'restaurant', child: Text('餐廳')),
            DropdownMenuItem(value: 'shopping', child: Text('購物')),
            DropdownMenuItem(value: 'hotel', child: Text('飯店')),
            DropdownMenuItem(value: 'transport', child: Text('交通')),
            DropdownMenuItem(value: 'activity', child: Text('活動')),
            DropdownMenuItem(value: 'parking', child: Text('停車')),
            DropdownMenuItem(value: 'other', child: Text('其他')),
          ],
          onChanged: enabled
              ? (value) => setState(() {
                  _customPoiType = value ?? 'attraction';
                  _submitError = null;
                })
              : null,
        ),
        const SizedBox(height: TpSpacing.s3),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                key: const ValueKey('add-entry-custom-lat'),
                controller: _customLatController,
                decoration: const InputDecoration(
                  labelText: '緯度',
                  border: OutlineInputBorder(),
                ),
                enabled: enabled,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                onChanged: (_) => setState(() => _submitError = null),
              ),
            ),
            const SizedBox(width: TpSpacing.s3),
            Expanded(
              child: TextFormField(
                key: const ValueKey('add-entry-custom-lng'),
                controller: _customLngController,
                decoration: const InputDecoration(
                  labelText: '經度',
                  border: OutlineInputBorder(),
                ),
                enabled: enabled,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                onChanged: (_) => setState(() => _submitError = null),
              ),
            ),
          ],
        ),
        const SizedBox(height: TpSpacing.s3),
        _CustomLocationPicker(
          center: mapCenter,
          pickedPoint: pickedPoint,
          enabled: enabled,
          onPicked: _setCustomPoint,
        ),
        const SizedBox(height: TpSpacing.s3),
        TextFormField(
          key: const ValueKey('add-entry-custom-note'),
          controller: _customNoteController,
          decoration: const InputDecoration(
            labelText: '備註（選填）',
            border: OutlineInputBorder(),
          ),
          enabled: enabled,
          minLines: 2,
          maxLines: 4,
        ),
        const SizedBox(height: TpSpacing.s4),
        FilledButton.icon(
          key: const ValueKey('add-entry-add-custom'),
          icon: _submittingKey == 'custom'
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_location_alt_outlined),
          label: const Text('加入自訂景點'),
          onPressed: enabled ? () => _addCustomEntry(dayNum) : null,
        ),
      ],
    );
  }

  Future<void> _runSearch() async {
    final query = _queryController.text.trim();
    if (query.length < 2) {
      setState(() {
        _searchState = AsyncError(
          ArgumentError('query too short'),
          StackTrace.current,
        );
      });
      return;
    }
    setState(() {
      _searchState = const AsyncLoading();
      _submitError = null;
    });
    final nextState = await AsyncValue.guard(
      () => ref
          .read(tripRepositoryProvider)
          .searchPois(query: query, region: null, limit: 20),
    );
    if (!mounted) return;
    setState(() => _searchState = nextState);
  }

  Future<void> _addSearchResult(PoiSearchResult result, int dayNum) async {
    if (!_validateTimes()) return;
    final startTime = _startTimeController.text.trim();
    final endTime = _endTimeController.text.trim();
    setState(() {
      _submittingKey = 'search:${result.placeId}';
      _submitError = null;
    });
    try {
      final repository = ref.read(tripRepositoryProvider);
      await repository.createEntryFromPoiSearchResult(
        tripId: widget.tripId,
        dayNum: dayNum,
        poi: result,
        startTime: startTime,
        endTime: endTime,
      );
      _afterEntryCreated(repository, dayNum);
    } on Exception {
      _showSubmitError();
    } finally {
      if (mounted) setState(() => _submittingKey = null);
    }
  }

  Future<void> _addFavorite(PoiFavorite favorite, int dayNum) async {
    if (!_validateTimes()) return;
    final startTime = _startTimeController.text.trim();
    final endTime = _endTimeController.text.trim();
    setState(() {
      _submittingKey = 'favorite:${favorite.id}';
      _submitError = null;
    });
    try {
      final repository = ref.read(tripRepositoryProvider);
      await repository.addPoiFavoriteToTrip(
        favorite.id,
        tripId: widget.tripId,
        dayNum: dayNum,
        startTime: startTime,
        endTime: endTime,
      );
      _afterEntryCreated(repository, dayNum);
    } on Exception {
      _showSubmitError();
    } finally {
      if (mounted) setState(() => _submittingKey = null);
    }
  }

  Future<void> _addCustomEntry(int dayNum) async {
    if (!_validateTimes()) return;
    final name = _customTitleController.text.trim();
    if (name.isEmpty) {
      setState(() => _submitError = '請輸入景點名稱');
      return;
    }
    final lat = double.tryParse(_customLatController.text.trim());
    final lng = double.tryParse(_customLngController.text.trim());
    if (!_isValidCustomCoord(lat, lng)) {
      setState(() => _submitError = '請在地圖上選位置，或輸入有效的緯度/經度');
      return;
    }

    final startTime = _startTimeController.text.trim();
    final endTime = _endTimeController.text.trim();
    final note = _customNoteController.text.trim();
    setState(() {
      _submittingKey = 'custom';
      _submitError = null;
    });
    try {
      final repository = ref.read(tripRepositoryProvider);
      await repository.createCustomEntry(
        tripId: widget.tripId,
        dayNum: dayNum,
        name: name,
        note: note.isEmpty ? null : note,
        lat: lat!,
        lng: lng!,
        poiType: _customPoiType,
        startTime: startTime,
        endTime: endTime,
      );
      _afterEntryCreated(repository, dayNum);
    } on Exception {
      _showSubmitError();
    } finally {
      if (mounted) setState(() => _submittingKey = null);
    }
  }

  void _afterEntryCreated(TripRepository repository, int dayNum) {
    unawaited(
      repository
          .recomputeTravel(widget.tripId, dayNum: dayNum)
          .catchError((Object _) {}),
    );
    ref.invalidate(tripDaysProvider(widget.tripId));
    if (mounted) context.go('/trips/${widget.tripId}');
  }

  bool _validateTimes() {
    final startTime = _startTimeController.text.trim();
    final endTime = _endTimeController.text.trim();
    if (!_timePattern.hasMatch(startTime) || !_timePattern.hasMatch(endTime)) {
      setState(() => _submitError = '時間格式需為 HH:MM');
      return false;
    }
    return true;
  }

  void _showSubmitError() {
    if (!mounted) return;
    setState(() {
      _submitError = '新增景點失敗，請確認時間沒有衝突後再試一次';
    });
  }

  int _resolveDayNum(List<TripDay> days) {
    final selectedDayNum = _selectedDayNum;
    if (selectedDayNum != null &&
        days.any((day) => day.dayNum == selectedDayNum)) {
      return selectedDayNum;
    }
    return days.first.dayNum;
  }

  String _normalizeSource(String? value) {
    return switch (value?.trim()) {
      'favorites' => 'favorites',
      'custom' => 'custom',
      _ => 'search',
    };
  }

  TripMapPoint? _customPointFromFields() {
    final lat = double.tryParse(_customLatController.text.trim());
    final lng = double.tryParse(_customLngController.text.trim());
    if (!_isValidCustomCoord(lat, lng)) return null;
    return TripMapPoint(lat!, lng!);
  }

  bool _isValidCustomCoord(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  void _setCustomPoint(TripMapPoint point) {
    _customLatController.text = point.latitude.toStringAsFixed(6);
    _customLngController.text = point.longitude.toStringAsFixed(6);
    setState(() => _submitError = null);
  }

  TripMapPoint _initialCustomMapCenter(
    List<TripDay> days,
    int dayNum,
    Trip? trip,
  ) {
    TripDay? selectedDay;
    for (final day in days) {
      if (day.dayNum == dayNum) {
        selectedDay = day;
        break;
      }
    }
    final timeline = selectedDay?.timeline ?? const <TimelineEntry>[];
    for (final entry in timeline.reversed) {
      final lat = entry.master?.lat;
      final lng = entry.master?.lng;
      if (lat != null && lng != null) return TripMapPoint(lat, lng);
    }
    final hotelLocation = selectedDay?.hotel?.location;
    if (hotelLocation?.lat != null && hotelLocation?.lng != null) {
      return TripMapPoint(hotelLocation!.lat!, hotelLocation.lng!);
    }
    for (final destination in trip?.destinations ?? const <TripDestination>[]) {
      final lat = destination.lat;
      final lng = destination.lng;
      if (lat != null && lng != null) return TripMapPoint(lat, lng);
    }
    return const TripMapPoint(35.681236, 139.767125);
  }

  String? _tripTitle(Trip? trip) {
    final title = trip?.title?.trim();
    if (title != null && title.isNotEmpty) return title;
    final name = trip?.name.trim();
    if (name != null && name.isNotEmpty) return name;
    return null;
  }
}

class _DayAndTimeFields extends StatelessWidget {
  const _DayAndTimeFields({
    required this.days,
    required this.effectiveDayNum,
    required this.startTimeController,
    required this.endTimeController,
    required this.enabled,
    required this.onDayChanged,
  });

  final List<TripDay> days;
  final int effectiveDayNum;
  final TextEditingController startTimeController;
  final TextEditingController endTimeController;
  final bool enabled;
  final ValueChanged<int?> onDayChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
          onChanged: enabled ? onDayChanged : null,
        ),
        const SizedBox(height: TpSpacing.s3),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                key: const ValueKey('add-entry-start-time'),
                controller: startTimeController,
                decoration: const InputDecoration(
                  labelText: '開始時間',
                  border: OutlineInputBorder(),
                ),
                enabled: enabled,
                keyboardType: TextInputType.datetime,
              ),
            ),
            const SizedBox(width: TpSpacing.s3),
            Expanded(
              child: TextFormField(
                key: const ValueKey('add-entry-end-time'),
                controller: endTimeController,
                decoration: const InputDecoration(
                  labelText: '結束時間',
                  border: OutlineInputBorder(),
                ),
                enabled: enabled,
                keyboardType: TextInputType.datetime,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _dayTitle(TripDay day) => 'Day ${day.dayNum} · ${day.displayTitle}';
}

class _CustomLocationPicker extends StatefulWidget {
  const _CustomLocationPicker({
    required this.center,
    required this.pickedPoint,
    required this.enabled,
    required this.onPicked,
  });

  final TripMapPoint center;
  final TripMapPoint? pickedPoint;
  final bool enabled;
  final ValueChanged<TripMapPoint> onPicked;

  @override
  State<_CustomLocationPicker> createState() => _CustomLocationPickerState();
}

class _CustomLocationPickerState extends State<_CustomLocationPicker> {
  final FlutterTripMapController _mapController = FlutterTripMapController();

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final pickedPoint = widget.pickedPoint;
    return SizedBox(
      key: const ValueKey('add-entry-custom-map'),
      height: 240,
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(TpRadius.md)),
        child: Stack(
          children: [
            FlutterMapCanvas(
              controller: _mapController,
              tilePreset: kTripMapTilePresets.first,
              initialFitPoints: const [],
              initialCenter: widget.center,
              initialZoom: 14,
              onTap: widget.enabled ? widget.onPicked : null,
              markers: [
                if (pickedPoint != null)
                  TripMapMarker(
                    point: pickedPoint,
                    width: 40,
                    height: 40,
                    child: Icon(
                      Icons.location_pin,
                      color: colorScheme.primary,
                      size: 40,
                    ),
                  ),
              ],
            ),
            Positioned(
              left: TpSpacing.s2,
              top: TpSpacing.s2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surface.withValues(alpha: 0.92),
                  borderRadius: const BorderRadius.all(
                    Radius.circular(TpRadius.sm),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TpSpacing.s2,
                    vertical: TpSpacing.s1,
                  ),
                  child: Text(
                    pickedPoint == null
                        ? '點地圖選位置'
                        : '${pickedPoint.latitude.toStringAsFixed(4)}, ${pickedPoint.longitude.toStringAsFixed(4)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddSearchResultCard extends StatelessWidget {
  const _AddSearchResultCard({
    required this.result,
    required this.isSubmitting,
    required this.onAdd,
  });

  final PoiSearchResult result;
  final bool isSubmitting;
  final VoidCallback onAdd;

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
            Text(result.name, style: theme.textTheme.titleMedium),
            const SizedBox(height: TpSpacing.s1),
            Wrap(
              spacing: TpSpacing.s2,
              runSpacing: TpSpacing.s1,
              children: [
                Text(poiTypeLabel(result.category), style: metaStyle),
                if (result.rating != null)
                  Text(result.rating!.toStringAsFixed(1), style: metaStyle),
              ],
            ),
            if (result.address != null &&
                result.address!.trim().isNotEmpty) ...[
              const SizedBox(height: TpSpacing.s2),
              Text(result.address!, style: metaStyle),
            ],
            const SizedBox(height: TpSpacing.s3),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                key: ValueKey('add-entry-add-search-${result.placeId}'),
                icon: isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_location_alt_outlined),
                label: const Text('加入行程'),
                onPressed: isSubmitting ? null : onAdd,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddFavoriteCard extends StatelessWidget {
  const _AddFavoriteCard({
    required this.favorite,
    required this.isSubmitting,
    required this.onAdd,
  });

  final PoiFavorite favorite;
  final bool isSubmitting;
  final VoidCallback onAdd;

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
            Text(favorite.displayName, style: theme.textTheme.titleMedium),
            const SizedBox(height: TpSpacing.s1),
            Wrap(
              spacing: TpSpacing.s2,
              runSpacing: TpSpacing.s1,
              children: [
                Text(poiTypeLabel(favorite.poiType), style: metaStyle),
                if (favorite.poiRating != null)
                  Text(
                    favorite.poiRating!.toStringAsFixed(1),
                    style: metaStyle,
                  ),
              ],
            ),
            if (favorite.poiAddress != null &&
                favorite.poiAddress!.trim().isNotEmpty) ...[
              const SizedBox(height: TpSpacing.s2),
              Text(favorite.poiAddress!, style: metaStyle),
            ],
            const SizedBox(height: TpSpacing.s3),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                key: ValueKey('add-entry-add-favorite-${favorite.id}'),
                icon: isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_location_alt_outlined),
                label: const Text('加入行程'),
                onPressed: isSubmitting ? null : onAdd,
              ),
            ),
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
