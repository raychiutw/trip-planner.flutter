/// Authenticated trip print/PDF preview (`/trips/:id/print`).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/providers.dart';
import '../../app/adaptive.dart';
import '../../app/app_loading_skeleton.dart';
import '../../app/app_feedback.dart';
import '../../models/day.dart';
import '../../models/entry.dart';
import '../../models/notes.dart';
import '../../theme/tokens.dart';
import 'trip_pdf_service.dart';
import 'trip_print_data.dart';

/// Loads the authenticated trip print document.
final tripPrintDataProvider = FutureProvider.family<TripPrintData, String>((
  ref,
  tripId,
) async {
  final repository = ref.watch(tripRepositoryProvider);
  final tripFuture = repository.fetchTrip(tripId);
  final daysFuture = repository.fetchDays(tripId);
  Future<TripNotes> fetchNotesOrEmpty() async {
    try {
      return await repository.fetchNotes(tripId);
    } catch (_) {
      return const TripNotes();
    }
  }

  final notesFuture = fetchNotesOrEmpty();
  return TripPrintData(
    trip: await tripFuture,
    days: await daysFuture,
    notes: await notesFuture,
  );
});

enum _PrintAction { print, pdf }

/// Authenticated print/PDF preview for a trip.
class TripPrintScreen extends ConsumerStatefulWidget {
  const TripPrintScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<TripPrintScreen> createState() => _TripPrintScreenState();
}

class _TripPrintScreenState extends ConsumerState<TripPrintScreen> {
  _PrintAction? _busyAction;

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(tripPrintDataProvider(widget.tripId));
    final data = dataAsync.value;
    final busy = _busyAction != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('列印預覽'),
        actions: [
          IconButton(
            key: const ValueKey('trip-print-do'),
            tooltip: '列印',
            icon: _busyAction == _PrintAction.print
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  )
                : const Icon(CupertinoIcons.printer),
            onPressed: data == null || busy
                ? null
                : () => unawaited(_runAction(_PrintAction.print, data)),
          ),
          IconButton(
            key: const ValueKey('trip-print-pdf'),
            tooltip: '匯出 PDF',
            icon: _busyAction == _PrintAction.pdf
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            onPressed: data == null || busy
                ? null
                : () => unawaited(_runAction(_PrintAction.pdf, data)),
          ),
        ],
      ),
      body: SafeArea(
        child: dataAsync.when(
          loading: () =>
              const AppListLoadingSkeleton(key: ValueKey('trip-print-loading')),
          error: (error, stackTrace) => _PrintError(
            onRetry: () => ref.invalidate(tripPrintDataProvider(widget.tripId)),
          ),
          data: (printData) => _TripPrintDocument(data: printData),
        ),
      ),
    );
  }

  Future<void> _runAction(_PrintAction action, TripPrintData data) async {
    setState(() => _busyAction = action);
    try {
      final actions = ref.read(tripPrintActionsProvider);
      switch (action) {
        case _PrintAction.print:
          await actions.print(data);
          if (!mounted) return;
          _showMessage('已送出列印');
          return;
        case _PrintAction.pdf:
          await actions.sharePdf(data);
          if (!mounted) return;
          _showMessage('PDF 已建立');
          return;
      }
    } on Exception {
      if (!mounted) return;
      showAppError(
        context,
        action == _PrintAction.print ? '列印失敗，請稍後再試' : 'PDF 建立失敗，請稍後再試',
      );
    } finally {
      if (mounted) setState(() => _busyAction = null);
    }
  }

  void _showMessage(String message) {
    showAppNotice(context, message);
  }
}

class _TripPrintDocument extends StatelessWidget {
  const _TripPrintDocument({required this.data});

  final TripPrintData data;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('trip-print-document'),
      padding: const EdgeInsets.fromLTRB(
        TpSpacing.s4,
        TpSpacing.s4,
        TpSpacing.s4,
        TpSpacing.s8,
      ),
      children: [
        _PrintHeader(data: data),
        const SizedBox(height: TpSpacing.s5),
        if (data.days.isEmpty)
          const _EmptyPrintDocument()
        else
          for (final day in data.days) _PrintDaySection(day: day),
        _PrintNotesSection(notes: data.notes),
      ],
    );
  }
}

class _PrintHeader extends StatelessWidget {
  const _PrintHeader({required this.data});

