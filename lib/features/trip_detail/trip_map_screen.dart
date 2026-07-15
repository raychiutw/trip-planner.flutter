import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/providers.dart';
import '../../app/app_feedback.dart';
import '../../models/day.dart';
import '../../models/entry.dart';
import '../../models/trip.dart';
import '../../theme/tokens.dart';
import '../../ui/tp_app_bar.dart';
import '../map/map_adapter.dart';
import '../map/map_location.dart';
import '../trips/trip_card.dart';
import '../trips/trips_list_screen.dart';
import 'trip_providers.dart';
import 'widgets/trip_section_menu.dart';

/// 地圖逐日輪替 10 色（Tailwind -500；design.md data-viz 例外 palette）。
const List<Color> kDayPinPalette = [
  Color(0xFFEF4444), // red
  Color(0xFFF97316), // orange
  Color(0xFFF59E0B), // amber
  Color(0xFF10B981), // emerald
  Color(0xFF14B8A6), // teal
  Color(0xFF0EA5E9), // sky
  Color(0xFF3B82F6), // blue
  Color(0xFF8B5CF6), // violet
  Color(0xFFD946EF), // fuchsia
  Color(0xFFF43F5E), // rose
];

/// 行程地圖：day tabs（總覽 + DAY NN）＋ 地圖 adapter ＋ 底部 entry cards。
class TripMapScreen extends ConsumerWidget {
  const TripMapScreen({
    super.key,
    required this.tripId,
    this.initialEntryId,
    this.mapBuilder,
    this.locationService,
    this.onTripSelected,
  });

  final String tripId;

  /// 初始聚焦的停留點 id，用於 `/trip/:tripId/stop/:entryId/map` deep link。
  final int? initialEntryId;

  /// 測試注入點：production 為原生 Google Maps，widget test 傳入假 renderer。
  final TripMapCanvasBuilder? mapBuilder;

  /// 測試注入點：production 用 geolocator，widget test 傳入 fake。
  final TripMapLocationService? locationService;
  final ValueChanged<String>? onTripSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daysAsync = ref.watch(tripDaysProvider(tripId));
    final trips = switch (ref.watch(myTripsProvider)) {
      AsyncData(:final value) => value,
      _ => const <TripSummary>[],
    };
    final currentTrip = _findTripSummary(trips, tripId);
    return Scaffold(
      appBar: TpAppBar(
        title: Text(currentTrip?.displayTitle ?? '行程地圖'),
        actions: [
          if (trips.length > 1)
            _TripMapTripPicker(
              currentTripId: tripId,
              trips: trips,
              onSelected: onTripSelected,
            ),
        ],
      ),
      body: daysAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(TpSpacing.s6),
            child: Text('載入失敗：$error', textAlign: TextAlign.center),
          ),
        ),
        data: (days) => _TripMapView(
          tripId: tripId,
          days: days,
          initialEntryId: initialEntryId,
          mapBuilder: mapBuilder,
          locationService: locationService,
        ),
      ),
    );
  }
}

TripSummary? _findTripSummary(List<TripSummary> trips, String tripId) {
  for (final trip in trips) {
    if (trip.tripId == tripId) return trip;
  }
  return null;
}

class _TripMapTripPicker extends StatelessWidget {
  const _TripMapTripPicker({
    required this.currentTripId,
    required this.trips,
    this.onSelected,
  });

  final String currentTripId;
  final List<TripSummary> trips;
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      key: const ValueKey('trip-map-trip-picker'),
      tooltip: '切換行程',
      icon: const Icon(Icons.swap_horiz),
      onSelected: (tripId) {
        if (tripId == currentTripId) return;
        if (onSelected != null) {
          onSelected!(tripId);
          return;
        }
        context.go('/trips/${Uri.encodeComponent(tripId)}/map');
      },
      itemBuilder: (context) {
        return [
          for (final trip in trips)
            PopupMenuItem<String>(
              key: ValueKey('trip-map-trip-pick-${trip.tripId}'),
              value: trip.tripId,
              child: _TripMapTripMenuItem(
                trip: trip,
                isActive: trip.tripId == currentTripId,
              ),
            ),
        ];
      },
    );
  }
}

