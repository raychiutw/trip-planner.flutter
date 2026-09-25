/// PDF generation and native print/share actions for trip print documents.
library;

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/day.dart';
import '../../models/entry.dart';
import '../../models/note_content.dart';
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
  final notes = projectTripNotes(data.notes);
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
        if (notes.isNotEmpty) ...[
          pw.SizedBox(height: 14),
          ..._noteWidgets(notes),
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
                      _cell(formatTravelLine(entry.travel)),
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

/// 長文字直接交給 MultiPage 的 spanning Text，避免整張筆記卡被鎖在單頁。
Iterable<pw.Widget> _noteWidgets(List<NoteContentSection> sections) sync* {
  yield pw.Text(
    '行程筆記',
    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
  );
  yield pw.SizedBox(height: 6);
  for (final section in sections) {
    yield pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
      ),
      child: pw.Text(
        section.label,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      ),
    );
    for (final row in section.rows) {
      if (row.title.isNotEmpty) {
        yield pw.Text(
          row.title,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        );
      }
      yield pw.RichText(
        overflow: pw.TextOverflow.span,
        text: pw.TextSpan(
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          children: [
            for (var index = 0; index < row.details.length; index++) ...[
              if (index > 0) const pw.TextSpan(text: ' · '),
              pw.TextSpan(
                text: row.details[index].text,
                annotation:
                    row.details[index].links.length == 1 &&
                        row.details[index].links.single.label ==
                            row.details[index].value
                    ? pw.AnnotationUrl(
                        row.details[index].links.single.uri.toString(),
                      )
                    : null,
              ),
            ],
          ],
        ),
      );
      for (final field in row.details) {
        if (field.links.length == 1 &&
            field.links.single.label == field.value) {
          continue;
        }
        for (final link in field.links) {
          yield pw.RichText(
            overflow: pw.TextOverflow.span,
            text: pw.TextSpan(
              text: link.label == link.uri.toString() ? '開啟連結' : link.label,
              annotation: pw.AnnotationUrl(link.uri.toString()),
              style: const pw.TextStyle(
                fontSize: 8,
                decoration: pw.TextDecoration.underline,
              ),
            ),
          );
        }
      }
      yield pw.SizedBox(height: 6);
    }
    yield pw.SizedBox(height: 8);
  }
}

String _timeLine(TimelineEntry entry) {
  final start = entry.startTime?.trim() ?? '';
  final end = entry.endTime?.trim() ?? '';
  if (start.isNotEmpty && end.isNotEmpty) return '$start-$end';
  if (entry.time?.trim().isNotEmpty == true) return entry.time!.trim();
  return start.isNotEmpty ? start : end;
}
