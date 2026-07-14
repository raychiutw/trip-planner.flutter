/// Trip audit log screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api_error.dart';
import '../../../api/providers.dart';
import '../../../app/app_loading_skeleton.dart';
import '../../../models/trip.dart';
import '../../../models/trip_audit.dart';
import '../../../theme/tokens.dart';

/// Shows the latest audit rows for a trip and allows safe rollback.
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
  int? _rollingBackId;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void didUpdateWidget(covariant TripAuditScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tripId != widget.tripId) {
      _load();
    }
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _error = null);
    }

    try {
      final repository = ref.read(tripRepositoryProvider);
      final results = await Future.wait<Object?>([
        repository.fetchTrip(widget.tripId),
        repository.fetchAuditLog(widget.tripId, limit: 50),
      ]);
      if (!mounted) return;
      setState(() {
        _trip = results[0] as Trip;
        _rows = results[1] as List<TripAuditRow>;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _error = _auditErrorMessage(error));
    } finally {
      if (mounted && showLoading) setState(() => _loading = false);
    }
  }

  Future<void> _rollback(TripAuditRow row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('回滾異動'),
        content: Text('確定要回滾 #${row.id} 這筆異動嗎？此操作會寫入新的 audit 記錄。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('回滾'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _rollingBackId = row.id;
      _error = null;
    });
    try {
      await ref
          .read(tripRepositoryProvider)
          .rollbackAudit(tripId: widget.tripId, auditId: row.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已回滾異動')));
      await _load(showLoading: false);
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _error = _auditErrorMessage(error));
    } finally {
      if (mounted) setState(() => _rollingBackId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripTitle = _trip?.title ?? _trip?.name ?? widget.tripId;
    return Scaffold(
      appBar: AppBar(
        title: const Text('異動紀錄'),
        actions: [
          IconButton(
            key: const ValueKey('trip-audit-refresh-button'),
            tooltip: '重新整理',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const AppListLoadingSkeleton(key: ValueKey('trip-audit-loading'))
            : RefreshIndicator(
                onRefresh: () => _load(showLoading: false),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    TpSpacing.s4,
                    TpSpacing.s4,
                    TpSpacing.s4,
                    TpSpacing.s8,
                  ),
                  children: [
                    _Header(title: tripTitle, count: _rows.length),
                    const SizedBox(height: TpSpacing.s4),
                    if (_error != null) ...[
                      _InlineError(message: _error!),
                      const SizedBox(height: TpSpacing.s4),
                    ],
                    if (_rows.isEmpty)
                      const _EmptyAudit()
                    else
                      for (final row in _rows) ...[
                        _AuditCard(
                          row: row,
                          rollingBack: _rollingBackId == row.id,
                          onRollback: row.action == TripAuditAction.error
                              ? null
                              : () => _rollback(row),
                        ),
                        const SizedBox(height: TpSpacing.s3),
                      ],
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
            const Chip(
              visualDensity: VisualDensity.compact,
              avatar: Icon(Icons.restore, size: 16),
              label: Text('可回滾'),
            ),
          ],
        ),
      ],
    );
  }
}

class _AuditCard extends StatelessWidget {
  const _AuditCard({
    required this.row,
    required this.rollingBack,
    required this.onRollback,
  });

  final TripAuditRow row;
  final bool rollingBack;
  final VoidCallback? onRollback;

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
            const SizedBox(height: TpSpacing.s3),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                key: ValueKey('trip-audit-rollback-${row.id}'),
                onPressed: rollingBack ? null : onRollback,
                icon: rollingBack
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.restore),
                label: const Text('回滾'),
              ),
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
    return Container(
      key: const ValueKey('trip-audit-error'),
      padding: const EdgeInsets.all(TpSpacing.s4),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(TpRadius.md),
      ),
      child: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: colorScheme.error),
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
