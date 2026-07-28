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
import '../../models/trip_request.dart';
import '../../theme/tokens.dart';
import '../../ui/tp_app_bar.dart';
import '../../ui/swipe_to_delete.dart';
import 'notes/note_edit_sheet.dart';
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
  // 三種生成是三條獨立的線:送出中、進行中、進度通道全部 per-docType。
  // 任何一格退回單一欄位,生成行前須知時緊急聯絡就會被連坐。

  /// POST 已送出、還沒拿到 job 的 docType（同型連點的守衛）。
  final _aiSubmitting = <NoteGenerationType>{};

  /// job 已啟動、還在等終態的 docType。
  final _aiPending = <NoteGenerationType>{};

  /// 每個 docType 各自的 SSE 進度通道。共用單一 subscription 會讓「啟動第二個生成」
  /// 順手殺掉第一個的通道 —— 畫面上兩個進行中都在,但第一個的完成事件永遠不到。
  final _aiSubscriptions =
      <NoteGenerationType, StreamSubscription<TripRequestEvent>>{};

  /// 生成失敗時的顯示訊息與可重試的類型；null 代表目前沒有錯誤。
  ({String message, NoteGenerationType type})? _aiFailure;

  /// 這一幀內完成的 docType;統一在 frame 結束後合成一則提示。
  /// 兩個 job 幾乎同時完成時各發一則,兩張浮層會疊在同一個位置互相蓋掉。
  final _aiJustCompleted = <NoteGenerationType>{};
  bool _aiNoticeScheduled = false;

  @override
  void dispose() {
    for (final subscription in _aiSubscriptions.values) {
      subscription.cancel();
    }
    _aiSubscriptions.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
    final aiBusyTypes = {..._aiSubmitting, ..._aiPending};
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
            if (_aiFailure case final failure?)
              _NotesAiErrorPanel(
                message: failure.message,
                onRetry: () => _startAiGeneration(failure.type),
                onDismiss: () => setState(() => _aiFailure = null),
              ),
            // 進行中的每一種各佔一列,並固定用 enum 的宣告順序,避免先後啟動
            // 造成面板上下跳動。
            if (_aiPending.isNotEmpty)
              Column(
                key: const ValueKey('notes-ai-pending'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final type in NoteGenerationType.values)
                    if (_aiPending.contains(type))
                      _NotesAiPendingPanel(
                        key: ValueKey('notes-ai-pending-${type.pathSegment}'),
                        label: type.pendingLabel,
                      ),
                ],
              ),
          ],
        ),
        _NotesSection(
          tripId: widget.tripId,
          section: NoteSection.flights,
          icon: CupertinoIcons.airplane,
          title: '航班',
          // mobile 預設展開航班（對齊 web TripNotesPage 行為）
          initiallyExpanded: true,
          rows: [
            for (final f in notes.flights)
              _NoteRowData(
                id: f.id,
                version: f.version,
                editFields: f.toEditFields(),
                display: _FlightRow(f),
              ),
          ],
        ),
        _NotesSection(
          tripId: widget.tripId,
          section: NoteSection.lodgings,
          icon: CupertinoIcons.bed_double,
          title: '住宿',
          rows: [
            for (final l in notes.lodgings)
              _NoteRowData(
                id: l.id,
                version: l.version,
                editFields: l.toEditFields(),
                display: _LodgingRow(l),
              ),
          ],
        ),
        _NotesSection(
          tripId: widget.tripId,
          section: NoteSection.reservations,
          icon: CupertinoIcons.ticket,
          title: '預訂',
          rows: [
            for (final r in notes.reservations)
              _NoteRowData(
                id: r.id,
                version: r.version,
                editFields: r.toEditFields(),
                display: _ReservationRow(r),
              ),
          ],
        ),
        _NotesSection(
          tripId: widget.tripId,
          section: NoteSection.pretrip,
          icon: CupertinoIcons.list_bullet,
          title: '行前須知',
          aiActions: [
            const _NoteAiAction(type: NoteGenerationType.tips, label: '一般'),
            _NoteAiAction(
              type: NoteGenerationType.lodgingTips,
              label: '住宿',
              enabled: notes.lodgings.isNotEmpty,
              disabledText: '需先新增住宿',
            ),
          ],
          aiBusyTypes: aiBusyTypes,
          onGenerateNotes: _startAiGeneration,
          rows: [
            for (final p in notes.pretripNotes)
              _NoteRowData(
                id: p.id,
                version: p.version,
                editFields: p.toEditFields(),
                display: _PretripNoteRow(p),
              ),
          ],
        ),
        _NotesSection(
          tripId: widget.tripId,
          section: NoteSection.emergency,
          icon: Icons.support_agent_outlined,
          title: '緊急聯絡',
          aiActions: const [
            _NoteAiAction(type: NoteGenerationType.emergency, label: 'AI'),
          ],
          aiBusyTypes: aiBusyTypes,
          onGenerateNotes: _startAiGeneration,
          rows: [
            for (final c in notes.emergencyContacts)
              _NoteRowData(
                id: c.id,
                version: c.version,
                editFields: c.toEditFields(),
                display: _EmergencyContactRow(c),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _startAiGeneration(NoteGenerationType type) async {
    // 守衛只看**這一種**:全域守衛會讓「按鈕按得下去但什麼都沒送出」——
    // 比按鈕直接 disabled 更糟,使用者按了以為在跑,其實什麼都沒發生。
    if (_aiSubmitting.contains(type) || _aiPending.contains(type)) return;
    setState(() {
      _aiSubmitting.add(type);
      _aiFailure = null;
    });

    try {
      final job = await ref
          .read(tripRepositoryProvider)
          .generateNotes(type, tripId: widget.tripId);
      if (!mounted) return;
      setState(() {
        _aiSubmitting.remove(type);
        _aiPending.add(type);
      });
      _watchAiJob(job.requestId, type);
    } catch (error) {
      // 攔 Error 與 Exception 兩類:解析非預期回應丟的是 TypeError,只攔
      // Exception 會讓它逃逸,送出旗標永遠留在真、按鈕從此按不下去。
      if (!mounted) return;
      if (_isAlreadyRunning(error)) {
        // 後端說同一份文件已經有 job 在跑（同 trip + docType）。那正是使用者
        // 要的結果,呈現成紅色錯誤面板等於把成功講成失敗。這次回應沒帶
        // requestId,所以只接上進行中狀態、沒有自己的進度通道 —— 重新接回
        // 通道是「離開再回來還看得到它在跑」那張票的事。
        setState(() {
          _aiSubmitting.remove(type);
          _aiPending.add(type);
        });
        return;
      }
      setState(() {
        _aiSubmitting.remove(type);
        // `_watchAiJob` 在進行中狀態設值之後才跑,而它也在 try 內。它丟例外時若
        // 不一併清掉,進行中面板與錯誤面板會同時在、按鈕仍卡死,連重試都被
        // `_startAiGeneration` 開頭的守衛擋回去。
        _aiPending.remove(type);
        _aiFailure = (message: _notesAiErrorMessage(error), type: type);
      });
    }
  }

  void _watchAiJob(int requestId, NoteGenerationType type) {
    // 只收掉**同一種**的舊通道（重試同一種時)。這裡若動到別的 docType,
    // 啟動第二個生成就會殺掉第一個的進度通道:畫面上兩個進行中都在,
    // 但第一個 job 的完成事件永遠不會到達,進行中狀態從此清不掉。
    _aiSubscriptions.remove(type)?.cancel();
    _aiSubscriptions[type] = ref
        .read(requestsRepositoryProvider)
        .watchRequestEvents(requestId)
        .listen(
          (event) {
            if (!event.isTerminal) return;
            _handleAiTerminal(event, type);
          },
          onError: (Object error) {
            _aiSubscriptions.remove(type)?.cancel();
            if (!mounted) return;
            setState(() {
              _aiPending.remove(type);
              _aiFailure = (message: _notesAiErrorMessage(error), type: type);
            });
          },
        );
  }

  void _handleAiTerminal(TripRequestEvent event, NoteGenerationType type) {
    _aiSubscriptions.remove(type)?.cancel();
    if (!mounted) return;

    if (event.status == RequestStatus.completed && event.error == null) {
      setState(() => _aiPending.remove(type));
      ref.invalidate(tripNotesProvider(widget.tripId));
      _scheduleAiCompletionNotice(type);
      return;
    }

    final rawError = event.error;
    setState(() {
      _aiPending.remove(type);
      _aiFailure = (
        // 非同步失敗是這條功能的主場景，走跟 POST 例外同一條翻譯管線：
        // `event.error` 是後端原字串，直接貼上面板會把 code 露給使用者看。
        message: rawError == null
            ? _notesAiFallbackMessage
            : _notesAiErrorMessage(rawError),
        type: type,
      );
    });
  }

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

  /// 後端說「同一份文件已經有一個生成中的 job」——不是失敗,是接上既有 job。
  bool _isAlreadyRunning(Object error) =>
      error is ApiError && error.code == _notesAiJobActiveCode;
}

/// 單一筆記 row 的資料：id/version（OCC）、editFields（編輯預填）、display（唯讀卡片）。
class _NoteRowData {
  const _NoteRowData({
    required this.id,
    required this.version,
    required this.editFields,
    required this.display,
  });

  final int id;
  final int version;
  final Map<String, dynamic> editFields;
  final Widget display;
}

/// AI 生成按鈕資料；只在可生成的 section 展開後顯示。
class _NoteAiAction {
  const _NoteAiAction({
    required this.type,
    required this.label,
    this.enabled = true,
    this.disabledText,
  });

  final NoteGenerationType type;
  final String label;
  final bool enabled;
  final String? disabledText;
}

class _NotesAiPendingPanel extends StatelessWidget {
  const _NotesAiPendingPanel({super.key, required this.label});

  final String label;

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
          const SizedBox(width: TpSpacing.s3),
          Expanded(
            child: Text(
              'AI 正在生成$label，完成後會自動更新。通常需 3-7 分鐘。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSecondaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesAiErrorPanel extends StatelessWidget {
  const _NotesAiErrorPanel({
    required this.message,
    required this.onRetry,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      key: const ValueKey('notes-ai-error'),
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
                        'AI 生成失敗',
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
                  key: const ValueKey('notes-ai-retry'),
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

/// 「同一份文件已經有 job 在跑」。這個 code 不走錯誤翻譯,由
/// [_TripNotesScreenState._isAlreadyRunning] 攔下來當成接上既有 job。
const _notesAiJobActiveCode = 'NOTES_AI_JOB_ACTIVE';

/// 生成期的 error code → 人話。維護權相關的 code（`NOTES_AI_NOT_REASSIGNABLE`／
/// `NOTES_AI_JOB_STALE`）只會在維護權 PATCH 出現，這裡不列，避免留下沒有呼叫端的死碼;
/// [_notesAiJobActiveCode] 同理 —— 它不是失敗,沒有任何路徑會把它翻成錯誤訊息。
const _notesAiErrorMessages = <String, String>{
  'NOTES_AI_INVALID_OUTPUT': 'AI 這次產生的內容格式不正確',
  'NOTES_AI_NO_VALID_ITEMS': 'AI 這次沒有產生可用的項目',
  'NOTES_AI_APPLY_FAILED': 'AI 內容寫回筆記時失敗',
};

const _notesAiFallbackMessage = '目前無法完成 AI 生成';

/// 三條失敗路徑（POST 例外／stream onError／SSE 終止事件）共用這一條翻譯管線，
/// 走全 app 一致的三層 fallback：**server 回繁中就直接用 → 否則查 code 對照表 →
/// 再不然通用訊息**。原始 error code 與型別文字一律不外流到畫面。
///
/// 終止事件的 `TripRequestEvent.error` 是後端原字串，可能是 code（`NOTES_AI_*`）
/// 也可能是繁中訊息，兩種都由這裡收斂；少了第一層，429 `SYS_RATE_LIMIT`、403 權限
/// 這些後端已經給了人話的失敗會全部退化成一句通用訊息。
String _notesAiErrorMessage(Object error) {
  final (String? code, String? message) = switch (error) {
    ApiError() => (error.code, error.message),
    String() => (error, error),
    _ => (null, null),
  };
  if (message != null && hasCjk(message)) return message;
  if (code == null) return _notesAiFallbackMessage;
  return _notesAiErrorMessages[code] ?? _notesAiFallbackMessage;
}

/// 單一 accordion section：hairline 卡片 + ExpansionTile header（icon/標題/count badge）。
/// 區內 rows 可拖曳排序、點擊編輯、左滑刪除;底部「+ 新增」。
class _NotesSection extends ConsumerWidget {
  const _NotesSection({
    required this.tripId,
    required this.section,
    required this.icon,
    required this.title,
    required this.rows,
    this.initiallyExpanded = false,
    this.aiActions = const [],
    this.aiBusyTypes = const {},
    this.onGenerateNotes,
  });

  final String tripId;
  final NoteSection section;
  final IconData icon;
  final String title;
  final List<_NoteRowData> rows;
  final bool initiallyExpanded;
  final List<_NoteAiAction> aiActions;

  /// 正在送出或進行中的生成類型;每顆按鈕只看自己那一種。
  final Set<NoteGenerationType> aiBusyTypes;
  final void Function(NoteGenerationType type)? onGenerateNotes;

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
                                  !action.enabled ||
                                  onGenerateNotes == null
                              ? null
                              : () => onGenerateNotes!(action.type),
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

  @override
  Widget build(BuildContext context) {
    return SwipeToDelete(
      dismissKey: ValueKey('note-dismiss-${section.name}-${row.id}'),
      onDelete: onDelete,
      backgroundMargin: const EdgeInsets.only(bottom: TpSpacing.s3),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => showNoteEditSheet(
                context,
                tripId: tripId,
                section: section,
                initialFields: row.editFields,
                rowId: row.id,
                version: row.version,
              ),
              borderRadius: const BorderRadius.all(
                Radius.circular(TpRadius.md),
              ),
              child: row.display,
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

class _PretripNoteRow extends StatelessWidget {
  const _PretripNoteRow(this.pretripNote);

  final TripPretripNote pretripNote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _NoteRowCard(
      children: [
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
