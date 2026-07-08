import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/day.dart';
import '../../models/entry.dart';
import '../../theme/tokens.dart';
import '../map/map_adapter.dart';
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

typedef TripMapLocationProvider = Future<TripMapPoint?> Function();

/// 行程地圖：day tabs（總覽 + DAY NN）＋ 地圖 adapter ＋ 底部 entry cards。
class TripMapScreen extends ConsumerWidget {
  const TripMapScreen({
    super.key,
    required this.tripId,
    this.focusEntryId,
    this.tileProvider,
    this.locationProvider,
  });

  final String tripId;

  /// Optional entry id used by `stop/:entryId/map` to focus a specific pin.
  final int? focusEntryId;

  /// 測試注入點：widget test 傳入假 tile provider 避免對 OSM 發網路請求。
  final TripMapTileProvider? tileProvider;

  /// 測試注入點：production 使用裝置定位，widget test 可傳固定座標。
  final TripMapLocationProvider? locationProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('行程地圖')),
      body: TripMapContent(
        tripId: tripId,
        focusEntryId: focusEntryId,
        tileProvider: tileProvider,
        locationProvider: locationProvider,
      ),
    );
  }
}

/// 可嵌入的行程地圖內容：讀取指定 trip days 後渲染地圖、day tabs 與 entry cards。
class TripMapContent extends ConsumerWidget {
  const TripMapContent({
    super.key,
    required this.tripId,
    this.focusEntryId,
    this.tileProvider,
    this.locationProvider,
    this.emptyMessage = '此行程尚無地點座標',
  });

  final String tripId;

  /// Optional entry id used to initialize the selected day and map camera.
  final int? focusEntryId;

  final TripMapTileProvider? tileProvider;
  final TripMapLocationProvider? locationProvider;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daysAsync = ref.watch(tripDaysProvider(tripId));
    return daysAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(TpSpacing.s6),
          child: Text('載入失敗：$error', textAlign: TextAlign.center),
        ),
      ),
      data: (days) => _TripMapView(
        days: days,
        focusEntryId: focusEntryId,
        tileProvider: tileProvider,
        locationProvider: locationProvider,
        emptyMessage: emptyMessage,
      ),
    );
  }
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

class _TripMapView extends StatefulWidget {
  const _TripMapView({
    required this.days,
    required this.focusEntryId,
    required this.emptyMessage,
    this.tileProvider,
    this.locationProvider,
  });

  final List<TripDay> days;
  final int? focusEntryId;
  final String emptyMessage;
  final TripMapTileProvider? tileProvider;
  final TripMapLocationProvider? locationProvider;

  @override
  State<_TripMapView> createState() => _TripMapViewState();
}

class _TripMapViewState extends State<_TripMapView> {
  final FlutterTripMapController _mapController = FlutterTripMapController();

  /// 0 = 總覽，i = 第 i 日（widget.days[i - 1]）。
  late int _selectedTabIndex;

  /// fitCamera/move 只能在地圖 render 後呼叫。
  bool _mapIsReady = false;
  bool _didApplyInitialFocus = false;
  bool _isLayerMenuOpen = false;
  bool _isLocating = false;
  int? _selectedEntryId;
  TripMapPoint? _userLocation;
  TripMapTileStyle _tileStyle = TripMapTileStyle.roadmap;

