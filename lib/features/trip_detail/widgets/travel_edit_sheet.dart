import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api_error.dart';
import '../../../api/providers.dart';
import '../../../models/segment.dart';
import '../../../theme/tokens.dart';
import '../trip_providers.dart';

const List<(String, String)> _modes = [
  ('driving', '開車'),
  ('walking', '步行'),
  ('transit', '大眾運輸'),
];

/// 開啟交通編輯 bottom sheet。
Future<void> showTravelEditSheet(
  BuildContext context, {
  required String tripId,
  TripSegment? segment,
  int? fromEntryId,
  int? toEntryId,
  String? initialMode,
  int? initialMin,
}) {
  assert(
    segment != null || (fromEntryId != null && toEntryId != null),
    'Missing segment creation requires fromEntryId and toEntryId.',
  );
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: TravelEditSheet(
        tripId: tripId,
        segment: segment,
        fromEntryId: fromEntryId,
        toEntryId: toEntryId,
        initialMode: initialMode,
        initialMin: initialMin,
      ),
    ),
  );
}

/// 交通方式編輯：開車/步行（後端打 Google 重算）、大眾運輸（手動填分鐘）。
/// 有 segment 時走 OCC PATCH；缺 segment row 時以 from/to entry pair 建立。
class TravelEditSheet extends ConsumerStatefulWidget {
  const TravelEditSheet({
    super.key,
    required this.tripId,
    this.segment,
    this.fromEntryId,
    this.toEntryId,
    this.initialMode,
    this.initialMin,
  }) : assert(
         segment != null || (fromEntryId != null && toEntryId != null),
         'Missing segment creation requires fromEntryId and toEntryId.',
       );

  final String tripId;
  final TripSegment? segment;
  final int? fromEntryId;
  final int? toEntryId;
  final String? initialMode;
  final int? initialMin;

  @override
  ConsumerState<TravelEditSheet> createState() => _TravelEditSheetState();
}

class _TravelEditSheetState extends ConsumerState<TravelEditSheet> {
  late String _mode;
  late final TextEditingController _min;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _mode = _normalizeTravelMode(widget.segment?.mode ?? widget.initialMode);
    _min = TextEditingController(
      text: (widget.segment?.min ?? widget.initialMin)?.toString() ?? '',
    );
    _min.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _min.dispose();
    super.dispose();
  }

  bool get _isTransit => _mode == 'transit';

  bool get _canSubmit {
    if (_submitting) return false;
    if (!_isTransit) return true;
    final v = int.tryParse(_min.text.trim());
    return v != null && v >= 0;
  }

  Future<void> _submit() async {
    final min = _isTransit ? int.tryParse(_min.text.trim()) : null;
    setState(() => _submitting = true);
    final repo = ref.read(tripRepositoryProvider);
    try {
      final segment = widget.segment;
      if (segment != null) {
        await repo.updateSegment(
          tripId: widget.tripId,
          segmentId: segment.id,
          mode: _mode,
          min: min,
          expectedVersion: segment.version,
        );
      } else {
        final fromEntryId = widget.fromEntryId;
        final toEntryId = widget.toEntryId;
        if (fromEntryId == null || toEntryId == null) {
          throw StateError('Missing segment endpoints.');
        }
        await repo.createSegment(
          tripId: widget.tripId,
          fromEntryId: fromEntryId,
          toEntryId: toEntryId,
          mode: _mode,
          min: min,
        );
      }
      ref.invalidate(tripDaysProvider(widget.tripId));
      ref.invalidate(tripSegmentsProvider(widget.tripId));
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已更新交通')));
    } on ApiError catch (error) {
      if (!mounted) return;
      if (error.status == 409) {
        ref.invalidate(tripSegmentsProvider(widget.tripId));
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('交通已更新，已重新載入')));
        return;
      }
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('更新失敗，請稍後再試')));
    } on Exception {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('更新失敗，請稍後再試')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('交通方式', style: theme.textTheme.titleLarge),
            const SizedBox(height: TpSpacing.s4),
            Wrap(
              spacing: TpSpacing.s2,
              children: [
                for (final (value, label) in _modes)
                  ChoiceChip(
                    key: ValueKey('travel-mode-$value'),
                    label: Text(label),
                    selected: _mode == value,
                    onSelected: (_) => setState(() => _mode = value),
                  ),
              ],
            ),
            const SizedBox(height: TpSpacing.s3),
            if (_isTransit)
              TextField(
                key: const ValueKey('travel-min'),
                controller: _min,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '分鐘數',
                  helperText: '大眾運輸需手動填寫',
                ),
              )
            else
              Text(
                '開車／步行會自動重算時間與距離',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: TpSpacing.s5),
            FilledButton(
              key: const ValueKey('travel-submit'),
              onPressed: _canSubmit ? _submit : null,
              child: Text(_submitting ? '更新中…' : '儲存'),
            ),
          ],
        ),
      ),
    );
  }
}

String _normalizeTravelMode(String? value) {
  return switch (value) {
    'driving' || 'drive' || 'car' || 'taxi' => 'driving',
    'walking' || 'walk' => 'walking',
    'transit' ||
    'bus' ||
    'train' ||
    'monorail' ||
    'tram' ||
    'ferry' => 'transit',
    _ => 'driving',
  };
}
