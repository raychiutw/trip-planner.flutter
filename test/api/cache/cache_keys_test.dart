import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/cache/cache_keys.dart';

void main() {
  group('cacheKeyFor', () {
    test('無 query', () {
      expect(cacheKeyFor('GET', '/my-trips'), 'GET /my-trips');
    });
    test('query 依 key 排序穩定', () {
      final a = cacheKeyFor('GET', '/x', {'b': '2', 'a': '1'});
      final b = cacheKeyFor('GET', '/x', {'a': '1', 'b': '2'});
      expect(a, b);
      expect(a, 'GET /x?a=1&b=2');
    });
  });

  group('cacheKeyMatchesPrefix', () {
    test('完全相等 / 子路徑 / query 邊界都命中', () {
      expect(cacheKeyMatchesPrefix('GET /trips/abc', 'GET /trips/abc'), isTrue);
      expect(
        cacheKeyMatchesPrefix('GET /trips/abc/days', 'GET /trips/abc'),
        isTrue,
      );
      expect(
        cacheKeyMatchesPrefix('GET /trips/abc?x=1', 'GET /trips/abc'),
        isTrue,
      );
      expect(
        cacheKeyMatchesPrefix(
          'GET /trips/abc/days?all=1',
          'GET /trips/abc/days',
        ),
        isTrue,
      );
    });
    test('id 前綴相同但不同 trip 不誤刪', () {
      expect(
        cacheKeyMatchesPrefix('GET /trips/abcdef/days', 'GET /trips/abc'),
        isFalse,
      );
    });
  });

  group('evictionPrefixesFor', () {
    test('GET 不失效任何快取', () {
      expect(evictionPrefixesFor('GET', '/trips/t/days'), isEmpty);
    });
    test('entries mutation → days/segments/entries', () {
      final p = evictionPrefixesFor('PATCH', '/trips/t/entries/5');
      expect(
        p,
        containsAll(<String>[
          'GET /trips/t/days',
          'GET /trips/t/segments',
          'GET /trips/t/entries',
        ]),
      );
    });
    test('notes mutation → notes', () {
      expect(
        evictionPrefixesFor('POST', '/trips/t/notes/flights'),
        contains('GET /trips/t/notes'),
      );
    });
    test('segments mutation → segments + days', () {
      final p = evictionPrefixesFor('PATCH', '/trips/t/segments/9');
      expect(
        p,
        containsAll(<String>['GET /trips/t/segments', 'GET /trips/t/days']),
      );
    });
    test('trip 編輯/刪除 → trip + 清單', () {
      final p = evictionPrefixesFor('PUT', '/trips/t');
      expect(
        p,
        containsAll(<String>['GET /trips/t', 'GET /my-trips', 'GET /trips']),
      );
    });
    test('建立 trip → 清單', () {
      expect(
        evictionPrefixesFor('POST', '/trips'),
        containsAll(<String>['GET /my-trips', 'GET /trips']),
      );
    });
    test('favorites → poi-favorites', () {
      expect(
        evictionPrefixesFor('POST', '/poi-favorites'),
        contains('GET /poi-favorites'),
      );
    });
    test('add-to-trip(body 帶 tripId)→ poi-favorites + 目標 trip days', () {
      final p = evictionPrefixesFor('POST', '/poi-favorites/42/add-to-trip', {
        'tripId': 't',
      });
      expect(
        p,
        containsAll(<String>['GET /poi-favorites', 'GET /trips/t/days']),
      );
    });
  });
}
