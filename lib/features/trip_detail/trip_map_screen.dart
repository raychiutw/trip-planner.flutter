import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/providers.dart';
import '../../app/app_feedback.dart';
import '../../models/day.dart';
import '../../models/entry.dart';
import '../../models/trip.dart';
import '../../theme/tokens.dart';
import '../../ui/tp_account_avatar_button.dart';
import '../../ui/tp_app_bar.dart';
import '../../ui/tp_bottom_accessory.dart';
import '../../ui/tp_horizontal_selector.dart';
import '../../ui/tp_root_scaffold.dart';
import '../../ui/tp_scope_menu.dart';
import '../map/map_adapter.dart';
import '../map/map_location.dart';
import '../map/map_style.dart';
import '../trips/trip_title_button.dart';
import '../trips/trips_list_screen.dart';
import 'trip_providers.dart';

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

/// 行程地圖：行程 action + DAY selector ＋ 地圖 adapter ＋ 底部 entry cards。
class TripMapScreen extends ConsumerWidget {
  const TripMapScreen({
    super.key,
    required this.tripId,
    this.initialEntryId,
    this.initialDayNum,
    this.mapBuilder,
    this.locationService,
    this.onTripSelected,
  });

  final String tripId;

  /// 初始聚焦的停留點 id，用於 `/trip/:tripId/stop/:entryId/map` deep link。
  final int? initialEntryId;

  /// 初始顯示天數，用於 timeline / map 互切時保留 DAY。
  final int? initialDayNum;

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      key: const ValueKey('trip-map-status-style'),
      value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
      child: TpRootScaffold(
        header: TpRootHeaderConfig(
          platformViewBackdrop: true,
          title: TripTitleButton(
            key: const ValueKey('trip-map-trip-picker'),
            currentTripId: tripId,
            currentTitle: currentTrip == null ? '行程' : _tripTitle(currentTrip),
            trips: trips,
            onSelected: (selectedTripId) {
              if (onTripSelected != null) {
                onTripSelected!(selectedTripId);
                return;
              }
              context.go('/trips/${Uri.encodeComponent(selectedTripId)}/map');
            },
          ),
          actions: [
            TpToolbarIconButton(
              key: const ValueKey('trip-map-notes-button'),
              tooltip: '筆記',
              onPressed: () =>
                  context.push('/trips/${Uri.encodeComponent(tripId)}/notes'),
              icon: CupertinoIcons.doc_text,
            ),
            const TpAccountAvatarButton(),
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
            initialDayNum: initialDayNum,
            mapBuilder: mapBuilder,
            locationService: locationService,
          ),
        ),
      ),
    );
  }
}

String _tripTitle(TripSummary trip) {
  final title = trip.title?.trim();
  return title == null || title.isEmpty ? trip.name : title;
}

TripSummary? _findTripSummary(List<TripSummary> trips, String tripId) {
  for (final trip in trips) {
    if (trip.tripId == tripId) return trip;
  }
  return null;
}

/// 單一地圖停留點：無座標時仍保留在水平 POI pages。
class _MapStop {
  const _MapStop({
    required this.dayIndex,
    required this.dayNum,
    required this.entry,
    this.point,
  });

  final int dayIndex;
  final int dayNum;
  final TimelineEntry entry;
  final TripMapPoint? point;

  /// 以 dayNum 取色（非陣列 index）—— 對齊 web，天數有缺口也不會配色錯位。
  Color get color => dayPinColor(dayNum);
}

/// 已取得幾何的路段。只存幾何與所屬日／端點，樣式留到 build 時依聚焦點推導。
class _RouteSegment {
  const _RouteSegment({
    required this.id,
    required this.points,
    required this.dayNum,
    required this.fromEntryId,
    required this.toEntryId,
  });

  final String id;
  final List<TripMapPoint> points;
  final int dayNum;
  final int fromEntryId;
  final int toEntryId;
}

class _TripMapView extends ConsumerStatefulWidget {
  const _TripMapView({
    required this.tripId,
    required this.days,
    this.initialEntryId,
    this.initialDayNum,
    this.mapBuilder,
    this.locationService,
  });

  final String tripId;
  final List<TripDay> days;
  final int? initialEntryId;
  final int? initialDayNum;
  final TripMapCanvasBuilder? mapBuilder;
  final TripMapLocationService? locationService;

