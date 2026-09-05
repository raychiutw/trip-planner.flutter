import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_error.dart';
import '../../api/providers.dart';
import '../../app/adaptive.dart';
import '../../app/adaptive_content.dart';
import '../../app/app_feedback.dart';
import '../../app/error_message.dart';
import '../../app/irreversible_action.dart';
import '../../app/app_loading_skeleton.dart';
import '../../models/note_section.dart';
import '../../models/notes.dart';
import '../../theme/tokens.dart';
import '../../ui/tp_action_item.dart';
import '../../ui/tp_app_bar.dart';
import '../../ui/swipe_to_delete.dart';
import 'notes/note_edit_sheet.dart';
import 'notes/note_field_spec.dart';
import 'notes/notes_ai_controller.dart';
import '../requests/request_lifecycle.dart';
import 'reorder_helpers.dart';
import 'trip_providers.dart';
import 'widgets/reorderable_row.dart';

/// 行程筆記：5-section accordion（航班/住宿/預訂/行前須知/緊急聯絡）。
class TripNotesScreen extends ConsumerStatefulWidget {
  const TripNotesScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<TripNotesScreen> createState() => _TripNotesScreenState();
}

class _TripNotesScreenState extends ConsumerState<TripNotesScreen> {
  /// 這一幀內完成的 docType;統一在 frame 結束後合成一則提示。
  /// 兩個 job 幾乎同時完成時各發一則,兩張浮層會疊在同一個位置互相蓋掉。
  final _aiJustCompleted = <NoteGenerationType>{};
  bool _aiNoticeScheduled = false;

