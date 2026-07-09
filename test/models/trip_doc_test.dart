import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/trip_doc.dart';

void main() {
  test('TripDocs.fromJson：batch docs 缺漏 type 解析為 null', () {
    final docs = TripDocs.fromJson({
      'docs': {
        'flights': {
          'doc_type': 'flights',
          'title': '航班',
          'updated_at': '2026-07-09T01:00:00Z',
          'entries': [
            {
              'id': 1,
              'sort_order': 0,
              'section': '去程',
              'title': 'BR112',
              'content': 'TPE -> OKA',
            },
          ],
        },
        'checklist': null,
        'backup': null,
        'suggestions': null,
        'emergency': null,
      },
    });

    final flights = docs[TripDocType.flights]!;
    expect(flights.type, TripDocType.flights);
    expect(flights.title, '航班');
    expect(flights.updatedAt, '2026-07-09T01:00:00Z');
    expect(flights.entries.single.id, 1);
    expect(flights.entries.single.sortOrder, 0);
    expect(docs[TripDocType.checklist], isNull);
  });

  test('TripDocEntry.toJson：PUT body 使用 server snake_case sort_order', () {
    final entry = const TripDocEntry(
      id: 9,
      sortOrder: 3,
      section: '備用',
      title: '保險',
      content: '保單號碼',
    );

    expect(entry.toJson(), {
      'sort_order': 3,
      'section': '備用',
      'title': '保險',
      'content': '保單號碼',
    });
  });

  test('parseTripDocType：無效 type 丟 FormatException', () {
    expect(() => parseTripDocType('lodgings'), throwsA(isA<FormatException>()));
  });
}
