/// 編輯單一 timeline entry 的表單。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_error.dart';
import '../../api/providers.dart';
import '../../api/trip_repository.dart';
import '../../models/entry.dart';
import '../../theme/tokens.dart';
import 'trip_providers.dart';

class EditEntryScreen extends ConsumerStatefulWidget {
  const EditEntryScreen({
    super.key,
    required this.tripId,
    required this.entryId,
  });

  final String tripId;
  final int entryId;

  @override
  ConsumerState<EditEntryScreen> createState() => _EditEntryScreenState();
}

class _EditEntryScreenState extends ConsumerState<EditEntryScreen> {
  final _startTimeController = TextEditingController();
  final _endTimeController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _hasHydrated = false;
  bool _isSubmitting = false;
  int? _alternatePendingPoiId;
  String? _submitError;
  String? _alternateError;

  static final _timePattern = RegExp(r'^\d{2}:\d{2}$');

  @override
  void dispose() {
    _startTimeController.dispose();
    _endTimeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = (tripId: widget.tripId, entryId: widget.entryId);
    final entryAsync = ref.watch(entryDetailProvider(args));

    return Scaffold(
      appBar: AppBar(title: const Text('編輯景點')),
      body: entryAsync.when(
        data: (entry) {
          _hydrateControllers(entry);
          return _buildForm(entry);
        },
        error: (error, stackTrace) => _LoadErrorState(
          message: '無法取得景點資料',
          onRetry: () => ref.invalidate(entryDetailProvider(args)),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildForm(TimelineEntry entry) {
    return ListView(
      padding: const EdgeInsets.all(TpSpacing.s4),
      children: [
        _EntrySummaryCard(entry: entry),
        const SizedBox(height: TpSpacing.s4),
        _PoiActions(
          tripId: widget.tripId,
          entryId: widget.entryId,
          enabled: !_isSubmitting,
        ),
        const SizedBox(height: TpSpacing.s4),
        _AlternatesSection(
          alternates: entry.alternates,
          pendingPoiId: _alternatePendingPoiId,
          error: _alternateError,
          enabled: !_isSubmitting && _alternatePendingPoiId == null,
          onMove: (alternate, delta) => _reorderAlternate(
            entry: entry,
            alternate: alternate,
            delta: delta,
          ),
          onDelete: (alternate) => _confirmRemoveAlternate(entry, alternate),
        ),
        const SizedBox(height: TpSpacing.s4),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                key: const ValueKey('edit-entry-start-time'),
                controller: _startTimeController,
                decoration: const InputDecoration(
                  labelText: '開始時間',
                  border: OutlineInputBorder(),
                ),
                enabled: !_isSubmitting,
                keyboardType: TextInputType.datetime,
              ),
            ),
            const SizedBox(width: TpSpacing.s3),
            Expanded(
              child: TextFormField(
                key: const ValueKey('edit-entry-end-time'),
                controller: _endTimeController,
                decoration: const InputDecoration(
                  labelText: '結束時間',
                  border: OutlineInputBorder(),
                ),
                enabled: !_isSubmitting,
                keyboardType: TextInputType.datetime,
              ),
            ),
          ],
        ),
        const SizedBox(height: TpSpacing.s3),
        TextFormField(
          key: const ValueKey('edit-entry-description'),
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: '描述',
            border: OutlineInputBorder(),
          ),
          enabled: !_isSubmitting,
          minLines: 3,
          maxLines: 5,
        ),
        if (_submitError != null) ...[
          const SizedBox(height: TpSpacing.s3),
          _InlineError(message: _submitError!),
        ],
        const SizedBox(height: TpSpacing.s5),
        FilledButton.icon(
          key: const ValueKey('edit-entry-save'),
          icon: _isSubmitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: const Text('儲存'),
          onPressed: _isSubmitting ? null : () => _save(entry),
        ),
        const SizedBox(height: TpSpacing.s3),
        OutlinedButton.icon(
          key: const ValueKey('edit-entry-delete'),
          icon: const Icon(Icons.delete_outline),
          label: const Text('刪除景點'),
          onPressed: _isSubmitting ? null : () => _confirmDelete(entry),
        ),
      ],
    );
  }

  void _hydrateControllers(TimelineEntry entry) {
    if (_hasHydrated) return;
    _startTimeController.text = entry.startTime ?? '';
    _endTimeController.text = entry.endTime ?? '';
    _descriptionController.text = entry.description ?? '';
    _hasHydrated = true;
  }

  Future<void> _save(TimelineEntry entry) async {
    final startTime = _startTimeController.text.trim();
    final endTime = _endTimeController.text.trim();
    final description = _descriptionController.text.trim();
    final startMinutes = _parseOptionalTime(startTime);
    final endMinutes = _parseOptionalTime(endTime);
    if (startMinutes == null || endMinutes == null) {
      setState(() => _submitError = '時間格式需為 HH:MM，或留空');
      return;
    }
    if (startMinutes >= 0 && endMinutes >= 0 && startMinutes >= endMinutes) {
      setState(() => _submitError = '開始時間必須早於結束時間');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });
    try {
      final repository = ref.read(tripRepositoryProvider);
      await _updateEntryWithRetry(
        repository,
        entry,
        startTime: startTime.isEmpty ? null : startTime,
        endTime: endTime.isEmpty ? null : endTime,
        description: description.isEmpty ? null : description,
      );
      _afterMutation(repository);
    } on Exception {
      if (!mounted) return;
      setState(() {
        _submitError = '儲存失敗，資料可能已更新，請返回後重新進入';
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _confirmDelete(TimelineEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('刪除景點？'),
        content: Text('確定要刪除「${entry.title}」嗎？此操作無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });
    try {
      final repository = ref.read(tripRepositoryProvider);
      await repository.deleteEntry(widget.tripId, widget.entryId);
      _afterMutation(repository);
    } on Exception {
      if (!mounted) return;
      setState(() => _submitError = '刪除失敗，請稍後再試');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _confirmRemoveAlternate(
    TimelineEntry entry,
    EntryPoiInfo alternate,
  ) async {
    final name = _poiName(alternate);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移除備選？'),
        content: Text('確定要移除「$name」嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _alternatePendingPoiId = alternate.poiId;
      _alternateError = null;
    });
    try {
      final repository = ref.read(tripRepositoryProvider);
      await _deleteAlternateWithRetry(repository, entry, alternate.poiId);
      _refreshEntryPois();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _alternateError = _alternateErrorMessage(error, '移除備選失敗，請稍後再試');
      });
    } finally {
      if (mounted) setState(() => _alternatePendingPoiId = null);
    }
  }

  Future<void> _reorderAlternate({
    required TimelineEntry entry,
    required EntryPoiInfo alternate,
    required int delta,
  }) async {
    final index = entry.alternates.indexWhere(
      (item) => item.poiId == alternate.poiId,
    );
    final targetIndex = index + delta;
    if (index < 0 ||
        targetIndex < 0 ||
        targetIndex >= entry.alternates.length) {
      return;
    }
    final orderedPoiIds = entry.alternates.map((item) => item.poiId).toList();
    final currentPoiId = orderedPoiIds[index];
    orderedPoiIds[index] = orderedPoiIds[targetIndex];
    orderedPoiIds[targetIndex] = currentPoiId;

    setState(() {
      _alternatePendingPoiId = alternate.poiId;
      _alternateError = null;
    });
    try {
      final repository = ref.read(tripRepositoryProvider);
      await _reorderAlternatesWithRetry(repository, entry, orderedPoiIds);
      _refreshEntryPois();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _alternateError = _alternateErrorMessage(error, '調整備選順序失敗，請稍後再試');
      });
    } finally {
      if (mounted) setState(() => _alternatePendingPoiId = null);
    }
  }

  Future<void> _updateEntryWithRetry(
    TripRepository repository,
    TimelineEntry entry, {
    required String? startTime,
    required String? endTime,
    required String? description,
  }) async {
    Future<void> send(TimelineEntry tokenEntry) async {
      await repository.updateEntry(
        widget.tripId,
        widget.entryId,
        expectedVersion: tokenEntry.version,
        startTime: startTime,
        endTime: endTime,
        description: description,
      );
    }

    try {
      await send(entry);
    } on ApiError catch (error, stackTrace) {
      if (error.code != 'STALE_ENTRY') {
        Error.throwWithStackTrace(error, stackTrace);
      }
      final latest = await _fetchLatestEntryForRetry(repository);
      if (latest == null) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      await send(latest);
    }
  }

  Future<void> _deleteAlternateWithRetry(
    TripRepository repository,
    TimelineEntry entry,
    int poiId,
  ) async {
    Future<void> send(TimelineEntry tokenEntry) async {
      await repository.deleteEntryAlternate(
        tripId: widget.tripId,
        entryId: widget.entryId,
        poiId: poiId,
        entryPoisVersion: tokenEntry.entryPoisVersion,
      );
    }

    try {
      await send(entry);
    } on ApiError catch (error, stackTrace) {
      if (error.code != 'STALE_ENTRY') {
        Error.throwWithStackTrace(error, stackTrace);
      }
      final latest = await _fetchLatestEntryForRetry(repository);
      if (latest == null) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      await send(latest);
    }
  }

  Future<void> _reorderAlternatesWithRetry(
    TripRepository repository,
    TimelineEntry entry,
    List<int> orderedPoiIds,
  ) async {
    Future<void> send(TimelineEntry tokenEntry) async {
      await repository.reorderEntryAlternates(
        tripId: widget.tripId,
        entryId: widget.entryId,
        orderedPoiIds: orderedPoiIds,
        entryPoisVersion: tokenEntry.entryPoisVersion,
      );
    }

    try {
      await send(entry);
    } on ApiError catch (error, stackTrace) {
      if (error.code != 'STALE_ENTRY') {
        Error.throwWithStackTrace(error, stackTrace);
      }
      final latest = await _fetchLatestEntryForRetry(repository);
      if (latest == null) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      await send(latest);
    }
  }

  Future<TimelineEntry?> _fetchLatestEntryForRetry(
    TripRepository repository,
  ) async {
    try {
      return await repository.fetchEntry(widget.tripId, widget.entryId);
    } on Exception {
      return null;
    }
  }

  void _afterMutation(TripRepository repository) {
    ref.invalidate(
      entryDetailProvider((tripId: widget.tripId, entryId: widget.entryId)),
    );
    ref.invalidate(tripDaysProvider(widget.tripId));
    unawaited(
      repository.recomputeTravel(widget.tripId).catchError((Object _) {}),
    );
    if (mounted) context.go('/trips/${widget.tripId}');
  }

  void _refreshEntryPois() {
    ref.invalidate(
      entryDetailProvider((tripId: widget.tripId, entryId: widget.entryId)),
    );
    ref.invalidate(tripDaysProvider(widget.tripId));
  }

  String _alternateErrorMessage(Object error, String fallback) {
    if (error is ApiError && error.code == 'STALE_ENTRY') {
      return '備選資料已被其他操作更新，請重新整理後再試';
    }
    return fallback;
  }

  int? _parseOptionalTime(String value) {
    if (value.isEmpty) return -1;
    if (!_timePattern.hasMatch(value)) return null;
    final parts = value.split(':');
    final hours = int.parse(parts[0]);
    final minutes = int.parse(parts[1]);
    if (hours > 23 || minutes > 59) return null;
    return hours * 60 + minutes;
  }
}

