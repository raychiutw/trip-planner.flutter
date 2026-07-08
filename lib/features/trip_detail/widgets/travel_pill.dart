import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api_error.dart';
import '../../../api/providers.dart';
import '../../../models/entry.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../trip_providers.dart';

/// 站間移動 pill：sage 描邊、透明底、type icon + 分鐘數（tabular）。
class TravelPill extends StatelessWidget {
  const TravelPill({
    super.key,
    required this.travel,
    this.onTap,
    this.isStale = false,
    this.tooltip,
  });

  final Travel travel;
  final VoidCallback? onTap;
  final bool isStale;
  final String? tooltip;

  /// 移動方式 → icon；未知 type 用通用路線 icon。
  static IconData iconForType(String type) {
    switch (type) {
      case 'walk':
      case 'walking':
        return Icons.directions_walk;
      case 'car':
      case 'drive':
      case 'driving':
        return Icons.directions_car;
      case 'transit':
        return Icons.directions_transit;
      case 'taxi':
        return Icons.local_taxi;
      case 'bus':
        return Icons.directions_bus;
      case 'train':
        return Icons.train;
      case 'monorail':
      case 'tram':
        return Icons.tram;
      case 'flight':
      case 'plane':
        return Icons.flight;
      case 'ferry':
      case 'boat':
        return Icons.directions_boat;
      case 'bike':
      case 'cycle':
        return Icons.directions_bike;
      default:
        return Icons.route;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tones = Theme.of(context).extension<TpTones>()!;
    final theme = Theme.of(context);
    final label = travel.min != null
        ? '${travel.min} 分鐘'
        : (travel.desc ?? '移動');
    final borderRadius = BorderRadius.circular(999);

    final pill = Container(
      padding: EdgeInsets.only(
        left: 10,
        right: onTap == null ? 10 : 8,
        top: 4,
        bottom: 4,
      ),
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(color: tones.sage),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: tones.sageDeep,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconForType(travel.type), size: 14, color: tones.sageDeep),
            const SizedBox(width: 4),
            Text(label),
            if (isStale) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.sync_problem_outlined,
                size: 13,
                color: theme.colorScheme.error,
              ),
            ],
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.edit_outlined, size: 12, color: tones.sageDeep),
            ],
          ],
        ),
      ),
    );

    if (onTap == null) return pill;
    return Tooltip(
      message: tooltip ?? '編輯交通',
      child: Semantics(
        button: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(borderRadius: borderRadius, onTap: onTap, child: pill),
        ),
      ),
    );
  }
}

class TravelSegmentEditorSheet extends ConsumerStatefulWidget {
  const TravelSegmentEditorSheet({
    super.key,
    required this.tripId,
    required this.segment,
    required this.fromTitle,
    required this.toTitle,
  });

  final String tripId;
  final TripSegment segment;
  final String fromTitle;
  final String toTitle;

  @override
  ConsumerState<TravelSegmentEditorSheet> createState() =>
      _TravelSegmentEditorSheetState();
}

