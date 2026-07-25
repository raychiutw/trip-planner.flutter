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
import '../../models/poi_type.dart';
import '../../models/trip.dart';
import '../../theme/tokens.dart';
import '../../ui/tp_action_item.dart';
import '../../ui/tp_app_bar.dart';
import '../../ui/tp_bottom_accessory.dart';
import '../../ui/tp_horizontal_selector.dart';
import '../../ui/tp_root_scaffold.dart';
import '../../ui/tp_scope_menu.dart';
import '../map/map_adapter.dart';
import '../map/google_maps_external_launcher.dart';
import '../map/map_location.dart';
import '../map/map_style.dart';
import '../trips/trip_title_button.dart';
import '../trips/trips_list_screen.dart';
import 'google_poi_accessory_card.dart';
import 'selected_day_provider.dart';
import 'trip_providers.dart';

/// 行程地圖：Header 行程 action + 全部／DAY selector ＋ 地圖 adapter ＋ 底部 entry cards。
class TripMapScreen extends ConsumerStatefulWidget {
  const TripMapScreen({
    super.key,
    required this.tripId,
    this.initialEntryId,
    this.initialDayNum,
    this.mapBuilder,
    this.locationService,
    this.locationSettingsOpener,
    this.onTripSelected,
    this.onActiveDayChanged,
    this.externalLauncher = const GoogleMapsExternalLauncher(),
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

  /// 測試注入點：production 開啟系統設定，widget test 驗證目標與失敗回饋。
  final Future<bool> Function(TripMapLocationSettingsTarget)?
  locationSettingsOpener;

  final ValueChanged<String>? onTripSelected;
  final ValueChanged<int?>? onActiveDayChanged;
  final GoogleMapsExternalLauncher externalLauncher;

  @override
  ConsumerState<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends ConsumerState<TripMapScreen> {
  /// 傳給地圖 view 的初始天數：路由查詢參數優先，缺席時才由共用選取日供值。
  int? _initialDayNum;

  /// 使用者在本畫面選了「全部」。「全部」不進共用狀態（空值在時間軸是另一個
  /// 意思），所以切回前景時得靠這個旗標記得使用者的選擇 —— 不能拿共用值有沒有
  /// 變動去反推，那推論會被任何一條也寫共用值的路徑弄髒。
  bool _showingAllDays = false;
  bool _wasActiveBranch = true;

  @override
  void initState() {
    super.initState();
    _resolveInitialDayNum();
  }

  @override
  void didUpdateWidget(covariant TripMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tripId != widget.tripId ||
        oldWidget.initialDayNum != widget.initialDayNum) {
      _resolveInitialDayNum();
    }
  }

  /// 換行程或換深連結日期時重新解析，順帶清掉上一段路由留下的「全部」。
  void _resolveInitialDayNum() {
    _showingAllDays = false;
    _initialDayNum =
        widget.initialDayNum ??
        ref.read(selectedDayProvider).dayNumFor(widget.tripId);
  }

  /// 只有前景分支可寫入：StatefulShellRoute 以 Offstage + TickerMode 保活，
  /// 背景分支雖然被 riverpod 暫停訂閱，仍會在「emit 落在切到背景的同一批」時以
  /// 背景身分重建一次並處理到新的 days —— 那一格會把畫面內部的退位寫進共用狀態。
  ///
  /// 「全部」（空值）不進共用狀態：地圖的空值是「全部」，時間軸的空值是
  /// 「未指定 → 第一天」，同一個空值兩種語意不可混用。
  void _publishSelectedDay(int? dayNum) {
    if (!TickerMode.valuesOf(context).enabled) return;
    _showingAllDays = dayNum == null;
    if (dayNum == null) return;
    ref
        .read(selectedDayProvider.notifier)
        .select(tripId: widget.tripId, dayNum: dayNum);
  }

  @override
  Widget build(BuildContext context) {
    // valuesOf 會建立 InheritedWidget 相依：分支在前景／背景之間切換時本畫面會
    // 重建，才接得住其他 tab 期間變動的共用選取日。
    final isActiveBranch = TickerMode.valuesOf(context).enabled;
    if (isActiveBranch && !_wasActiveBranch && !_showingAllDays) {
      final sharedDayNum = ref
          .read(selectedDayProvider)
          .dayNumFor(widget.tripId);
      if (sharedDayNum != null) _initialDayNum = sharedDayNum;
    }
    _wasActiveBranch = isActiveBranch;
    final daysAsync = ref.watch(tripDaysProvider(widget.tripId));
    final trips = switch (ref.watch(myTripsProvider)) {
      AsyncData(:final value) => value,
      _ => const <TripSummary>[],
    };
    final currentTrip = _findTripSummary(trips, widget.tripId);
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
            currentTripId: widget.tripId,
            currentTitle: currentTrip == null ? '行程' : _tripTitle(currentTrip),
            trips: trips,
            onSelected: (selectedTripId) {
              if (widget.onTripSelected != null) {
                widget.onTripSelected!(selectedTripId);
                return;
              }
              context.go('/trips/${Uri.encodeComponent(selectedTripId)}/map');
            },
          ),
          actions: [
            // 與 root tab「行程」重複的 bar button 已移除，切換交由 tab 承擔；
            // 目前看的是第幾天改由共用選取日跨 tab 沿用。
            TpMoreMenuButton<_TripMapHeaderAction>(
              key: const ValueKey('trip-map-more-button'),
              onSelected: (action) {
                if (action == _TripMapHeaderAction.notes) {
                  context.push(
                    '/trips/${Uri.encodeComponent(widget.tripId)}/notes',
                  );
                }
              },
              items: const [
                TpActionItem(
                  key: ValueKey('trip-map-notes-button'),
                  value: _TripMapHeaderAction.notes,
                  icon: CupertinoIcons.doc_text,
                  label: '筆記',
                ),
              ],
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
            tripId: widget.tripId,
            days: days,
            initialEntryId: widget.initialEntryId,
            initialDayNum: _initialDayNum,
            mapBuilder: widget.mapBuilder,
            locationService: widget.locationService,
            locationSettingsOpener: widget.locationSettingsOpener,
            externalLauncher: widget.externalLauncher,
            onActiveDayChanged: (dayNum) {
              _publishSelectedDay(dayNum);
              widget.onActiveDayChanged?.call(dayNum);
            },
          ),
        ),
      ),
    );
  }
}

