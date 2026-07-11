import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/providers.dart';
import '../../models/day.dart';
import '../../models/entry.dart';
import '../../theme/tokens.dart';
import '../map/google_map_adapter.dart';
import '../map/marker_bitmap.dart';
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

/// 行程地圖：day tabs（總覽 + DAY NN）＋ 地圖 adapter ＋ 底部 entry cards。
class TripMapScreen extends ConsumerWidget {
  const TripMapScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daysAsync = ref.watch(tripDaysProvider(tripId));
    return Scaffold(
      appBar: AppBar(title: const Text('行程地圖')),
      body: daysAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(TpSpacing.s6),
            child: Text('載入失敗：$error', textAlign: TextAlign.center),
          ),
        ),
        data: (days) => _TripMapView(days: days),
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

class _TripMapView extends ConsumerStatefulWidget {
  const _TripMapView({required this.days});

  final List<TripDay> days;

  @override
  ConsumerState<_TripMapView> createState() => _TripMapViewState();
}

class _TripMapViewState extends ConsumerState<_TripMapView> {
  final GoogleTripMapController _mapController = GoogleTripMapController();
  final PinBitmapCache _pinCache = PinBitmapCache();

  /// 目前 tab 的 marker(bitmap 已 resolve);async 產生故存於 state。
  List<TripMapBitmapMarker> _markers = const [];

  /// resolve 世代:避免舊 resolve 完成後覆寫新 tab 的 marker。
  int _markerGen = 0;

  /// 目前 tab 的 per-day 道路折線(async 打 /api/route 取真實道路)。
  List<TripMapPolyline> _polylines = const [];

  /// route resolve 世代:避免舊 tab 的折線覆寫新 tab。
  int _routeGen = 0;

  /// 0 = 總覽，i = 第 i 日（widget.days[i - 1]）。
  int _selectedTabIndex = 0;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveMarkers();
    _resolveRoutes();
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

  void _selectTab(int tabIndex) {
    setState(() => _selectedTabIndex = tabIndex);
    _resolveMarkers();
    _resolveRoutes();
    _fitToPoints([for (final pin in _pinsForTab(tabIndex)) pin.point]);
  }

  /// 目前 tab 要畫折線的「各日 pin 清單」:總覽=全部日、單日=該日。
  /// 折線只連同一日內相鄰 pin,不跨日,故總覽也要逐日切開。
  List<List<_DayPin>> _visibleDaysPins() {
    final byDay = _pinsByDay;
    if (_selectedTabIndex == 0) return byDay;
    return [byDay[_selectedTabIndex - 1]];
  }

  /// 逐日、相鄰 pin 對平行打 /api/route 取道路折線;失敗(null)該段略過(對齊
  /// web:不退化直線)。折線用該日輪替色。GET 走 ApiClient 透明快取。
  Future<void> _resolveRoutes() async {
    final gen = ++_routeGen;
    final repo = ref.read(routeRepositoryProvider);
    final futures = <Future<TripMapPolyline?>>[];
    for (final dayPins in _visibleDaysPins()) {
      for (var i = 0; i + 1 < dayPins.length; i++) {
        final from = dayPins[i];
        final to = dayPins[i + 1];
        futures.add(
          repo
              .fetchRoute(
                fromLat: from.point.latitude,
                fromLng: from.point.longitude,
                toLat: to.point.latitude,
                toLng: to.point.longitude,
              )
              .then((route) {
                if (route == null || route.polyline.isEmpty) return null;
                return TripMapPolyline(
                  id: 'route-${from.entry.id}-${to.entry.id}',
                  points: [
                    for (final p in route.polyline) TripMapPoint(p.lat, p.lng),
                  ],
                  color: from.color,
                );
              }),
        );
      }
    }
    final resolved = (await Future.wait(
      futures,
    )).whereType<TripMapPolyline>().toList();
    if (mounted && gen == _routeGen) {
      setState(() => _polylines = resolved);
    }
  }

  /// 逐 pin resolve 彩色序號 bitmap(cache 命中則免重繪),完成後 setState。
  Future<void> _resolveMarkers() async {
    final gen = ++_markerGen;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final pins = _pinsForTab(_selectedTabIndex);
    final resolved = <TripMapBitmapMarker>[];
    for (final pin in pins) {
      final icon = await _pinCache.resolve(
        color: pin.color,
        number: pin.pinNumber,
        devicePixelRatio: dpr,
      );
      resolved.add(
        TripMapBitmapMarker(
          id: 'pin-${pin.entry.id}',
          point: pin.point,
          icon: icon,
          onTap: () => _focusPin(pin),
        ),
      );
    }
    if (mounted && gen == _markerGen) {
      setState(() => _markers = resolved);
    }
  }

  void _fitToPoints(List<TripMapPoint> points) {
    if (points.isEmpty) return;
    _mapController.fitPoints(
      points,
      padding: const EdgeInsets.all(TpSpacing.s10),
      maxZoom: 16,
    );
  }

  void _focusPin(_DayPin pin) {
    _mapController.move(pin.point, 16);
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
        _buildDayTabs(context),
        Expanded(child: _buildMap(allPins)),
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

    return Semantics(
      key: ValueKey('trip-map-tab-$tabIndex'),
      label: label,
      button: true,
      selected: isSelected,
      onTap: () => _selectTab(tabIndex),
      child: ExcludeSemantics(
        child: Material(
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
        ),
      ),
    );
  }

  Widget _buildMap(List<_DayPin> allPins) {
    return GoogleMapCanvas(
      controller: _mapController,
      initialFitPoints: [for (final pin in allPins) pin.point],
      initialPadding: const EdgeInsets.all(TpSpacing.s10),
      initialMaxZoom: 16,
      markers: _markers,
      polylines: _polylines,
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