String _poiName(EntryPoiInfo poi) => poi.name ?? 'POI #${poi.poiId}';

class _PoiActions extends StatelessWidget {
  const _PoiActions({
    required this.tripId,
    required this.entryId,
    required this.enabled,
  });

  final String tripId;
  final int entryId;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('edit-entry-change-poi'),
                icon: const Icon(Icons.swap_horiz_outlined),
                label: const Text('置換景點'),
                onPressed: enabled
                    ? () =>
                          context.go('/trips/$tripId/stop/$entryId/change-poi')
                    : null,
              ),
            ),
            const SizedBox(width: TpSpacing.s3),
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('edit-entry-add-alternate'),
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('加入備選'),
                onPressed: enabled
                    ? () => context.go(
                        '/trips/$tripId/stop/$entryId/change-poi?mode=alternate',
                      )
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: TpSpacing.s2),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('edit-entry-copy'),
                icon: const Icon(Icons.copy_outlined),
                label: const Text('複製景點'),
                onPressed: enabled
                    ? () => context.go('/trips/$tripId/stop/$entryId/copy')
                    : null,
              ),
            ),
            const SizedBox(width: TpSpacing.s3),
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('edit-entry-move'),
                icon: const Icon(Icons.drive_file_move),
                label: const Text('移動景點'),
                onPressed: enabled
                    ? () => context.go('/trips/$tripId/stop/$entryId/move')
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EntrySummaryCard extends StatelessWidget {
  const _EntrySummaryCard({required this.entry});

  final TimelineEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metaStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final master = entry.master;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(entry.title, style: theme.textTheme.titleMedium),
            if (master?.note != null && master!.note!.trim().isNotEmpty) ...[
              const SizedBox(height: TpSpacing.s2),
              Text(master.note!, style: metaStyle),
            ],
            if (entry.alternates.isNotEmpty) ...[
              const SizedBox(height: TpSpacing.s2),
              Text(
                '備選：${entry.alternates.map((poi) => poi.name ?? 'POI #${poi.poiId}').join('、')}',
                style: metaStyle,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AlternatesSection extends StatelessWidget {
  const _AlternatesSection({
    required this.alternates,
    required this.pendingPoiId,
    required this.error,
    required this.enabled,
    required this.onMove,
    required this.onDelete,
  });

  final List<EntryPoiInfo> alternates;
  final int? pendingPoiId;
  final String? error;
  final bool enabled;
  final void Function(EntryPoiInfo alternate, int delta) onMove;
  final void Function(EntryPoiInfo alternate) onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('備選景點', style: theme.textTheme.titleSmall),
            const SizedBox(width: TpSpacing.s2),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: const BorderRadius.all(
                  Radius.circular(TpRadius.md),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TpSpacing.s2,
                  vertical: TpSpacing.s1,
                ),
                child: Text('${alternates.length} 個'),
              ),
            ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: TpSpacing.s2),
          _InlineError(message: error!),
        ],
        const SizedBox(height: TpSpacing.s2),
        if (alternates.isEmpty)
          Text(
            '還沒有備選景點。可從搜尋或收藏加入。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          )
        else
          for (var index = 0; index < alternates.length; index++) ...[
            _AlternateTile(
              alternate: alternates[index],
              displayOrder: index + 2,
              isPending: pendingPoiId == alternates[index].poiId,
              canMoveUp: enabled && index > 0,
              canMoveDown: enabled && index < alternates.length - 1,
              canDelete: enabled,
              onMoveUp: () => onMove(alternates[index], -1),
              onMoveDown: () => onMove(alternates[index], 1),
              onDelete: () => onDelete(alternates[index]),
            ),
            if (index < alternates.length - 1)
              const SizedBox(height: TpSpacing.s2),
          ],
      ],
    );
  }
}

