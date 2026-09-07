/// Public no-login trip share page (`/s/:token`).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/providers.dart';
import '../../app/adaptive.dart';
import '../../app/app_loading_skeleton.dart';
import '../../app/app_feedback.dart';
import '../../models/day.dart';
import '../../models/entry.dart';
import '../../models/notes.dart';
import '../../models/share.dart';
import '../../theme/tokens.dart';
import '../../ui/tp_app_bar.dart';
import '../trip_detail/trip_pdf_service.dart';
import '../trip_detail/trip_print_data.dart';

/// 公開分享頁資料 provider。
final publicTripShareProvider = FutureProvider.family<PublicTripShare, String>((
  ref,
  token,
) {
  return ref.watch(tripRepositoryProvider).fetchPublicTripShare(token);
});

class PublicShareScreen extends ConsumerStatefulWidget {
  const PublicShareScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<PublicShareScreen> createState() => _PublicShareScreenState();
}

enum _PublicShareAction { print, pdf }

class _PublicShareScreenState extends ConsumerState<PublicShareScreen> {
  bool _cloning = false;
  String? _cloneError;
  _PublicShareAction? _busyAction;

  String get _token => widget.token.trim();

  @override
  Widget build(BuildContext context) {
    final shareAsync = ref.watch(publicTripShareProvider(_token));
    final currentUser = ref.watch(authStateProvider).value;
    return Scaffold(
      appBar: const TpAppBar(
        role: TpAppBarRole.standalone,
        title: Text('行程分享'),
      ),
      body: SafeArea(
        child: shareAsync.when(
          loading: () => const AppListLoadingSkeleton(
            key: ValueKey('public-share-loading'),
          ),
          error: (error, stackTrace) => _NotFoundState(
            onRetry: () => ref.invalidate(publicTripShareProvider(_token)),
          ),
          data: (share) => _ShareContent(
            share: share,
            cloning: _cloning,
            cloneError: _cloneError,
            busyAction: _busyAction,
            isLoggedIn: currentUser != null,
            onPrint: () =>
                unawaited(_runPrintAction(_PublicShareAction.print, share)),
            onPdf: () =>
                unawaited(_runPrintAction(_PublicShareAction.pdf, share)),
            onClone: () => unawaited(_cloneOrLogin()),
          ),
        ),
      ),
    );
  }

  Future<void> _cloneOrLogin() async {
    if (_token.isEmpty || _cloning) return;
    final currentUser = ref.read(authStateProvider).value;
    if (currentUser == null) {
      context.go('/login?redirect_after=${Uri.encodeComponent('/s/$_token')}');
      return;
    }

    setState(() {
      _cloning = true;
      _cloneError = null;
    });
    try {
      final tripId = await ref
          .read(accountRepositoryProvider)
          .clonePublicTripShare(_token);
      if (!mounted) return;
      HapticFeedback.lightImpact();
      context.go('/trips/${Uri.encodeComponent(tripId)}');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cloning = false;
        _cloneError = '複製失敗，請稍後再試';
      });
    }
  }

  Future<void> _runPrintAction(
    _PublicShareAction action,
    PublicTripShare share,
  ) async {
    if (_busyAction != null) return;
    setState(() => _busyAction = action);
    try {
      final data = TripPrintData.fromPublicShare(share);
      final actions = ref.read(tripPrintActionsProvider);
      switch (action) {
        case _PublicShareAction.print:
          await actions.print(data);
          if (!mounted) return;
          _showMessage('已送出列印');
          return;
        case _PublicShareAction.pdf:
          await actions.sharePdf(data);
          if (!mounted) return;
          _showMessage('PDF 已建立');
          return;
      }
    } on Exception {
      if (!mounted) return;
      showAppError(
        context,
        action == _PublicShareAction.print ? '列印失敗，請稍後再試' : 'PDF 建立失敗，請稍後再試',
      );
    } finally {
      if (mounted) setState(() => _busyAction = null);
    }
  }

  void _showMessage(String message) {
    showAppNotice(context, message);
  }
}

class _ShareContent extends StatelessWidget {
  const _ShareContent({
    required this.share,
    required this.cloning,
    required this.cloneError,
    required this.busyAction,
    required this.isLoggedIn,
    required this.onPrint,
    required this.onPdf,
    required this.onClone,
  });

  final PublicTripShare share;
  final bool cloning;
  final String? cloneError;
  final _PublicShareAction? busyAction;
  final bool isLoggedIn;
  final VoidCallback onPrint;
  final VoidCallback onPdf;
  final VoidCallback onClone;

  @override
  Widget build(BuildContext context) {
    final actionBusy = busyAction != null;
    return ListView(
      key: const ValueKey('public-share-page'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
        TpSpacing.s4,
        TpSpacing.s4,
        TpSpacing.s4,
        TpSpacing.s8,
      ),
      children: [
        _ShareHero(share: share),
        const SizedBox(height: TpSpacing.s4),
        Row(
          children: [
            IconButton.filledTonal(
              key: const ValueKey('public-share-print'),
              tooltip: '列印',
              onPressed: actionBusy ? null : onPrint,
              icon: busyAction == _PublicShareAction.print
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    )
                  : const Icon(CupertinoIcons.printer),
            ),
            const SizedBox(width: TpSpacing.s2),
            IconButton.filledTonal(
              key: const ValueKey('public-share-pdf'),
              tooltip: '匯出 PDF',
              onPressed: actionBusy ? null : onPdf,
              icon: busyAction == _PublicShareAction.pdf
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
            ),
            const SizedBox(width: TpSpacing.s2),
            Expanded(
              child: FilledButton.icon(
                key: const ValueKey('public-share-clone'),
                onPressed: cloning ? null : onClone,
                icon: cloning
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator.adaptive(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(CupertinoIcons.doc_on_doc),
                label: Text(
                  cloning
                      ? '複製中…'
                      : isLoggedIn
                      ? '複製到我的行程'
                      : '登入後複製行程',
                ),
              ),
            ),
          ],
        ),
        if (cloneError != null) ...[
          const SizedBox(height: TpSpacing.s3),
          _InlineError(message: cloneError!),
        ],
        const SizedBox(height: TpSpacing.s6),
        _ShareDocument(share: share),
      ],
    );
  }
}

