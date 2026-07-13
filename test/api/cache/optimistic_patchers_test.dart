import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/cache/optimistic_patchers.dart';
import 'package:tripline/models/entry.dart';

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

  test('entry.add 樂觀資料用 displayTitle 給 TimelineEntry 顯示', () {
    final out =
        applyOptimisticPatch('entry.add', makeDays(), {
              'dayNum': 1,
              'title': 'New',
              'tempId': -1,
            })
            as List;
    final day1 = out.firstWhere((d) => (d as Map)['dayNum'] == 1) as Map;
    final added = (day1['timeline'] as List).last as Map<String, dynamic>;

    expect(TimelineEntry.fromJson(added).title, 'New');
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

  group('note patchers', () {
    Map<String, Object?> makeNotes() => {
      'flights': [
        {'id': 1, 'airline': 'A'},
      ],
      'lodgings': <dynamic>[],
      'pretripNotes': [
        {'id': 9, 'content': 'old'},
      ],
    };

    test('note.create 在指定段末端插入 + snake→camel', () {
      final out =
          applyOptimisticPatch('note.create', makeNotes(), {
                'sectionKey': 'flights',
                'fields': {'airline': 'B', 'flight_no': 'IT5'},
                'tempId': -1,
              })
              as Map;
      final flights = out['flights'] as List;
      expect(flights, hasLength(2));
      expect((flights.last as Map)['flightNo'], 'IT5'); // snake→camel
      expect((flights.last as Map)['id'], -1);
    });

    test('note.update merge 欄位', () {
      final out =
          applyOptimisticPatch('note.update', makeNotes(), {
                'sectionKey': 'pretripNotes',
                'rowId': 9,
                'fields': {'content': 'new'},
              })
              as Map;
      expect(((out['pretripNotes'] as List).first as Map)['content'], 'new');
    });

    test('note.delete 移除指定 row', () {
      final out =
          applyOptimisticPatch('note.delete', makeNotes(), {
                'sectionKey': 'flights',
                'rowId': 1,
              })
              as Map;
      expect(out['flights'] as List, isEmpty);
    });

    test('note.create 段不存在 → 建新段', () {
      final out =
          applyOptimisticPatch(
                'note.create',
                {'flights': <dynamic>[]},
                {
                  'sectionKey': 'emergencyContacts',
                  'fields': {'name': 'X'},
                  'tempId': -2,
                },
              )
              as Map;
      expect(out['emergencyContacts'] as List, hasLength(1));
    });

    test('note.create 不就地改原 cached', () {
      final original = makeNotes();
      applyOptimisticPatch('note.create', original, {
        'sectionKey': 'flights',
        'fields': {'airline': 'Z'},
        'tempId': -1,
      });
      expect(original['flights'] as List, hasLength(1));
    });
  });
}
