import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api_error.dart';
import '../../../api/providers.dart';
import '../../../models/add_to_trip.dart';
import '../../../models/poi_type.dart';
import '../../../models/trip.dart';
import '../../../theme/tokens.dart';
import '../../trip_detail/trip_providers.dart';
import '../../trips/trip_card.dart';
import '../../trips/trips_list_screen.dart';
import '../favorites_providers.dart';

/// 加入行程（fullpage）：選 trip/day/時間 → 送出（favorite / direct mode）。
class AddToTripScreen extends ConsumerStatefulWidget {
  const AddToTripScreen({super.key, required this.args});

  final AddToTripArgs args;

  @override
  ConsumerState<AddToTripScreen> createState() => _AddToTripScreenState();
}

class _AddToTripScreenState extends ConsumerState<AddToTripScreen> {
  String? _tripId;
  int? _dayNum;
  TimeOfDay _start = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 11, minute: 0);
  bool _submitting = false;

  String get _title => switch (widget.args) {
        AddToTripFavorite(:final displayName) => displayName,
        AddToTripDirect(:final poi) => poi.name,
      };

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
        context: context, initialTime: isStart ? _start : _end);
    if (picked != null) {
      setState(() => isStart ? _start = picked : _end = picked);
    }
  }

  Future<void> _submit() async {
    final tripId = _tripId;
    final dayNum = _dayNum;
    if (tripId == null || dayNum == null) return;
    setState(() => _submitting = true);
    try {
      switch (widget.args) {
        case AddToTripFavorite(:final favoriteId):
          await ref.read(favoritesRepositoryProvider).addFavoriteToTrip(
                favoriteId: favoriteId,
                tripId: tripId,
                dayNum: dayNum,
                startTime: _fmt(_start),
                endTime: _fmt(_end),
              );
        case AddToTripDirect(:final poi):
          await ref.read(tripRepositoryProvider).addEntryToDay(
                tripId: tripId,
                dayNum: dayNum,
                title: poi.name,
                poiType: mapGooglePrimaryTypeToPoiType(poi.category),
                lat: poi.lat,
                lng: poi.lng,
                startTime: _fmt(_start),
                endTime: _fmt(_end),
              );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已加入行程')));
      Navigator.of(context).pop();
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      if (error.status == 409) {
        final raw = error.payload?['conflictWith'];
        if (raw is Map) {
          await _showConflict(
              TripEntryConflict.fromJson(Map<String, dynamic>.from(raw)));
          return;
        }
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('加入行程失敗,請稍後再試')));
    } on Exception {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('加入行程失敗,請稍後再試')));
    }
  }

  Future<void> _showConflict(TripEntryConflict conflict) {
    final timeLabel = conflict.time == null ? '' : '（${conflict.time}）';
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('時段衝突'),
        content:
            Text('該時段已有「${conflict.title}」$timeLabel。請改選其他時間後再試。'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(myTripsProvider);

    return Scaffold(
      appBar: AppBar(title: Text('加入行程：$_title')),
      body: tripsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(TpSpacing.s6),
            child: Text('無法載入行程清單:$e', textAlign: TextAlign.center),
          ),
        ),
        data: (trips) => _form(context, trips),
      ),
    );
  }

  Widget _form(BuildContext context, List<TripSummary> trips) {
    final tripId = _tripId ??= trips.isEmpty ? null : trips.first.tripId;
    final daysAsync =
        tripId == null ? null : ref.watch(tripDaysProvider(tripId));

    return ListView(
      padding: const EdgeInsets.all(TpSpacing.s4),
      children: [
        DropdownButtonFormField<String>(
          key: const ValueKey('add-to-trip-trip'),
          initialValue: tripId,
          decoration: const InputDecoration(labelText: '行程'),
          items: [
            for (final t in trips)
              DropdownMenuItem(value: t.tripId, child: Text(t.displayTitle)),
          ],
          onChanged: (v) => setState(() {
            _tripId = v;
            _dayNum = null;
          }),
        ),
        const SizedBox(height: TpSpacing.s4),
        if (daysAsync != null)
          daysAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('無法載入日程:$e'),
            data: (days) {
              final dayNum = _dayNum ??= days.isEmpty ? null : days.first.dayNum;
              return DropdownButtonFormField<int>(
                key: const ValueKey('add-to-trip-day'),
                initialValue: dayNum,
                decoration: const InputDecoration(labelText: '日期'),
                items: [
                  for (final d in days)
                    DropdownMenuItem(
                        value: d.dayNum,
                        child: Text('DAY ${d.dayNum} · ${d.displayTitle}')),
                ],
                onChanged: (v) => setState(() => _dayNum = v),
              );
            },
          ),
        const SizedBox(height: TpSpacing.s4),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('add-to-trip-start'),
                onPressed: () => _pickTime(true),
                child: Text('開始 ${_fmt(_start)}'),
              ),
            ),
            const SizedBox(width: TpSpacing.s3),
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('add-to-trip-end'),
                onPressed: () => _pickTime(false),
                child: Text('結束 ${_fmt(_end)}'),
              ),
            ),
          ],
        ),
        const SizedBox(height: TpSpacing.s6),
        FilledButton(
          key: const ValueKey('add-to-trip-submit'),
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? '加入中…' : '加入行程'),
        ),
      ],
    );
  }
}