enum _TripMapHeaderAction { notes }

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
    this.locationSettingsOpener,
    required this.externalLauncher,
    required this.onActiveDayChanged,
  });

  final String tripId;
  final List<TripDay> days;
  final int? initialEntryId;
  final int? initialDayNum;
  final TripMapCanvasBuilder? mapBuilder;
  final TripMapLocationService? locationService;
  final Future<bool> Function(TripMapLocationSettingsTarget)?
  locationSettingsOpener;
  final GoogleMapsExternalLauncher externalLauncher;
  final ValueChanged<int?> onActiveDayChanged;

  @override
  ConsumerState<_TripMapView> createState() => _TripMapViewState();
}

class _TripMapViewState extends ConsumerState<_TripMapView> {
  static const _focusZoom = 13.0;

  final TripMapController _mapController = TripMapController();
  late final PageController _pageController;
  TripMapPoint? _userLocation;
  bool _locating = false;
  int? _activeEntryId;
  int? _previewEntryId;
  GoogleMapPoiSelection? _selectedGooglePoi;

  double get _poiAccessoryHeight {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final additionalHeight = ((scale - 1) * 120).clamp(0.0, 220.0);
    return TpBottomAccessory.height + additionalHeight;
  }

  double get _daySelectorHeight =>
      TpHorizontalSelector.preferredHeight(context);

  EdgeInsets _mapPadding({required bool hasAccessory}) => EdgeInsets.fromLTRB(
    TpSpacing.s10,
    TpRootGeometry.headerBottom(context) +
        TpSpacing.s2 +
        _daySelectorHeight +
        TpSpacing.s2 +
        TpSpacing.tapMin +
        TpSpacing.s4,
    TpSpacing.s10,
    (hasAccessory ? _poiAccessoryHeight : 0) +
        TpRootTabGeometry.clearance(context) +
        TpSpacing.s6,
  );