  TripMapTilePreset get _activeTilePreset {
    return kTripMapTilePresets.firstWhere(
      (preset) => preset.style == _tileStyle,
      orElse: () => kTripMapTilePresets.first,
    );
  }

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = _tabIndexForEntry(widget.focusEntryId) ?? 0;
    _selectedEntryId = _pinForEntry(widget.focusEntryId)?.entry.id;
  }

  @override
  void didUpdateWidget(covariant _TripMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusEntryId != widget.focusEntryId ||
        !identical(oldWidget.days, widget.days)) {
      _didApplyInitialFocus = false;
      _selectedTabIndex = _tabIndexForEntry(widget.focusEntryId) ?? 0;
      _selectedEntryId = _pinForEntry(widget.focusEntryId)?.entry.id;
      WidgetsBinding.instance.addPostFrameCallback((_) => _applyInitialFocus());
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

  List<TripMapRoute> _routesForTab(int tabIndex) {
    final pinsByDay = _pinsByDay;
    final dayPinGroups = tabIndex == 0
        ? pinsByDay
        : <List<_DayPin>>[pinsByDay[tabIndex - 1]];
    return [
      for (final dayPins in dayPinGroups)
        if (dayPins.length >= 2)
          TripMapRoute(
            points: [for (final pin in dayPins) pin.point],
            color: dayPins.first.color,
            strokeWidth: 4,
            borderColor: Colors.white.withAlpha(220),
            borderStrokeWidth: 2,
          ),
    ];
  }

  int? _tabIndexForEntry(int? entryId) {
    if (entryId == null) return null;
    for (final (dayIndex, day) in widget.days.indexed) {
      if (day.timeline.any((entry) => entry.id == entryId)) {
        return dayIndex + 1;
      }
    }
    return null;
  }

  _DayPin? _pinForEntry(int? entryId) {
    if (entryId == null) return null;
    for (final dayPins in _pinsByDay) {
      for (final pin in dayPins) {
        if (pin.entry.id == entryId) return pin;
      }
    }
    return null;
  }

  void _selectTab(int tabIndex) {
    setState(() {
      _selectedTabIndex = tabIndex;
      _selectedEntryId = null;
      _isLayerMenuOpen = false;
    });
    _fitToPoints([for (final pin in _pinsForTab(tabIndex)) pin.point]);
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

  void _selectPin(_DayPin pin) {
    final targetTabIndex = pin.dayIndex + 1;
    setState(() {
      _selectedTabIndex = targetTabIndex;
      _selectedEntryId = pin.entry.id;
      _isLayerMenuOpen = false;
    });
    _focusPin(pin);
  }

  void _selectCard(_DayPin pin) {
    setState(() {
      _selectedEntryId = pin.entry.id;
      _isLayerMenuOpen = false;
    });
    _focusPin(pin);
  }

  void _selectTileStyle(TripMapTileStyle style) {
    setState(() {
      _tileStyle = style;
      _isLayerMenuOpen = false;
    });
  }

  void _showMapMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<TripMapPoint?> _resolveDeviceLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showMapMessage('定位服務未開啟');
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMapMessage('尚未授權定位');
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      return TripMapPoint(position.latitude, position.longitude);
    } catch (error) {
      _showMapMessage('無法取得位置：$error');
      return null;
    }
  }

  Future<void> _locateUser() async {
    if (_isLocating) return;
    setState(() {
      _isLocating = true;
      _isLayerMenuOpen = false;
    });
    try {
      final provider = widget.locationProvider ?? _resolveDeviceLocation;
      final point = await provider();
      if (!mounted) return;
      if (point == null) {
        if (widget.locationProvider != null) _showMapMessage('無法取得位置');
        return;
      }
      setState(() => _userLocation = point);
      if (_mapIsReady) {
        _mapController.move(point, 15);
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _applyInitialFocus() {
    if (!mounted || !_mapIsReady || _didApplyInitialFocus) return;
    _didApplyInitialFocus = true;

    final focusedPin = _pinForEntry(widget.focusEntryId);
    if (focusedPin != null) {
      setState(() => _selectedEntryId = focusedPin.entry.id);
      _focusPin(focusedPin);
      return;
    }
    _fitToPoints([for (final pin in _pinsForTab(_selectedTabIndex)) pin.point]);
  }

  @override
  Widget build(BuildContext context) {
    final allPins = _pinsForTab(0);
    if (allPins.isEmpty) {
      return Center(
        child: Text(
          widget.emptyMessage,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final visiblePins = _pinsForTab(_selectedTabIndex);
    return Column(
      children: [
        _buildDayTabs(context),
        Expanded(child: _buildMap(allPins, visiblePins)),
        _buildEntryCards(context, visiblePins),
      ],
    );
  }

  Widget _buildDayTabs(BuildContext context) {
    return SizedBox(
      height: TpSpacing.tapMin + TpSpacing.s2 * 2,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: TpSpacing.s4,
          vertical: TpSpacing.s2,
        ),
        itemCount: widget.days.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: TpSpacing.s2),
        itemBuilder: (context, tabIndex) => _buildDayTabPill(context, tabIndex),
      ),
    );
  }

  Widget _buildDayTabPill(BuildContext context, int tabIndex) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = tabIndex == _selectedTabIndex;
    final isOverview = tabIndex == 0;
    final label = isOverview
        ? '總覽'
        : 'DAY ${widget.days[tabIndex - 1].dayNum.toString().padLeft(2, '0')}';
    // 總覽用主色，單日用該日輪替色（地圖 data-viz 例外）。
    final pillColor = isOverview
        ? colorScheme.primary
        : kDayPinPalette[(tabIndex - 1) % kDayPinPalette.length];

    return Material(
      color: isSelected ? pillColor : Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(
          color: isSelected ? pillColor : colorScheme.outlineVariant,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => _selectTab(tabIndex),
        child: Container(
          constraints: const BoxConstraints(minHeight: TpSpacing.tapMin),
          padding: const EdgeInsets.symmetric(horizontal: TpSpacing.s4),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isOverview) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : pillColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: TpSpacing.s2),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: isSelected ? Colors.white : colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMap(List<_DayPin> allPins, List<_DayPin> visiblePins) {
    final tilePreset = _activeTilePreset;
    final visibleRoutes = _routesForTab(_selectedTabIndex);
    return Stack(
      children: [
        FlutterMapCanvas(
          controller: _mapController,
          tilePreset: tilePreset,
          initialFitPoints: [for (final pin in allPins) pin.point],
          initialPadding: const EdgeInsets.all(TpSpacing.s10),
          initialMaxZoom: 16,
          tileProvider: widget.tileProvider,
          routes: visibleRoutes,
          markers: [
            for (final pin in visiblePins) _buildMarker(pin),
            if (_userLocation != null) _buildUserLocationMarker(),
          ],
          onMapReady: () {
            _mapIsReady = true;
            _applyInitialFocus();
          },
          tileLayerKey: const ValueKey('trip-map-tile-layer'),
          routeLayerKey: const ValueKey('trip-map-polylines'),
        ),
        _buildMapFabs(context),
      ],
    );
  }

  TripMapMarker _buildMarker(_DayPin pin) {
    final isSelected = pin.entry.id == _selectedEntryId;
    return TripMapMarker(
      point: pin.point,
      width: 32,
      height: 32,
      child: GestureDetector(
        key: ValueKey('map-pin-${pin.entry.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _selectPin(pin),
        child: Container(
          key: ValueKey('map-pin-dot-${pin.entry.id}'),
          decoration: BoxDecoration(
            color: pin.color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Colors.black : Colors.white,
              width: isSelected ? 4 : 2,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            '${pin.pinNumber}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              fontFeatures: [FontFeature.tabularFigures()],
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  TripMapMarker _buildUserLocationMarker() {
    return TripMapMarker(
      point: _userLocation!,
      width: 28,
      height: 28,
      child: Container(
        key: const ValueKey('trip-map-user-location'),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withAlpha(220),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(60),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapFabs(BuildContext context) {
    return Positioned(
      right: TpSpacing.s4,
      bottom: TpSpacing.s4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isLayerMenuOpen) ...[
            _buildLayerMenu(context),
            const SizedBox(height: TpSpacing.s2),
          ],
          _MapFabButton(
            key: const ValueKey('trip-map-layer-fab'),
            icon: Icons.layers_outlined,
            tooltip: '切換地圖圖層',
            selected: _isLayerMenuOpen,
            onPressed: () {
              setState(() => _isLayerMenuOpen = !_isLayerMenuOpen);
            },
          ),
          const SizedBox(height: TpSpacing.s2),
          _MapFabButton(
            key: const ValueKey('trip-map-locate-fab'),
            icon: _isLocating ? null : Icons.my_location,
            tooltip: '定位到我的位置',
            selected: _isLocating,
            onPressed: _isLocating ? null : _locateUser,
            child: _isLocating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildLayerMenu(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      key: const ValueKey('trip-map-layer-menu'),
      elevation: 6,
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.all(Radius.circular(TpRadius.md)),
      child: SizedBox(
        width: 128,
        child: Padding(
          padding: const EdgeInsets.all(TpSpacing.s1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final preset in kTripMapTilePresets)
                _LayerOption(
                  key: ValueKey('trip-map-layer-${preset.style.name}'),
                  label: preset.label,
                  selected: preset.style == _tileStyle,
                  onTap: () => _selectTileStyle(preset.style),
                ),
            ],
          ),
        ),
      ),
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
    final isSelected = pin.entry.id == _selectedEntryId;
    // 總覽模式加 D{N} 前綴標示所屬日。
    final timeLabel = _selectedTabIndex == 0
        ? 'D${pin.dayNum} · $timeText'
        : timeText;

    return SizedBox(
      width: 220,
      child: Card(
        key: ValueKey('entry-card-shell-${pin.entry.id}'),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(TpRadius.md)),
          side: BorderSide(
            color: isSelected ? pin.color : Colors.transparent,
            width: isSelected ? 2 : 0,
          ),
        ),
        child: InkWell(
          key: ValueKey('entry-card-${pin.entry.id}'),
          borderRadius: const BorderRadius.all(Radius.circular(TpRadius.md)),
          onTap: () => _selectCard(pin),
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

class _MapFabButton extends StatelessWidget {
  const _MapFabButton({
    super.key,
    required this.tooltip,
    required this.selected,
    required this.onPressed,
    this.icon,
    this.child,
  });

  final IconData? icon;
  final String tooltip;
  final bool selected;
  final VoidCallback? onPressed;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: selected ? colorScheme.primary : colorScheme.surface,
        shape: const CircleBorder(),
        elevation: 4,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: TpSpacing.tapMin,
            height: TpSpacing.tapMin,
            child: Center(
              child:
                  child ??
                  Icon(
                    icon,
                    size: 22,
                    color: selected
                        ? colorScheme.onPrimary
                        : colorScheme.onSurface,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LayerOption extends StatelessWidget {
  const _LayerOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: const BorderRadius.all(Radius.circular(TpRadius.sm)),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: TpSpacing.tapMin),
        padding: const EdgeInsets.symmetric(horizontal: TpSpacing.s3),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary.withAlpha(28)
              : Colors.transparent,
          borderRadius: const BorderRadius.all(Radius.circular(TpRadius.sm)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: selected ? colorScheme.primary : colorScheme.outline,
            ),
            const SizedBox(width: TpSpacing.s2),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
                color: selected ? colorScheme.primary : colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