class _AlternateTile extends StatelessWidget {
  const _AlternateTile({
    required this.alternate,
    required this.displayOrder,
    required this.isPending,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.canDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
  });

  final EntryPoiInfo alternate;
  final int displayOrder;
  final bool isPending;
  final bool canMoveUp;
  final bool canMoveDown;
  final bool canDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: colorScheme.secondaryContainer,
          foregroundColor: colorScheme.onSecondaryContainer,
          child: Text('$displayOrder'),
        ),
        title: Text(_poiName(alternate)),
        subtitle: alternate.type == null ? null : Text(alternate.type!),
        trailing: isPending
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: ValueKey('edit-entry-alt-up-${alternate.poiId}'),
                    tooltip: '上移',
                    icon: const Icon(Icons.keyboard_arrow_up),
                    onPressed: canMoveUp ? onMoveUp : null,
                  ),
                  IconButton(
                    key: ValueKey('edit-entry-alt-down-${alternate.poiId}'),
                    tooltip: '下移',
                    icon: const Icon(Icons.keyboard_arrow_down),
                    onPressed: canMoveDown ? onMoveDown : null,
                  ),
                  IconButton(
                    key: ValueKey('edit-entry-alt-delete-${alternate.poiId}'),
                    tooltip: '移除',
                    icon: const Icon(Icons.delete_outline),
                    color: theme.colorScheme.error,
                    onPressed: canDelete ? onDelete : null,
                  ),
                ],
              ),
      ),
    );
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
        child: Row(
          children: [
            Icon(Icons.error_outline, color: colorScheme.error),
            const SizedBox(width: TpSpacing.s2),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadErrorState extends StatelessWidget {
  const _LoadErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: TpSpacing.s3),
          FilledButton(onPressed: onRetry, child: const Text('重試')),
        ],
      ),
    );
  }
}