  /// 0 = 全部；i = 第 i 日（widget.days[i - 1]）。
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
    _previewEntryId = initialStops.isEmpty
        ? null
        : initialStops[initialPage].entry.id;
    _activeEntryId = widget.initialEntryId == _previewEntryId
        ? _previewEntryId
        : null;
    _pageController = PageController(
      viewportFraction: 0.74,
      initialPage: initialPage,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onActiveDayChanged(_dayNumForTab(_selectedTabIndex));
      unawaited(_loadRoutes());
    });
  }

  @override
  void didUpdateWidget(covariant _TripMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tripId != widget.tripId ||
        oldWidget.initialEntryId != widget.initialEntryId ||
        oldWidget.initialDayNum != widget.initialDayNum ||
        !identical(oldWidget.days, widget.days)) {
      _selectedTabIndex = _initialTabIndex();
      final stops = _stopsForTab(_selectedTabIndex);
      final initialPage = _initialStopPage(stops);
      _previewEntryId = stops.isEmpty ? null : stops[initialPage].entry.id;
      _activeEntryId = widget.initialEntryId == _previewEntryId
          ? _previewEntryId
          : null;
      _selectedGooglePoi = null;
      _initialFocusApplied = false;
      unawaited(_loadRoutes());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onActiveDayChanged(_dayNumForTab(_selectedTabIndex));
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

  int? _dayNumForTab(int tabIndex) =>
      tabIndex == 0 ? null : widget.days[tabIndex - 1].dayNum;

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
    final stops = _stopsForTab(tabIndex);
    setState(() {
      _selectedTabIndex = tabIndex;
      _previewEntryId = stops.firstOrNull?.entry.id;
      _activeEntryId = null;
      _selectedGooglePoi = null;
    });
    widget.onActiveDayChanged(_dayNumForTab(tabIndex));
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
    setState(() {
      _routeSegments = const [];
      _loadingRoutes = true;
    });
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
    _mapController.move(center, _focusZoom);
  }

  void _focusStop(_MapStop stop) {
    final point = stop.point;
    if (!_mapIsReady || point == null) return;
    _mapController.move(point, _focusZoom);
  }

  void _selectStop(_MapStop stop, {bool animatePage = false}) {
    if (_activeEntryId != stop.entry.id ||
        _previewEntryId != stop.entry.id ||
        _selectedGooglePoi != null) {
      setState(() {
        _activeEntryId = stop.entry.id;
        _previewEntryId = stop.entry.id;
        _selectedGooglePoi = null;
      });
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

  void _previewStop(_MapStop stop) {
    if (_activeEntryId == stop.entry.id &&
        _previewEntryId == stop.entry.id &&
        _selectedGooglePoi == null) {
      return;
    }
    setState(() {
      _activeEntryId = stop.entry.id;
      _previewEntryId = stop.entry.id;
      _selectedGooglePoi = null;
    });
    _focusStop(stop);
  }

  void _selectGooglePoi(GoogleMapPoiSelection selection) {
    if (_selectedGooglePoi == selection) return;
    setState(() => _selectedGooglePoi = selection);
  }

  void _clearGooglePoi() {
    if (_selectedGooglePoi == null) return;
    setState(() => _selectedGooglePoi = null);
  }

  Future<void> _openGooglePoi(GoogleMapPoiSelection selection) async {
    try {
      if (await widget.externalLauncher.open(selection)) return;
    } catch (_) {
      // The same visible recovery applies to false and platform failures.
    }
    if (mounted) showAppError(context, '無法開啟 Google 地圖，請稍後再試');
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
      _showLocationError(error);
    } on Exception {
      if (!mounted) return;
      _showLocationError(const TripMapLocationException('無法取得目前位置，請稍後重試'));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _showLocationError(TripMapLocationException error) {
    final settingsTarget = error.settingsTarget;
    showAppError(
      context,
      error.message,
      onRetry: settingsTarget == null
          ? _locateMe
          : () => unawaited(_openLocationSettings(settingsTarget)),
      retryLabel: settingsTarget == null ? '重試' : '開啟設定',
    );
  }

  Future<void> _openLocationSettings(
    TripMapLocationSettingsTarget target,
  ) async {
    final opener = widget.locationSettingsOpener ?? openTripMapLocationSettings;
    try {
      if (await opener(target)) return;
    } catch (_) {
      // False and platform failures share one persistent recovery state.
    }
    if (!mounted) return;
    showAppError(
      context,
      '無法自動開啟設定，請手動前往系統「設定」允許定位',
      onRetry: () => unawaited(_openLocationSettings(target)),
    );
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
    final hasAccessory = visibleStops.isNotEmpty || _selectedGooglePoi != null;
    return Stack(
      children: [
        Positioned.fill(
          child: buildTripMapCanvas(
            TripMapCanvasConfig(
              controller: _mapController,
              tilePreset: kTripMapTilePresets.first,
              initialFitPoints: const [],
              initialCenter: initialCenter,
              initialZoom: _focusZoom,
              initialPadding: _mapPadding(hasAccessory: hasAccessory),
              onMapReady: _handleMapReady,
              onTap: (_) => _clearGooglePoi(),
              onGooglePoiSelected: _selectGooglePoi,
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
              TpScopeOption(
                value: 0,
                label: '全部',
                semanticsLabel: '全部，共 ${widget.days.length} 天',
              ),
              for (final (index, day) in widget.days.indexed)
                TpScopeOption(
                  value: index + 1,
                  label: 'Day ${day.dayNum}',
                  semanticsLabel: '第 ${day.dayNum} 天，共 ${widget.days.length} 天',
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
              _daySelectorHeight +
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
                _daySelectorHeight +
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
        if (hasAccessory) _buildPoiAccessory(visibleStops),
      ],
    );
  }

  TripMapMarker _buildMarker(_MapStop pin, {required int number}) {
    // 白底圓形 chip + 日別色外圈／數字；聚焦點改 adaptive app tint 填底並放大。
    final style = tripMapMarkerStyle(
      dayColor: pin.color,
      focusColor: Theme.of(context).colorScheme.primary,
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
      child: AnimatedSwitcher(
        duration: TpMotion.resolve(context, TpMotion.fast),
        child: _selectedGooglePoi == null
            ? KeyedSubtree(
                key: const ValueKey('tripline-poi-accessory'),
                child: _buildTriplinePoiPager(visibleStops),
              )
            : GooglePoiAccessoryCard(
                key: const ValueKey('google-poi-accessory'),
                selection: _selectedGooglePoi!,
                onClose: _clearGooglePoi,
                onOpen: () => unawaited(_openGooglePoi(_selectedGooglePoi!)),
              ),
      ),
    );
  }

  Widget _buildTriplinePoiPager(List<_MapStop> visibleStops) {
    return visibleStops.isEmpty
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
                  pageSnapping: false,
                  scrollDirection: Axis.horizontal,
                  itemCount: visibleStops.length,
                  onPageChanged: (index) => _previewStop(visibleStops[index]),
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
                              width: stop.entry.id == _previewEntryId ? 14 : 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: stop.entry.id == _previewEntryId
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
                        '${visibleStops.indexWhere((stop) => stop.entry.id == _previewEntryId) + 1} / ${visibleStops.length}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
              ),
            ],
          );
  }

  Widget _buildEntryCard(
    BuildContext context,
    _MapStop stop, {
    required int index,
    required int total,
  }) {
    final theme = Theme.of(context);
    final startTime = (stop.entry.startTime ?? stop.entry.time)?.trim();
    final endTime = stop.entry.endTime?.trim();
    final timeLabel = startTime == null || startTime.isEmpty
        ? '時間未設定'
        : endTime == null || endTime.isEmpty
        ? startTime
        : '$startTime–$endTime';
    final isActive = _activeEntryId == stop.entry.id;
    final isPreview = _previewEntryId == stop.entry.id;
    final category = stop.entry.master?.category?.trim();
    final categoryLabel =
        poiCategoryLabel(
          category == null || category.isEmpty
              ? stop.entry.master?.type
              : category,
        ) ??
        (stop.point == null ? '尚無位置' : '未分類');
    // The drawer itself is the single refractive layer. Keeping POI cards
    // translucent but non-blurred avoids a doubled, cloudy glass edge.
    final cardColor = theme.colorScheme.surface.withValues(
      alpha: isPreview
          ? (theme.brightness == Brightness.dark ? 0.86 : 0.90)
          : (theme.brightness == Brightness.dark ? 0.68 : 0.74),
    );

    return KeyedSubtree(
      key: ValueKey(
        '${isActive
            ? 'active'
            : isPreview
            ? 'preview'
            : 'inactive'}-entry-card-${stop.entry.id}',
      ),
      child: Semantics(
        button: true,
        selected: isActive,
        label:
            '第 ${index + 1} 個，共 $total 個，${stop.entry.title}，$timeLabel，$categoryLabel',
        child: GestureDetector(
          onTap: () => _selectStop(stop),
          child: DecoratedBox(
            key: ValueKey('entry-card-${stop.entry.id}'),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: const BorderRadius.all(Radius.circular(15)),
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(
                  alpha: isActive
                      ? 0.30
                      : isPreview
                      ? 0.20
                      : 0.10,
                ),
              ),
              boxShadow: isPreview
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
                          stop.entry.title,
                          key: ValueKey('entry-card-title-${stop.entry.id}'),
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          timeLabel,
                          key: ValueKey('entry-card-time-${stop.entry.id}'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          categoryLabel,
                          key: ValueKey('entry-card-category-${stop.entry.id}'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: stop.point == null
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
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
