import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api_error.dart';
import '../../../api/providers.dart';
import '../../../app/adaptive.dart';
import '../../../app/app_feedback.dart';
import '../../../models/entry.dart';
import '../../../models/segment.dart';
import '../../../theme/tokens.dart';
import '../trip_providers.dart';

/// 開啟交通編輯 bottom sheet。
Future<void> showTravelEditSheet(
  BuildContext context, {
  required String tripId,
  TripSegment? segment,
  int? fromEntryId,
  int? toEntryId,
  Travel? travel,
}) async {
  // 不變式由 TravelEditSheet 的建構子守,這裡不再重複 assert。
  final controller = AppSheetFormController();
  try {
    await showAppFormSheet(
      context,
      title: '交通方式',
      submitLabel: '儲存',
      submitKey: const ValueKey('travel-submit'),
      controller: controller,
      builder: (_) => TravelEditSheet(
        tripId: tripId,
        segment: segment,
        fromEntryId: fromEntryId,
        toEntryId: toEntryId,
        travel: travel,
        formController: controller,
      ),
    );
  } finally {
    controller.dispose();
  }
}

/// 交通方式編輯：固定方式可自動估算並覆寫分鐘；「其他」需填 1–1440 分鐘。
/// 有 segment 時走 OCC PATCH；缺 segment row 時以 from/to entry pair 建立。
class TravelEditSheet extends ConsumerStatefulWidget {
  const TravelEditSheet({
    super.key,
    required this.tripId,
    this.segment,
    this.fromEntryId,
    this.toEntryId,
    this.travel,
    this.formController,
  }) : assert(
         segment != null || (fromEntryId != null && toEntryId != null),
         'Missing segment creation requires fromEntryId and toEntryId.',
       );

  final String tripId;
  final TripSegment? segment;
  final int? fromEntryId;
  final int? toEntryId;

  /// 缺 segment row 時的初始值來源(時間軸上停留點自帶的移動段資料)。
  final Travel? travel;
  final AppSheetFormController? formController;

  @override
  ConsumerState<TravelEditSheet> createState() => _TravelEditSheetState();
}

