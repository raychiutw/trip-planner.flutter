/// AI trip health-check screen.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../api/api_error.dart';
import '../../../api/providers.dart';
import '../../../app/app_loading_skeleton.dart';
import '../../../models/day.dart';
import '../../../models/trip.dart';
import '../../../models/trip_health.dart';
import '../../../models/trip_poi_health.dart';
import '../../../theme/tokens.dart';
import '../../../ui/tp_app_bar.dart';

const _pollInterval = Duration(seconds: 5);

/// Shows the latest AI health report and lets the user start a new check.
class TripHealthScreen extends ConsumerStatefulWidget {
  const TripHealthScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<TripHealthScreen> createState() => _TripHealthScreenState();
}

class _TripHealthScreenState extends ConsumerState<TripHealthScreen> {
  bool _loading = true;
  bool _starting = false;
  String? _error;
  Trip? _trip;
  List<TripDay> _days = const [];
  TripHealthReport? _report;
  TripPoiHealthReport? _poiHealth;
  Timer? _pollTimer;

  int get _entryCount =>
      _days.fold<int>(0, (count, day) => count + day.timeline.length);

  bool get _isPending => _report?.status == TripHealthStatus.pending;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void didUpdateWidget(covariant TripHealthScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tripId != widget.tripId) {
      _pollTimer?.cancel();
      _load();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repository = ref.read(tripRepositoryProvider);
      final results = await Future.wait<Object?>([
        repository.fetchTrip(widget.tripId),
        repository.fetchDays(widget.tripId),
        repository.fetchHealthReport(widget.tripId),
        repository.fetchPoiHealth(widget.tripId),
      ]);
      if (!mounted) return;
      final report = results[2] as TripHealthReport?;
      setState(() {
        _trip = results[0] as Trip;
        _days = results[1] as List<TripDay>;
        _report = report;
        _poiHealth = results[3] as TripPoiHealthReport;
      });
      _schedulePoll(report);
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _error = _healthErrorMessage(error, '載入健檢資料失敗，請稍後重試'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startHealthCheck() async {
    if (_starting || _isPending || _entryCount == 0) return;
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final report = await ref
          .read(tripRepositoryProvider)
          .startHealthCheck(widget.tripId);
      if (!mounted) return;
      setState(() => _report = report);
      _schedulePoll(report);
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _error = _healthErrorMessage(error, '觸發健檢失敗，請稍後再試'));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _schedulePoll(TripHealthReport? report) {
    _pollTimer?.cancel();
    if (report?.status != TripHealthStatus.pending) return;
    _pollTimer = Timer(_pollInterval, () async {
      try {
        final next = await ref
            .read(tripRepositoryProvider)
            .fetchHealthReport(widget.tripId);
        if (!mounted || next == null) return;
        setState(() => _report = next);
        _schedulePoll(next);
      } on Exception {
        if (!mounted) return;
        _schedulePoll(_report);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tripTitle = _trip?.title ?? _trip?.name ?? '行程';
    return Scaffold(
      appBar: TpAppBar(
        title: const Text('AI 健檢'),
        actions: [
          TpToolbarIconButton(
            key: const ValueKey('trip-health-refresh-button'),
            tooltip: '重新整理',
            onPressed: _loading ? null : _load,
            icon: Icons.refresh,
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const AppListLoadingSkeleton(key: ValueKey('trip-health-loading'))
            : _trip == null
            ? _ErrorState(message: _error ?? '載入健檢資料失敗，請稍後重試', onRetry: _load)
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
                    _Header(
                      title: tripTitle,
                      entryCount: _entryCount,
                      report: _report,
                    ),
                    const SizedBox(height: TpSpacing.s4),
                    if (_error != null) ...[
                      _InlineError(message: _error!),
                      const SizedBox(height: TpSpacing.s4),
                    ],
                    if (_entryCount == 0) ...[
                      const _EmptyTripGuard(),
                      const SizedBox(height: TpSpacing.s4),
                    ],
                    _StartButton(
                      report: _report,
                      starting: _starting,
                      enabled: !_starting && !_isPending && _entryCount > 0,
                      onPressed: _startHealthCheck,
                    ),
                    const SizedBox(height: TpSpacing.s4),
                    if (_poiHealth != null) _PoiHealthCard(report: _poiHealth!),
                    const SizedBox(height: TpSpacing.s4),
                    _ReportSection(report: _report, tripId: widget.tripId),
                  ],
                ),
              ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.entryCount,
    required this.report,
  });

  final String title;
  final int entryCount;
  final TripHealthReport? report;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final completedAt = report?.completedAt ?? report?.createdAt;
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
              avatar: Icon(
                _statusIcon(report?.status),
                size: 16,
                color: colorScheme.primary,
              ),
              label: Text(_statusLabel(report?.status)),
            ),
            Chip(
              visualDensity: VisualDensity.compact,
              avatar: const Icon(Icons.place_outlined, size: 16),
              label: Text('$entryCount 個停留點'),
            ),
            if (completedAt != null)
              Chip(
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.schedule, size: 16),
                label: Text(_formatTimestamp(completedAt)),
              ),
          ],
        ),
      ],
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({
    required this.report,
    required this.starting,
    required this.enabled,
    required this.onPressed,
  });

  final TripHealthReport? report;
  final bool starting;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      key: const ValueKey('trip-health-start-button'),
      onPressed: enabled ? onPressed : null,
      icon: starting
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(report == null ? Icons.auto_awesome : Icons.refresh),
      label: Text(_buttonLabel(report, starting)),
    );
  }
}

