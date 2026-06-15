import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/cache/rebase_merge.dart';

void main() {
  group('rebaseMerge', () {
    test('server 沒動該欄(theirs==base)→ 無衝突', () {
      expect(rebaseMerge({'title': 'A'}, {'title': 'B'}, {'title': 'A'}), isEmpty);
    });
    test('離線與 server 同值(ours==theirs)→ 無衝突', () {
      expect(rebaseMerge({'title': 'A'}, {'title': 'B'}, {'title': 'B'}), isEmpty);
    });
    test('三方不同 → 衝突欄位', () {
      expect(rebaseMerge({'title': 'A'}, {'title': 'B'}, {'title': 'C'}), ['title']);
    });
    test('多欄位混合 → 只回衝突欄位', () {
      final r = rebaseMerge(
        {'title': 'A', 'description': 'x'},
        {'title': 'B', 'description': 'y'},
        {'title': 'A', 'description': 'z'},
      );
      expect(r, ['description']);
    });
    test('base==null → 無衝突(降級 last-write-wins)', () {
      expect(rebaseMerge(null, {'title': 'B'}, {'title': 'C'}), isEmpty);
    });
    test('[C1] int vs double 同值 → 不誤判衝突', () {
      expect(rebaseMerge({'min': 5}, {'min': 7}, {'min': 5.0}), isEmpty);
    });
  });

  group('extractEntryFields', () {
    final days = [
      {'dayNum': 1, 'timeline': [
        {'id': 7, 'title': '舊標題', 'description': 'd', 'startTime': '09:00',
         'endTime': '10:00', 'version': 3},
      ]},
    ];
    test('找到 entry → 取指定欄位 + version(camelCase)', () {
      final r = extractEntryFields(days, 7, ['title', 'startTime']);
      expect(r, {'title': '舊標題', 'startTime': '09:00', 'version': 3});
    });
    test('找不到 entry → null', () {
      expect(extractEntryFields(days, 999, ['title']), isNull);
    });
    test('cached 非 List → null', () {
      expect(extractEntryFields(null, 7, ['title']), isNull);
    });
  });

  group('extractNoteFields', () {
    final notes = {
      'pretripNotes': [
        {'id': 5, 'content': '舊內容', 'version': 2},
      ],
    };
    test('找到 note row → 取欄位 + version', () {
      final r = extractNoteFields(notes, 'pretripNotes', 5, ['content']);
      expect(r, {'content': '舊內容', 'version': 2});
    });
    test('段不存在 → null', () {
      expect(extractNoteFields(notes, 'flights', 5, ['content']), isNull);
    });
  });
}
