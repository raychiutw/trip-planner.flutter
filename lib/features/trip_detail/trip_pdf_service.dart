/// PDF generation and native print/share actions for trip print documents.
library;

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/day.dart';
import '../../models/entry.dart';
import '../../models/notes.dart';
import 'trip_print_data.dart';

/// Print/PDF action implementation used by [TripPrintScreen].
final tripPrintActionsProvider = Provider<TripPrintActions>((ref) {
  return const PrintingTripPrintActions();
});

/// Abstracts platform print and share actions for widget tests.
abstract class TripPrintActions {
  const TripPrintActions();

  /// Opens the platform print dialog for [data].
  Future<void> print(TripPrintData data);

  /// Builds and shares a PDF file for [data].
  Future<void> sharePdf(TripPrintData data);
}

/// Production print/share actions backed by the `printing` package.
class PrintingTripPrintActions implements TripPrintActions {
  const PrintingTripPrintActions();

  @override
  Future<void> print(TripPrintData data) {
    return Printing.layoutPdf(
      name: data.pdfFileName(),
      onLayout: (format) => buildTripPdf(data, pageFormat: format),
    );
  }

  @override
  Future<void> sharePdf(TripPrintData data) async {
    final bytes = await buildTripPdf(data);
    await Printing.sharePdf(bytes: bytes, filename: data.pdfFileName());
  }
}

/// Builds the PDF bytes for a trip print document.
Future<Uint8List> buildTripPdf(
  TripPrintData data, {
  PdfPageFormat pageFormat = PdfPageFormat.a4,
}) async {
  final baseFont = await PdfGoogleFonts.notoSansTCRegular();
  final boldFont = await PdfGoogleFonts.notoSansTCBold();
  final document = pw.Document();
  document.addPage(
    pw.MultiPage(
      pageFormat: pageFormat,
      margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 36),
      theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
      build: (context) => [
        _PdfHeader(data: data),
        pw.SizedBox(height: 18),
        if (data.days.isEmpty)
          pw.Center(child: pw.Text('尚無行程'))
        else
          for (final day in data.days) _PdfDaySection(day: day),
        if (_hasNotes(data.notes)) ...[
          pw.SizedBox(height: 14),
          _PdfNotesSection(notes: data.notes),
        ],
      ],
    ),
  );
  return document.save();
}

class _PdfHeader extends pw.StatelessWidget {
  _PdfHeader({required this.data});

  final TripPrintData data;

  @override
  pw.Widget build(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            data.displayTitle,
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          if (data.metaLine.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              data.metaLine,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          ],
        ],
      ),
    );
  }
}

class _PdfDaySection extends pw.StatelessWidget {
  _PdfDaySection({required this.day});

  final TripDay day;