class _PoiHealthCard extends StatelessWidget {
  const _PoiHealthCard({required this.report});

  final TripPoiHealthReport report;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      key: const ValueKey('trip-health-poi-card'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TpRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_searching, color: colorScheme.primary),
                const SizedBox(width: TpSpacing.s2),
                Text('POI 狀態', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: TpSpacing.s3),
            if (!report.hasIssues)
              const Text('POI 狀態看起來正常。')
            else ...[
              Text('已歇業 ${report.closed} · 缺少資料 ${report.missing}'),
              const SizedBox(height: TpSpacing.s3),
              for (final item in report.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: TpSpacing.s2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        item.status == TripPoiHealthStatus.closed
                            ? Icons.block
                            : Icons.help_outline,
                        size: 18,
                        color: colorScheme.error,
                      ),
                      const SizedBox(width: TpSpacing.s2),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.poiName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (item.reason != null)
                              Text(
                                item.reason!,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReportSection extends StatelessWidget {
  const _ReportSection({required this.report, required this.tripId});

  final TripHealthReport? report;
  final String tripId;

  @override
  Widget build(BuildContext context) {
    final report = this.report;
    if (report == null) {
      return const _EmptyReport();
    }
    return switch (report.status) {
      TripHealthStatus.pending => const _PendingReport(),
      TripHealthStatus.failed => _FailedReport(message: report.errorMessage),
      TripHealthStatus.completed =>
        report.findings.isEmpty
            ? const _NoIssuesReport()
            : _FindingsList(report: report, tripId: tripId),
    };
  }
}

class _EmptyReport extends StatelessWidget {
  const _EmptyReport();

  @override
  Widget build(BuildContext context) {
    return const _StatePanel(
      key: ValueKey('trip-health-empty'),
      icon: Icons.auto_awesome,
      title: '尚未健檢過此行程',
      message: '由 AI 檢視時間衝突、距離過遠、餐飲空窗與漏排行程。',
    );
  }
}

class _PendingReport extends StatelessWidget {
  const _PendingReport();

  @override
  Widget build(BuildContext context) {
    return const _StatePanel(
      key: ValueKey('trip-health-pending'),
      icon: Icons.hourglass_top,
      title: 'AI 健檢進行中',
      message: '通常 3-7 分鐘完成。你可以先離開，稍後回來查看結果。',
    );
  }
}

class _FailedReport extends StatelessWidget {
  const _FailedReport({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return _StatePanel(
      key: const ValueKey('trip-health-failed'),
      icon: Icons.error_outline,
      title: '健檢失敗',
      message: message ?? 'AI 處理時發生錯誤，可重新生成再試。',
    );
  }
}

class _NoIssuesReport extends StatelessWidget {
  const _NoIssuesReport();

  @override
  Widget build(BuildContext context) {
    return const _StatePanel(
      key: ValueKey('trip-health-no-issues'),
      icon: Icons.check_circle_outline,
      title: '看起來沒有問題',
      message: 'AI 沒有找到需要修正的地方。行程安排良好。',
    );
  }
}

class _FindingsList extends StatelessWidget {
  const _FindingsList({required this.report, required this.tripId});

  final TripHealthReport report;
  final String tripId;

  @override
  Widget build(BuildContext context) {
    final findings = [...report.findings]
      ..sort((a, b) => _severityRank(a.severity) - _severityRank(b.severity));
    return Column(
      key: const ValueKey('trip-health-results'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('AI 建議', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: TpSpacing.s3),
        for (final finding in findings) ...[
          _FindingCard(finding: finding, tripId: tripId),
          const SizedBox(height: TpSpacing.s3),
        ],
        Text('由 AI 產生，僅供參考。', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _FindingCard extends StatelessWidget {
  const _FindingCard({required this.finding, required this.tripId});

  final TripHealthFinding finding;
  final String tripId;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final target = finding.actionTarget;
    return Card(
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
                _SeverityChip(severity: finding.severity),
                if (finding.dimension != null)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(_dimensionLabel(finding.dimension!)),
                  ),
              ],
            ),
            const SizedBox(height: TpSpacing.s2),
            Text(finding.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: TpSpacing.s2),
            Text(finding.description),
            if (finding.suggestion != null) ...[
              const SizedBox(height: TpSpacing.s3),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(TpSpacing.s3),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(TpRadius.md),
                ),
                child: Text('建議：${finding.suggestion}'),
              ),
            ],
            if (target?.entryId != null || target?.day != null) ...[
              const SizedBox(height: TpSpacing.s3),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final entryId = target?.entryId;
                    if (entryId != null) {
                      final encodedTripId = Uri.encodeComponent(tripId);
                      context.go('/trips/$encodedTripId/entries/$entryId/edit');
                      return;
                    }
                    final day = target?.day;
                    final encodedTripId = Uri.encodeComponent(tripId);
                    context.go(
                      Uri(
                        path: '/trips/$encodedTripId',
                        queryParameters: day == null
                            ? null
                            : {'day': day.toString()},
                      ).toString(),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(_entryTargetLabel(target)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SeverityChip extends StatelessWidget {
  const _SeverityChip({required this.severity});

  final TripHealthSeverity severity;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (severity) {
      TripHealthSeverity.high => (
        colorScheme.errorContainer,
        colorScheme.error,
      ),
      TripHealthSeverity.medium => (
        colorScheme.tertiaryContainer,
        colorScheme.onTertiaryContainer,
      ),
      TripHealthSeverity.low => (
        colorScheme.secondaryContainer,
        colorScheme.onSecondaryContainer,
      ),
    };
    return Chip(
      visualDensity: VisualDensity.compact,
      backgroundColor: bg,
      labelStyle: TextStyle(color: fg, fontWeight: FontWeight.w700),
      label: Text(_severityLabel(severity)),
    );
  }
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TpRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colorScheme.primary),
            const SizedBox(height: TpSpacing.s3),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: TpSpacing.s2),
            Text(message),
          ],
        ),
      ),
    );
  }
}

class _EmptyTripGuard extends StatelessWidget {
  const _EmptyTripGuard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('trip-health-empty-trip'),
      padding: const EdgeInsets.all(TpSpacing.s4),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(TpRadius.md),
      ),
      child: Text(
        '此行程尚無景點，請先加入景點再執行健檢。',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: colorScheme.error),
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
      key: const ValueKey('trip-health-error'),
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

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, key: const ValueKey('trip-health-load-error')),
            const SizedBox(height: TpSpacing.s4),
            FilledButton(onPressed: onRetry, child: const Text('重試')),
          ],
        ),
      ),
    );
  }
}

