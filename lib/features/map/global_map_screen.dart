/// 行程總覽地圖(`/map` 分頁):trip picker 切換行程 → 顯示該行程每天景點與路線
/// (共用 [TripDayMapView])。比照 web 手機版 GlobalMapPage;不顯示收藏(收藏維持
/// 清單頁)。與 trip map 的差別僅在頂部多一個可切換 tripId 的 picker。
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/trip.dart';
import '../../theme/tokens.dart';
import '../trip_detail/trip_providers.dart';
import '../trips/trips_list_screen.dart';
import 'trip_overview_map.dart';

class GlobalMapScreen extends ConsumerStatefulWidget {
  const GlobalMapScreen({super.key});

  @override
  ConsumerState<GlobalMapScreen> createState() => _GlobalMapScreenState();
}

class _GlobalMapScreenState extends ConsumerState<GlobalMapScreen> {
  /// null → 尚未手動選 → 用清單第一個行程。
  String? _selectedTripId;

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(myTripsProvider);
    return tripsAsync.when(
      loading: () => _scaffold(
        const Text('地圖'),
        const Center(child: CircularProgressIndicator.adaptive()),
      ),
      error: (e, _) => _scaffold(
        const Text('地圖'),
        const _Hint(title: '載入失敗', body: '無法取得行程清單,請稍後再試。'),
      ),
      data: (trips) {
        if (trips.isEmpty) {
          return _scaffold(
            const Text('地圖'),
            const _Hint(
              title: '還沒有行程',
              body: '建立行程並加入地點後,就能在這裡看到每天的景點與路線。',
            ),
          );
        }
        final selected = trips.firstWhere(
          (t) => t.tripId == _selectedTripId,
          orElse: () => trips.first,
        );
        return _scaffold(
          _pickerTitle(context, trips, selected),
          _TripDaysBody(tripId: selected.tripId),
        );
      },
    );
  }

  Widget _scaffold(Widget title, Widget body) =>
      Scaffold(appBar: AppBar(title: title), body: body);

  /// AppBar 標題即 trip picker:行程名 + 下拉指示,點擊開 bottom sheet 切換。
  Widget _pickerTitle(
    BuildContext context,
    List<TripSummary> trips,
    TripSummary selected,
  ) {
    return InkWell(
      key: const ValueKey('trip-picker'),
      borderRadius: const BorderRadius.all(Radius.circular(TpRadius.sm)),
      onTap: () => _openPicker(context, trips, selected),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TpSpacing.s2,
          vertical: TpSpacing.s1,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(selected.name, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: TpSpacing.s1),
            const Icon(CupertinoIcons.chevron_down, size: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _openPicker(
    BuildContext context,
    List<TripSummary> trips,
    TripSummary selected,
  ) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final t in trips)
              ListTile(
                key: ValueKey('picker-trip-${t.tripId}'),
                title: Text(t.name),
                trailing: t.tripId == selected.tripId
                    ? const Icon(CupertinoIcons.check_mark)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(t.tripId),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedTripId = picked);
    }
  }
}

/// 監看選定行程的 days → 交給共用 [TripDayMapView]。以 `ValueKey(tripId)` 重建,
/// 切換行程時重置選中日、避免 day tab 越界。
class _TripDaysBody extends ConsumerWidget {
  const _TripDaysBody({required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daysAsync = ref.watch(tripDaysProvider(tripId));
    return daysAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator.adaptive()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(TpSpacing.s6),
          child: Text('載入失敗：$error', textAlign: TextAlign.center),
        ),
      ),
      data: (days) => TripDayMapView(key: ValueKey(tripId), days: days),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: TpSpacing.s2),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
