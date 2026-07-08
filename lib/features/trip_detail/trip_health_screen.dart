import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_error.dart';
import '../../api/providers.dart';
import '../../models/health.dart';
import '../../models/trip.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

/// AI 行程健檢：GET/POST `/trips/:id/health-check` + pending report polling。
class TripHealthScreen extends ConsumerStatefulWidget {
  const TripHealthScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<TripHealthScreen> createState() => _TripHealthScreenState();
}

class _TripHealthScreenState extends ConsumerState<TripHealthScreen> {
  static const _pollInterval = Duration(seconds: 3);

  Trip? _trip;
  TripHealthReport? _report;
  bool _initialLoading = true;
  bool _submitting = false;
  bool _pollingNow = false;
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_loadInitial());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _initialLoading = true;
      _error = null;
    });
    try {
      final repository = ref.read(tripRepositoryProvider);
      final trip = await repository.fetchTrip(widget.tripId);
      final report = await repository.fetchTripHealthReport(widget.tripId);
      if (!mounted) return;
      setState(() {
        _trip = trip;
        _report = report;
      });
      if (report?.isPending == true) _startPolling();
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '載入失敗，請重新整理');
    } finally {
      if (mounted) setState(() => _initialLoading = false);
    }
  }

  Future<void> _startHealthCheck() async {
    if (_submitting || _report?.isPending == true) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final report = await ref
          .read(tripRepositoryProvider)
          .startTripHealthCheck(widget.tripId);
      if (!mounted) return;
      setState(() => _report = report);
      if (report.isPending) _startPolling();
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.code == 'TRIP_EMPTY' ? error.message : '觸發健檢失敗，請稍後再試';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '觸發健檢失敗，請稍後再試');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    unawaited(_pollReport());
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      unawaited(_pollReport());
    });
  }

  Future<void> _pollReport() async {
    if (_pollingNow) return;
    _pollingNow = true;
    try {
      final report = await ref
          .read(tripRepositoryProvider)
          .fetchTripHealthReport(widget.tripId);
      if (!mounted) return;
      if (report != null) {
        setState(() => _report = report);
        if (!report.isPending) {
          _pollTimer?.cancel();
          _pollTimer = null;
        }
      }
    } catch (_) {
      // 保持 pending UI，下一輪 polling 再試。
    } finally {
      _pollingNow = false;
    }
  }

  void _goToDay(int day) {
    GoRouter.maybeOf(
      context,
    )?.go('/trips/${Uri.encodeComponent(widget.tripId)}?day=$day');
  }

  void _goToEntry(int entryId) {
    GoRouter.maybeOf(
      context,
    )?.go('/trips/${Uri.encodeComponent(widget.tripId)}/stop/$entryId/edit');
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final canStart = !_submitting && report?.isPending != true;
    final ctaLabel = _submitting
        ? '送出中'
        : report == null
        ? '開始健檢'
        : '重新生成';

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 健檢'),
        actions: [
          if (!_initialLoading && report != null)
            IconButton(
              key: const ValueKey('health-refresh'),
              tooltip: ctaLabel,
              icon: const Icon(Icons.refresh_outlined),
              onPressed: canStart ? _startHealthCheck : null,
            ),
        ],
      ),
      body: _initialLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadInitial,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  TpSpacing.s4,
                  TpSpacing.s4,
                  TpSpacing.s4,
                  TpSpacing.s8,
                ),
                children: [
                  _HealthHero(trip: _trip, report: report),
                  if (_error != null) ...[
                    const SizedBox(height: TpSpacing.s3),
                    _HealthError(message: _error!),
                  ],
                  const SizedBox(height: TpSpacing.s4),
                  if (report == null)
                    _HealthEmpty(
                      submitting: _submitting,
                      onStart: canStart ? _startHealthCheck : null,
                    )
                  else ...[
                    if (report.isPending)
                      const _HealthPendingBanner()
                    else if (report.isFailed)
                      _HealthError(
                        title: '健檢失敗',
                        message: report.errorMessage ?? 'AI 處理時發生錯誤，可重新生成再試。',
                      )
                    else if (report.isCompleted && report.findings.isEmpty)
                      const _HealthNoIssues()
                    else
                      _HealthResults(
                        report: report,
                        onGoToDay: _goToDay,
                        onGoToEntry: _goToEntry,
                      ),
                    if (report.isPending && report.findings.isNotEmpty) ...[
                      const SizedBox(height: TpSpacing.s4),
                      _HealthResults(
                        report: report,
                        dimmed: true,
                        onGoToDay: _goToDay,
                        onGoToEntry: _goToEntry,
                      ),
                    ],
                  ],
                ],
              ),
            ),
    );
  }
}