String _buttonLabel(TripHealthReport? report, bool starting) {
  if (starting) return '送出中';
  if (report == null) return '開始健檢';
  if (report.status == TripHealthStatus.pending) return '健檢進行中';
  return '重新生成';
}

String _statusLabel(TripHealthStatus? status) {
  if (status == null) return '尚未健檢';
  return switch (status) {
    TripHealthStatus.pending => '進行中',
    TripHealthStatus.completed => '已完成',
    TripHealthStatus.failed => '失敗',
  };
}

IconData _statusIcon(TripHealthStatus? status) {
  if (status == null) return Icons.auto_awesome;
  return switch (status) {
    TripHealthStatus.pending => Icons.hourglass_top,
    TripHealthStatus.completed => Icons.check_circle_outline,
    TripHealthStatus.failed => Icons.error_outline,
  };
}

String _severityLabel(TripHealthSeverity severity) => switch (severity) {
  TripHealthSeverity.high => '高風險',
  TripHealthSeverity.medium => '中風險',
  TripHealthSeverity.low => '低風險',
};

int _severityRank(TripHealthSeverity severity) => switch (severity) {
  TripHealthSeverity.high => 0,
  TripHealthSeverity.medium => 1,
  TripHealthSeverity.low => 2,
};

String _dimensionLabel(TripHealthDimension dimension) => switch (dimension) {
  TripHealthDimension.timing => '時間',
  TripHealthDimension.distance => '距離',
  TripHealthDimension.meals => '餐飲',
  TripHealthDimension.sights => '景點',
  TripHealthDimension.hotel => '住宿',
};

String _entryTargetLabel(TripHealthActionTarget? target) =>
    target?.entryId != null ? '前往景點' : '前往 Day ${target?.day ?? ''}';

String _formatTimestamp(String value) {
  if (value.length >= 16) {
    return value.replaceFirst('T', ' ').substring(0, 16);
  }
  return value;
}

String _healthErrorMessage(Object error, String fallback) {
  if (error is ApiError) {
    if (_hasCjk(error.message)) return error.message;
    if (error.code == 'TRIP_EMPTY') return '此行程尚無景點，請先加入景點再執行健檢';
    return fallback;
  }
  return fallback;
}

bool _hasCjk(String value) => RegExp(r'[一-鿿]').hasMatch(value);
