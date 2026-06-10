import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/notes.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import 'trip_providers.dart';

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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(TpSpacing.s6),
            child: Text('載入失敗：$error', textAlign: TextAlign.center),
          ),
        ),
        data: (notes) => _buildSections(context, notes),
      ),
    );
  }

  Widget _buildSections(BuildContext context, TripNotes notes) {
    final tones = Theme.of(context).extension<TpTones>()!;
    return ListView(
      padding: const EdgeInsets.all(TpSpacing.s4),
      children: [
        _NotesSection(
          countKeySuffix: 'flights',
          icon: Icons.flight_takeoff,
          iconColor: tones.sageDeep,
          title: '航班',
          count: notes.flights.length,
          // mobile 預設展開航班（對齊 web TripNotesPage 行為）
          initiallyExpanded: true,
          rows: [for (final flight in notes.flights) _FlightRow(flight)],
        ),
        _NotesSection(
          countKeySuffix: 'lodgings',
          icon: Icons.hotel_outlined,
          iconColor: tones.sageDeep,
          title: '住宿',
          count: notes.lodgings.length,
          rows: [for (final lodging in notes.lodgings) _LodgingRow(lodging)],
        ),
        _NotesSection(
          countKeySuffix: 'reservations',
          icon: Icons.confirmation_number_outlined,
          iconColor: tones.pinkDeep,
          title: '預訂',
          count: notes.reservations.length,
          rows: [
            for (final reservation in notes.reservations)
              _ReservationRow(reservation),
          ],
        ),
        _NotesSection(
          countKeySuffix: 'pretrip',
          icon: Icons.checklist_outlined,
          iconColor: tones.accentDeep,
          title: '行前須知',
          count: notes.pretripNotes.length,
          rows: [
            for (final pretripNote in notes.pretripNotes)
              _PretripNoteRow(pretripNote),
          ],
        ),
        _NotesSection(
          countKeySuffix: 'emergency',
          icon: Icons.support_agent_outlined,
          iconColor: tones.accentDeep,
          title: '緊急聯絡',
          count: notes.emergencyContacts.length,
          rows: [
            for (final contact in notes.emergencyContacts)
              _EmergencyContactRow(contact),
          ],
        ),
      ],
    );
  }
}

/// 單一 accordion section：hairline 卡片 + ExpansionTile header（icon/標題/count badge）。
class _NotesSection extends StatelessWidget {
  const _NotesSection({
    required this.countKeySuffix,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.count,
    required this.rows,
    this.initiallyExpanded = false,
  });

  final String countKeySuffix;
  final IconData icon;
  final Color iconColor;
  final String title;
  final int count;
  final List<Widget> rows;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
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
        title: Row(
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(fontSize: 16),
            ),
            const SizedBox(width: TpSpacing.s2),
            Container(
              key: ValueKey('notes-count-$countKeySuffix'),
              padding: const EdgeInsets.symmetric(
                horizontal: TpSpacing.s2,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: tones.accentSubtle,
                borderRadius: const BorderRadius.all(Radius.circular(999)),
              ),
              child: Text(
                '$count',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: tones.accentDeep,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
        children: rows.isEmpty
            ? [
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
                ),
              ]
            : rows,
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
      padding: const EdgeInsets.symmetric(horizontal: TpSpacing.s2, vertical: 2),
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
