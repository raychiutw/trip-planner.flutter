/// Public no-login trip share page (`/s/:token`).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/providers.dart';
import '../../models/day.dart';
import '../../models/entry.dart';
import '../../models/notes.dart';
import '../../models/share.dart';
import '../../theme/tokens.dart';

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

class _PublicShareScreenState extends ConsumerState<PublicShareScreen> {
  bool _cloning = false;
  String? _cloneError;

  String get _token => widget.token.trim();

  @override
  Widget build(BuildContext context) {
    final shareAsync = ref.watch(publicTripShareProvider(_token));
    final currentUser = ref.watch(authStateProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('行程分享')),
      body: SafeArea(
        child: shareAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              key: ValueKey('public-share-loading'),
            ),
          ),
          error: (error, stackTrace) => _NotFoundState(
            onRetry: () => ref.invalidate(publicTripShareProvider(_token)),
          ),
          data: (share) => _ShareContent(
            share: share,
            cloning: _cloning,
            cloneError: _cloneError,
            isLoggedIn: currentUser != null,
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
          .read(tripRepositoryProvider)
          .clonePublicTripShare(_token);
      if (!mounted) return;
      context.go('/trips/${Uri.encodeComponent(tripId)}');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cloning = false;
        _cloneError = '複製失敗，請稍後再試';
      });
    }
  }
}

class _ShareContent extends StatelessWidget {
  const _ShareContent({
    required this.share,
    required this.cloning,
    required this.cloneError,
    required this.isLoggedIn,
    required this.onClone,
  });

  final PublicTripShare share;
  final bool cloning;
  final String? cloneError;
  final bool isLoggedIn;
  final VoidCallback onClone;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('public-share-page'),
      padding: const EdgeInsets.fromLTRB(
        TpSpacing.s4,
        TpSpacing.s4,
        TpSpacing.s4,
        TpSpacing.s8,
      ),
      children: [
        _ShareHero(share: share),
        const SizedBox(height: TpSpacing.s4),
        FilledButton.icon(
          key: const ValueKey('public-share-clone'),
          onPressed: cloning ? null : onClone,
          icon: cloning
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.copy_outlined),
          label: Text(
            cloning
                ? '複製中…'
                : isLoggedIn
                ? '複製到我的行程'
                : '登入後複製行程',
          ),
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
      share.dateRange,
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
                  Icons.auto_awesome_outlined,
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
      day.date,
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
    final travelLine = _travelLine(entry.travel);
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

class _HotelRow extends StatelessWidget {
  const _HotelRow({required this.hotel});

  final DayHotel hotel;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.bed_outlined),
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
          icon: Icons.flight_takeoff_outlined,
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
          icon: Icons.hotel_outlined,
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
          icon: Icons.check_circle_outline,
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
          icon: Icons.article_outlined,
          rows: notes.pretripNotes
              .map(
                (note) => _NoteRowData(title: note.title, body: note.content),
              )
              .toList(),
        ),
      if (notes.emergencyContacts.isNotEmpty)
        _NoteCard(
          title: '緊急聯絡',
          icon: Icons.phone_outlined,
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
    return Center(
      key: const ValueKey('public-share-notfound'),
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
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
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

String _travelLine(Travel? travel) {
  if (travel == null) return '';
  final parts = <String>[
    _travelModeLabel(travel.type),
    if (travel.min != null && travel.min! > 0) '${travel.min} 分',
    if (travel.distanceM != null && travel.distanceM! > 0)
      '${(travel.distanceM! / 1000).toStringAsFixed(1)}km',
  ].where((part) => part.trim().isNotEmpty).toList();
  return parts.join(' · ');
}

String _travelModeLabel(String value) {
  return switch (value) {
    'driving' || 'car' || 'drive' => '開車',
    'walking' || 'walk' => '步行',
    'transit' => '大眾運輸',
    'bus' => '公車',
    'train' => '火車',
    'metro' || 'subway' => '捷運',
    'ferry' => '渡輪',
    'flight' || 'plane' => '飛機',
    _ => value,
  };
}