  @override
  ConsumerState<_TripMapView> createState() => _TripMapViewState();
}

class _TripMapViewState extends ConsumerState<_TripMapView> {
  static const _dayZoom = 12.0;
  static const _poiFocusZoom = 12.0;

  final GoogleTripMapController _mapController = GoogleTripMapController();
  late final PageController _pageController;
  TripMapPoint? _userLocation;
  bool _locating = false;
  int? _activeEntryId;

  double get _poiAccessoryHeight =>
      MediaQuery.textScalerOf(context).scale(1) >= 1.2
      ? 144
      : TpBottomAccessory.height;

  EdgeInsets get _mapPadding => EdgeInsets.fromLTRB(
    TpSpacing.s10,
    TpRootGeometry.headerBottom(context) +
        TpSpacing.s2 +
        TpSpacing.tapMin +
        TpSpacing.s2 +
        TpSpacing.tapMin +
        TpSpacing.s4,
    TpSpacing.s10,
    _poiAccessoryHeight + TpRootTabGeometry.clearance(context) + TpSpacing.s6,
  );

  /// -1 = 行程 action、0 = 總覽、i = 第 i 日（widget.days[i - 1]）。
  int _selectedTabIndex = 0;

  /// fitCamera/move 只能在地圖 render 後呼叫。
  bool _mapIsReady = false;