class _TripMapTripMenuItem extends StatelessWidget {
  const _TripMapTripMenuItem({required this.trip, required this.isActive});

  final TripSummary trip;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = _tripMeta(trip);
    return Row(
      children: [
        Icon(
          isActive ? Icons.check : Icons.trip_origin,
          size: 18,
          color: isActive
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: TpSpacing.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                trip.displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (meta != null)
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

String? _tripMeta(TripSummary trip) {
  final parts = <String>[
    if (trip.countries != null && trip.countries!.trim().isNotEmpty)
      trip.countries!.trim(),
    if (trip.totalDays != null) '${trip.totalDays} 天',
  ];
  if (parts.isEmpty) return null;
  return parts.join(' · ');
}

/// 單一 pin：entry master 座標 + 所屬日 index（決定輪替色）與該日內序號。
class _DayPin {
  const _DayPin({
    required this.dayIndex,
    required this.dayNum,
    required this.pinNumber,
    required this.entry,
    required this.point,
  });

  final int dayIndex;
  final int dayNum;

  /// 該日內 1-based 序號（圓形 marker 上的數字）。
  final int pinNumber;
  final TimelineEntry entry;
  final TripMapPoint point;

  Color get color => kDayPinPalette[dayIndex % kDayPinPalette.length];
}

class _TripMapView extends ConsumerStatefulWidget {
  const _TripMapView({
    required this.tripId,
    required this.days,
    this.initialEntryId,
    this.mapBuilder,
    this.locationService,
  });

  final String tripId;
  final List<TripDay> days;
  final int? initialEntryId;
  final TripMapCanvasBuilder? mapBuilder;
  final TripMapLocationService? locationService;

  @override
  ConsumerState<_TripMapView> createState() => _TripMapViewState();
}

class _TripMapViewState extends ConsumerState<_TripMapView> {
  final GoogleTripMapController _mapController = GoogleTripMapController();
  TripMapPoint? _userLocation;
  bool _locating = false;

  /// 0 = 總覽，i = 第 i 日（widget.days[i - 1]）。
  int _selectedTabIndex = 0;

  /// fitCamera/move 只能在地圖 render 後呼叫。
  bool _mapIsReady = false;

  bool _initialFocusApplied = false;
  List<TripMapRoute> _routes = const [];
  bool _loadingRoutes = false;
  int _routeLoadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = _initialTabIndex();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadRoutes());
    });
  }

