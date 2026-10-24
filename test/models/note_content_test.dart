import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/note_content.dart';
import 'package:tripline/models/notes.dart';

void main() {
  final notes = TripNotes.fromJson({
    'flights': [
      {
        'id': 1,
        'airline': '長榮航空',
        'flightNo': 'BR108',
        'departAirport': 'TPE',
        'arriveAirport': 'OKA',
        'departAt': '2026-11-01T09:00',
        'arriveAt': '2026-11-01T11:30',
      },
    ],
    'lodgings': [
      {
        'id': 2,
        'name': '那霸海濱飯店',
        'checkInAt': '2026-11-01',
        'checkOutAt': '2026-11-03',
      },
    ],
    'reservations': [
      {'id': 3, 'title': '牧志市場燒肉', 'reservedAt': '2026-11-01T19:00'},
    ],
  });

  List<String> texts(String label) => [
    for (final section in projectTripNotes(notes))
      if (section.label == label)
        for (final row in section.rows)
          for (final field in row.details) field.text,
  ];

  test('日期時間不外露 ISO 的 T，改用空格分隔', () {
    expect(texts('航班'), containsAll(['2026-11-01 09:00', '2026-11-01 11:30']));
    expect(texts('預訂'), contains('2026-11-01 19:00'));
    for (final text in [...texts('航班'), ...texts('預訂')]) {
      expect(text, isNot(matches(r'\dT\d')));
    }
  });

  test('住宿的入住與退房日期各自帶標籤，不會變成兩個並排的日期', () {
    expect(texts('住宿'), ['入住 2026-11-01', '退房 2026-11-03']);
  });

  test('語意標籤保留欄位名稱與正規化後的值', () {
    final field = projectTripNotes(notes)
        .firstWhere((s) => s.label == '航班')
        .rows
        .single
        .details
        .firstWhere((f) => f.label == '出發時間');
    expect(field.semanticsLabel, '出發時間：2026-11-01 09:00');
  });
}
