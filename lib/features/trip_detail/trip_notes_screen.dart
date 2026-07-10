import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/providers.dart';
import '../../app/adaptive.dart';
import '../../models/note_section.dart';
import '../../models/notes.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import 'notes/note_edit_sheet.dart';
import 'reorder_helpers.dart';
import 'trip_providers.dart';
import 'widgets/reorderable_row.dart';

/// 行程筆記：5-section accordion（航班/住宿/預訂/行前須知/緊急聯絡），MVP 唯讀。
class TripNotesScreen extends ConsumerWidget {
  const TripNotesScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(tripNotesProvider(tripId));
    return Scaffold(
      appBar: AppBar(title: const Text('行程筆記')),
      body: notesAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(TpSpacing.s6),
            child: Text('載入失敗：$error', textAlign: TextAlign.center),
          ),
        ),
        data: (notes) => _buildSections(context, ref, notes),
      ),
    );
  }

  Widget _buildSections(BuildContext context, WidgetRef ref, TripNotes notes) {
    final tones = Theme.of(context).extension<TpTones>()!;
    return ListView(
      padding: const EdgeInsets.all(TpSpacing.s4),
      children: [
        _NotesSection(
          tripId: tripId,
          section: NoteSection.flights,
          icon: CupertinoIcons.airplane,
          iconColor: tones.sageDeep,
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
          tripId: tripId,
          section: NoteSection.lodgings,
          icon: CupertinoIcons.bed_double,
          iconColor: tones.sageDeep,
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
          tripId: tripId,
          section: NoteSection.reservations,
          icon: CupertinoIcons.ticket,
          iconColor: tones.pinkDeep,
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
          tripId: tripId,
          section: NoteSection.pretrip,
          icon: CupertinoIcons.list_bullet,
          iconColor: tones.accentDeep,
          title: '行前須知',
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
          tripId: tripId,
          section: NoteSection.emergency,
          icon: Icons.support_agent_outlined,
          iconColor: tones.accentDeep,
          title: '緊急聯絡',
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

/// 單一 accordion section：hairline 卡片 + ExpansionTile header（icon/標題/count badge）。
/// 區內 rows 可拖曳排序、點擊編輯、左滑刪除;底部「+ 新增」。
class _NotesSection extends ConsumerWidget {
  const _NotesSection({
    required this.tripId,
    required this.section,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.rows,
    this.initiallyExpanded = false,
  });

  final String tripId;
  final NoteSection section;
  final IconData icon;
  final Color iconColor;
  final String title;
  final List<_NoteRowData> rows;
  final bool initiallyExpanded;

  Future<void> _delete(BuildContext context, WidgetRef ref, int rowId) {
    return confirmAndDelete(
      context,
      title: '刪除筆記',
      message: '確定要刪除這筆嗎？',
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
        showAppNotice(context, '排序失敗，請稍後再試');
      }
    } finally {
      ref.invalidate(tripNotesProvider(tripId));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tones = theme.extension<TpTones>()!;
    return Container(
      margin: const EdgeInsets.only(bottom: TpSpacing.s3),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.all(Radius.circular(TpRadius.lg)),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        // hairline 樣式：取消 ExpansionTile 展開時的預設上下分隔線
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: TpSpacing.s4),
        childrenPadding: const EdgeInsets.fromLTRB(
          TpSpacing.s4,
          0,
          TpSpacing.s4,
          TpSpacing.s4,
        ),
        iconColor: theme.colorScheme.onSurfaceVariant,
        collapsedIconColor: theme.colorScheme.onSurfaceVariant,
        leading: Icon(icon, size: 20, color: iconColor),
        title: Wrap(
          spacing: TpSpacing.s2,
          runSpacing: TpSpacing.s1,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(fontSize: 16),
            ),
            Container(
              key: ValueKey('notes-count-${section.name}'),
              padding: const EdgeInsets.symmetric(
                horizontal: TpSpacing.s2,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: tones.accentSubtle,
                borderRadius: const BorderRadius.all(Radius.circular(999)),
              ),
              child: Text(
                '${rows.length}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: tones.accentDeep,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
        children: [
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
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: ValueKey('note-add-${section.name}'),
              onPressed: () =>
                  showNoteEditSheet(context, tripId: tripId, section: section),
              icon: const Icon(CupertinoIcons.add),
              label: Text('新增$title'),
            ),
          ),
        ],
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
  });

  final NoteSection section;
  final String tripId;
  final _NoteRowData row;
  final int index;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    return SwipeToDelete(
      dismissKey: ValueKey('note-dismiss-${section.name}-${row.id}'),
      onDelete: onDelete,
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

/// kind 小 chip（三色 tone）。
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
          Text(
            flightTitle,
            style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
          ),
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
        Text(
          lodging.name,
          style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
        ),
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
    final tones = theme.extension<TpTones>()!;
    // 三色語意：吃 = 粉、移動 = sage、其餘 = accent
    final (chipBg, chipFg) = switch (reservation.kind) {
      'restaurant' => (tones.pinkBg, tones.pinkDeep),
      'transport' => (tones.sageBg, tones.sageDeep),
      _ => (tones.accentBg, tones.accentDeep),
    };
    return _NoteRowCard(
      children: [
        Row(
          children: [
            _KindChip(
              label: _kindLabels[reservation.kind] ?? reservation.kind,
              bg: chipBg,
              fg: chipFg,
            ),
            const SizedBox(width: TpSpacing.s2),
            Expanded(
              child: Text(
                reservation.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
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
          Text(
            pretripNote.title,
            style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
          ),
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
    final tones = theme.extension<TpTones>()!;
    return _NoteRowCard(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                contact.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
              ),
            ),
            const SizedBox(width: TpSpacing.s2),
            _KindChip(
              label: _kindLabels[contact.kind] ?? contact.kind,
              bg: tones.accentBg,
              fg: tones.accentDeep,
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