  @override
  void didUpdateWidget(covariant _TripMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialEntryId != widget.initialEntryId ||
        !identical(oldWidget.days, widget.days)) {
      _selectedTabIndex = _initialTabIndex();
      _initialFocusApplied = false;
      unawaited(_loadRoutes());
      if (_mapIsReady) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _applyInitialFocus();
        });
      }
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  /// 逐日萃取 master 座標非 null 的 entries 為 pins。
  List<List<_DayPin>> get _pinsByDay {
    return [
      for (final (dayIndex, day) in widget.days.indexed)
        _extractDayPins(dayIndex, day),
    ];
  }

  List<_DayPin> _extractDayPins(int dayIndex, TripDay day) {
    final dayPins = <_DayPin>[];
    for (final entry in day.timeline) {
      final lat = entry.master?.lat;
      final lng = entry.master?.lng;
      if (lat == null || lng == null) continue;
      dayPins.add(
        _DayPin(
          dayIndex: dayIndex,
          dayNum: day.dayNum,
          pinNumber: dayPins.length + 1,
          entry: entry,
          point: TripMapPoint(lat, lng),
        ),
      );
    }
    return dayPins;
  }

  List<_DayPin> _pinsForTab(int tabIndex) {
    final pinsByDay = _pinsByDay;
    if (tabIndex == 0) {
      return [for (final dayPins in pinsByDay) ...dayPins];
    }
    return pinsByDay[tabIndex - 1];
  }

  int _initialTabIndex() {
    final entryId = widget.initialEntryId;
    if (entryId == null) return 0;
    final pinsByDay = _pinsByDay;
    for (final (dayIndex, dayPins) in pinsByDay.indexed) {
      if (dayPins.any((pin) => pin.entry.id == entryId)) {
        return dayIndex + 1;
      }
    }
    return 0;
  }

  _DayPin? _initialPin() {
    final entryId = widget.initialEntryId;
    if (entryId == null) return null;
    for (final dayPins in _pinsByDay) {
      for (final pin in dayPins) {
        if (pin.entry.id == entryId) return pin;
      }
    }
    return null;
  }

  void _selectTab(int tabIndex) {
    setState(() => _selectedTabIndex = tabIndex);
    _fitToPoints([for (final pin in _pinsForTab(tabIndex)) pin.point]);
    unawaited(_loadRoutes());
  }

  List<(_DayPin, _DayPin)> _routePairsForTab(int tabIndex) {
    final days = tabIndex == 0 ? _pinsByDay : [_pinsByDay[tabIndex - 1]];
    return [
      for (final pins in days)
        for (var index = 0; index + 1 < pins.length; index++)
          (pins[index], pins[index + 1]),
    ];
  }

  Future<void> _loadRoutes() async {
    final generation = ++_routeLoadGeneration;
    final pairs = _routePairsForTab(_selectedTabIndex);
    if (pairs.isEmpty) {
      if (mounted) {
        setState(() {
          _routes = const [];
          _loadingRoutes = false;
        });
      }
      return;
    }
    setState(() => _loadingRoutes = true);
    final repository = ref.read(mapRepositoryProvider);
    final routes = await Future.wait([
      for (final (index, pair) in pairs.indexed)
        () async {
          try {
            final result = await repository.fetchRoute(
              fromLat: pair.$1.point.latitude,
              fromLng: pair.$1.point.longitude,
              toLat: pair.$2.point.latitude,
              toLng: pair.$2.point.longitude,
            );
            if (result.polyline.length < 2) return null;
            return TripMapRoute(
              id: 'day-route-$index',
              points: [
                for (final point in result.polyline)
                  TripMapPoint(point.lat, point.lng),
              ],
              color: pair.$1.color,
              strokeWidth: 5,
              borderColor: Colors.white,
              borderStrokeWidth: 1.5,
            );
          } on Exception {
            return null;
          }
        }(),
    ]);
    if (!mounted || generation != _routeLoadGeneration) return;
    setState(() {
      _routes = routes.whereType<TripMapRoute>().toList();
      _loadingRoutes = false;
    });
  }

  void _fitToPoints(List<TripMapPoint> points) {
    if (!_mapIsReady || points.isEmpty) return;
    _mapController.fitPoints(
      points,
      padding: const EdgeInsets.all(TpSpacing.s10),
      maxZoom: 16,
    );
  }

  void _focusPin(_DayPin pin) {
    if (!_mapIsReady) return;
    _mapController.move(pin.point, 16);
  }

  Future<void> _locateMe() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final service =
          widget.locationService ?? const GeolocatorTripMapLocationService();
      final point = await service.currentLocation();
      if (!mounted) return;
      setState(() => _userLocation = point);
      _mapController.move(point, 15);
    } on TripMapLocationException catch (error) {
      if (!mounted) return;
      _showLocationError(error.message);
    } on Exception {
      if (!mounted) return;
      _showLocationError('無法取得目前位置');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _showLocationError(String message) {
    showAppError(context, message, onRetry: _locateMe);
  }

  void _handleMapReady() {
    _mapIsReady = true;
    _applyInitialFocus();
  }

  void _applyInitialFocus() {
    if (_initialFocusApplied || !_mapIsReady) return;
    _initialFocusApplied = true;
    final pin = _initialPin();
    if (pin == null) return;
    _focusPin(pin);
  }

  @override
  Widget build(BuildContext context) {
    final allPins = _pinsForTab(0);
    if (allPins.isEmpty) {
      return Center(
        child: Text(
          '此行程尚無地點座標',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final visiblePins = _pinsForTab(_selectedTabIndex);
    return Column(
      children: [
        Expanded(child: _buildMap(allPins, visiblePins)),
        _buildEntryCards(context, visiblePins),
      ],
    );
  }

  Widget _buildMap(List<_DayPin> allPins, List<_DayPin> visiblePins) {
    return Stack(
      children: [
        Positioned.fill(
          child: buildTripMapCanvas(
            TripMapCanvasConfig(
              controller: _mapController,
              tilePreset: kTripMapTilePresets.first,
              initialFitPoints: [for (final pin in allPins) pin.point],
              initialPadding: const EdgeInsets.all(TpSpacing.s10),
              initialMaxZoom: 16,
              onMapReady: _handleMapReady,
              routes: _routes,
              clusterMarkers: visiblePins.length >= 12,
              markers: [
                for (final pin in visiblePins) _buildMarker(pin),
                if (_userLocation != null)
                  buildTripMapUserLocationMarker(
                    point: _userLocation!,
                    id: 'trip-map-user-location',
                  ),
              ],
            ),
            builder: widget.mapBuilder,
          ),
        ),
        if (_loadingRoutes)
          const Positioned(
            left: TpSpacing.s4,
            top: TpSpacing.s10,
            child: SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator.adaptive(strokeWidth: 2),
            ),
          ),
        Positioned(
          top: TpSpacing.s3,
          left: TpSpacing.s4,
          child: TripSectionMenu(
            section: TripSection.map,
            tripId: widget.tripId,
            days: widget.days,
            selectedDayIndex: _selectedTabIndex,
            onDaySelected: _selectTab,
          ),
        ),
        Positioned(
          top: TpSpacing.s4,
          right: TpSpacing.s4,
          child: TripMapLocateButton(
            key: const ValueKey('trip-map-locate-button'),
            locating: _locating,
            onPressed: _locateMe,
          ),
        ),
      ],
    );
  }

  TripMapMarker _buildMarker(_DayPin pin) {
    return TripMapMarker(
      id: 'map-pin-${pin.entry.id}',
      point: pin.point,
      color: pin.color,
      title: '${pin.pinNumber}. ${pin.entry.title}',
      snippet: 'DAY ${pin.dayNum}',
      glyph: '${pin.pinNumber}',
      onTap: () => _focusPin(pin),
      zIndex: 100 - pin.dayIndex,
    );
  }

  Widget _buildEntryCards(BuildContext context, List<_DayPin> visiblePins) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 104,
      child: visiblePins.isEmpty
          ? Center(
              child: Text(
                '本日尚無地點座標',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(TpSpacing.s3),
              itemCount: visiblePins.length,
              separatorBuilder: (_, _) => const SizedBox(width: TpSpacing.s2),
              itemBuilder: (context, cardIndex) =>
                  _buildEntryCard(context, visiblePins[cardIndex]),
            ),
    );
  }

  Widget _buildEntryCard(BuildContext context, _DayPin pin) {
    final theme = Theme.of(context);
    final timeText = pin.entry.startTime ?? pin.entry.time ?? '--:--';
    // 總覽模式加 D{N} 前綴標示所屬日。
    final timeLabel = _selectedTabIndex == 0
        ? 'D${pin.dayNum} · $timeText'
        : timeText;

    return SizedBox(
      width: 220,
      child: Card(
        child: InkWell(
          key: ValueKey('entry-card-${pin.entry.id}'),
          borderRadius: const BorderRadius.all(Radius.circular(TpRadius.md)),
          onTap: () => _focusPin(pin),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TpSpacing.s3,
              vertical: TpSpacing.s2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: pin.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: TpSpacing.s2),
                    Text(
                      timeLabel,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: TpSpacing.s1),
                Text(
                  pin.entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
