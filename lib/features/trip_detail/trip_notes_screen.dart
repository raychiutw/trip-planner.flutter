import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/providers.dart';
import '../../app/adaptive_content.dart';
import '../../app/app_feedback.dart';
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
import 'widgets/trip_section_menu.dart';

/// 行程筆記：5-section accordion（航班/住宿/預訂/行前須知/緊急聯絡）。
class TripNotesScreen extends ConsumerStatefulWidget {
  const TripNotesScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<TripNotesScreen> createState() => _TripNotesScreenState();
}

class _TripNotesScreenState extends ConsumerState<TripNotesScreen> {
  ({int requestId, int jobId, NoteGenerationType type})? _aiJob;
  StreamSubscription<TripRequestEvent>? _aiSubscription;
  bool _aiSubmitting = false;
  String? _aiError;

  @override
  void dispose() {
    _aiSubscription?.cancel();
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
    final aiBusy = _aiSubmitting || _aiJob != null;
    return ListView(
      key: const ValueKey('trip-notes-list'),
      padding: const EdgeInsets.all(TpSpacing.s4),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TripSectionMenu(
            section: TripSection.notes,
            tripId: widget.tripId,
          ),
        ),
        const SizedBox(height: TpSpacing.s3),
        if (_aiError != null)
          _NotesAiErrorPanel(
            message: _aiError!,
            onDismiss: () => setState(() => _aiError = null),
          ),
        if (_aiJob != null)
          _NotesAiPendingPanel(label: _aiJob!.type.pendingLabel),
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
          aiBusy: aiBusy,
          activeAiType: _aiJob?.type,
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
          aiBusy: aiBusy,
          activeAiType: _aiJob?.type,
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
    if (_aiSubmitting || _aiJob != null) return;
    setState(() {
      _aiSubmitting = true;
      _aiError = null;
    });

    try {
      final job = await ref
          .read(tripRepositoryProvider)
          .generateNotes(type, tripId: widget.tripId);
      if (!mounted) return;
      setState(() {
        _aiSubmitting = false;
        _aiJob = (requestId: job.requestId, jobId: job.jobId, type: type);
      });
      _watchAiJob(job.requestId, type);
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _aiSubmitting = false;
        _aiError = _notesAiErrorMessage(error);
      });
    }
  }

  void _watchAiJob(int requestId, NoteGenerationType type) {
    _aiSubscription?.cancel();
    _aiSubscription = ref
        .read(requestsRepositoryProvider)
        .watchRequestEvents(requestId)
        .listen(
          (event) {
            if (!event.isTerminal) return;
            _handleAiTerminal(event, type);
          },
          onError: (Object error) {
            if (!mounted) return;
            setState(() {
              _aiJob = null;
              _aiError = _notesAiErrorMessage(error);
            });
          },
        );
  }

  void _handleAiTerminal(TripRequestEvent event, NoteGenerationType type) {
    final subscription = _aiSubscription;
    _aiSubscription = null;
    subscription?.cancel();
    if (!mounted) return;

    if (event.status == RequestStatus.completed && event.error == null) {
      setState(() => _aiJob = null);
      ref.invalidate(tripNotesProvider(widget.tripId));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('AI 生成完成（${type.pendingLabel}）')));
      return;
    }

    setState(() {
      _aiJob = null;
      _aiError = event.error ?? 'AI 生成失敗';
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
  const _NotesAiPendingPanel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      key: const ValueKey('notes-ai-pending'),
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
  const _NotesAiErrorPanel({required this.message, required this.onDismiss});

  final String message;
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
      child: Row(
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
          TextButton(onPressed: onDismiss, child: const Text('關閉')),
        ],
      ),
    );
  }
}

String _notesAiErrorMessage(Object error) {
  final text = error.toString();
  const exceptionPrefix = 'Exception: ';
  if (text.startsWith(exceptionPrefix)) {
    return text.substring(exceptionPrefix.length);
  }
  return text;
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
    this.aiBusy = false,
    this.activeAiType,
    this.onGenerateNotes,
  });

  final String tripId;
  final NoteSection section;
  final IconData icon;
  final String title;
  final List<_NoteRowData> rows;
  final bool initiallyExpanded;
  final List<_NoteAiAction> aiActions;
  final bool aiBusy;
  final NoteGenerationType? activeAiType;
  final void Function(NoteGenerationType type)? onGenerateNotes;

  Future<void> _delete(BuildContext context, WidgetRef ref, int rowId) {
    return confirmAndDelete(
      context,
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
                        OutlinedButton.icon(
                          key: ValueKey('note-ai-${action.type.pathSegment}'),
                          onPressed:
                              aiBusy ||
                                  !action.enabled ||
                                  onGenerateNotes == null
                              ? null
                              : () => onGenerateNotes!(action.type),
                          icon: const Icon(Icons.auto_awesome_outlined),
                          label: Text(
                            activeAiType == action.type
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
