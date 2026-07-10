import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api_error.dart';
import '../../../api/providers.dart';
import '../../../app/adaptive.dart';
import '../../../models/segment.dart';
import '../../../theme/tokens.dart';
import '../trip_providers.dart';

typedef _TravelMethod = ({
  String key,
  String mode,
  String? submode,
  String label,
  bool auto,
});

const List<_TravelMethod> _methods = [
  (key: 'driving', mode: 'driving', submode: null, label: '駕車', auto: true),
  (key: 'walking', mode: 'walking', submode: null, label: '步行', auto: true),
  (
    key: 'monorail',
    mode: 'transit',
    submode: 'monorail',
    label: '單軌',
    auto: true,
  ),
  (key: 'bus', mode: 'transit', submode: 'bus', label: '公車', auto: true),
  (key: 'metro', mode: 'transit', submode: 'metro', label: '地鐵', auto: false),
  (key: 'train', mode: 'transit', submode: 'train', label: '火車', auto: false),
  (key: 'hsr', mode: 'transit', submode: 'hsr', label: '高鐵', auto: false),
  (key: 'other', mode: 'transit', submode: null, label: '其他', auto: false),
];

String _initialMethodKey(TripSegment segment) {
  if (segment.noTravel) return 'sameplace';
  if (segment.mode == 'driving' || segment.mode == 'walking') {
    return segment.mode;
  }
  final submode = segment.submode;
  if (_methods.any((method) => method.key == submode)) return submode!;
  return 'other';
}

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
  late final String _initialKey;
  late String _selectedKey;
  late final String _initialMinText;
  late final TextEditingController _min;
  late final TextEditingController _other;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _initialKey = _initialMethodKey(widget.segment);
    _selectedKey = _initialKey;
    final initialMethod = _selectedKey == 'sameplace'
        ? null
        : _methods.firstWhere((method) => method.key == _selectedKey);
    _initialMinText =
        initialMethod?.auto == true && widget.segment.source != 'manual'
        ? ''
        : widget.segment.min?.toString() ?? '';
    _min = TextEditingController(text: _initialMinText)..addListener(_refresh);
    _other = TextEditingController(
      text: _selectedKey == 'other' ? widget.segment.submode ?? '' : '',
    )..addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _min.dispose();
    _other.dispose();
    super.dispose();
  }

  bool get _isSamePlace => _selectedKey == 'sameplace';

  _TravelMethod get _selectedMethod =>
      _methods.firstWhere((method) => method.key == _selectedKey);

  bool get _validMinutes {
    final value = int.tryParse(_min.text.trim());
    return value != null && value >= 1 && value <= 1440;
  }

  bool get _canSubmit {
    if (_submitting) return false;
    if (_isSamePlace) return true;
    final method = _selectedMethod;
    if (method.key == 'other' && _other.text.trim().isEmpty) return false;
    if (method.auto && _min.text.trim().isEmpty) return true;
    return _validMinutes;
  }

  void _select(String key) {
    setState(() => _selectedKey = key);
    _min.text = key == _initialKey ? _initialMinText : '';
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final repo = ref.read(tripRepositoryProvider);
    try {
      if (_isSamePlace) {
        await repo.updateSegment(
          tripId: widget.tripId,
          segmentId: widget.segment.id,
          mode: widget.segment.mode,
          noTravel: true,
          expectedVersion: widget.segment.version,
        );
      } else {
        final method = _selectedMethod;
        await repo.updateSegment(
          tripId: widget.tripId,
          segmentId: widget.segment.id,
          mode: method.mode,
          submode: method.key == 'other' ? _other.text.trim() : method.submode,
          min: _min.text.trim().isEmpty ? null : int.parse(_min.text.trim()),
          expectedVersion: widget.segment.version,
        );
      }
      ref.invalidate(tripDaysProvider(widget.tripId));
      ref.invalidate(tripSegmentsProvider(widget.tripId));
      if (!mounted) return;
      HapticFeedback.lightImpact();
      Navigator.of(context).pop();
      showAppNotice(context, '已更新交通');
    } on ApiError catch (error) {
      if (!mounted) return;
      if (error.status == 409) {
        ref.invalidate(tripSegmentsProvider(widget.tripId));
        Navigator.of(context).pop();
        showAppNotice(context, '交通已更新，已重新載入');
        return;
      }
      setState(() => _submitting = false);
      showAppNotice(context, '更新失敗，請稍後再試');
    } on Exception {
      if (!mounted) return;
      setState(() => _submitting = false);
      showAppNotice(context, '更新失敗，請稍後再試');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final method = _isSamePlace ? null : _selectedMethod;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(TpSpacing.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('交通方式', style: theme.textTheme.titleLarge),
            const SizedBox(height: TpSpacing.s4),
            Wrap(
              spacing: TpSpacing.s2,
              runSpacing: TpSpacing.s2,
              children: [
                for (final option in _methods)
                  ChoiceChip(
                    key: ValueKey('travel-method-${option.key}'),
                    label: Text(option.label),
                    selected: _selectedKey == option.key,
                    onSelected: (_) => _select(option.key),
                  ),
              ],
            ),
            const SizedBox(height: TpSpacing.s3),
            Text('或', style: theme.textTheme.labelMedium),
            ListTile(
              key: const ValueKey('travel-method-sameplace'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('同一地點・免交通'),
              subtitle: const Text('此段不顯示交通時間'),
              selected: _isSamePlace,
              onTap: () => _select('sameplace'),
            ),
            if (!_isSamePlace) ...[
              const SizedBox(height: TpSpacing.s3),
              if (method!.key == 'other') ...[
                TextField(
                  key: const ValueKey('travel-other-name'),
                  controller: _other,
                  maxLength: 20,
                  decoration: const InputDecoration(
                    labelText: '交通方式名稱',
                    hintText: '例：水上巴士、纜車',
                  ),
                ),
                const SizedBox(height: TpSpacing.s2),
              ],
              TextField(
                key: const ValueKey('travel-min'),
                controller: _min,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: method.auto ? '手動覆寫分鐘（選填）' : '分鐘數',
                  helperText: method.auto ? '留空會使用自動計算' : '請輸入 1–1440 分鐘',
                ),
              ),
            ] else ...[
              const SizedBox(height: TpSpacing.s2),
              Text(
                '兩地視為同一處，不計交通時間。選擇上方方式即可恢復。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
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
