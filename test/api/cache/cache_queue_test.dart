import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/cache/cache_store.dart';

QueuedMutation _m(String id) => QueuedMutation(
  id: id,
  method: 'POST',
  path: '/p',
  type: 'entry.add',
  cacheKey: 'GET /k',
  args: const {'a': 1},
  createdAt: '2026-01-01',
);

void main() {
  late InMemoryCacheStore store;
  setUp(() => store = InMemoryCacheStore());

  test('append → readQueue 保插入序', () async {
    await store.appendMutation(_m('1'));
    await store.appendMutation(_m('2'));
    final q = await store.readQueue();
    expect(q.map((m) => m.id), ['1', '2']);
  });

  test('removeMutation 依 id 移除', () async {
    await store.appendMutation(_m('1'));
    await store.appendMutation(_m('2'));
    await store.removeMutation('1');
    expect((await store.readQueue()).map((m) => m.id), ['2']);
  });

  test('toMap/fromMap round-trip', () {
    final m = QueuedMutation(
      id: 'x',
      method: 'PATCH',
      path: '/p',
      query: const {'q': '1'},
      body: const {'b': 2},
      type: 'entry.update',
      cacheKey: 'GET /k',
      args: const {'entryId': 5},
      createdAt: 't',
    );
    final back = QueuedMutation.fromMap(m.toMap());
    expect(back.id, 'x');
    expect(back.method, 'PATCH');
    expect(back.body, {'b': 2});
    expect(back.args, {'entryId': 5});
    expect(back.query, {'q': '1'});
  });

  test('clear 一併清佇列與回應快取', () async {
    await store.writeResponse('GET /k', [1]);
    await store.appendMutation(_m('1'));
    await store.clear();
    expect(await store.readResponse('GET /k'), isNull);
    expect(await store.readQueue(), isEmpty);
  });
}