  @override
  pw.Widget build(pw.Context context) {
    final dateLine = [
      day.date,
      day.dayOfWeek == null ? null : '（${day.dayOfWeek}）',
      day.label,
    ].whereType<String>().where((part) => part.isNotEmpty).join(' ');
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Text(
                'Day ${day.dayNum}',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (dateLine.isNotEmpty) ...[
                pw.SizedBox(width: 8),
                pw.Text(
                  dateLine,
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ],
          ),
          pw.SizedBox(height: 6),
          if (day.timeline.isEmpty && day.hotel == null)
            pw.Text('尚無景點', style: const pw.TextStyle(fontSize: 10))
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: const {
                0: pw.FixedColumnWidth(58),
                1: pw.FlexColumnWidth(),
                2: pw.FixedColumnWidth(92),
              },
              children: [
                for (final entry in day.timeline)
                  pw.TableRow(
                    children: [
                      _cell(_timeLine(entry)),
                      _entryCell(entry),
                      _cell(_travelLine(entry.travel)),
                    ],
                  ),
                if (day.hotel != null)
                  pw.TableRow(
                    children: [
                      _cell('住宿'),
                      _cell(day.hotel!.name, bold: true),
                      _cell(day.hotel!.checkout ?? ''),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PdfNotesSection extends pw.StatelessWidget {
  _PdfNotesSection({required this.notes});

  final TripNotes notes;

  @override
  pw.Widget build(pw.Context context) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '行程筆記',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        if (notes.flights.isNotEmpty)
          _noteBlock(
            '航班',
            notes.flights.map((flight) {
              return _NoteLine(
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
              );
            }).toList(),
          ),
        if (notes.lodgings.isNotEmpty)
          _noteBlock(
            '住宿',
            notes.lodgings.map((lodging) {
              return _NoteLine(
                title: lodging.name,
                body: [
                  lodging.checkInAt,
                  lodging.checkOutAt,
                  lodging.address,
                  lodging.phone,
                  lodging.bookingNo,
                  lodging.note,
                ].where((part) => part.isNotEmpty).join(' · '),
              );
            }).toList(),
          ),
        if (notes.reservations.isNotEmpty)
          _noteBlock(
            '預訂',
            notes.reservations.map((reservation) {
              return _NoteLine(
                title: reservation.title,
                body: [
                  reservation.reservedAt,
                  reservation.partySize > 0 ? '${reservation.partySize} 位' : '',
                  reservation.reservationNo,
                  reservation.phone,
                  reservation.note,
                ].where((part) => part.isNotEmpty).join(' · '),
              );
            }).toList(),
          ),
        if (notes.pretripNotes.isNotEmpty)
          _noteBlock(
            '行前須知',
            notes.pretripNotes
                .map((note) => _NoteLine(title: note.title, body: note.content))
                .toList(),
          ),
        if (notes.emergencyContacts.isNotEmpty)
          _noteBlock(
            '緊急聯絡',
            notes.emergencyContacts.map((contact) {
              return _NoteLine(
                title: contact.name,
                body: [
                  contact.relationship,
                  contact.phone,
                  contact.email,
                ].where((part) => part.isNotEmpty).join(' · '),
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _NoteLine {
  const _NoteLine({required this.title, required this.body});

  final String title;
  final String body;
}

pw.Widget _entryCell(TimelineEntry entry) {
  final alternates = entry.alternates
      .map((poi) => poi.name ?? '')
      .where((name) => name.isNotEmpty)
      .toList();
  return pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          entry.title,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        if (entry.description?.trim().isNotEmpty == true)
          pw.Text(
            entry.description!.trim(),
            style: const pw.TextStyle(fontSize: 9),
          ),
        if (entry.note?.trim().isNotEmpty == true)
          pw.Text(entry.note!.trim(), style: const pw.TextStyle(fontSize: 9)),
        if (alternates.isNotEmpty)
          pw.Text(
            '備選：${alternates.join(' · ')}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
      ],
    ),
  );
}

pw.Widget _cell(String text, {bool bold = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(
      text.isEmpty ? '—' : text,
      style: pw.TextStyle(
        fontSize: 9,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
}

pw.Widget _noteBlock(String title, List<_NoteLine> rows) {
  final visibleRows = rows
      .where((row) => row.title.trim().isNotEmpty || row.body.trim().isNotEmpty)
      .toList();
  if (visibleRows.isEmpty) return pw.SizedBox.shrink();
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 8),
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        for (final row in visibleRows)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (row.title.trim().isNotEmpty)
                  pw.Text(
                    row.title.trim(),
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                if (row.body.trim().isNotEmpty)
                  pw.Text(
                    row.body.trim(),
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey700,
                    ),
                  ),
              ],
            ),
          ),
      ],
    ),
  );
}

bool _hasNotes(TripNotes notes) {
  return notes.flights.isNotEmpty ||
      notes.lodgings.isNotEmpty ||
      notes.reservations.isNotEmpty ||
      notes.pretripNotes.isNotEmpty ||
      notes.emergencyContacts.isNotEmpty;
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