  @override
  Widget build(BuildContext context) {
    ref.listen(notesAiControllerProvider(widget.tripId), (previous, next) {
      for (final type in NoteGenerationType.values) {
        if (previous?.of(type).phase != NotesAiPhase.completed &&
            next.of(type).phase == NotesAiPhase.completed) {
          _scheduleAiCompletionNotice(type);
        }
      }
    });
    final notesAsync = ref.watch(tripNotesProvider(widget.tripId));
    return Scaffold(
      appBar: const TpAppBar(role: TpAppBarRole.detail, title: Text('行程筆記')),
      body: AppAdaptiveContent(
        maxWidth: AppContentWidth.feed,
        contentKey: const ValueKey('trip-notes-content'),
        child: notesAsync.when(
          loading: () =>
              const AppListLoadingSkeleton(key: ValueKey('trip-notes-loading')),
          error: (error, _) => Center(
            child: Semantics(
              key: const ValueKey('trip-notes-error'),
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.all(TpSpacing.s6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('載入失敗：$error', textAlign: TextAlign.center),
                    const SizedBox(height: TpSpacing.s2),
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(tripNotesProvider(widget.tripId)),
                      child: const Text('重試'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          data: (notes) => _buildSections(context, notes),
        ),
      ),
    );
  }

  Widget _buildSections(BuildContext context, TripNotes notes) {
    final ai = ref.watch(notesAiControllerProvider(widget.tripId));
    final controller = ref.read(
      notesAiControllerProvider(widget.tripId).notifier,
    );
    NoteGenerationType? firstWith(NotesAiPhase phase) => NoteGenerationType
        .values
        .where((t) => ai.of(t).phase == phase)
        .firstOrNull;
    final summaryType = NoteGenerationType.values
        .where(
          (t) =>
              ai.of(t).phase == NotesAiPhase.completed &&
              ai.of(t).summary != null,
        )
        .firstOrNull;
    final timedOutType = firstWith(NotesAiPhase.timedOut);
    final failedType = firstWith(NotesAiPhase.failed);
    final pendingTypes = [
      for (final t in NoteGenerationType.values)
        if (ai.of(t).phase == NotesAiPhase.pending) t,
    ];
    return ListView(
      key: const ValueKey('trip-notes-list'),
      padding: const EdgeInsets.all(TpSpacing.s4),
      children: [
        // 固定佔一個 slot:ListView 的 children 一旦增減,後面每個 slot 的 widget
        // 都會換位而重建,展開中的 section 會被收合。狀態面板永遠在這個 Column 裡進出。
        Column(
          key: const ValueKey('notes-ai-status'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (summaryType case final type?)
              _NotesAiSummaryPanel(
                key: const ValueKey('notes-ai-summary'),
                job: ai.of(type).summary!,
                onDismiss: () => controller.dismiss(type),
              ),
            if (timedOutType case final type?)
              _NotesAiErrorPanel(
                key: const ValueKey('notes-ai-timeout'),
                panelKey: const ValueKey('notes-ai-timeout-panel'),
                retryKey: const ValueKey('notes-ai-timeout-retry'),
                title: '生成逾時',
                message: '這次生成超過 10 分鐘沒有完成，已經停止。可以再試一次。',
                onRetry: () {
                  controller.dismiss(type);
                  unawaited(controller.generate(type));
                },
                onDismiss: () => controller.dismiss(type),
              ),
            if (ai.stateError case final message?)
              _NotesAiErrorPanel(
                key: const ValueKey('notes-ai-state-error'),
                panelKey: const ValueKey('notes-ai-state-error-panel'),
                retryKey: const ValueKey('notes-ai-state-retry'),
                message: message,
                onRetry: () => unawaited(controller.load()),
                onDismiss: () => controller.clearStateError(),
              ),
            if (failedType case final type?)
              _NotesAiErrorPanel(
                message: ai.of(type).failureMessage ?? notesAiFallbackMessage,
                onRetry: () {
                  controller.dismiss(type);
                  unawaited(controller.generate(type));
                },
                onDismiss: () => controller.dismiss(type),
              ),
            // 進行中的每一種各佔一列,並固定用 enum 的宣告順序,避免先後啟動
            // 造成面板上下跳動。
            if (pendingTypes.isNotEmpty)
              Column(
                key: const ValueKey('notes-ai-pending'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final type in pendingTypes)
                    _NotesAiPendingPanel(
                      key: ValueKey('notes-ai-pending-${type.pathSegment}'),
                      label: type.pendingLabel,
                      stage: ai.of(type).stage,
                      stopKey: ValueKey('notes-ai-stop-${type.pathSegment}'),
                      onStopWaiting: () => _stopWaitingFor(type),
                    ),
                ],
              ),
          ],
        ),
        for (final section in NoteSection.values)
          _NotesSection(
            tripId: widget.tripId,
            section: section,
            // mobile 預設展開航班(對齊 web TripNotesPage 行為)
            initiallyExpanded: section == NoteSection.flights,
            hasLodgings: notes.lodgings.isNotEmpty,
            rows: _rowsFor(section, notes),
          ),
      ],
    );
  }

  /// 停止等待 —— 走 controller;伺服器沒確認時誠實提示。
  Future<void> _stopWaitingFor(NoteGenerationType type) async {
    final confirmed = await ref
        .read(notesAiControllerProvider(widget.tripId).notifier)
        .stopWaiting(type);
    if (!mounted || confirmed) return;
    showAppError(context, kStopWaitingUnconfirmedMessage);
  }

  List<_NoteRowData> _rowsFor(NoteSection section, TripNotes notes) =>
      switch (section) {
        NoteSection.flights => [
          for (final f in notes.flights)
            _NoteRowData(
              id: f.id,
              version: f.version,
              editFields: f.toEditFields(),
              display: _FlightRow(f),
            ),
        ],
        NoteSection.lodgings => [
          for (final l in notes.lodgings)
            _NoteRowData(
              id: l.id,
              version: l.version,
              editFields: l.toEditFields(),
              display: _LodgingRow(l),
            ),
        ],
        NoteSection.reservations => [
          for (final r in notes.reservations)
            _NoteRowData(
              id: r.id,
              version: r.version,
              editFields: r.toEditFields(),
              display: _ReservationRow(r),
            ),
        ],
        NoteSection.pretrip => [
          for (final p in notes.pretripNotes)
            _NoteRowData(
              id: p.id,
              version: p.version,
              editFields: p.toEditFields(),
              display: _PretripNoteRow(p),
              canReassignToAi: p.canReassignToAi,
            ),
        ],
        NoteSection.emergency => [
          for (final c in notes.emergencyContacts)
            _NoteRowData(
              id: c.id,
              version: c.version,
              editFields: c.toEditFields(),
              display: _EmergencyContactRow(c),
              canReassignToAi: c.canReassignToAi,
            ),
        ],
      };

  /// 完成提示延到 frame 結束才發:同一幀內完成的合成一則,兩張浮層才不會疊在
  /// 同一個位置互相蓋掉,也不會連發兩則。
  void _scheduleAiCompletionNotice(NoteGenerationType type) {
    _aiJustCompleted.add(type);
    if (_aiNoticeScheduled) return;
    _aiNoticeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _aiNoticeScheduled = false;
      final completed = _aiJustCompleted.toList()
        ..sort((a, b) => a.index.compareTo(b.index));
      _aiJustCompleted.clear();
      if (!mounted || completed.isEmpty) return;
      final labels = completed.map((t) => t.pendingLabel).join('、');
      showAppNotice(context, 'AI 生成完成：$labels');
    });
  }
}

/// 單一筆記 row 的資料：id/version（OCC）、editFields（編輯預填）、display（唯讀卡片）。
class _NoteRowData {
  const _NoteRowData({
    required this.id,
    required this.version,
    required this.editFields,
    required this.display,
    this.canReassignToAi = false,
  });

