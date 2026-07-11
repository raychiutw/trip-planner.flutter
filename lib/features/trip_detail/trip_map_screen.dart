import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/tokens.dart';
import '../map/trip_overview_map.dart';
import 'trip_providers.dart';

/// 行程地圖:固定 tripId,watch 該行程 days → 交給共用 [TripDayMapView] 呈現
/// (day tabs / GoogleMap / entry cards / per-day 折線)。/map 為可切換 tripId 版。
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
        data: (days) => TripDayMapView(days: days),
      ),
    );
  }
}
