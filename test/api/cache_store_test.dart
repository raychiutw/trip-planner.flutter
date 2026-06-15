import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/cache/cache_store.dart';

void main() {
  group('QueuedMutation base 序列化', () {
    test('toMap/fromMap round-trip 保留 base', () {
      const m = QueuedMutation(
        id: '1', method: 'PATCH', path: '/x', type: 'entry.update',
        cacheKey: 'k', args: {}, createdAt: 't',
        base: {'title': '舊'},
      );
      final back = QueuedMutation.fromMap(m.toMap());
      expect(back.base, {'title': '舊'});
    });
    test('舊資料缺 base → null(降級不崩)', () {
      final back = QueuedMutation.fromMap(const {
        'id': '1', 'method': 'PATCH', 'path': '/x', 'type': 'entry.update',
        'cacheKey': 'k', 'args': <String, dynamic>{}, 'createdAt': 't',
      });
      expect(back.base, isNull);
    });
  });

  group('InMemoryCacheStore conflict store', () {
    ConflictRecord rec(String id) => ConflictRecord(
      id: id, type: 'entry.update', path: '/trips/t/entries/7',
      body: const {'title': 'B'}, args: const {'entryId': 7},
      cacheKey: 'k', ours: const {'title': 'B'}, theirs: const {'title': 'C'},
      newVersion: 5, conflictFields: const ['title'], createdAt: 't',
    );
    test('append → read 回該筆;remove 後消失', () async {
      final s = InMemoryCacheStore();
      await s.appendConflict(rec('a'));
      expect((await s.readConflicts()).map((c) => c.id), ['a']);
      await s.removeConflict('a');
      expect(await s.readConflicts(), isEmpty);
    });
    test('append/remove 觸發 changes', () async {
      final s = InMemoryCacheStore();
      final seen = <void>[];
      final sub = s.changes.listen(seen.add);
      await s.appendConflict(rec('a'));
      await s.removeConflict('a');
      await Future<void>.delayed(Duration.zero);
      expect(seen.length, 2);
      await sub.cancel();
    });
    test('clear 一併清 conflict store', () async {
      final s = InMemoryCacheStore();
      await s.appendConflict(rec('a'));
      await s.clear();
      expect(await s.readConflicts(), isEmpty);
    });
    test('ConflictRecord toMap/fromMap round-trip', () {
      final back = ConflictRecord.fromMap(rec('a').toMap());
      expect(back.id, 'a');
      expect(back.conflictFields, ['title']);
      expect(back.newVersion, 5);
    });
  });
}
