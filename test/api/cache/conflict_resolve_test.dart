import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/cache/cache_keys.dart';
import 'package:tripline/api/cache/cache_store.dart';
import 'package:tripline/api/session_store.dart';

/// 同 flush_rebase_test.dart 的 RoutingSequencedAdapter(複用型別太瑣碎,直接內嵌)。
class RoutingSequencedAdapter implements HttpClientAdapter {
  final Map<String, List<Scripted>> _routes = {};
  final Map<String, int> callCounts = {};
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
    final n = callCounts[key] ?? 0;
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

  /// 建構一筆 entry.update 的 ConflictRecord。
  ConflictRecord entryConflict({
    required String id,
    required int entryId,
    required String oursTitle,
    required String theirsTitle,
    required int newVersion,
    String path = '/trips/t/entries/5',
  }) => ConflictRecord(
    id: id,
    type: 'entry.update',
    path: path,
    body: {
      'title': oursTitle,
      'description': null,
      'start_time': null,
      'end_time': null,
      'expectedVersion': newVersion - 1,
    },
    args: {
      'entryId': entryId,
      'title': oursTitle,
      'description': null,
      'startTime': null,
      'endTime': null,
    },
    cacheKey: daysKey,
    ours: {
      'title': oursTitle,
      'description': null,
      'startTime': null,
      'endTime': null,
    },
    theirs: {
      'title': theirsTitle,
      'description': null,
      'startTime': null,
      'endTime': null,
    },
    newVersion: newVersion,
    conflictFields: ['title'],
    createdAt: 't',
  );

  /// days?all=1 回應:單一 day、單筆 entry。
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

  Map<String, dynamic> bodyOf(RequestOptions o) =>
      (o.data as Map).cast<String, dynamic>();

  // ─────────────────────────────────────────────
  // resolveConflictKeepOurs
  // ─────────────────────────────────────────────

  test(
    '1. resolveKeepOurs 重送成功 → removeConflict(conflict store 清空)',
    () async {
      final c = entryConflict(
        id: 'c1',
        entryId: 5,
        oursTitle: '我改的標題',
        theirsTitle: '他人改的標題',
        newVersion: 7,
      );
      await cache.appendConflict(c);

      // PATCH 帶新 expectedVersion → 200 成功。
      adapter.on('PATCH', '/trips/t/entries/5', [
        const Scripted.json(200, {'ok': true}),
      ]);

      await client.resolveConflictKeepOurs(c);

      expect(await cache.readConflicts(), isEmpty);
      // 確認送出的 PATCH 帶正確 expectedVersion(= newVersion)。
      final patch = adapter.recorded.single;
      expect(patch.method, 'PATCH');
      expect(bodyOf(patch)['expectedVersion'], 7);
      expect(bodyOf(patch)['title'], '我改的標題');
    },
  );

  test(
    '[A3] resolveKeepOurs 重送離線 → 衝突留存 + 方法 throw',
    () async {
      final c = entryConflict(
        id: 'c1',
        entryId: 5,
        oursTitle: '我改的標題',
        theirsTitle: '他人改的標題',
        newVersion: 7,
      );
      await cache.appendConflict(c);

      // PATCH 連線錯誤(模擬離線)。
      adapter.on('PATCH', '/trips/t/entries/5', [const Scripted.offline()]);

      // 方法應拋出 DioException。
      await expectLater(
        () => client.resolveConflictKeepOurs(c),
        throwsA(isA<DioException>()),
      );

      // 衝突仍在 store(未被移除)。
      final remaining = await cache.readConflicts();
      expect(remaining, hasLength(1));
      expect(remaining.single.id, 'c1');
    },
  );

