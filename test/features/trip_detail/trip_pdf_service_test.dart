import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:printing/printing.dart';
import 'package:tripline/features/trip_detail/trip_pdf_service.dart';
import 'package:tripline/features/trip_detail/trip_print_data.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/models/notes.dart';
import 'package:tripline/models/share.dart';

import '../../fixtures/note_content_fixture.dart';

/// 第三方公開 cache seam：使用 production 同一份字型，且不產生清理 timer。
class _FontCache extends PdfBaseCache {
  final fonts = <String, Uint8List>{
    for (final weight in ['Regular', 'Bold'])
      'NotoSansTC-$weight': File(
        'test/fixtures/fonts/noto-sans-tc/NotoSansTC-$weight.ttf',
      ).readAsBytesSync(),
  };
  @override
  Future<bool> contains(String key) async => true;
  @override
  Future<Uint8List?> get(String key) async =>
      fonts[key] ?? (throw StateError('未預期字型：$key'));
  @override
  Future<void> add(String key, Uint8List bytes) async => fonts[key] = bytes;
  @override
  Future<void> remove(String key) async => fonts.remove(key);
  @override
  Future<void> clear() async => fonts.clear();
}

Future<Map<String, dynamic>> readPdf(TripPrintData data, String name) async {
  final file = File('build/test-artifacts/notes/$name.pdf');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(await buildTripPdf(data));
  if (Platform.isMacOS) {
    final result = await Process.run('xcrun', [
      'swift',
      'test/support/read_pdf.swift',
      file.path,
    ]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    return jsonDecode(result.stdout as String) as Map<String, dynamic>;
  }
  // Ubuntu CI 使用真正 PDF 解析器，不以文字外觀推論是否存在 link annotation。
  final text = await Process.run('pdftotext', [
    '-enc',
    'UTF-8',
    file.path,
    '-',
  ]);
  expect(text.exitCode, 0, reason: '${text.stderr}');
  final urls = await Process.run('pdfinfo', ['-url', file.path]);
  expect(urls.exitCode, 0, reason: '${urls.stderr}');
  return {
    'pages': (text.stdout as String)
        .split('\f')
        .where((page) => page.trim().isNotEmpty)
        .toList(),
    'links': RegExp(r'^\s*\d+\s+Annotation\s+(.*)$', multiLine: true)
        .allMatches(urls.stdout as String)
        .map((match) => match.group(1)!.trim())
        .toList(),
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PdfBaseCache original;
  setUp(() {
    original = PdfBaseCache.defaultCache;
    PdfBaseCache.defaultCache = _FontCache();
  });
  tearDown(() {
    PdfBaseCache.defaultCache = original;
  });

  test('真實 PDF 保留五區文字與航班艙等', () async {
    final document = await readPdf(
      const TripPrintData(
        trip: Trip(id: 'trip-1', name: '筆記驗收'),
        days: [],
        notes: noteContentFixture,
      ),
      'full',
    );
    final text = (document['pages'] as List).join('\n');
    expect(
      document['links'],
      containsAll([
        'tel:+886912345678',
        'mailto:family@example.com',
        'https://example.com/travel',
      ]),
    );
    var cursor = 0;
    for (final value in noteContentExpectedOrder) {
      final next = text.indexOf(value, cursor);
      expect(next, greaterThanOrEqualTo(0), reason: '缺少或順序錯誤：$value');
      cursor = next + value.length;
    }
    expect(text, isNot(contains('0 位')));
    final empty = await readPdf(
      const TripPrintData(
        trip: Trip(id: 'trip-1', name: '空白筆記驗收'),
        days: [],
        notes: emptyNoteContentFixture,
      ),
      'empty',
    );
    expect((empty['pages'] as List).join('\n'), isNot(contains('行程筆記')));
  });
  test('真實 PDF 的長中文筆記可跨頁且不遺漏尾段', () async {
    final paragraphs = List.generate(
      90,
      (index) => '第${index + 1}段：旅途中請攜帶護照與雨具，確認交通時間並保留緊急聯絡資料。',
    );
    final document = await readPdf(
      TripPrintData(
        trip: const Trip(id: 'trip-1', name: '長中文驗收'),
        days: [],
        notes: TripNotes(
          pretripNotes: [
            TripPretripNote(
              id: 1,
              sortOrder: 0,
              version: 0,
              title: '長篇行前須知',
              content: '${paragraphs.join("\n")}\n最後一段驗收完成',
            ),
          ],
        ),
      ),
      'long',
    );
    final pages = document['pages'] as List;
    expect(pages.length, greaterThan(1));
    final text = pages.join('\n');
    for (final paragraph in paragraphs) {
      expect(text, contains(paragraph));
    }
    expect(pages.last, contains('最後一段驗收完成'));
  });
  test('真實 PDF 的多個具名與參考連結保留文字及真正annotation', () async {
    const content =
        '[入境文件](https://example.com/a_(b)?x=1&y=2) [參考文件][guide] [拒絕帳密](https://user:pass@example.com/private) [](https://example.com/empty) [   ](https://example.com/blank)\n\n[guide]: https://example.com/guide';
    final document = await readPdf(
      const TripPrintData(
        trip: Trip(id: 'trip-1', name: '連結驗收'),
        days: [],
        notes: TripNotes(
          pretripNotes: [
            TripPretripNote(id: 1, sortOrder: 0, version: 0, content: content),
          ],
        ),
      ),
      'named-links',
    );
    final text = (document['pages'] as List).join('\n');
    expect(text, contains('入境文件'));
    expect(text, contains('參考文件'));
    expect(text, contains('拒絕帳密'));
    expect(text, contains('開啟連結'));
    expect(
      document['links'],
      unorderedEquals([
        'https://example.com/a_(b)?x=1&y=2',
        'https://example.com/guide',
        'https://example.com/empty',
        'https://example.com/blank',
      ]),
    );
  });
  test('公開分享的真實 PDF 僅包含授權視圖', () async {
    final document = await readPdf(
      TripPrintData.fromPublicShare(
        const PublicTripShare(name: '公開旅行', notes: publicNoteFixture),
      ),
      'public',
    );
    final text = (document['pages'] as List).join('\n');
    expect(text, contains('PUBLIC-BR112'));
    expect(text, contains('公開提醒'));
    expect(text, isNot(contains('PRIVATE-SECRET-385')));
    expect(text, isNot(contains('緊急聯絡')));
    expect(text, isNot(contains('住宿')));
  });
}