  final TripPrintData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: const BorderRadius.all(Radius.circular(TpRadius.md)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data.displayTitle, style: theme.textTheme.headlineSmall),
            if (data.metaLine.isNotEmpty) ...[
              const SizedBox(height: TpSpacing.s2),
              Text(
                data.metaLine,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PrintDaySection extends StatelessWidget {
  const _PrintDaySection({required this.day});

  final TripDay day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLine = [
      day.date,
      day.dayOfWeek == null ? null : '（${day.dayOfWeek}）',
      day.label,
    ].whereType<String>().where((part) => part.isNotEmpty).join(' ');
    return Padding(
      padding: const EdgeInsets.only(bottom: TpSpacing.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Day ${day.dayNum}', style: theme.textTheme.titleMedium),
              if (dateLine.isNotEmpty) ...[
                const SizedBox(width: TpSpacing.s2),
                Expanded(
                  child: Text(
                    dateLine,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: TpSpacing.s2),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var index = 0; index < day.timeline.length; index++) ...[
                  _EntryRow(entry: day.timeline[index]),
                  if (index != day.timeline.length - 1)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: theme.colorScheme.outlineVariant,
                    ),
                ],
                if (day.hotel != null) ...[
                  if (day.timeline.isNotEmpty)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ListTile(
                    leading: const Icon(CupertinoIcons.bed_double),
                    title: Text(day.hotel!.name),
                    subtitle: day.hotel!.checkout == null
                        ? null
                        : Text(day.hotel!.checkout!),
                  ),
                ],
                if (day.timeline.isEmpty && day.hotel == null)
                  const ListTile(title: Text('尚無景點')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final TimelineEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final travelLine = formatTravelLine(entry.travel);
    return ListTile(
      title: Text(entry.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_timeLine(entry).isNotEmpty) Text(_timeLine(entry)),
          if (entry.description?.trim().isNotEmpty == true)
            Text(entry.description!.trim()),
          if (entry.note?.trim().isNotEmpty == true) Text(entry.note!.trim()),
          if (entry.alternates.isNotEmpty)
            Text(
              '備選：${entry.alternates.map((poi) => poi.name ?? '').where((name) => name.isNotEmpty).join(' · ')}',
            ),
          if (travelLine.isNotEmpty)
            Text(
              travelLine,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _PrintNotesSection extends StatelessWidget {
  const _PrintNotesSection({required this.notes});

  final TripNotes notes;

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[
      if (notes.flights.isNotEmpty)
        _NoteCard(
          title: '航班',
          icon: CupertinoIcons.airplane,
          rows: notes.flights
              .map(
                (flight) => _NoteRowData(
                  title: [
                    flight.airline,
                    flight.flightNo,
                  ].where((part) => part.isNotEmpty).join(' '),
                  body: [
                    flight.departAirport,
                    flight.departAt,
                    flight.arriveAirport.isEmpty
                        ? ''
                        : '→ ${flight.arriveAirport}',
                    flight.arriveAt,
                    flight.note,
                  ].where((part) => part.isNotEmpty).join(' · '),
                ),
              )
              .toList(),
        ),
      if (notes.lodgings.isNotEmpty)
        _NoteCard(
          title: '住宿',
          icon: CupertinoIcons.bed_double,
          rows: notes.lodgings
              .map(
                (lodging) => _NoteRowData(
                  title: lodging.name,
                  body: [
                    lodging.checkInAt,
                    lodging.checkOutAt,
                    lodging.address,
                    lodging.phone,
                    lodging.bookingNo,
                    lodging.note,
                  ].where((part) => part.isNotEmpty).join(' · '),
                ),
              )
              .toList(),
        ),
      if (notes.reservations.isNotEmpty)
        _NoteCard(
          title: '預訂',
          icon: CupertinoIcons.checkmark_circle,
          rows: notes.reservations
              .map(
                (reservation) => _NoteRowData(
                  title: reservation.title,
                  body: [
                    reservation.reservedAt,
                    reservation.partySize > 0
                        ? '${reservation.partySize} 位'
                        : '',
                    reservation.reservationNo,
                    reservation.phone,
                    reservation.note,
                  ].where((part) => part.isNotEmpty).join(' · '),
                ),
              )
              .toList(),
        ),
      if (notes.pretripNotes.isNotEmpty)
        _NoteCard(
          title: '行前須知',
          icon: CupertinoIcons.doc_text,
          rows: notes.pretripNotes
              .map(
                (note) => _NoteRowData(title: note.title, body: note.content),
              )
              .toList(),
        ),
      if (notes.emergencyContacts.isNotEmpty)
        _NoteCard(
          title: '緊急聯絡',
          icon: CupertinoIcons.phone,
          rows: notes.emergencyContacts
              .map(
                (contact) => _NoteRowData(
                  title: contact.name,
                  body: [
                    contact.relationship,
                    contact.phone,
                    contact.email,
                  ].where((part) => part.isNotEmpty).join(' · '),
                ),
              )
              .toList(),
        ),
    ];
    if (sections.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('行程筆記', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: TpSpacing.s2),
        ...sections,
      ],
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.title,
    required this.icon,
    required this.rows,
  });

  final String title;
  final IconData icon;
  final List<_NoteRowData> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: TpSpacing.s3),
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: TpSpacing.s2),
                Text(title, style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: TpSpacing.s2),
            for (final row in rows)
              if (row.title.trim().isNotEmpty || row.body.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: TpSpacing.s2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (row.title.trim().isNotEmpty)
                        Text(
                          row.title.trim(),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      if (row.body.trim().isNotEmpty) Text(row.body.trim()),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _NoteRowData {
  const _NoteRowData({required this.title, required this.body});

  final String title;
  final String body;
}

class _EmptyPrintDocument extends StatelessWidget {
  const _EmptyPrintDocument();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: TpSpacing.s6),
      child: Center(child: Text('尚無行程')),
    );
  }
}

class _PrintError extends StatelessWidget {
  const _PrintError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('trip-print-error'),
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '行程載入失敗，請稍後重試',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: TpSpacing.s3),
            FilledButton(onPressed: onRetry, child: const Text('重試')),
          ],
        ),
      ),
    );
  }
}

String _timeLine(TimelineEntry entry) {
  final start = entry.startTime?.trim() ?? '';
  final end = entry.endTime?.trim() ?? '';
  if (start.isNotEmpty && end.isNotEmpty) return '$start-$end';
  if (entry.time?.trim().isNotEmpty == true) return entry.time!.trim();
  return start.isNotEmpty ? start : end;
}
