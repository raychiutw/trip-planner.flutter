import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/cache/cache_store.dart';

void main() {
  late InMemoryCacheStore store;
  setUp(() => store = InMemoryCacheStore());

  test('write 後 read 回 data + cachedAt', () async {
    await store.writeResponse('GET /x', {'a': 1});
    final e = await store.readResponse('GET /x');
    expect(e!.data, {'a': 1});
    expect(e.cachedAt, isA<DateTime>());
  });

  test('miss 回 null', () async {
    expect(await store.readResponse('GET /none'), isNull);
  });

  test('evictByPrefix 只刪命中,不誤刪 id 前綴相同者', () async {
    await store.writeResponse('GET /trips/abc/days?all=1', [1]);
    await store.writeResponse('GET /trips/abc/notes', {'n': 1});
    await store.writeResponse('GET /trips/abcdef/days', [2]);
    await store.evictByPrefix('GET /trips/abc/days');
    expect(await store.readResponse('GET /trips/abc/days?all=1'), isNull);
    expect(await store.readResponse('GET /trips/abc/notes'), isNotNull);
    expect(await store.readResponse('GET /trips/abcdef/days'), isNotNull);
  });

  test('clear 清空', () async {
    await store.writeResponse('GET /x', 1);
    await store.clear();
    expect(await store.readResponse('GET /x'), isNull);
  });
}