  test(
    '[A3] resolveKeepOurs 重送再 409 STALE → 重新 rebase:無衝突 → synced + conflict 清空',
    () async {
      // 衝突:ours title = '我改的標題',theirs = '他人改的標題',newVersion = 7。
      // 重送 PATCH 用 expectedVersion=7 → 又回 409 STALE_ENTRY。
      // _tryRebase 重抓 GET /days:server 此刻 title = '我改的標題'(與 ours 相同)
      // → 三方 merge 無衝突(base 以 ours 為基準)→ 自動 synced。
      final c = ConflictRecord(
        id: 'c1',
        type: 'entry.update',
        path: '/trips/t/entries/5',
        body: {
          'title': '我改的標題',
          'description': null,
          'start_time': null,
          'end_time': null,
          'expectedVersion': 6,
        },
        args: {
          'entryId': 5,
          'title': '我改的標題',
          'description': null,
          'startTime': null,
          'endTime': null,
        },
        cacheKey: daysKey,
        ours: {
          'title': '我改的標題',
          'description': null,
          'startTime': null,
          'endTime': null,
        },
        theirs: {
          'title': '他人改的標題',
          'description': null,
          'startTime': null,
          'endTime': null,
        },
        newVersion: 7,
        conflictFields: ['title'],
        createdAt: 't',
      );
      await cache.appendConflict(c);

      // 第一次 PATCH(resolve 重送)→ 409 STALE_ENTRY。
      // 第二次 PATCH(_tryRebase 重送)→ 200 成功。
      adapter.on('PATCH', '/trips/t/entries/5', [
        const Scripted.json(409, {
          'error': {'code': 'STALE_ENTRY', 'message': 'stale'},
        }),
        const Scripted.json(200, {'ok': true}),
      ]);

      // _tryRebase 重抓 GET /days:server title = '我改的標題'(與 ours 相同)→ 無衝突。
      // version 進到 9,供重送帶新 expectedVersion。
      adapter.on('GET', '/trips/t/days', [
        Scripted.json(
          200,
          daysWithEntry(entryId: 5, title: '我改的標題', version: 9),
        ),
      ]);

      await client.resolveConflictKeepOurs(c);

      // 衝突已解,conflict store 清空。
      expect(await cache.readConflicts(), isEmpty);
      // 有觸發重抓 GET /days。
      expect(adapter.countOf('GET', '/trips/t/days'), greaterThan(0));
      // 主佇列也應為空(synced,不入佇列)。
      expect(await cache.readQueue(), isEmpty);
    },
  );

  test(
    '[Issue1] resolveKeepOurs 重送 body 只含 dirty 欄位(不覆蓋使用者沒改的欄)',
    () async {
      // ConflictRecord 帶 base:ours 為 full-form(title 與 description 都在),
      // 但只 title 與 base 不同(使用者只改 title)。description 與 base 相同。
      // 「保留你的」重送應只送 dirty 的 title + 新 expectedVersion,不送 description。
      final c = ConflictRecord(
        id: 'c1',
        type: 'entry.update',
        path: '/trips/t/entries/5',
        body: const {
          'title': '我改的標題',
          'description': '舊備註',
          'start_time': null,
          'end_time': null,
          'expectedVersion': 6,
        },
        args: const {
          'entryId': 5,
          'title': '我改的標題',
          'description': '舊備註',
          'startTime': null,
          'endTime': null,
        },
        cacheKey: daysKey,
        ours: const {
          'title': '我改的標題',
          'description': '舊備註',
          'startTime': null,
          'endTime': null,
        },
        theirs: const {
          'title': '他人改的標題',
          'description': '舊備註',
          'startTime': null,
          'endTime': null,
        },
        newVersion: 7,
        conflictFields: const ['title'],
        createdAt: 't',
        base: const {
          'title': '舊標題',
          'description': '舊備註',
          'startTime': null,
          'endTime': null,
        },
      );
      await cache.appendConflict(c);

      adapter.on('PATCH', '/trips/t/entries/5', [
        const Scripted.json(200, {'ok': true}),
      ]);

      await client.resolveConflictKeepOurs(c);

      expect(await cache.readConflicts(), isEmpty);
      final body = bodyOf(adapter.recorded.single);
      expect(body['title'], '我改的標題');
      expect(body['expectedVersion'], 7);
      // 不含 description(使用者沒改 → 保留 server theirs,不覆蓋)。
      expect(body.containsKey('description'), isFalse);
    },
  );

  // ─────────────────────────────────────────────
  // resolveConflictKeepTheirs
  // ─────────────────────────────────────────────

  test(
    '4. resolveKeepTheirs → 僅 removeConflict(不發網路 request)',
    () async {
      final c = entryConflict(
        id: 'c1',
        entryId: 5,
        oursTitle: '我改的標題',
        theirsTitle: '他人改的標題',
        newVersion: 7,
      );
      await cache.appendConflict(c);

      await client.resolveConflictKeepTheirs(c);

      expect(await cache.readConflicts(), isEmpty);
      // 沒有發出任何 HTTP request。
      expect(adapter.recorded, isEmpty);
    },
  );
}
