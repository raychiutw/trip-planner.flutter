import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/cache/cache_keys.dart';
import 'package:tripline/api/cache/cache_store.dart';
import 'package:tripline/api/session_store.dart';

/// 依「method + path」路由、同一路由可序列回放(每次呼叫吐下一筆,最後一筆 sticky)
/// 的假 adapter。flush rebase 需要:PATCH 先 409 再 200、其間插一個 GET /days,
/// 且要對 GET 計數(驗 P1 去重)— http_mock_adapter 的單一 handler 無法序列回放,
/// 故自製。連線錯誤以丟出的 DioException 表示。
class RoutingSequencedAdapter implements HttpClientAdapter {
  RoutingSequencedAdapter();

  /// key = 'METHOD path' → 該路由的回應腳本(依序消費)。
  final Map<String, List<Scripted>> _routes = {};

  /// key = 'METHOD path' → 已收到幾次 request。
  final Map<String, int> callCounts = {};

  /// 全部請求(依時序),供斷言 body / 順序。
  final List<RequestOptions> recorded = [];

  void on(String method, String path, List<Scripted> script) {
    _routes['$method $path'] = script;
  }

  int countOf(String method, String path) => callCounts['$method $path'] ?? 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    recorded.add(options);
    final key = '${options.method} ${options.path}';
    final n = (callCounts[key] ?? 0);
    callCounts[key] = n + 1;
    final script = _routes[key];
    if (script == null || script.isEmpty) {
      return ResponseBody.fromString(
        jsonEncode({
          'error': {'code': 'TEST_NO_ROUTE', 'message': 'no route for $key'},
        }),
        404,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    final scripted = script[n.clamp(0, script.length - 1)];
    if (scripted.throwOffline) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    return ResponseBody.fromString(
      jsonEncode(scripted.body),
      scripted.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class Scripted {
  const Scripted.json(this.status, this.body) : throwOffline = false;
  const Scripted.offline() : status = 0, body = null, throwOffline = true;
  final int status;
  final Object? body;
  final bool throwOffline;
}

void main() {
  late RoutingSequencedAdapter adapter;
  late InMemoryCacheStore cache;
  late ApiClient client;

  setUp(() {
    final dio = Dio(BaseOptions())..options.validateStatus = (_) => true;
    adapter = RoutingSequencedAdapter();
    dio.httpClientAdapter = adapter;
    cache = InMemoryCacheStore();
    client = ApiClient(
      sessionStore: InMemorySessionStore(),
      dio: dio,
      cacheStore: cache,
    );
  });

  final daysKey = cacheKeyFor('GET', '/trips/t/days', {'all': '1'});

  // entry.update 的離線佇列建構:base = 舊值、body 帶 expectedVersion。
  QueuedMutation entryUpdateMut({
    required String id,
    required int entryId,
    required String oursTitle,
    required String baseTitle,
    required int expectedVersion,
    String path = '/trips/t/entries/5',
  }) => QueuedMutation(
    id: id,
    method: 'PATCH',
    path: path,
    body: {
      'title': oursTitle,
      'description': null,
      'start_time': null,
      'end_time': null,
      'expectedVersion': expectedVersion,
    },
    type: 'entry.update',
    cacheKey: daysKey,
    args: {
      'entryId': entryId,
      'title': oursTitle,
      'description': null,
      'startTime': null,
      'endTime': null,
    },
    createdAt: 't',
    base: {
      'title': baseTitle,
      'description': null,
      'startTime': null,
      'endTime': null,
    },
  );

  // days?all=1 回應:單一 day、單筆 entry,帶 version 與 title。
  Object daysWithEntry({
    required int entryId,
    required String title,
    required int version,
  }) => [
    {
      'dayNum': 1,
      'timeline': [
        {
          'id': entryId,
          'title': title,
          'description': null,
          'startTime': null,
          'endTime': null,
          'version': version,
        },
      ],
    },
  ];

  final notesKey = cacheKeyFor('GET', '/trips/t/notes');

  // note.update 的離線佇列建構:fields 為 snake_case(對齊 repository)。
  QueuedMutation noteUpdateMut({
    required String id,
    required int rowId,
    required String sectionKey,
    required Map<String, dynamic> oursFields,
    required Map<String, dynamic> baseFields,
    required int expectedVersion,
    String path = '/trips/t/notes/flights/9',
  }) => QueuedMutation(
    id: id,
    method: 'PATCH',
    path: path,
    body: {...oursFields, 'expectedVersion': expectedVersion},
    type: 'note.update',
    cacheKey: notesKey,
    args: {'sectionKey': sectionKey, 'rowId': rowId, 'fields': oursFields},
    createdAt: 't',
    // base 以 camelCase 鍵存(對齊 sendMutation 的 extractNoteFields 取法)。
    base: baseFields,
  );

  Map<String, dynamic> bodyOf(RequestOptions o) =>
      (o.data as Map).cast<String, dynamic>();

  test(
    '1. STALE 無衝突 → 重抓 + 重送(帶新 version)+ remove + synced',
    () async {
      await cache.appendMutation(
        entryUpdateMut(
          id: '1',
          entryId: 5,
          oursTitle: '我改的新標題',
          baseTitle: '舊標題',
          expectedVersion: 3,
        ),
      );
      // PATCH:第一次 409 STALE,第二次 200。
      adapter.on('PATCH', '/trips/t/entries/5', [
        const Scripted.json(409, {
          'error': {'code': 'STALE_ENTRY', 'message': 'stale'},
        }),
        const Scripted.json(200, {'ok': true}),
      ]);
      // 重抓:server title 仍是舊標題(沒人動 title),只是 version 進到 5。
      adapter.on('GET', '/trips/t/days', [
        Scripted.json(200, daysWithEntry(entryId: 5, title: '舊標題', version: 5)),
      ]);

      final r = await client.flushQueue();

      expect(r.synced, 1);
      expect(r.conflicts, isEmpty);
      expect(await cache.readQueue(), isEmpty);
      expect(await cache.readConflicts(), isEmpty);
      // 第二次 PATCH 的 expectedVersion 應被改為重抓到的 5。
      final patches = adapter.recorded
          .where((o) => o.method == 'PATCH')
          .toList();
      expect(patches, hasLength(2));
      expect(bodyOf(patches[1])['expectedVersion'], 5);
      // 重送仍保留 ours 的 title。
      expect(bodyOf(patches[1])['title'], '我改的新標題');
    },
  );

  test('2. STALE 有衝突 → appendConflict、不重送、移出主佇列、上報', () async {
    await cache.appendMutation(
      entryUpdateMut(
        id: '1',
        entryId: 5,
        oursTitle: '我改的標題',
        baseTitle: '舊標題',
        expectedVersion: 3,
      ),
    );
    adapter.on('PATCH', '/trips/t/entries/5', [
      const Scripted.json(409, {
        'error': {'code': 'STALE_ENTRY', 'message': 'stale'},
      }),
      // 若誤重送,讓它成功以凸顯「不該被呼叫」。
      const Scripted.json(200, {'ok': true}),
    ]);
    // 重抓:server title 是「他人改的不同值」→ base/ours/theirs 三方衝突。
    adapter.on('GET', '/trips/t/days', [
      Scripted.json(200, daysWithEntry(entryId: 5, title: '他人改的標題', version: 7)),
    ]);

    final r = await client.flushQueue();

    expect(r.synced, 0);
    expect(r.conflicts.map((m) => m.id), ['1']);
    expect(await cache.readQueue(), isEmpty);
    final conflicts = await cache.readConflicts();
    expect(conflicts, hasLength(1));
    expect(conflicts.single.conflictFields, ['title']);
    expect(conflicts.single.newVersion, 7);
    expect(conflicts.single.ours['title'], '我改的標題');
    expect(conflicts.single.theirs['title'], '他人改的標題');
    // 只打過一次 PATCH(沒有重送)。
    expect(adapter.countOf('PATCH', '/trips/t/entries/5'), 1);
  });

  test('3. 重抓時連線錯誤 → break 保留佇列、synced 0', () async {
    await cache.appendMutation(
      entryUpdateMut(
        id: '1',
        entryId: 5,
        oursTitle: '我改的標題',
        baseTitle: '舊標題',
        expectedVersion: 3,
      ),
    );
    adapter.on('PATCH', '/trips/t/entries/5', [
      const Scripted.json(409, {
        'error': {'code': 'STALE_ENTRY', 'message': 'stale'},
      }),
    ]);
    // 重抓連線錯誤。
    adapter.on('GET', '/trips/t/days', [const Scripted.offline()]);

    final r = await client.flushQueue();

    expect(r.synced, 0);
    expect(r.conflicts, isEmpty);
    expect((await cache.readQueue()).map((m) => m.id), ['1']);
    expect(await cache.readConflicts(), isEmpty);
  });

  test('4. 重送再 409 → break 保留待下次', () async {
    await cache.appendMutation(
      entryUpdateMut(
        id: '1',
        entryId: 5,
        oursTitle: '我改的新標題',
        baseTitle: '舊標題',
        expectedVersion: 3,
      ),
    );
    // PATCH 兩次都 409(重抓無衝突後重送又撞上更新的 version)。
    adapter.on('PATCH', '/trips/t/entries/5', [
      const Scripted.json(409, {
        'error': {'code': 'STALE_ENTRY', 'message': 'stale'},
      }),
    ]);
    // 重抓:title 沒動 → 無衝突,可重送。
    adapter.on('GET', '/trips/t/days', [
      Scripted.json(200, daysWithEntry(entryId: 5, title: '舊標題', version: 5)),
    ]);

    final r = await client.flushQueue();

    expect(r.synced, 0);
    expect(r.conflicts, isEmpty);
    expect((await cache.readQueue()).map((m) => m.id), ['1']);
    expect(await cache.readConflicts(), isEmpty);
    // 兩次 PATCH 都發生了(第一次直送、第二次重送)。
    expect(adapter.countOf('PATCH', '/trips/t/entries/5'), 2);
  });

  test('5. 非 STALE 的 409(type 非 rebasable)→ 維持上報 + drop(回歸)', () async {
    // entry.add 不在 rebasable 集合,即使 code 是 STALE_ENTRY 也走舊行為。
    await cache.appendMutation(
      QueuedMutation(
        id: '1',
        method: 'POST',
        path: '/trips/t/days/1/entries',
        body: const {'title': 'x'},
        type: 'entry.add',
        cacheKey: daysKey,
        args: const {'dayNum': 1},
        createdAt: 't',
      ),
    );
    adapter.on('POST', '/trips/t/days/1/entries', [
      const Scripted.json(409, {
        'error': {'code': 'STALE_ENTRY', 'message': 'stale'},
      }),
    ]);

    final r = await client.flushQueue();

    expect(r.synced, 0);
    expect(r.conflicts.map((m) => m.id), ['1']);
    expect(await cache.readQueue(), isEmpty); // 上報並移除
    expect(await cache.readConflicts(), isEmpty); // 走舊路徑、不入 conflict store
    // 沒有任何重抓(沒打 GET /days)。
    expect(adapter.countOf('GET', '/trips/t/days'), 0);
  });

  test('5b. STALE 但 code 非 STALE_ENTRY 的 409 → 維持上報 + drop(回歸)', () async {
    // type 可 rebasable(entry.update),但 code 不是 STALE_ENTRY → 不 rebase。
    await cache.appendMutation(
      entryUpdateMut(
        id: '1',
        entryId: 5,
        oursTitle: '我改的標題',
        baseTitle: '舊標題',
        expectedVersion: 3,
      ),
    );
    adapter.on('PATCH', '/trips/t/entries/5', [
      const Scripted.json(409, {
        'error': {'code': 'SOME_OTHER_CONFLICT', 'message': 'nope'},
      }),
    ]);

    final r = await client.flushQueue();

    expect(r.synced, 0);
    expect(r.conflicts.map((m) => m.id), ['1']);
    expect(await cache.readQueue(), isEmpty);
    expect(await cache.readConflicts(), isEmpty);
    expect(adapter.countOf('GET', '/trips/t/days'), 0);
  });

  test('6. [P1] 同 trip 多筆 STALE → 整包 days GET 只打一次', () async {
    await cache.appendMutation(
      entryUpdateMut(
        id: '1',
        entryId: 5,
        oursTitle: 'A 新',
        baseTitle: 'A 舊',
        expectedVersion: 3,
        path: '/trips/t/entries/5',
      ),
    );
    await cache.appendMutation(
      entryUpdateMut(
        id: '2',
        entryId: 6,
        oursTitle: 'B 新',
        baseTitle: 'B 舊',
        expectedVersion: 3,
        path: '/trips/t/entries/6',
      ),
    );
    adapter.on('PATCH', '/trips/t/entries/5', [
      const Scripted.json(409, {
        'error': {'code': 'STALE_ENTRY', 'message': 'stale'},
      }),
      const Scripted.json(200, {'ok': true}),
    ]);
    adapter.on('PATCH', '/trips/t/entries/6', [
      const Scripted.json(409, {
        'error': {'code': 'STALE_ENTRY', 'message': 'stale'},
      }),
      const Scripted.json(200, {'ok': true}),
    ]);
    // 一份 days 同時含兩筆 entry,各自沒被他人動 title → 皆可 rebase 重送。
    adapter.on('GET', '/trips/t/days', [
      Scripted.json(200, [
        {
          'dayNum': 1,
          'timeline': [
            {
              'id': 5,
              'title': 'A 舊',
              'description': null,
              'startTime': null,
              'endTime': null,
              'version': 9,
            },
            {
              'id': 6,
              'title': 'B 舊',
              'description': null,
              'startTime': null,
              'endTime': null,
              'version': 11,
            },
          ],
        },
      ]),
    ]);

    final r = await client.flushQueue();

    expect(r.synced, 2);
    expect(r.conflicts, isEmpty);
    expect(await cache.readQueue(), isEmpty);
    // 關鍵:重抓整包 days 只發一次(P1 去重)。
    expect(adapter.countOf('GET', '/trips/t/days'), 1);
    // 兩筆各自的重送都帶到對應的新 version。
    final patch5 = adapter.recorded.lastWhere(
      (o) => o.path == '/trips/t/entries/5',
    );
    final patch6 = adapter.recorded.lastWhere(
      (o) => o.path == '/trips/t/entries/6',
    );
    expect(bodyOf(patch5)['expectedVersion'], 9);
    expect(bodyOf(patch6)['expectedVersion'], 11);
  });

  test('7. note.update STALE 無衝突 → 重抓 notes + 重送(snake→camel 欄位對齊)', () async {
    await cache.appendMutation(
      noteUpdateMut(
        id: '1',
        rowId: 9,
        sectionKey: 'flights',
        // fields 用 snake_case(repository 慣例),且含一個多字底線欄。
        oursFields: const {'note': '我改的備註', 'flight_no': 'JL123'},
        baseFields: const {'note': '舊備註', 'flightNo': 'JL123'},
        expectedVersion: 2,
      ),
    );
    adapter.on('PATCH', '/trips/t/notes/flights/9', [
      const Scripted.json(409, {
        'error': {'code': 'STALE_ENTRY', 'message': 'stale'},
      }),
      const Scripted.json(200, {'ok': true}),
    ]);
    // 重抓 notes:flights 段內 row 9,note/flightNo 未被他人動,version 進到 4。
    adapter.on('GET', '/trips/t/notes', [
      const Scripted.json(200, {
        'flights': [
          {'id': 9, 'note': '舊備註', 'flightNo': 'JL123', 'version': 4},
        ],
        'lodgings': [],
      }),
    ]);

    final r = await client.flushQueue();

    expect(r.synced, 1);
    expect(r.conflicts, isEmpty);
    expect(await cache.readQueue(), isEmpty);
    expect(await cache.readConflicts(), isEmpty);
    expect(adapter.countOf('GET', '/trips/t/notes'), 1);
    final patches = adapter.recorded
        .where((o) => o.method == 'PATCH')
        .toList();
    expect(patches, hasLength(2));
    // 重送帶新 version,且保留 ours 的 snake_case body 欄位。
    expect(bodyOf(patches[1])['expectedVersion'], 4);
    expect(bodyOf(patches[1])['note'], '我改的備註');
    expect(bodyOf(patches[1])['flight_no'], 'JL123');
  });
}