class _HealthHero extends StatelessWidget {
  const _HealthHero({required this.trip, required this.report});

  final Trip? trip;
  final TripHealthReport? report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = trip?.title ?? trip?.name ?? '行程';
    final meta = switch (report?.status) {
      'pending' => 'AI 健檢進行中',
      'completed' => '共 ${report!.findings.length} 項建議',
      'failed' => '健檢失敗',
      _ => '尚未進行 AI 健檢',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI 行程建議',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: TpSpacing.s1),
        Text(title, style: theme.textTheme.headlineMedium),
        const SizedBox(height: TpSpacing.s1),
        Text(
          meta,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: report?.isPending == true
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _HealthEmpty extends StatelessWidget {
  const _HealthEmpty({required this.submitting, required this.onStart});

  final bool submitting;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _HealthPanel(
      icon: Icons.auto_awesome_outlined,
      title: '尚未健檢過此行程',
      body: '由 AI 檢視整份行程，找出時間衝突、移動過遠、漏掉必排景點等問題。',
      iconColor: theme.colorScheme.primary,
      child: FilledButton.icon(
        key: const ValueKey('health-start'),
        onPressed: onStart,
        icon: submitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.auto_awesome_outlined),
        label: Text(submitting ? '送出中' : '開始健檢'),
      ),
    );
  }
}

class _HealthNoIssues extends StatelessWidget {
  const _HealthNoIssues();

  @override
  Widget build(BuildContext context) {
    final tones = Theme.of(context).extension<TpTones>()!;
    return _HealthPanel(
      icon: Icons.check_circle_outline,
      title: '看起來沒有問題',
      body: 'AI 沒有找到需要修正的地方。行程安排良好。',
      iconColor: tones.success,
    );
  }
}

class _HealthPendingBanner extends StatelessWidget {
  const _HealthPendingBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s4),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: TpSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI 健檢進行中', style: theme.textTheme.titleMedium),
                  const SizedBox(height: TpSpacing.s1),
                  Text(
                    '通常 3-7 分鐘完成，可以同時編輯行程。',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthResults extends StatelessWidget {
  const _HealthResults({
    required this.report,
    required this.onGoToDay,
    required this.onGoToEntry,
    this.dimmed = false,
  });

  final TripHealthReport report;
  final ValueChanged<int> onGoToDay;
  final ValueChanged<int> onGoToEntry;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      _HealthSeverityCounts(report: report),
      const SizedBox(height: TpSpacing.s3),
      for (final severity in kTripHealthSeverityOrder)
        if (report.findingsForSeverity(severity).isNotEmpty)
          _HealthSeverityGroup(
            severity: severity,
            findings: [
              for (final (index, finding) in report.findings.indexed)
                if (finding.severity == severity) (index, finding),
            ],
            onGoToDay: onGoToDay,
            onGoToEntry: onGoToEntry,
          ),
      const SizedBox(height: TpSpacing.s2),
      Center(
        child: Text(
          '由 Claude AI 產生，僅供參考',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    ];
    return Opacity(
      opacity: dimmed ? 0.55 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _HealthSeverityCounts extends StatelessWidget {
  const _HealthSeverityCounts({required this.report});

  final TripHealthReport report;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: TpSpacing.s2,
      runSpacing: TpSpacing.s2,
      children: [
        for (final severity in kTripHealthSeverityOrder)
          if (report.severityCount(severity) > 0)
            _SeverityChip(
              key: ValueKey('health-count-$severity'),
              severity: severity,
              label:
                  '${_severityLabel(severity)} ${report.severityCount(severity)}',
            ),
      ],
    );
  }
}

class _HealthSeverityGroup extends StatelessWidget {
  const _HealthSeverityGroup({
    required this.severity,
    required this.findings,
    required this.onGoToDay,
    required this.onGoToEntry,
  });

  final String severity;
  final List<(int, TripHealthFinding)> findings;
  final ValueChanged<int> onGoToDay;
  final ValueChanged<int> onGoToEntry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TpSpacing.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _SeverityChip(
                severity: severity,
                label: _severityHeading(severity),
              ),
              const SizedBox(width: TpSpacing.s2),
              Text(
                '${findings.length} 項',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: TpSpacing.s2),
          for (final (index, finding) in findings) ...[
            _FindingCard(
              index: index,
              finding: finding,
              onGoToDay: onGoToDay,
              onGoToEntry: onGoToEntry,
            ),
            const SizedBox(height: TpSpacing.s2),
          ],
        ],
      ),
    );
  }
}

