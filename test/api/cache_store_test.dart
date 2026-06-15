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
}