class _ShareHero extends StatelessWidget {
  const _ShareHero({required this.share});

  final PublicTripShare share;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = [
      _localizedDateRange(context, share),
      share.destinationsLabel,
      share.days.isEmpty ? '' : '${share.days.length} 天',
    ].where((part) => part.trim().isNotEmpty).join(' · ');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: const BorderRadius.all(Radius.circular(TpRadius.lg)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TpSpacing.s5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  CupertinoIcons.sparkles,
                  size: 18,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: TpSpacing.s2),
                Expanded(
                  child: Text(
                    share.sharedBy.trim().isEmpty
                        ? '有人分享了一份行程給你'
                        : '由 ${share.sharedBy} 分享給你',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: TpSpacing.s3),
            Text(
              share.displayTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            if (meta.isNotEmpty) ...[
              const SizedBox(height: TpSpacing.s2),
              Text(
                meta,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ShareDocument extends StatelessWidget {
  const _ShareDocument({required this.share});

  final PublicTripShare share;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (share.days.isEmpty)
          const _EmptyDocument()
        else
          for (final day in share.days) _DaySection(day: day),
        _NotesSection(notes: share.notes),
      ],
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({required this.day});

  final TripDay day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLine = [
      _localizedDate(context, day.date),
      day.dayOfWeek == null ? null : '（${day.dayOfWeek}）',
      day.label,
    ].whereType<String>().where((part) => part.isNotEmpty).join(' ');
    return Padding(
      key: ValueKey('public-share-day-${day.dayNum}'),
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
                  _HotelRow(hotel: day.hotel!),
                ],
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
    final timeLine = _timeLine(context, entry);
    return ListTile(
      title: Text(entry.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (timeLine.isNotEmpty) Text(timeLine),
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

class _HotelRow extends StatelessWidget {
  const _HotelRow({required this.hotel});

  final DayHotel hotel;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(CupertinoIcons.bed_double),
      title: Text(hotel.name),
      subtitle: hotel.note == null && hotel.checkout == null
          ? null
          : Text(
              [hotel.checkout, hotel.note]
                  .whereType<String>()
                  .where((part) => part.isNotEmpty)
                  .join(' · '),
            ),
    );
  }
}

class _NotesSection extends StatelessWidget {
  const _NotesSection({required this.notes});

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

class _EmptyDocument extends StatelessWidget {
  const _EmptyDocument();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: TpSpacing.s6),
      child: Center(child: Text('尚無行程')),
    );
  }
}

class _NotFoundState extends StatelessWidget {
  const _NotFoundState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const ValueKey('public-share-notfound'),
      container: true,
      liveRegion: true,
      label: '連結已失效',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(TpSpacing.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.link_off_outlined,
                size: 40,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: TpSpacing.s3),
              Text('連結已失效', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: TpSpacing.s2),
              const Text(
                '這個分享連結不存在、已被關閉或已過期。請向分享者索取新的連結。',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: TpSpacing.s4),
              FilledButton(onPressed: onRetry, child: const Text('重試')),
            ],
          ),
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
    return Semantics(
      key: const ValueKey('public-share-clone-error'),
      container: true,
      liveRegion: true,
      label: '錯誤：$message',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: const BorderRadius.all(Radius.circular(TpRadius.md)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(TpSpacing.s3),
          child: Text(
            message,
            style: TextStyle(color: colorScheme.onErrorContainer),
          ),
        ),
      ),
    );
  }
}

String _timeLine(BuildContext context, TimelineEntry entry) {
  final start = entry.startTime?.trim() ?? '';
  final end = entry.endTime?.trim() ?? '';
  if (start.isNotEmpty && end.isNotEmpty) {
    return '${_localizedTime(context, start)}–${_localizedTime(context, end)}';
  }
  if (entry.time?.trim().isNotEmpty == true) {
    return _localizedTime(context, entry.time!.trim());
  }
  return _localizedTime(context, start.isNotEmpty ? start : end);
}

String _localizedDateRange(BuildContext context, PublicTripShare share) {
  final dates = share.days
      .map((day) => day.date?.trim())
      .whereType<String>()
      .where((date) => date.isNotEmpty)
      .toList();
  if (dates.isEmpty) return '';
  final first = _localizedDate(context, dates.first);
  final last = _localizedDate(context, dates.last);
  return dates.first == dates.last ? first : '$first – $last';
}

String _localizedDate(BuildContext context, String? value) {
  final raw = value?.trim() ?? '';
  final date = DateTime.tryParse(raw);
  if (date == null) return raw;
  return MaterialLocalizations.of(context).formatCompactDate(date.toLocal());
}

String _localizedTime(BuildContext context, String value) {
  final parts = value.split(':');
  if (parts.length < 2) return value;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null ||
      minute == null ||
      hour < 0 ||
      hour > 23 ||
      minute < 0 ||
      minute > 59) {
    return value;
  }
  return MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay(hour: hour, minute: minute),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
}
