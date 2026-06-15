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
}