  final int id;
  final int version;
  final Map<String, dynamic> editFields;
  final Widget display;

  /// 原本 AI 產生、目前人工維護 —— 只有這種才給「交還 AI 維護」。
  final bool canReassignToAi;
}

/// AI 生成按鈕資料；只在可生成的 section 展開後顯示。
class _NoteAiAction {
  const _NoteAiAction({required this.type, this.disabledText});

  final NoteGenerationType type;
  String get label => type.label;
  bool get enabled => disabledText == null;

  /// 不能生成的原因;有值就是 disabled。
  final String? disabledText;
}

extension _NotesAiStageX on NotesAiStage {
  /// `label` 是該種生成的中文名(行前須知(一般)/緊急聯絡…)。
  String message(String label) => switch (this) {
    NotesAiStage.queued => '已送出$label的生成，正在等待排程。通常需 3-7 分鐘。',
    NotesAiStage.processing => '正在讀行程並整理$label的內容，完成後會自動更新。',
  };

  /// 不只靠顏色 —— 灰階下也分得出兩個階段。
  IconData get icon => switch (this) {
    NotesAiStage.queued => CupertinoIcons.clock,
    NotesAiStage.processing => CupertinoIcons.sparkles,
  };
}

class _NotesAiPendingPanel extends StatelessWidget {
  const _NotesAiPendingPanel({
    super.key,
    required this.label,
    required this.stage,
    required this.stopKey,
    required this.onStopWaiting,
  });

  final String label;
  final NotesAiStage stage;
  final Key stopKey;

  /// 停止等待 —— 次要文字鈕,不換掉生成按鈕、不進工具列。
  final VoidCallback onStopWaiting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: TpSpacing.s3),
      padding: const EdgeInsets.all(TpSpacing.s3),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: const BorderRadius.all(Radius.circular(TpRadius.md)),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: TpSpacing.s2),
          Icon(stage.icon, size: 16, color: colors.onSecondaryContainer),
          const SizedBox(width: TpSpacing.s2),
          Expanded(
            child: Text(
              stage.message(label),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSecondaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Semantics(
            button: true,
            label: '停止等待',
            hint: '停止等待這次生成。AI 若仍在處理，完成後的結果還是會寫進筆記。',
            excludeSemantics: true,
            child: TextButton(
              key: stopKey,
              onPressed: onStopWaiting,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, TpSpacing.tapMin),
                padding: const EdgeInsets.symmetric(horizontal: TpSpacing.s2),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('停止等待'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 完成摘要:用中文句子講「動了什麼」,不是裸露的數字表格。
class _NotesAiSummaryPanel extends StatelessWidget {
  const _NotesAiSummaryPanel({
    super.key,
    required this.job,
    required this.onDismiss,
  });

  final TripNoteAiJob job;
  final VoidCallback onDismiss;

  /// 為零或缺漏的 count 直接略過 —— 「抑制 0 則」是雜訊不是資訊。
  String get _sentence {
    final parts = <String>[
      if (job.insertedCount > 0) '新增 ${job.insertedCount} 則',
      if (job.replacedCount > 0) '替換 ${job.replacedCount} 則',
      if (job.preservedManualCount > 0)
        '保留你手動維護的 ${job.preservedManualCount} 則',
      if (job.duplicateExcludedCount > 0)
        '略過重複的 ${job.duplicateExcludedCount} 則',
      if (job.suppressedCount > 0) '略過你排除過的 ${job.suppressedCount} 則',
    ];
    if (parts.isEmpty) return '這次生成沒有變更任何項目。';
    return '這次生成${parts.join('、')}。';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: TpSpacing.s3),
      padding: const EdgeInsets.all(TpSpacing.s3),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: const BorderRadius.all(Radius.circular(TpRadius.md)),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            CupertinoIcons.checkmark_circle,
            size: 18,
            color: colors.onSecondaryContainer,
          ),
          const SizedBox(width: TpSpacing.s2),
          Expanded(
            child: Text(
              _sentence,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSecondaryContainer,
              ),
            ),
          ),
          TextButton(onPressed: onDismiss, child: const Text('關閉')),
        ],
      ),
    );
  }
}