class _FindingCard extends StatelessWidget {
  const _FindingCard({
    required this.index,
    required this.finding,
    required this.onGoToDay,
    required this.onGoToEntry,
  });

  final int index;
  final TripHealthFinding finding;
  final ValueChanged<int> onGoToDay;
  final ValueChanged<int> onGoToEntry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final target = finding.actionTarget;
    final barColor = _severityColor(context, finding.severity);
    return Card(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 6,
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(TpRadius.md),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(TpSpacing.s3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: TpSpacing.s2,
                      runSpacing: TpSpacing.s1,
                      children: [
                        Text(finding.title, style: theme.textTheme.titleMedium),
                        if (finding.dimensionLabel.isNotEmpty)
                          Chip(
                            label: Text(finding.dimensionLabel),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                      ],
                    ),
                    if (finding.description.isNotEmpty) ...[
                      const SizedBox(height: TpSpacing.s2),
                      Text(
                        finding.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if ((finding.suggestion ?? '').isNotEmpty) ...[
                      const SizedBox(height: TpSpacing.s2),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(TpRadius.sm),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(TpSpacing.s2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '建議',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: TpSpacing.s2),
                              Expanded(child: Text(finding.suggestion!)),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (target?.entryId != null || target?.day != null) ...[
                      const SizedBox(height: TpSpacing.s3),
                      Wrap(
                        spacing: TpSpacing.s2,
                        runSpacing: TpSpacing.s2,
                        children: [
                          if (target?.entryId != null)
                            FilledButton.tonalIcon(
                              key: ValueKey('health-goto-entry-$index'),
                              onPressed: () => onGoToEntry(target!.entryId!),
                              icon: const Icon(Icons.place_outlined),
                              label: const Text('前往景點'),
                            )
                          else if (target?.day != null)
                            FilledButton.tonalIcon(
                              key: ValueKey('health-goto-day-$index'),
                              onPressed: () => onGoToDay(target!.day!),
                              icon: const Icon(Icons.calendar_today_outlined),
                              label: Text('前往 Day ${target?.day}'),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeverityChip extends StatelessWidget {
  const _SeverityChip({super.key, required this.severity, required this.label});

  final String severity;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(context, severity);
    return Chip(
      avatar: Icon(Icons.circle, size: 8, color: color),
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.12),
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide.none,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _HealthPanel extends StatelessWidget {
  const _HealthPanel({
    required this.icon,
    required this.title,
    required this.body,
    required this.iconColor,
    this.child,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color iconColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s6),
        child: Column(
          children: [
            Icon(icon, size: 44, color: iconColor),
            const SizedBox(height: TpSpacing.s3),
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: TpSpacing.s2),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (child != null) ...[
              const SizedBox(height: TpSpacing.s4),
              child!,
            ],
          ],
        ),
      ),
    );
  }
}

class _HealthError extends StatelessWidget {
  const _HealthError({required this.message, this.title = '操作失敗'});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(TpRadius.md),
        border: Border.all(color: theme.colorScheme.error),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: TpSpacing.s1),
            Text(message),
          ],
        ),
      ),
    );
  }
}

String _severityLabel(String severity) => switch (severity) {
  'high' => '高',
  'medium' => '中',
  'low' => '低',
  _ => severity,
};

String _severityHeading(String severity) => switch (severity) {
  'high' => '高優先',
  'medium' => '中等',
  'low' => '低',
  _ => severity,
};

Color _severityColor(BuildContext context, String severity) {
  final tones = Theme.of(context).extension<TpTones>()!;
  return switch (severity) {
    'high' => Theme.of(context).colorScheme.error,
    'medium' => tones.warning,
    'low' => Theme.of(context).colorScheme.primary,
    _ => Theme.of(context).colorScheme.onSurfaceVariant,
  };
}
