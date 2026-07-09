import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// 行程地圖：day tabs（總覽 + DAY NN）＋ 地圖 adapter ＋ 底部 entry cards。
class TripMapScreen extends ConsumerWidget {
  const TripMapScreen({
    super.key,
    required this.tripId,
    this.initialEntryId,
    this.tileProvider,
  });

  final String tripId;

  /// 初始聚焦的停留點 id，用於 `/trip/:tripId/stop/:entryId/map` deep link。
  final int? initialEntryId;

  /// 測試注入點：widget test 傳入假 tile provider 避免對 OSM 發網路請求。
  final TripMapTileProvider? tileProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daysAsync = ref.watch(tripDaysProvider(tripId));
    return Scaffold(
      appBar: AppBar(title: const Text('行程地圖')),
      body: daysAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(TpSpacing.s6),
            child: Text('載入失敗：$error', textAlign: TextAlign.center),
          ),
        ),
        data: (days) => _TripMapView(
          days: days,
          initialEntryId: initialEntryId,
          tileProvider: tileProvider,
        ),
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
    this.initialEntryId,
    this.tileProvider,
  });

  final List<TripDay> days;
  final int? initialEntryId;
  final TripMapTileProvider? tileProvider;

  @override
  State<_TripMapView> createState() => _TripMapViewState();
}

class _TripMapViewState extends State<_TripMapView> {
  final FlutterTripMapController _mapController = FlutterTripMapController();

  /// 0 = 總覽，i = 第 i 日（widget.days[i - 1]）。
  int _selectedTabIndex = 0;

  /// fitCamera/move 只能在地圖 render 後呼叫。
  bool _mapIsReady = false;

  bool _initialFocusApplied = false;

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = _initialTabIndex();
  }

  @override
  void didUpdateWidget(covariant _TripMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialEntryId != widget.initialEntryId ||
        !identical(oldWidget.days, widget.days)) {
      _selectedTabIndex = _initialTabIndex();
      _initialFocusApplied = false;
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
    return FlutterMapCanvas(
      controller: _mapController,
      tilePreset: kTripMapTilePresets.first,
      initialFitPoints: [for (final pin in allPins) pin.point],
      initialPadding: const EdgeInsets.all(TpSpacing.s10),
      initialMaxZoom: 16,
      tileProvider: widget.tileProvider,
      onMapReady: _handleMapReady,
      markers: [for (final pin in visiblePins) _buildMarker(pin)],
    );
  }

  TripMapMarker _buildMarker(_DayPin pin) {
    return TripMapMarker(
      point: pin.point,
      width: 32,
      height: 32,
      child: Container(
        key: ValueKey('map-pin-${pin.entry.id}'),
        decoration: BoxDecoration(
          color: pin.color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
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
