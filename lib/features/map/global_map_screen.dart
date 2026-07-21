/// 根分頁地圖：與 Web 共用「目前行程」模型，不再維護跨收藏 POI 的第二套地圖。
library;

import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/providers.dart';
import '../../models/trip.dart';
import '../../theme/tokens.dart';
import '../../ui/tp_root_scaffold.dart';
import '../trip_detail/trip_map_screen.dart';
import '../trips/trips_list_screen.dart';
import 'map_adapter.dart';
import 'map_location.dart';

const _lastMapTripCacheKey = 'ui:last-map-trip';

class GlobalMapScreen extends ConsumerStatefulWidget {
  const GlobalMapScreen({
    super.key,
    this.initialTripId,
    this.initialEntryId,
    this.initialDayNum,
    this.mapBuilder,
    this.locationService,
  });

  final String? initialTripId;
  final int? initialEntryId;
  final int? initialDayNum;
  final TripMapCanvasBuilder? mapBuilder;
  final TripMapLocationService? locationService;

  @override
  ConsumerState<GlobalMapScreen> createState() => _GlobalMapScreenState();
}

class _GlobalMapScreenState extends ConsumerState<GlobalMapScreen> {
  String? _selectedTripId;

  @override
  void initState() {
    super.initState();
    _selectedTripId = widget.initialTripId;
    if (_selectedTripId == null) {
      unawaited(_loadLastTrip());
    } else {
      unawaited(_rememberTrip(_selectedTripId!));
    }
  }

  @override
  void didUpdateWidget(covariant GlobalMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final explicitTripId = widget.initialTripId;
    if (explicitTripId != null && explicitTripId != _selectedTripId) {
      setState(() => _selectedTripId = explicitTripId);
      unawaited(_rememberTrip(explicitTripId));
    }
  }

  Future<void> _loadLastTrip() async {
    final cached = await ref
        .read(cacheStoreProvider)
        .readResponse(_lastMapTripCacheKey);
    final value = cached?.data;
    if (!mounted ||
        _selectedTripId != null ||
        value is! String ||
        value.isEmpty) {
      return;
    }
    setState(() => _selectedTripId = value);
  }

  Future<void> _selectTrip(String tripId) async {
    setState(() => _selectedTripId = tripId);
    await _rememberTrip(tripId);
  }

  Future<void> _rememberTrip(String tripId) async {
    await ref
        .read(cacheStoreProvider)
        .writeResponse(_lastMapTripCacheKey, tripId);
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(myTripsProvider);
    return tripsAsync.when(
      loading: () => _rootState(
        context,
        const Center(child: CircularProgressIndicator.adaptive()),
      ),
      error: (error, stackTrace) => _rootState(
        context,
        _MapState(
          icon: CupertinoIcons.exclamationmark_triangle,
          title: '載入失敗',
          body: '無法取得行程，請稍後再試。',
          actionLabel: '重試',
          onAction: () => ref.invalidate(myTripsProvider),
        ),
      ),
      data: (trips) {
        if (trips.isEmpty) {
          return _rootState(
            context,
            _MapState(
              icon: CupertinoIcons.map,
              title: '先建立行程',
              body: '建立行程並加入地點後，就能在地圖上查看每日路線。',
              actionLabel: '新增行程',
              onAction: () => context.push('/new-trip'),
            ),
          );
        }
        final selected = _resolveSelectedTrip(trips);
        if (_selectedTripId != selected.tripId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _selectedTripId != selected.tripId) {
              unawaited(_selectTrip(selected.tripId));
            }
          });
        }
        return TripMapScreen(
          key: ValueKey('global-trip-map-${selected.tripId}'),
          tripId: selected.tripId,
          initialEntryId: widget.initialEntryId,
          initialDayNum: widget.initialDayNum,
          mapBuilder: widget.mapBuilder,
          locationService: widget.locationService,
          onTripSelected: (tripId) => unawaited(_selectTrip(tripId)),
        );
      },
    );
  }

  Widget _rootState(BuildContext context, Widget body) {
    return TpRootScaffold(
      header: const TpRootHeaderConfig(title: Text('地圖')),
      body: Padding(
        padding: EdgeInsets.only(
          top: TpRootGeometry.initialContentTop(context),
        ),
        child: body,
      ),
    );
  }

  TripSummary _resolveSelectedTrip(List<TripSummary> trips) {
    final selectedId = _selectedTripId;
    if (selectedId != null) {
      for (final trip in trips) {
        if (trip.tripId == selectedId) return trip;
      }
    }
    return trips.first;
  }
}

class _MapState extends StatelessWidget {
  const _MapState({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: TpSpacing.s4),
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: TpSpacing.s2),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: TpSpacing.s4),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