class _TravelSegmentEditorSheetState
    extends ConsumerState<TravelSegmentEditorSheet> {
  late String _mode;
  late TextEditingController _minutesController;
  bool _saving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _mode = _normalizedMode(widget.segment.mode);
    _minutesController = TextEditingController(
      text: widget.segment.min?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _minutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          TpSpacing.s4,
          TpSpacing.s4,
          TpSpacing.s4,
          TpSpacing.s4 + bottomInset,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('調整移動方式', style: theme.textTheme.titleMedium),
              const SizedBox(height: TpSpacing.s1),
              Text(
                '${widget.fromTitle} 到 ${widget.toTitle}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: TpSpacing.s4),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(
                    value: 'driving',
                    icon: Icon(Icons.directions_car),
                    label: Text('開車'),
                  ),
                  ButtonSegment<String>(
                    value: 'walking',
                    icon: Icon(Icons.directions_walk),
                    label: Text('步行'),
                  ),
                  ButtonSegment<String>(
                    value: 'transit',
                    icon: Icon(Icons.directions_transit),
                    label: Text('大眾運輸'),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: _saving
                    ? null
                    : (values) {
                        setState(() {
                          _mode = values.first;
                          _errorText = null;
                        });
                      },
              ),
              if (_mode == 'transit') ...[
                const SizedBox(height: TpSpacing.s4),
                TextField(
                  key: const ValueKey('travel-segment-min'),
                  controller: _minutesController,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: '移動分鐘',
                    suffixText: '分鐘',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              if (_errorText != null) ...[
                const SizedBox(height: TpSpacing.s4),
                _SegmentEditError(text: _errorText!),
              ],
              const SizedBox(height: TpSpacing.s5),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).maybePop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: TpSpacing.s2),
                  FilledButton.icon(
                    key: const ValueKey('travel-segment-save'),
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? '儲存中' : '儲存'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final selectedMode = _mode;
    final minutes = selectedMode == 'transit' ? _validTransitMinutes() : null;
    if (selectedMode == 'transit' && minutes == null) {
      setState(() => _errorText = '大眾運輸時間需介於 1 到 1440 分鐘');
      return;
    }

    setState(() {
      _saving = true;
      _errorText = null;
    });

    try {
      await _patchSegment(
        mode: selectedMode,
        min: minutes,
        expectedVersion: widget.segment.version,
      );
      _refreshTimelineData();
      if (mounted) Navigator.of(context).pop();
    } on ApiError catch (error) {
      if (error.code != 'STALE_ENTRY') {
        _showError(_messageForError(error));
        return;
      }
      await _retryWithFreshVersion(mode: selectedMode, min: minutes);
    } catch (error) {
      _showError(_messageForError(error));
    }
  }

  Future<void> _retryWithFreshVersion({
    required String mode,
    required int? min,
  }) async {
    try {
      final latestSegments = await ref
          .read(tripRepositoryProvider)
          .fetchTripSegments(widget.tripId);
      final latest = _findLatestSegment(latestSegments);
      if (latest == null) {
        _showError('交通段已被更新，請重新整理後再試');
        return;
      }
      await _patchSegment(
        mode: mode,
        min: min,
        expectedVersion: latest.version,
      );
      _refreshTimelineData();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      _showError(_messageForError(error));
    }
  }

  TripSegment? _findLatestSegment(List<TripSegment> segments) {
    for (final segment in segments) {
      if (segment.id == widget.segment.id) return segment;
    }
    for (final segment in segments) {
      if (segment.fromEntryId == widget.segment.fromEntryId &&
          segment.toEntryId == widget.segment.toEntryId) {
        return segment;
      }
    }
    return null;
  }

  Future<void> _patchSegment({
    required String mode,
    required int? min,
    required int expectedVersion,
  }) {
    return ref
        .read(tripRepositoryProvider)
        .updateTripSegment(
          tripId: widget.tripId,
          segmentId: widget.segment.id,
          mode: mode,
          min: min,
          expectedVersion: expectedVersion,
        );
  }

  void _refreshTimelineData() {
    ref.invalidate(tripSegmentsProvider(widget.tripId));
    ref.invalidate(tripDaysProvider(widget.tripId));
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _saving = false;
      _errorText = message;
    });
  }

  int? _validTransitMinutes() {
    final minutes = int.tryParse(_minutesController.text.trim());
    if (minutes == null || minutes < 1 || minutes > 1440) return null;
    return minutes;
  }

  String _normalizedMode(String mode) {
    switch (mode) {
      case 'walk':
        return 'walking';
      case 'car':
      case 'drive':
        return 'driving';
      case 'driving':
      case 'walking':
      case 'transit':
        return mode;
      default:
        return 'driving';
    }
  }

  String _messageForError(Object error) {
    if (error is ApiError && error.message.isNotEmpty) {
      return error.message;
    }
    return '交通段更新失敗，請稍後再試';
  }
}

class _SegmentEditError extends StatelessWidget {
  const _SegmentEditError({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey('travel-segment-error'),
      padding: const EdgeInsets.all(TpSpacing.s3),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(TpRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline,
            size: 18,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: TpSpacing.s2),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
