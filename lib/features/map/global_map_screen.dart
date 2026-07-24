/// 根分頁地圖：與 Web 共用「目前行程」模型，不再維護跨收藏 POI 的第二套地圖。
library;

import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/tokens.dart';
import '../../ui/tp_root_scaffold.dart';
import '../trip_detail/trip_map_screen.dart';
import '../trips/current_trip_provider.dart';
import '../trips/trips_list_screen.dart';
import 'map_adapter.dart';
import 'map_location.dart';

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
  int? _activeDayNum;
  String? _pendingRouteTripId;
  String? _renderedTripId;

  @override
  void initState() {
    super.initState();
    _activeDayNum = widget.initialDayNum;
    final tripId = widget.initialTripId;
    _pendingRouteTripId = tripId;
    if (tripId != null) _selectRouteTripAfterBuild(tripId);
  }

  @override
  void didUpdateWidget(covariant GlobalMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final explicitTripId = widget.initialTripId;
    if (explicitTripId != oldWidget.initialTripId) {
      _pendingRouteTripId = explicitTripId;
      if (explicitTripId != null) {
        _selectRouteTripAfterBuild(explicitTripId);
      }
    }
    if (widget.initialDayNum != oldWidget.initialDayNum) {
      _activeDayNum = widget.initialDayNum;
    }
  }

  void _selectRouteTripAfterBuild(String tripId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pendingRouteTripId != tripId) return;
      unawaited(ref.read(currentTripIdProvider.notifier).select(tripId));
      setState(() => _pendingRouteTripId = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(myTripsProvider);
    final isActiveBranch = TickerMode.valuesOf(context).enabled;
    final selectedAsync = isActiveBranch
        ? ref.watch(currentTripIdProvider)
        : ref.read(currentTripIdProvider);
    if (isActiveBranch &&
        _pendingRouteTripId == null &&
        !selectedAsync.isLoading) {
      _renderedTripId = selectedAsync.value;
    }
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
              title: '尚無行程',
              body: '建立行程並加入地點後，就能在地圖上查看每日路線。',
              actionLabel: '新增行程',
              onAction: () => context.push('/new-trip'),
            ),
            title: '尚無行程',
          );
        }
        if ((selectedAsync.isLoading && _pendingRouteTripId == null) ||
            (_pendingRouteTripId != null &&
                !trips.any((trip) => trip.tripId == _pendingRouteTripId))) {
          return _rootState(
            context,
            const Center(child: CircularProgressIndicator.adaptive()),
          );
        }
        final selected = resolveCurrentTrip(
          trips,
          _pendingRouteTripId ??
              (isActiveBranch ? selectedAsync.value : _renderedTripId),
        )!;
        final sharedTrip = trips
            .where((trip) => trip.tripId == selectedAsync.value)
            .firstOrNull;
        if (isActiveBranch &&
            _pendingRouteTripId == null &&
            widget.initialTripId != null &&
            sharedTrip != null &&
            widget.initialTripId != sharedTrip.tripId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final day = _activeDayNum;
            GoRouter.maybeOf(context)?.go(
              '/map?tripId=${Uri.encodeQueryComponent(sharedTrip.tripId)}'
              '${day == null ? '' : '&day=$day'}',
            );
          });
        }
        return TripMapScreen(
          key: ValueKey('global-trip-map-${selected.tripId}'),
          tripId: selected.tripId,
          initialEntryId: selected.tripId == widget.initialTripId
              ? widget.initialEntryId
              : null,
          initialDayNum: _activeDayNum,
          mapBuilder: widget.mapBuilder,
          locationService: widget.locationService,
          onTripSelected: (tripId) => unawaited(
            ref.read(currentTripIdProvider.notifier).select(tripId),
          ),
          onActiveDayChanged: (dayNum) => _activeDayNum = dayNum,
        );
      },
    );
  }

  Widget _rootState(BuildContext context, Widget body, {String title = '地圖'}) {
    return TpRootScaffold(
      header: TpRootHeaderConfig(title: Text(title)),
      body: Padding(
        padding: EdgeInsets.only(
          top: TpRootGeometry.initialContentTop(context),
        ),
        child: body,
      ),
    );
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
