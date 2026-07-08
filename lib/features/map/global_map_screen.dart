import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/providers.dart';
import '../../models/trip.dart';
import '../../theme/tokens.dart';
import 'map_adapter.dart';
import '../trip_detail/trip_map_screen.dart';

/// 全域地圖 tab 第一波：以目前使用者的行程清單作為入口，預設顯示第一趟行程地圖。
class GlobalMapScreen extends ConsumerStatefulWidget {
  const GlobalMapScreen({super.key, this.tileProvider});

  /// 測試注入點：避免 widget test 對 OSM 發網路請求。
  final TripMapTileProvider? tileProvider;

  @override
  ConsumerState<GlobalMapScreen> createState() => _GlobalMapScreenState();
}

class _GlobalMapScreenState extends ConsumerState<GlobalMapScreen> {
  List<TripSummary> _trips = const [];
  String? _selectedTripId;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadTrips());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('地圖')),
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _trips.isEmpty) {
      return _ErrorState(message: _error!, onRetry: _loadTrips);
    }
    if (_trips.isEmpty) {
      return _EmptyTripsState(onCreateTrip: () => context.go('/trips/new'));
    }

    final selectedTripId = _selectedTripId ?? _trips.first.tripId;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(TpSpacing.s4),
          child: DropdownButtonFormField<String>(
            key: const ValueKey('global-map-trip-picker'),
            initialValue: selectedTripId,
            decoration: const InputDecoration(
              labelText: '行程',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final trip in _trips)
                DropdownMenuItem(
                  value: trip.tripId,
                  child: Text(_tripTitle(trip)),
                ),
            ],
            onChanged: (tripId) {
              if (tripId == null || tripId == _selectedTripId) return;
              setState(() {
                _selectedTripId = tripId;
                _error = null;
              });
            },
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: TpSpacing.s4),
            child: _InlineError(message: _error!),
          ),
        Expanded(
          child: TripMapContent(
            key: ValueKey('global-map-content-$selectedTripId'),
            tripId: selectedTripId,
            tileProvider: widget.tileProvider,
            emptyMessage: '這趟行程尚無地點座標',
          ),
        ),
      ],
    );
  }

  Future<void> _loadTrips() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final trips = await ref.read(tripRepositoryProvider).fetchMyTrips();
      if (!mounted) return;
      setState(() {
        _trips = trips;
        _selectedTripId = trips.isEmpty ? null : trips.first.tripId;
        _loading = false;
      });
    } on Exception {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '無法載入行程清單';
      });
    }
  }

  String _tripTitle(TripSummary trip) {
    final title = trip.title?.trim();
    if (title != null && title.isNotEmpty) return title;
    return trip.name;
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
        child: Text(
          message,
          style: TextStyle(color: colorScheme.onErrorContainer),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: TpSpacing.s3),
          FilledButton(onPressed: onRetry, child: const Text('重試')),
        ],
      ),
    );
  }
}

class _EmptyTripsState extends StatelessWidget {
  const _EmptyTripsState({required this.onCreateTrip});

  final VoidCallback onCreateTrip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.map_outlined,
              size: 44,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: TpSpacing.s3),
            Text('還沒有行程可以看', style: theme.textTheme.titleLarge),
            const SizedBox(height: TpSpacing.s2),
            Text(
              '新增第一趟行程後，地圖 tab 會顯示行程裡所有有座標的景點。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: TpSpacing.s4),
            FilledButton.icon(
              key: const ValueKey('global-map-new-trip'),
              icon: const Icon(Icons.add),
              label: const Text('新增行程'),
              onPressed: onCreateTrip,
            ),
          ],
        ),
      ),
    );
  }
}