  bool _initialFocusApplied = false;
  List<_RouteSegment> _routeSegments = const [];
  bool _loadingRoutes = false;
  int _routeLoadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = _initialTabIndex();
    final initialStops = _stopsForTab(_selectedTabIndex);
    final initialPage = _initialStopPage(initialStops);
    _activeEntryId = initialStops.isEmpty
        ? null
        : initialStops[initialPage].entry.id;
    _pageController = PageController(
      viewportFraction: 0.72,
      initialPage: initialPage,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadRoutes());
    });
  }

  @override
  void didUpdateWidget(covariant _TripMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialEntryId != widget.initialEntryId ||
        oldWidget.initialDayNum != widget.initialDayNum ||
        !identical(oldWidget.days, widget.days)) {
      _selectedTabIndex = _initialTabIndex();
      final stops = _stopsForTab(_selectedTabIndex);
      final initialPage = _initialStopPage(stops);
      _activeEntryId = stops.isEmpty ? null : stops[initialPage].entry.id;
      _initialFocusApplied = false;
      unawaited(_loadRoutes());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_pageController.hasClients) _pageController.jumpToPage(initialPage);
        if (_mapIsReady) _applyInitialFocus();
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  /// 所有 entries 都是 POI page 的資料來源。
  List<List<_MapStop>> get _stopsByDay {
    return [
      for (final (dayIndex, day) in widget.days.indexed)
        _extractDayStops(dayIndex, day),
    ];
  }

  List<_MapStop> _extractDayStops(int dayIndex, TripDay day) {
    return [
      for (final entry in day.timeline)
        _MapStop(
          dayIndex: dayIndex,
          dayNum: day.dayNum,
          entry: entry,
          point: switch ((entry.master?.lat, entry.master?.lng)) {
            (final double lat, final double lng) => TripMapPoint(lat, lng),
            _ => null,
          },
        ),
    ];
  }

  List<List<_MapStop>> get _pinsByDay => [
    for (final stops in _stopsByDay)
      [
        for (final stop in stops)
          if (stop.point != null) stop,
      ],
  ];

  List<_MapStop> _stopsForTab(int tabIndex) {
    final stopsByDay = _stopsByDay;
    if (tabIndex == 0) {
      return [for (final dayStops in stopsByDay) ...dayStops];
    }
    return stopsByDay[tabIndex - 1];
  }

  List<_MapStop> _pinsForTab(int tabIndex) {
    final pinsByDay = _pinsByDay;
    if (tabIndex == 0) {
      return [for (final dayPins in pinsByDay) ...dayPins];
    }
    return pinsByDay[tabIndex - 1];
  }

  int _initialTabIndex() {
    final entryId = widget.initialEntryId;
    if (entryId != null) {
      for (final (dayIndex, dayStops) in _stopsByDay.indexed) {
        if (dayStops.any((stop) => stop.entry.id == entryId)) {
          return dayIndex + 1;
        }
      }
    }
    final initialDayNum = widget.initialDayNum;
    if (initialDayNum != null) {
      final index = widget.days.indexWhere(
        (day) => day.dayNum == initialDayNum,
      );
      if (index >= 0) return index + 1;
    }
    return widget.days.isEmpty ? 0 : 1;
  }

  int _initialStopPage(List<_MapStop> stops) {
    final entryId = widget.initialEntryId;
    if (entryId == null) return 0;
    final index = stops.indexWhere((stop) => stop.entry.id == entryId);
    return index < 0 ? 0 : index;
  }

  _MapStop? _initialStop() {
    final entryId = widget.initialEntryId;
    if (entryId == null) return null;
    for (final dayStops in _stopsByDay) {
      for (final stop in dayStops) {
        if (stop.entry.id == entryId) return stop;
      }
    }
    return null;
  }

  void _selectTab(int tabIndex) {
    if (tabIndex == -1) {
      final dayNum = _selectedTabIndex > 0
          ? widget.days[_selectedTabIndex - 1].dayNum
          : widget.days.firstOrNull?.dayNum;
      final query = dayNum == null ? '' : '?day=$dayNum';
      context.go('/trips/${Uri.encodeComponent(widget.tripId)}$query');
      return;
    }
    final stops = _stopsForTab(tabIndex);
    setState(() {
      _selectedTabIndex = tabIndex;
      _activeEntryId = stops.firstOrNull?.entry.id;
    });
    if (_pageController.hasClients) _pageController.jumpToPage(0);
    _focusDay(_pinsForTab(tabIndex));
    unawaited(_loadRoutes());
  }

  List<(_MapStop, _MapStop)> _routePairsForTab(int tabIndex) {
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
          _routeSegments = const [];
          _loadingRoutes = false;
        });
      }
      return;
    }
    setState(() => _loadingRoutes = true);
    final repository = ref.read(mapRepositoryProvider);
    final segments = await Future.wait([
      for (final (index, pair) in pairs.indexed)
        () async {
          try {
            final result = await repository.fetchRoute(
              fromLat: pair.$1.point!.latitude,
              fromLng: pair.$1.point!.longitude,
              toLat: pair.$2.point!.latitude,
              toLng: pair.$2.point!.longitude,
            );
            if (result.polyline.length < 2) return null;
            return _RouteSegment(
              id: 'day-route-$index',
              points: [
                for (final point in result.polyline)
                  TripMapPoint(point.lat, point.lng),
              ],
              dayNum: pair.$1.dayNum,
              fromEntryId: pair.$1.entry.id,
              toEntryId: pair.$2.entry.id,
            );
          } catch (_) {
            // 單段失敗只略過該段（spec：保留 marker／卡片）。這裡必須攔下 Error
            // 而不只是 Exception —— Future.wait 是 fail-fast，漏出去會讓整趟路線
            // 全滅且 _loadingRoutes 永遠卡在 true。
            return null;
          }
        }(),
    ]);
    if (!mounted || generation != _routeLoadGeneration) return;
    setState(() {
      _routeSegments = segments.whereType<_RouteSegment>().toList();
      _loadingRoutes = false;
    });
  }

  /// 只存幾何，樣式在此依目前聚焦點推導 —— 換聚焦不必重打 /route。
  List<TripMapRoute> _buildRoutes() {
    return [
      for (final segment in _routeSegments)
        () {
          final style = tripMapRouteStyle(
            dayNum: segment.dayNum,
            isActive:
                _activeEntryId == segment.fromEntryId ||
                _activeEntryId == segment.toEntryId,
          );
          return TripMapRoute(
            id: segment.id,
            points: segment.points,
            color: style.color,
            strokeWidth: style.strokeWidth,
            opacity: style.opacity,
            dashed: style.dashed,
          );
        }(),
    ];
  }

  TripMapPoint? _centerForPins(List<_MapStop> pins) {
    if (pins.isEmpty) return null;
    return TripMapPoint(
      pins.map((pin) => pin.point!.latitude).reduce((a, b) => a + b) /
          pins.length,
      pins.map((pin) => pin.point!.longitude).reduce((a, b) => a + b) /
          pins.length,
    );
  }

  void _focusDay(List<_MapStop> pins) {
    final center = _centerForPins(pins);
    if (!_mapIsReady || center == null) return;
    _mapController.move(center, _dayZoom);
  }

  void _focusStop(_MapStop stop) {
    final point = stop.point;
    if (!_mapIsReady || point == null) return;
    _mapController.move(point, _poiFocusZoom);
  }

  void _selectStop(_MapStop stop, {bool animatePage = false}) {
    if (_activeEntryId != stop.entry.id) {
      setState(() => _activeEntryId = stop.entry.id);
    }
    if (animatePage) {
      final index = _stopsForTab(
        _selectedTabIndex,
      ).indexWhere((candidate) => candidate.entry.id == stop.entry.id);
      if (index >= 0 && _pageController.hasClients) {
        unawaited(
          _pageController.animateToPage(
            index,
            duration: TpMotion.resolve(context, TpMotion.normal),
            curve: TpMotion.appleEase,
          ),
        );
      }
    }
    _focusStop(stop);
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
    final stop = _initialStop();
    if (stop != null) {
      _focusStop(stop);
      return;
    }
    _focusDay(_pinsForTab(_selectedTabIndex));
  }

  @override
  Widget build(BuildContext context) {
    final allPins = _pinsForTab(0);
    final visiblePins = _pinsForTab(_selectedTabIndex);
    final visibleStops = _stopsForTab(_selectedTabIndex);
    return _buildMap(allPins, visiblePins, visibleStops);
  }

  Widget _buildMap(
    List<_MapStop> allPins,
    List<_MapStop> visiblePins,
    List<_MapStop> visibleStops,
  ) {
    final initialCenter =
        _centerForPins(visiblePins) ?? allPins.firstOrNull?.point;
    return Stack(
      children: [
        Positioned.fill(
          child: buildTripMapCanvas(
            TripMapCanvasConfig(
              controller: _mapController,
              tilePreset: kTripMapTilePresets.first,
              initialFitPoints: const [],
              initialCenter: initialCenter,
              initialZoom: _dayZoom,
              initialPadding: _mapPadding,
              onMapReady: _handleMapReady,
              routes: _buildRoutes(),
              clusterMarkers: visiblePins.length >= 12,
              markers: [
                for (final pin in visiblePins)
                  _buildMarker(
                    pin,
                    number:
                        visibleStops.indexWhere(
                          (stop) => stop.entry.id == pin.entry.id,
                        ) +
                        1,
                  ),
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
          Positioned(
            left: TpSpacing.s4,
            top: TpRootGeometry.headerBottom(context) + TpSpacing.s3,
            child: const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator.adaptive(strokeWidth: 2),
            ),
          ),
        Positioned(
          top: TpRootGeometry.headerBottom(context) + TpSpacing.s2,
          left: TpSpacing.s3,
          right: TpSpacing.s3,
          child: TpHorizontalSelector<int>(
            key: const ValueKey('trip-map-day-selector'),
            platformViewBackdrop: true,
            value: _selectedTabIndex,
            options: [
              const TpScopeOption(
                value: -1,
                label: '行程',
                icon: CupertinoIcons.calendar,
                isAction: true,
                key: ValueKey('trip-map-itinerary'),
              ),
              const TpScopeOption(
                value: 0,
                label: '總覽',
                key: ValueKey('trip-map-day-overview'),
              ),
              for (final (index, day) in widget.days.indexed)
                TpScopeOption(
                  value: index + 1,
                  label: 'DAY ${day.dayNum}',
                  key: ValueKey('trip-map-day-${day.dayNum}'),
                ),
            ],
            onSelected: _selectTab,
          ),
        ),
        Positioned(
          top:
              TpRootGeometry.headerBottom(context) +
              TpSpacing.s2 +
              TpSpacing.tapMin +
              TpSpacing.s2,
          right: TpSpacing.s4,
          child: TripMapLocateButton(
            key: const ValueKey('trip-map-locate-button'),
            locating: _locating,
            onPressed: _locateMe,
          ),
        ),
        if (visiblePins.isEmpty)
          Positioned(
            top:
                TpRootGeometry.headerBottom(context) +
                TpSpacing.s2 +
                TpSpacing.tapMin +
                TpSpacing.s2 +
                TpSpacing.tapMin +
                TpSpacing.s4,
            left: TpSpacing.s4,
            right: TpSpacing.s4,
            child: IgnorePointer(
              child: Text(
                '此範圍尚無地點座標',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        _buildPoiAccessory(visibleStops),
      ],
    );
  }

  TripMapMarker _buildMarker(_MapStop pin, {required int number}) {
    // 白底圓形 chip + 日別色外圈／數字；聚焦點改 accent 填底並放大（對齊 web）。
    final style = tripMapMarkerStyle(
      dayColor: pin.color,
      isFocused: pin.entry.id == _activeEntryId,
    );
    return TripMapMarker(
      id: 'map-pin-${pin.entry.id}',
      point: pin.point!,
      color: pin.color,
      style: style,
      title: '$number. ${pin.entry.title}',
      snippet: 'DAY ${pin.dayNum}',
      glyph: '$number',
      onTap: () => _selectStop(pin, animatePage: true),
      zIndex: _activeEntryId == pin.entry.id ? 1000 : 100 - pin.dayIndex,
    );
  }

  Widget _buildPoiAccessory(List<_MapStop> visibleStops) {
    return TpBottomAccessory(
      key: const ValueKey('trip-map-poi-drawer'),
      accessoryHeight: _poiAccessoryHeight,
      child: visibleStops.isEmpty
          ? Center(
              child: Text(
                '此範圍尚無停留點',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    padEnds: false,
                    scrollDirection: Axis.horizontal,
                    itemCount: visibleStops.length,
                    onPageChanged: (index) => _selectStop(visibleStops[index]),
                    itemBuilder: (context, index) => Padding(
                      key: ValueKey(
                        'trip-map-poi-card-padding-${visibleStops[index].entry.id}',
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: TpSpacing.s2,
                        vertical: TpSpacing.s1,
                      ),
                      child: _buildEntryCard(
                        context,
                        visibleStops[index],
                        index: index,
                        total: visibleStops.length,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: TpSpacing.s3,
                  child: visibleStops.length <= 12
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (final stop in visibleStops) ...[
                              Container(
                                width: stop.entry.id == _activeEntryId ? 14 : 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: stop.entry.id == _activeEntryId
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurface
                                            .withValues(alpha: 0.26),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                              const SizedBox(width: TpSpacing.s1),
                            ],
                          ],
                        )
                      : Text(
                          '${visibleStops.indexWhere((stop) => stop.entry.id == _activeEntryId) + 1} / ${visibleStops.length}',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEntryCard(
    BuildContext context,
    _MapStop stop, {
    required int index,
    required int total,
  }) {
    final theme = Theme.of(context);
    final timeText = stop.entry.startTime ?? stop.entry.time ?? '--:--';
    final timeLabel = timeText;
    final isActive = _activeEntryId == stop.entry.id;
    final locationLabel = stop.point == null
        ? '尚無位置'
        : stop.entry.master?.category ?? stop.entry.master?.type ?? '已定位';
    // The drawer itself is the single refractive layer. Keeping POI cards
    // translucent but non-blurred avoids a doubled, cloudy glass edge.
    final cardColor = theme.colorScheme.surface.withValues(
      alpha: isActive
          ? (theme.brightness == Brightness.dark ? 0.86 : 0.90)
          : (theme.brightness == Brightness.dark ? 0.68 : 0.74),
    );

    return KeyedSubtree(
      key: ValueKey(
        '${isActive ? 'active' : 'inactive'}-entry-card-${stop.entry.id}',
      ),
      child: Semantics(
        button: true,
        label:
            '${index + 1} / $total，${stop.entry.title}，$timeLabel，$locationLabel',
        child: GestureDetector(
          onTap: () => _selectStop(stop),
          child: DecoratedBox(
            key: ValueKey('entry-card-${stop.entry.id}'),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: const BorderRadius.all(Radius.circular(15)),
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(
                  alpha: isActive ? 0.20 : 0.10,
                ),
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: theme.colorScheme.shadow.withValues(alpha: 0.14),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.all(TpSpacing.s2),
              child: Row(
                children: [
                  Container(
                    key: ValueKey('poi-number-${stop.entry.id}'),
                    width: TpSpacing.tapMin,
                    height: TpSpacing.tapMin,
                    decoration: BoxDecoration(
                      color: stop.color.withValues(alpha: 0.20),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: stop.color.withValues(alpha: 0.72),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: stop.color,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(width: TpSpacing.s3),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '停留 ${index + 1} / $total',
                          maxLines: 1,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          stop.entry.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          '$timeLabel · $locationLabel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: stop.point == null
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurfaceVariant,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: TpSpacing.s2),
                  SizedBox.square(
                    dimension: TpSpacing.tapMin,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        CupertinoIcons.arrow_right,
                        size: 18,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
