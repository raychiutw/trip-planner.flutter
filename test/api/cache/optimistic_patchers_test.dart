import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/cache/optimistic_patchers.dart';

void main() {
  // 每個測試用新鮮 days(確認 patcher 不就地改)。
  List<Object?> makeDays() => [
    {
      'dayNum': 1,
      'timeline': [
        {'id': 101, 'title': 'A'},
      ],
    },
    {
      'dayNum': 2,
      'timeline': [
        {'id': 201, 'title': 'B'},
      ],
    },
  ];

  test('entry.add 插入到指定 day 末端,其他 day 不變', () {
    final out =
        applyOptimisticPatch('entry.add', makeDays(), {
              'dayNum': 1,
              'title': 'New',
              'tempId': -1,
            })
            as List;
    final day1 = out.firstWhere((d) => (d as Map)['dayNum'] == 1) as Map;
    expect((day1['timeline'] as List).map((e) => (e as Map)['title']), [
      'A',
      'New',
    ]);
    final day2 = out.firstWhere((d) => (d as Map)['dayNum'] == 2) as Map;
    expect(day2['timeline'] as List, hasLength(1));
  });

  test('entry.add 帶 lat/lng → 建 master', () {
    final out =
        applyOptimisticPatch('entry.add', makeDays(), {
              'dayNum': 1,
              'title': 'POI',
              'lat': 26.2,
              'lng': 127.6,
              'poiType': 'attraction',
              'tempId': -2,
            })
            as List;
    final added = ((out[0] as Map)['timeline'] as List).last as Map;
    expect((added['master'] as Map)['name'], 'POI');
    expect((added['master'] as Map)['lat'], 26.2);
  });

  test('entry.add 不就地改原 cached', () {
    final original = makeDays();
    applyOptimisticPatch('entry.add', original, {
      'dayNum': 1,
      'title': 'X',
      'tempId': -1,
    });
    expect(((original[0] as Map)['timeline'] as List), hasLength(1));
  });

  test('entry.update 改對 entry 欄位', () {
    final out =
        applyOptimisticPatch('entry.update', makeDays(), {
              'entryId': 201,
              'title': 'B2',
            })
            as List;
    final e = ((out[1] as Map)['timeline'] as List).first as Map;
    expect(e['title'], 'B2');
  });

  test('entry.delete 移除指定 entry', () {
    final out =
        applyOptimisticPatch('entry.delete', makeDays(), {'entryId': 101})
            as List;
    expect((out[0] as Map)['timeline'] as List, isEmpty);
    expect((out[1] as Map)['timeline'] as List, hasLength(1));
  });

  test('base 為 null → 回 null(無從 patch,mutation 仍會入佇列)', () {
    expect(applyOptimisticPatch('entry.add', null, {'dayNum': 1}), isNull);
  });

  test('未知 type → 回原值', () {
    final days = makeDays();
    expect(applyOptimisticPatch('unknown', days, const {}), same(days));
  });

  test('找不到 dayNum → 不爆、timeline 不變', () {
    final out =
        applyOptimisticPatch('entry.add', makeDays(), {
              'dayNum': 99,
              'title': 'X',
              'tempId': -1,
            })
            as List;
    expect((out[0] as Map)['timeline'] as List, hasLength(1));
    expect((out[1] as Map)['timeline'] as List, hasLength(1));
  });
}
