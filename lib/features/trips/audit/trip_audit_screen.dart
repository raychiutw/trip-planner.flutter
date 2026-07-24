/// Trip audit log screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api_error.dart';
import '../../../api/providers.dart';
import '../../../app/adaptive_content.dart';
import '../../../app/app_loading_skeleton.dart';
import '../../../models/trip.dart';
import '../../../models/trip_audit.dart';
import '../../../theme/tokens.dart';
import '../../../ui/tp_app_bar.dart';

/// Shows the latest audit rows for a trip as a read-only history.
class TripAuditScreen extends ConsumerStatefulWidget {
  const TripAuditScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<TripAuditScreen> createState() => _TripAuditScreenState();
}

class _TripAuditScreenState extends ConsumerState<TripAuditScreen> {
  bool _loading = true;
  String? _error;
  Trip? _trip;
  List<TripAuditRow> _rows = const [];
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void didUpdateWidget(covariant TripAuditScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tripId != widget.tripId) {
      _trip = null;
      _rows = const [];
      _load();
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    final generation = ++_generation;
    final tripId = widget.tripId;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repository = ref.read(tripRepositoryProvider);
      final results = await Future.wait<Object?>([
        repository.fetchTrip(tripId),
        repository.fetchAuditLog(tripId, limit: 50),
      ]);
      if (!_isCurrent(generation, tripId)) return;
      setState(() {
        _trip = results[0] as Trip;
        _rows = results[1] as List<TripAuditRow>;
      });
    } on Exception catch (error) {
      if (!_isCurrent(generation, tripId)) return;
      setState(() => _error = _auditErrorMessage(error));
    } finally {
      if (_isCurrent(generation, tripId)) {
        setState(() => _loading = false);
      }
    }
  }

  bool _isCurrent(int generation, String tripId) =>
      mounted && generation == _generation && widget.tripId == tripId;

  @override
  Widget build(BuildContext context) {
    final tripTitle = _trip?.title ?? _trip?.name ?? widget.tripId;
    return Scaffold(
      appBar: TpAppBar(
        role: TpAppBarRole.detail,
        title: const Text('異動紀錄'),
        actions: [
          TpToolbarIconButton(
            key: const ValueKey('trip-audit-refresh-button'),
            tooltip: '重新整理',
            onPressed: _loading ? null : _load,
            icon: Icons.refresh,
          ),
        ],
      ),
      body: SafeArea(
        child: _loading && _trip == null
            ? Semantics(
                key: ValueKey('trip-audit-loading-live'),
                liveRegion: true,
                label: '正在載入異動紀錄',
                child: const ExcludeSemantics(
                  child: AppListLoadingSkeleton(
                    key: ValueKey('trip-audit-loading'),
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    TpSpacing.s4,
                    TpSpacing.s4,
                    TpSpacing.s4,
                    TpSpacing.s8,
                  ),
                  children: [
                    AppAdaptiveContent(
                      maxWidth: AppContentWidth.form,
                      contentKey: const ValueKey('trip-audit-content'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_loading) ...[
                            Semantics(
                              key: const ValueKey('trip-audit-refreshing'),
                              liveRegion: true,
                              label: '正在更新異動紀錄',
                              child: const LinearProgressIndicator(),
                            ),
                            const SizedBox(height: TpSpacing.s3),
                          ],
                          _Header(title: tripTitle, count: _rows.length),
                          const SizedBox(height: TpSpacing.s4),
                          if (_error != null) ...[
                            _InlineError(message: _error!, onRetry: _load),
                            const SizedBox(height: TpSpacing.s4),
                          ],
                          if (_rows.isEmpty && _error == null)
                            const _EmptyAudit()
                          else
                            for (final row in _rows) ...[
                              _AuditCard(row: row),
                              const SizedBox(height: TpSpacing.s3),
                            ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: textTheme.headlineSmall),
        const SizedBox(height: TpSpacing.s2),
        Wrap(
          spacing: TpSpacing.s2,
          runSpacing: TpSpacing.s2,
          children: [
            Chip(
              visualDensity: VisualDensity.compact,
              avatar: const Icon(Icons.history_outlined, size: 16),
              label: Text('$count 筆'),
            ),
          ],
        ),
      ],
    );
  }
}

class _AuditCard extends StatelessWidget {
  const _AuditCard({required this.row});

  final TripAuditRow row;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final diffLines = _diffLines(row);
    return Card(
      key: ValueKey('trip-audit-row-${row.id}'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TpRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: TpSpacing.s2,
              runSpacing: TpSpacing.s2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: _actionBackground(context, row.action),
                  label: Text(_actionLabel(row.action)),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(_tableLabel(row.tableName)),
                ),
                if (row.requestId != null)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text('Request #${row.requestId}'),
                  ),
              ],
            ),
            const SizedBox(height: TpSpacing.s2),
            Text(
              '#${row.id} · ${_formatTimestamp(row.createdAt)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: TpSpacing.s1),
            Text(
              row.changedBy ?? 'system',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (row.recordId != null) ...[
              const SizedBox(height: TpSpacing.s1),
              Text(
                'Record #${row.recordId}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (diffLines.isNotEmpty) ...[
              const SizedBox(height: TpSpacing.s3),
              for (final line in diffLines)
                Padding(
                  padding: const EdgeInsets.only(bottom: TpSpacing.s1),
                  child: Text(line),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      key: const ValueKey('trip-audit-error'),
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(TpSpacing.s4),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(TpRadius.md),
        ),
        child: Wrap(
          spacing: TpSpacing.s2,
          runSpacing: TpSpacing.s2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
            TextButton(
              key: const ValueKey('trip-audit-error-retry'),
              onPressed: onRetry,
              child: const Text('重試'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyAudit extends StatelessWidget {
  const _EmptyAudit();

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('trip-audit-empty'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TpRadius.md),
      ),
      child: const Padding(
        padding: EdgeInsets.all(TpSpacing.s5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.history_outlined),
            SizedBox(height: TpSpacing.s3),
            Text('尚無異動紀錄'),
          ],
        ),
      ),
    );
  }
}

Color _actionBackground(BuildContext context, TripAuditAction action) {
  final colorScheme = Theme.of(context).colorScheme;
  return switch (action) {
    TripAuditAction.insert => colorScheme.secondaryContainer,
    TripAuditAction.update => colorScheme.primaryContainer,
    TripAuditAction.delete => colorScheme.errorContainer,
    TripAuditAction.error => colorScheme.errorContainer,
    TripAuditAction.unknown => colorScheme.surfaceContainerHigh,
  };
}

String _actionLabel(TripAuditAction action) => switch (action) {
  TripAuditAction.insert => '新增',
  TripAuditAction.update => '更新',
  TripAuditAction.delete => '刪除',
  TripAuditAction.error => '錯誤',
  TripAuditAction.unknown => '未知',
};

String _tableLabel(String tableName) => switch (tableName) {
  'trips' => '行程',
  'trip_days' => '日期',
  'trip_entries' => '停留點',
  'pois' => 'POI',
  'poi_relations' => 'POI 關聯',
  'trip_docs' => '文件',
  'trip_doc_entries' => '文件項目',
  'trip_requests' => 'AI 請求',
  'trip_permissions' => '權限',
  _ => tableName,
};

List<String> _diffLines(TripAuditRow row) {
  final diff = _readMap(() => row.diff);
  if (diff != null && diff.isNotEmpty) {
    return [
      for (final entry in diff.entries.take(4))
        '${entry.key}: ${_diffValue(entry.value)}',
    ];
  }
  final snapshot = _readMap(() => row.snapshotRow);
  if (snapshot != null && snapshot.isNotEmpty) {
    return [
      '快照：',
      for (final entry in snapshot.entries.take(3))
        '${entry.key}: ${_compactValue(entry.value)}',
    ];
  }
  if (row.companionFailureReason != null) {
    return ['原因：${row.companionFailureReason}'];
  }
  return const [];
}

Map<String, dynamic>? _readMap(Map<String, dynamic>? Function() read) {
  try {
    return read();
  } on FormatException {
    return null;
  }
}

String _diffValue(Object? value) {
  if (value is Map) {
    final oldValue = _compactValue(value['old']);
    final newValue = _compactValue(value['new']);
    return '$oldValue → $newValue';
  }
  return _compactValue(value);
}

String _compactValue(Object? value) {
  final text = value?.toString() ?? 'null';
  return text.length > 48 ? '${text.substring(0, 48)}...' : text;
}

String _formatTimestamp(String value) {
  if (value.length >= 16) return value.replaceFirst('T', ' ').substring(0, 16);
  return value;
}

String _auditErrorMessage(Object error) {
  if (error is ApiError && _hasCjk(error.message)) return error.message;
  return '載入異動紀錄失敗，請稍後再試';
}

bool _hasCjk(String value) => RegExp(r'[一-鿿]').hasMatch(value);
