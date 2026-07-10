import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
const _autoTransitSubmodes = {'monorail', 'bus'};

/// 開啟交通編輯 bottom sheet。
Future<void> showTravelEditSheet(
  BuildContext context, {
  required String tripId,
  required TripSegment segment,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: TravelEditSheet(tripId: tripId, segment: segment),
    ),
  );
}

/// 交通方式編輯：開車/步行（後端打 Google 重算）、大眾運輸（手動填分鐘）。
/// OCC = segment.version（expectedVersion）。
class TravelEditSheet extends ConsumerStatefulWidget {
  const TravelEditSheet({
    super.key,
    required this.tripId,
    required this.segment,
  });

  final String tripId;
  final TripSegment segment;

  @override
  ConsumerState<TravelEditSheet> createState() => _TravelEditSheetState();
}

class _TravelEditSheetState extends ConsumerState<TravelEditSheet> {
  late String _mode;
  late final String? _submode;
  late final String _initialMinText;
  late final TextEditingController _min;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _mode =
        const {'driving', 'walking', 'transit'}.contains(widget.segment.mode)
        ? widget.segment.mode
        : 'driving';
    _submode = _mode == 'transit' ? widget.segment.submode : null;
    _initialMinText = widget.segment.min?.toString() ?? '';
    _min = TextEditingController(text: _initialMinText);
    _min.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _min.dispose();
    super.dispose();
  }

  bool get _isTransit => _mode == 'transit';

  bool get _isAutoTransit =>
      _isTransit &&
      _autoTransitSubmodes.contains(_submode) &&
      widget.segment.source != 'manual';

  bool get _canSubmit {
    if (_submitting) return false;
    if (!_isTransit) return true;
    if (_isAutoTransit && _min.text.trim() == _initialMinText) return true;
    final v = int.tryParse(_min.text.trim());
    return v != null && v >= 0;
  }

  Future<void> _submit() async {
    final minText = _min.text.trim();
    final min = _isTransit && (!_isAutoTransit || minText != _initialMinText)
        ? int.tryParse(minText)
        : null;
    setState(() => _submitting = true);
    final repo = ref.read(tripRepositoryProvider);
    try {
      await repo.updateSegment(
        tripId: widget.tripId,
        segmentId: widget.segment.id,
        mode: _mode,
        submode: _isTransit ? _submode : null,
        min: min,
        expectedVersion: widget.segment.version,
      );
      ref.invalidate(tripDaysProvider(widget.tripId));
      ref.invalidate(tripSegmentsProvider(widget.tripId));
      if (!mounted) return;
      HapticFeedback.lightImpact();
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