class _TravelEditSheetState extends ConsumerState<TravelEditSheet> {
  late String _methodKey;
  late final String _initialMethodKey;
  late final String? _initialSource;
  late final int? _initialMin;
  late final TextEditingController _min;
  late final TextEditingController _other;
  late bool _noTravel;
  bool _submitting = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final travel = widget.travel;
    final mode = widget.segment?.mode ?? travel?.type;
    final submode = widget.segment?.submode ?? travel?.submode;
    final source = widget.segment?.source ?? travel?.source;
    _methodKey = travelMethodKey(mode, submode);
    _initialMethodKey = _methodKey;
    _initialSource = source;
    _noTravel = widget.segment?.noTravel ?? travel?.sameplace ?? false;
    final option = _optionFor(_methodKey);
    final currentMin = widget.segment?.min ?? travel?.min;
    _initialMin = currentMin;
    _min = TextEditingController(
      text: !option.automatic || source == 'manual'
          ? currentMin?.toString() ?? ''
          : '',
    );
    _other = TextEditingController(
      text: _methodKey == 'other'
          ? (submode?.trim().isNotEmpty == true ? submode!.trim() : '大眾運輸')
          : '大眾運輸',
    );
    _min.addListener(_markChanged);
    _other.addListener(_markChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.formController?.attach(_submitForSheet);
      _syncFormState();
    });
  }

  @override
  void dispose() {
    _min.dispose();
    _other.dispose();
    super.dispose();
  }

  TravelMethodOption get _selected => _optionFor(_methodKey);

  int? get _minuteValue => int.tryParse(_min.text.trim());

  bool get _minuteIsValid {
    final value = _minuteValue;
    return value != null && value >= 1 && value <= 1440;
  }

  bool get _canSubmit {
    if (_submitting) return false;
    if (_noTravel) return true;
    if (_methodKey == 'other') {
      final name = _other.text.trim();
      if (name.isEmpty || name.length > 20) return false;
    }
    if (_min.text.trim().isEmpty) return _selected.automatic;
    return _minuteIsValid;
  }

  void _markChanged() {
    _dirty = true;
    setState(() {});
    _syncFormState();
  }

  void _syncFormState() {
    widget.formController?.update(
      dirty: _dirty,
      canSubmit: _canSubmit,
      submitting: _submitting,
    );
  }

  void _selectMethod(TravelMethodOption option) {
    final changed = _methodKey != option.key;
    _noTravel = false;
    _methodKey = option.key;
    _markChanged();
    if (!changed) return;
    if (option.automatic &&
        option.key == _initialMethodKey &&
        _initialSource == 'manual') {
      _min.text = _initialMin?.toString() ?? '';
    } else {
      _min.clear();
    }
  }

  Future<bool> _submitForSheet() => _save();

  Future<void> _submitLegacy() async {
    final saved = await _save();
    if (!saved || !mounted) return;
    Navigator.of(context).pop();
  }

  Future<bool> _save() async {
    final min = _min.text.trim().isEmpty ? null : _minuteValue;
    final option = _selected;
    final submode = _methodKey == 'other' ? _other.text.trim() : option.submode;
    setState(() => _submitting = true);
    _syncFormState();
    final repo = ref.read(tripRepositoryProvider);
    try {
      final segment = widget.segment;
      if (segment != null) {
        await repo.updateSegment(
          tripId: widget.tripId,
          segmentId: segment.id,
          mode: _noTravel ? null : option.mode,
          submode: _noTravel ? null : submode,
          clearSubmode: !_noTravel && submode == null,
          min: _noTravel ? null : min,
          noTravel: _noTravel,
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
          mode: _noTravel ? null : option.mode,
          submode: _noTravel ? null : submode,
          min: _noTravel ? null : min,
          noTravel: _noTravel,
        );
      }
      ref.invalidate(tripDaysProvider(widget.tripId));
      ref.invalidate(tripSegmentsProvider(widget.tripId));
      if (!mounted) return false;
      HapticFeedback.lightImpact();
      _dirty = false;
      _submitting = false;
      _syncFormState();
      showAppNotice(context, '已更新交通');
      return true;
    } on ApiError catch (error) {
      if (!mounted) return false;
      if (error.status == 409) {
        ref.invalidate(tripSegmentsProvider(widget.tripId));
        showAppError(context, '交通已更新，已重新載入');
        setState(() => _submitting = false);
        _syncFormState();
        return false;
      }
      setState(() => _submitting = false);
      _syncFormState();
      showAppError(context, '更新失敗，請稍後再試');
      return false;
    } on Exception {
      if (!mounted) return false;
      setState(() => _submitting = false);
      _syncFormState();
      showAppError(context, '更新失敗，請稍後再試');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(TpSpacing.s4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.formController == null) ...[
                Text('交通方式', style: theme.textTheme.titleLarge),
                const SizedBox(height: TpSpacing.s4),
              ],
              Wrap(
                spacing: TpSpacing.s2,
                runSpacing: TpSpacing.s2,
                children: [
                  for (final option in travelMethodOptions)
                    ChoiceChip(
                      key: ValueKey(
                        option.key == 'other'
                            ? 'travel-mode-transit'
                            : 'travel-mode-${option.key}',
                      ),
                      label: Text(option.label),
                      selected: !_noTravel && _methodKey == option.key,
                      onSelected: (_) => _selectMethod(option),
                    ),
                  ChoiceChip(
                    key: const ValueKey('travel-mode-no-travel'),
                    label: const Text('不需計算路程'),
                    selected: _noTravel,
                    onSelected: (_) {
                      _noTravel = true;
                      _markChanged();
                    },
                  ),
                ],
              ),
              const SizedBox(height: TpSpacing.s3),
              if (!_noTravel && _methodKey == 'other') ...[
                TextField(
                  key: const ValueKey('travel-other-name'),
                  controller: _other,
                  maxLength: 20,
                  decoration: const InputDecoration(labelText: '交通方式名稱'),
                ),
                const SizedBox(height: TpSpacing.s2),
              ],
              if (!_noTravel) ...[
                TextField(
                  key: const ValueKey('travel-min'),
                  controller: _min,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: '分鐘數',
                    helperText: _selected.automatic
                        ? '自動計算；選填 1–1440 分鐘可手動覆寫'
                        : '必填 1–1440 分鐘',
                    errorText: _min.text.trim().isNotEmpty && !_minuteIsValid
                        ? '請輸入 1–1440'
                        : null,
                  ),
                ),
                if (_selected.automatic && _min.text.trim().isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      key: const ValueKey('travel-restore-auto'),
                      onPressed: _min.clear,
                      child: const Text('恢復自動計算'),
                    ),
                  ),
              ] else
                Text(
                  '此段會保留相鄰地點，但不顯示交通時間與距離。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              if (widget.formController == null) ...[
                const SizedBox(height: TpSpacing.s5),
                FilledButton(
                  key: const ValueKey('travel-submit'),
                  onPressed: _canSubmit ? _submitLegacy : null,
                  child: Text(_submitting ? '更新中…' : '儲存'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

TravelMethodOption _optionFor(String key) =>
    travelMethodOptions.firstWhere((option) => option.key == key);