class _NotesAiErrorPanel extends StatelessWidget {
  const _NotesAiErrorPanel({
    super.key,
    required this.message,
    required this.onRetry,
    required this.onDismiss,
    this.panelKey = const ValueKey('notes-ai-error'),
    this.retryKey = const ValueKey('notes-ai-retry'),
    this.title = 'AI 生成失敗',
  });

  final String message;

  /// 內層容器的 key。兩個面板(生成失敗 / 狀態讀取失敗)共用這個 widget,
  /// 但測試要分得出是哪一個。
  final VoidCallback onRetry;
  final VoidCallback onDismiss;
  final Key panelKey;
  final Key retryKey;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      key: panelKey,
      margin: const EdgeInsets.only(bottom: TpSpacing.s3),
      padding: const EdgeInsets.all(TpSpacing.s3),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: const BorderRadius.all(Radius.circular(TpRadius.md)),
        border: Border.all(color: colors.error),
      ),
      child: Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, color: colors.onErrorContainer),
                const SizedBox(width: TpSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colors.onErrorContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: TpSpacing.s1),
                      Text(
                        '$message。可重試或手動填寫。',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: TpSpacing.s1),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: onDismiss, child: const Text('關閉')),
                const SizedBox(width: TpSpacing.s2),
                FilledButton(
                  key: retryKey,
                  onPressed: onRetry,
                  child: const Text('重試'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 排除清單:被刪掉的 AI 項目,可逐項恢復。
///
/// 恢復改的是「下次會不會生成」,不是當下的內容 —— 那一則要等下一次生成
/// 才會再出現在筆記裡。
Future<void> showNoteExclusionsSheet(
  BuildContext context, {
  required String tripId,
  required NoteGenerationType docType,
}) => showAppContentSheet<void>(
  context,
  title: '已排除的項目',
  builder: (sheetContext) =>
      _NoteExclusionsList(tripId: tripId, docType: docType),
);

class _NoteExclusionsList extends ConsumerStatefulWidget {
  const _NoteExclusionsList({required this.tripId, required this.docType});

  final String tripId;
  final NoteGenerationType docType;

  @override
  ConsumerState<_NoteExclusionsList> createState() =>
      _NoteExclusionsListState();
}

class _NoteExclusionsListState extends ConsumerState<_NoteExclusionsList> {
  late Future<List<TripNoteExclusion>> _future = _load();

  Future<List<TripNoteExclusion>> _load() => ref
      .read(tripRepositoryProvider)
      .fetchNoteExclusions(widget.docType, tripId: widget.tripId);

  Future<void> _restore(TripNoteExclusion exclusion) async {
    try {
      await ref
          .read(tripRepositoryProvider)
          .restoreNoteExclusion(
            widget.docType,
            tripId: widget.tripId,
            exclusionId: exclusion.id,
          );
      if (!mounted) return;
      setState(() {
        _future = _load();
      });
      ref.invalidate(tripNotesProvider(widget.tripId));
    } on ApiError catch (error) {
      if (!mounted) return;
      showAppError(
        context,
        hasCjk(error.message) ? error.message : '目前無法恢復這一則。',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<TripNoteExclusion>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(TpSpacing.s6),
            child: Center(child: CircularProgressIndicator.adaptive()),
          );
        }
        final items = snapshot.data ?? const <TripNoteExclusion>[];
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(TpSpacing.s6),
            child: Text('沒有被排除的項目。', style: theme.textTheme.bodyMedium),
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: TpSpacing.s3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.label, style: theme.textTheme.bodyLarge),
                          if (item.deletedAt case final at?)
                            Text(
                              '刪除於 $at',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: TpSpacing.s2),
                    TextButton(
                      key: ValueKey('notes-exclusion-restore-${item.id}'),
                      onPressed: () => _restore(item),
                      child: const Text('恢復'),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

const _sectionIcons = <NoteSection, IconData>{
  NoteSection.flights: CupertinoIcons.airplane,
  NoteSection.lodgings: CupertinoIcons.bed_double,
  NoteSection.reservations: CupertinoIcons.ticket,
  NoteSection.pretrip: CupertinoIcons.list_bullet,
  NoteSection.emergency: Icons.support_agent_outlined,
};

/// 單一 accordion section：hairline 卡片 + ExpansionTile header（icon/標題/count badge）。
/// 區內 rows 可拖曳排序、點擊編輯、左滑刪除;底部「+ 新增」。
class _NotesSection extends ConsumerWidget {
  const _NotesSection({
    required this.tripId,
    required this.section,
    required this.rows,
    this.initiallyExpanded = false,
    this.hasLodgings = false,
  });

  final String tripId;
  final NoteSection section;
  IconData get icon => _sectionIcons[section]!;
  String get title => noteSectionTitles[section]!;
  final List<_NoteRowData> rows;
  final bool initiallyExpanded;

  /// 住宿生成的前置條件;其餘 AI 資料都從 docType 描述子與 controller 查得。
  final bool hasLodgings;

  List<_NoteAiAction> get aiActions => [
    for (final type in section.generationTypes)
      _NoteAiAction(
        type: type,
        disabledText: type.disabledReason(hasLodgings: hasLodgings),
      ),
  ];

  Future<void> _delete(BuildContext context, WidgetRef ref, int rowId) {
    return confirmAndDelete(
      context,
      // 筆記列只有左滑刪除這條路徑，不是選單來源，alert 仍合規。
      source: TpDestructiveConfirmSource.direct,
      title: '刪除筆記',
      message: '「$title」中的這筆資料會永久刪除，且無法復原。',
      delete: () => ref
          .read(tripRepositoryProvider)
          .deleteNote(section, tripId: tripId, rowId: rowId),
      onSuccess: () => ref.invalidate(tripNotesProvider(tripId)),
    );
  }

  Future<void> _reorder(
    BuildContext context,
    WidgetRef ref,
    int oldIndex,
    int newIndex,
  ) async {
    final items = reorderedSortOrders(
      [for (final r in rows) r.id],
      oldIndex,
      newIndex,
    );
    try {
      await ref
          .read(tripRepositoryProvider)
          .reorderNotes(section, tripId: tripId, items: items);
    } on Exception {
      if (context.mounted) {
        showAppError(context, '排序失敗，請稍後再試');
      }
    } finally {
      ref.invalidate(tripNotesProvider(tripId));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // AI 相關資料全部從 controller 與 docType 描述子查得,不由父層一路手傳。
    final ai = ref.watch(notesAiControllerProvider(tripId));
    final aiBusyTypes = ai.busyTypes;
    final exclusionCounts = {
      for (final type in section.generationTypes)
        type: ai.of(type).exclusionCount,
    };
    void onGenerateNotes(NoteGenerationType type) => unawaited(
      ref.read(notesAiControllerProvider(tripId).notifier).generate(type),
    );
    return Card(
      key: ValueKey('notes-section-${section.name}'),
      margin: const EdgeInsets.only(bottom: TpSpacing.s3),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          shape: const Border(),
          collapsedShape: const Border(),
          iconColor: colors.onSurfaceVariant,
          collapsedIconColor: colors.onSurfaceVariant,
          leading: Icon(icon, size: 20, color: colors.onSurfaceVariant),
          title: Row(
            children: [
              Flexible(child: Text(title, style: theme.textTheme.titleMedium)),
              const SizedBox(width: TpSpacing.s2),
              Container(
                key: ValueKey('notes-count-${section.name}'),
                padding: const EdgeInsets.symmetric(
                  horizontal: TpSpacing.s2,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: const BorderRadius.all(Radius.circular(999)),
                ),
                child: Text(
                  '${rows.length}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (exclusionCounts.values.any((n) => n > 0)) const Spacer(),
              for (final MapEntry(key: type, value: count)
                  in exclusionCounts.entries)
                if (count > 0)
                  TextButton(
                    key: ValueKey('notes-exclusions-${type.pathSegment}'),
                    onPressed: () => showNoteExclusionsSheet(
                      context,
                      tripId: tripId,
                      docType: type,
                    ),
                    // 同一區有兩種生成時,標出是哪一種的排除清單。
                    child: Text(
                      exclusionCounts.length > 1
                          ? '${type.label}已排除 $count 項'
                          : '已排除 $count 項',
                    ),
                  ),
            ],
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            TpSpacing.s4,
            0,
            TpSpacing.s4,
            TpSpacing.s4,
          ),
          children: [
            if (aiActions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: TpSpacing.s3),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: TpSpacing.s2,
                    runSpacing: TpSpacing.s2,
                    children: [
                      for (final action in aiActions) ...[
                        // 只看自己這一種在不在跑:別種在生成不該把這顆一起鎖住。
                        // `action.enabled` 是按鈕自身的前置條件（例如沒有住宿就
                        // 不能生成住宿建議），與 AI 忙不忙無關,兩者各自成立。
                        OutlinedButton.icon(
                          key: ValueKey('note-ai-${action.type.pathSegment}'),
                          onPressed:
                              aiBusyTypes.contains(action.type) ||
                                  !action.enabled
                              ? null
                              : () => onGenerateNotes(action.type),
                          icon: const Icon(Icons.auto_awesome_outlined),
                          label: Text(
                            aiBusyTypes.contains(action.type)
                                ? '生成中...'
                                : action.label,
                          ),
                        ),
                        if (!action.enabled && action.disabledText != null)
                          Padding(
                            padding: const EdgeInsets.only(right: TpSpacing.s2),
                            child: Text(
                              action.disabledText!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: TpSpacing.s2),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '尚無資料',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: rows.length,
                onReorderItem: (oldIndex, newIndex) =>
                    _reorder(context, ref, oldIndex, newIndex),
                itemBuilder: (context, i) => _NoteRowTile(
                  key: ValueKey('note-row-${section.name}-${rows[i].id}'),
                  section: section,
                  tripId: tripId,
                  row: rows[i],
                  index: i,
                  onDelete: () => _delete(context, ref, rows[i].id),
                  onMoveUp: i == 0
                      ? null
                      : () => _reorder(context, ref, i, i - 1),
                  onMoveDown: i == rows.length - 1
                      ? null
                      : () => _reorder(context, ref, i, i + 1),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: ValueKey('note-add-${section.name}'),
                onPressed: () => showNoteEditSheet(
                  context,
                  tripId: tripId,
                  section: section,
                ),
                icon: const Icon(CupertinoIcons.add),
                label: Text('新增$title'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 可拖曳/點擊/左滑的筆記 row：唯讀 display 卡 + drag handle + 左滑刪除。
class _NoteRowTile extends StatelessWidget {
  const _NoteRowTile({
    super.key,
    required this.section,
    required this.tripId,
    required this.row,
    required this.index,
    required this.onDelete,
    this.onMoveUp,
    this.onMoveDown,
  });

  final NoteSection section;
  final String tripId;
  final _NoteRowData row;
  final int index;
  final Future<void> Function() onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  /// 交還 AI 維護。**兩個入口並存** —— 這是長按的捷徑,編輯 sheet 內另有一列
  /// 主介面入口。Apple HIG「Context menus」明文:context menu 的動作在主介面
  /// 也必須拿得到。
  /// 長按的捷徑選單。用 action sheet 而不是自刻選單 —— 這一列右側已經有拖曳
  /// 把手,塞不下 `⋯`;action sheet 出現在與列不同的位置、需要刻意關閉。
  Future<void> _showReassignSheet(BuildContext context, WidgetRef ref) async {
    final picked = await showAppActionSheet<int>(
      context,
      actions: const [TpActionItem(value: 0, label: '交還 AI 維護')],
    );
    if (picked == null || !context.mounted) return;
    await _reassign(context, ref);
  }

  Future<void> _reassign(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(tripRepositoryProvider)
          .setNoteMaintainer(
            section,
            tripId: tripId,
            rowId: row.id,
            managedBy: NoteMaintainer.ai,
            expectedVersion: row.version,
          );
      if (!context.mounted) return;
      ref.invalidate(tripNotesProvider(tripId));
      showAppNotice(context, '已交還 AI 維護，下次生成才會更新內容');
    } on ApiError catch (error) {
      if (!context.mounted) return;
      showAppError(context, _maintenanceErrorMessage(error));
    }
  }

  static String _maintenanceErrorMessage(ApiError error) =>
      switch (error.code) {
        'NOTES_AI_NOT_REASSIGNABLE' => '這一則不是 AI 產生的，不能交還 AI 維護。',
        'NOTES_AI_JOB_STALE' => '這一則已經被更新過，請重新整理後再試。',
        _ => hasCjk(error.message) ? error.message : '目前無法變更維護方式。',
      };

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) => GestureDetector(
        // 長按必須掛在 SwipeToDelete **外面** —— flutter_slidable 會先攔下
        // 手勢,掛在內層的 InkWell.onLongPress 永遠不會觸發。
        onLongPress: row.canReassignToAi
            ? () => _showReassignSheet(context, ref)
            : null,
        child: child,
      ),
      child: _buildRow(context),
    );
  }

  Widget _buildRow(BuildContext context) {
    return SwipeToDelete(
      dismissKey: ValueKey('note-dismiss-${section.name}-${row.id}'),
      onDelete: onDelete,
      backgroundMargin: const EdgeInsets.only(bottom: TpSpacing.s3),
      child: Row(
        children: [
          Expanded(
            child: Consumer(
              builder: (context, ref, _) => InkWell(
                onTap: () => showNoteEditSheet(
                  context,
                  tripId: tripId,
                  section: section,
                  initialFields: row.editFields,
                  rowId: row.id,
                  version: row.version,
                ),
                // 長按掛在這裡沒用 —— 外層 SwipeToDelete(flutter_slidable)
                // 會先攔下手勢。改掛在 SwipeToDelete 之外(見 build 開頭)。
                borderRadius: const BorderRadius.all(
                  Radius.circular(TpRadius.md),
                ),
                child: row.display,
              ),
            ),
          ),
          ReorderDragHandle(
            index: index,
            iconKey: ValueKey('note-drag-${section.name}-${row.id}'),
            onMoveUp: onMoveUp,
            onMoveDown: onMoveDown,
          ),
        ],
      ),
    );
  }
}

/// section 內的唯讀 row 卡片（hairline、radius md）。
class _NoteRowCard extends StatelessWidget {
  const _NoteRowCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: TpSpacing.s2),
      padding: const EdgeInsets.all(TpSpacing.s3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.all(Radius.circular(TpRadius.md)),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// 時間/日期文字（tabular figures）。
class _TimeText extends StatelessWidget {
  const _TimeText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// kind 小 chip；舊 tone API 目前映射為中性色。
class _KindChip extends StatelessWidget {
  const _KindChip({required this.label, required this.bg, required this.fg});

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TpSpacing.s2,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg),
      ),
    );
  }
}

class _FlightRow extends StatelessWidget {
  const _FlightRow(this.flight);

  final TripFlight flight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final flightTitle = '${flight.airline} ${flight.flightNo}'.trim();
    return _NoteRowCard(
      children: [
        if (flightTitle.isNotEmpty)
          Text(flightTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: TpSpacing.s1),
        Text(
          '${flight.departAirport} → ${flight.arriveAirport}',
          style: theme.textTheme.bodyMedium,
        ),
        if (flight.departAt.isNotEmpty) ...[
          const SizedBox(height: TpSpacing.s1),
          _TimeText(flight.departAt),
        ],
      ],
    );
  }
}

class _LodgingRow extends StatelessWidget {
  const _LodgingRow(this.lodging);

  final TripLodging lodging;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _NoteRowCard(
      children: [
        Text(lodging.name, style: theme.textTheme.titleMedium),
        if (lodging.checkInAt.isNotEmpty || lodging.checkOutAt.isNotEmpty) ...[
          const SizedBox(height: TpSpacing.s1),
          _TimeText('${lodging.checkInAt} ~ ${lodging.checkOutAt}'),
        ],
        if (lodging.address.isNotEmpty) ...[
          const SizedBox(height: TpSpacing.s1),
          Text(
            lodging.address,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _ReservationRow extends StatelessWidget {
  const _ReservationRow(this.reservation);

  final TripReservation reservation;

  static const _kindLabels = {
    'restaurant': '餐廳',
    'experience': '體驗',
    'ticket': '票券',
    'transport': '交通',
    'other': '其他',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return _NoteRowCard(
      children: [
        Row(
          children: [
            _KindChip(
              label: _kindLabels[reservation.kind] ?? reservation.kind,
              bg: colors.surfaceContainerHighest,
              fg: colors.onSurfaceVariant,
            ),
            const SizedBox(width: TpSpacing.s2),
            Expanded(
              child: Text(
                reservation.title,
                style: theme.textTheme.titleMedium,
              ),
            ),
          ],
        ),
        if (reservation.reservedAt.isNotEmpty) ...[
          const SizedBox(height: TpSpacing.s1),
          _TimeText(reservation.reservedAt),
        ],
      ],
    );
  }
}

/// 「AI 產生」標記。走中性語意層 —— 不另外調色、無 gradient、無 emoji。
///
/// **定位一律用 key,不要用 `find.text('AI')`** —— 緊急聯絡那顆生成按鈕的
/// label 本身就是「AI」,同畫面會有兩個。
class _NoteAiBadge extends StatelessWidget {
  const _NoteAiBadge({required this.rowKey});

  final String rowKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Semantics(
      label: 'AI 產生',
      container: true,
      excludeSemantics: true,
      child: Padding(
        key: ValueKey('note-ai-badge-$rowKey'),
        padding: const EdgeInsets.only(top: TpSpacing.s1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.sparkles, size: 13, color: muted),
            const SizedBox(width: 4),
            Text(
              'AI',
              style: theme.textTheme.labelSmall?.copyWith(color: muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _PretripNoteRow extends StatelessWidget {
  const _PretripNoteRow(this.pretripNote);

  final TripPretripNote pretripNote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _NoteRowCard(
      children: [
        if (pretripNote.showsAiBadge)
          _NoteAiBadge(rowKey: 'pretrip-${pretripNote.id}'),
        if (pretripNote.section.isNotEmpty)
          Text(
            pretripNote.section,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        if (pretripNote.title.isNotEmpty) ...[
          const SizedBox(height: TpSpacing.s1),
          Text(pretripNote.title, style: theme.textTheme.titleMedium),
        ],
        if (pretripNote.content.isNotEmpty) ...[
          const SizedBox(height: TpSpacing.s1),
          Text(pretripNote.content, style: theme.textTheme.bodyMedium),
        ],
      ],
    );
  }
}

class _EmergencyContactRow extends StatelessWidget {
  const _EmergencyContactRow(this.contact);

  final TripEmergencyContact contact;

  static const _kindLabels = {
    'personal': '個人',
    'embassy': '大使館',
    'police': '警察',
    'medical': '醫療',
    'insurance': '保險',
    'hotel': '飯店',
    'other': '其他',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return _NoteRowCard(
      children: [
        if (contact.showsAiBadge)
          _NoteAiBadge(rowKey: 'emergency-${contact.id}'),
        Row(
          children: [
            Expanded(
              child: Text(contact.name, style: theme.textTheme.titleMedium),
            ),
            const SizedBox(width: TpSpacing.s2),
            _KindChip(
              label: _kindLabels[contact.kind] ?? contact.kind,
              bg: colors.surfaceContainerHighest,
              fg: colors.onSurfaceVariant,
            ),
          ],
        ),
        if (contact.phone.isNotEmpty) ...[
          const SizedBox(height: TpSpacing.s1),
          _TimeText(contact.phone),
        ],
      ],
    );
  }
}
