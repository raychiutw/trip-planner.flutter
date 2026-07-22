import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/cache/cache_keys.dart';
import 'package:tripline/api/cache/cache_store.dart';
import 'package:tripline/api/cache/offline_op.dart';
import 'package:tripline/api/session_store.dart';

DioException _offline(String path) => DioException(
  requestOptions: RequestOptions(path: path),
  type: DioExceptionType.connectionError,
);

class _BlockingSuccessAdapter implements HttpClientAdapter {
  final firstRequestStarted = Completer<void>();
  final releaseFirstRequest = Completer<void>();
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requests.length == 1) {
      firstRequestStarted.complete();
      await releaseFirstRequest.future;
    }
    return ResponseBody.fromString(
      jsonEncode({'ok': true}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FirstSuccessThenOfflineAdapter implements HttpClientAdapter {
  final firstRequestStarted = Completer<void>();
  final releaseFirstRequest = Completer<void>();
  var requestCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestCount++;
    if (requestCount == 1) {
      firstRequestStarted.complete();
      await releaseFirstRequest.future;
      return ResponseBody.fromString(
        jsonEncode({'ok': true}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
    );
  }

  @override
  void close({bool force = false}) {}
}

class _BlockingResponseReadCache extends InMemoryCacheStore {
  final responseReadStarted = Completer<void>();
  final releaseResponseRead = Completer<void>();
  final evictionStarted = Completer<void>();
  final responseWriteStarted = Completer<void>();
  final releaseResponseWrite = Completer<void>();
  final appendedMutations = <QueuedMutation>[];
  bool blockNextResponseRead = false;
  bool blockNextResponseWrite = false;

  @override
  Future<CacheEntry?> readResponse(String key) async {
    if (blockNextResponseRead) {
      blockNextResponseRead = false;
      responseReadStarted.complete();
      await releaseResponseRead.future;
    }
    return super.readResponse(key);
  }

  @override
  Future<void> appendMutation(QueuedMutation mutation) async {
    appendedMutations.add(mutation);
    await super.appendMutation(mutation);
  }

  @override
  Future<void> writeResponse(
    String key,
    Object? data, {
    DateTime? cachedAt,
  }) async {
    if (blockNextResponseWrite) {
      blockNextResponseWrite = false;
      responseWriteStarted.complete();
      await releaseResponseWrite.future;
    }
    await super.writeResponse(key, data, cachedAt: cachedAt);
  }

  @override
  Future<void> evictByPrefix(String prefix) async {
    if (!evictionStarted.isCompleted) evictionStarted.complete();
    await super.evictByPrefix(prefix);
  }
}

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late InMemoryCacheStore cache;
  late ApiClient client;

  setUp(() {
    dio = Dio(BaseOptions())..options.validateStatus = (_) => true;
    adapter = DioAdapter(dio: dio);
    cache = InMemoryCacheStore();
    client = ApiClient(
      sessionStore: InMemorySessionStore(),
      dio: dio,
      cacheStore: cache,
    );
  });

  final daysKey = cacheKeyFor('GET', '/trips/t/days', {'all': '1'});
  OfflineOp addOp() => OfflineOp('entry.add', daysKey, {
    'dayNum': 1,
    'title': 'New',
    'tempId': -1,
  });

  test('sendMutation 線上成功 → 不入佇列、回 server 回應', () async {
    adapter.onPost(
      '/trips/t/days/1/entries',
      (s) => s.reply(200, {'ok': true}),
      data: {'title': 'New'},
    );
    final r = await client.sendMutation(
      'POST',
      '/trips/t/days/1/entries',
      body: {'title': 'New'},
      optimistic: addOp(),
    );
    expect(r, {'ok': true});
    expect(await cache.readQueue(), isEmpty);
  });

  test('sendMutation 離線 + optimistic → 入佇列 + 樂觀 patch 快取 + 回 null', () async {
    await cache.writeResponse(daysKey, [
      {'dayNum': 1, 'timeline': <dynamic>[]},
    ]);
    adapter.onPost(
      '/trips/t/days/1/entries',
      (s) => s.throws(503, _offline('/trips/t/days/1/entries')),
      data: {'title': 'New'},
    );
    final r = await client.sendMutation(
      'POST',
      '/trips/t/days/1/entries',
      body: {'title': 'New'},
      optimistic: addOp(),
    );
    expect(r, isNull);
    final queue = await cache.readQueue();
    expect(queue, hasLength(1));
    expect(queue.single.type, 'entry.add');
    expect(queue.single.cacheKey, daysKey);
    final patched = (await cache.readResponse(daysKey))!.data as List;
    expect((patched.first as Map)['timeline'] as List, hasLength(1));
  });

  test('sendMutation 離線 + optimistic=null → rethrow', () async {
    adapter.onPost('/x', (s) => s.throws(503, _offline('/x')));
    expect(
      () => client.sendMutation('POST', '/x', body: const {}),
      throwsA(isA<DioException>()),
    );
  });

  test('getStream:fresh 到達後仍套用佇列 pending patch(不變式)', () async {
    await cache.appendMutation(
      QueuedMutation(
        id: '1',
        method: 'POST',
        path: '/trips/t/days/1/entries',
        type: 'entry.add',
        cacheKey: daysKey,
        args: const {'dayNum': 1, 'title': 'Pending', 'tempId': -1},
        createdAt: 't',
      ),
    );
    adapter.onGet(
      '/trips/t/days',
      (s) => s.reply(200, [
        {'dayNum': 1, 'timeline': <dynamic>[]},
      ]),
      queryParameters: {'all': '1'},
    );
    final emissions = await client
        .getStream('/trips/t/days', query: {'all': '1'})
        .toList();
    final last = emissions.last as List;
    final timeline = (last.first as Map)['timeline'] as List;
    expect(timeline, hasLength(1));
    expect((timeline.first as Map)['title'], 'Pending');
  });

  test('getStream:離線時對「已 patch 的快取」不重複套 pending(無雙重套用)', () async {
    // 離線新增一筆 → 快取被 patch、佇列有 1
    await cache.writeResponse(daysKey, [
      {'dayNum': 1, 'timeline': <dynamic>[]},
    ]);
    adapter.onPost(
      '/trips/t/days/1/entries',
      (s) => s.throws(503, _offline('/trips/t/days/1/entries')),
      data: {'title': 'New'},
    );
    await client.sendMutation(
      'POST',
      '/trips/t/days/1/entries',
      body: {'title': 'New'},
      optimistic: addOp(),
    );
    // 離線重讀:仍離線
    adapter.onGet(
      '/trips/t/days',
      (s) => s.throws(503, _offline('/trips/t/days')),
      queryParameters: {'all': '1'},
    );
    final emissions = await client
        .getStream('/trips/t/days', query: {'all': '1'})
        .toList();
    // 只應有 1 筆(stale=已 patch 的快取),不因 fallback 再套一次變 2 筆
    final last = emissions.last as List;
    expect((last.first as Map)['timeline'] as List, hasLength(1));
  });

  test('getStream:queue 已寫但快取尚未 patch 時，stale 會重播 pending update', () async {
    await cache.writeResponse(daysKey, [
      {
        'dayNum': 1,
        'timeline': [
          {'id': 201, 'description': '舊備註', 'version': 2},
        ],
      },
    ]);
    await cache.appendMutation(
      QueuedMutation(
        id: 'pending-update',
        method: 'PATCH',
        path: '/trips/t/entries/201',
        type: 'entry.update',
        cacheKey: daysKey,
        args: const {'entryId': 201, 'description': '離線新備註'},
        createdAt: 't',
      ),
    );
    adapter.onGet(
      '/trips/t/days',
      (s) => s.throws(503, _offline('/trips/t/days')),
      queryParameters: {'all': '1'},
    );

    final emissions = await client
        .getStream('/trips/t/days', query: {'all': '1'})
        .toList();

    final timeline =
        ((emissions.single as List).first as Map)['timeline'] as List;
    expect((timeline.single as Map)['description'], '離線新備註');

    final repaired = (await cache.readResponse(daysKey))!.data as List;
    final repairedTimeline = (repaired.first as Map)['timeline'] as List;
    expect(
      (repairedTimeline.single as Map)['description'],
      '離線新備註',
      reason: '當機復原重播的 patch 必須寫回快取，供下一筆修改擷取正確 base',
    );

    await client.sendMutation(
      'PATCH',
      '/trips/t/entries/201',
      body: const {'description': '第二版離線備註', 'expectedVersion': 2},
      optimistic: OfflineOp('entry.update', daysKey, const {
        'entryId': 201,
        'description': '第二版離線備註',
      }),
    );
    final queue = await cache.readQueue();
    expect(queue, hasLength(2));
    expect(queue.last.base?['description'], '離線新備註');
  });

  test('getStream:單筆 entry stale 會套用 days queue 的 pending update', () async {
    const entryPath = '/trips/t/entries/201';
    final entryKey = cacheKeyFor('GET', entryPath);
    await cache.writeResponse(entryKey, {
      'id': 201,
      'sortOrder': 0,
      'displayTitle': '首里城',
      'description': '舊備註',
      'version': 2,
    });
    await cache.appendMutation(
      QueuedMutation(
        id: 'pending-update',
        method: 'PATCH',
        path: entryPath,
        type: 'entry.update',
        cacheKey: daysKey,
        args: const {
          'entryId': 201,
          'description': '離線新備註',
          'startTime': '10:00',
        },
        createdAt: 't',
      ),
    );
    adapter.onGet(entryPath, (s) => s.throws(503, _offline(entryPath)));

    final emissions = await client.getStream(entryPath).toList();

    expect(emissions, hasLength(1));
    expect((emissions.single as Map)['description'], '離線新備註');
    expect((emissions.single as Map)['startTime'], '10:00');
  });

  test('getStream:單筆 entry fresh 與重寫快取仍保留 pending update', () async {
    const entryPath = '/trips/t/entries/201';
    final entryKey = cacheKeyFor('GET', entryPath);
    await cache.appendMutation(
      QueuedMutation(
        id: 'pending-update',
        method: 'PATCH',
        path: entryPath,
        type: 'entry.update',
        cacheKey: daysKey,
        args: const {
          'entryId': 201,
          'description': '離線新備註',
          'startTime': '10:00',
        },
        createdAt: 't',
      ),
    );
    adapter.onGet(
      entryPath,
      (s) => s.reply(200, {
        'id': 201,
        'description': '伺服器舊備註',
        'startTime': '09:00',
        'version': 2,
      }),
    );

    final emissions = await client.getStream(entryPath).toList();

    expect((emissions.single as Map)['description'], '離線新備註');
    expect((emissions.single as Map)['startTime'], '10:00');
    final rewritten = (await cache.readResponse(entryKey))!.data as Map;
    expect(rewritten['description'], '離線新備註');
    expect(rewritten['startTime'], '10:00');
  });

  test('sendMutation:同資源已有 pending 時，新修改排入 queue 而不插隊送網路', () async {
    const entryPath = '/trips/t/entries/201';
    await cache.writeResponse(daysKey, [
      {
        'dayNum': 1,
        'timeline': [
          {'id': 201, 'description': '第一版離線備註', 'version': 2},
        ],
      },
    ]);
    await cache.appendMutation(
      QueuedMutation(
        id: 'older-pending',
        method: 'PATCH',
        path: entryPath,
        type: 'entry.update',
        cacheKey: daysKey,
        args: const {'entryId': 201, 'description': '第一版離線備註'},
        createdAt: 't',
      ),
    );
    adapter.onPatch(
      entryPath,
      (s) => s.reply(200, {'unexpected': true}),
      data: Matchers.any,
    );

    final result = await client.sendMutation(
      'PATCH',
      entryPath,
      body: const {'description': '第二版較新備註', 'expectedVersion': 2},
      optimistic: OfflineOp('entry.update', daysKey, const {
        'entryId': 201,
        'description': '第二版較新備註',
      }),
    );

    expect(result, isNull, reason: '已有 pending 時不得讓較新的修改先直送 server');
    final queue = await cache.readQueue();
    expect(queue, hasLength(2));
    expect(queue.last.args['description'], '第二版較新備註');
    final days = (await cache.readResponse(daysKey))!.data as List;
    final timeline = (days.first as Map)['timeline'] as List;
    expect((timeline.single as Map)['description'], '第二版較新備註');
  });

  test('sendMutation:不同 path 共用 pending cache 時仍依序排入 queue', () async {
    const firstEntryPath = '/trips/t/entries/201';
    const secondEntryPath = '/trips/t/entries/202';
    await cache.writeResponse(daysKey, [
      {
        'dayNum': 1,
        'timeline': [
          {'id': 201, 'description': '第一景點離線備註', 'version': 2},
          {'id': 202, 'description': '第二景點原始備註', 'version': 4},
        ],
      },
    ]);
    await cache.appendMutation(
      QueuedMutation(
        id: 'first-entry-pending',
        method: 'PATCH',
        path: firstEntryPath,
        type: 'entry.update',
        cacheKey: daysKey,
        args: const {'entryId': 201, 'description': '第一景點離線備註'},
        createdAt: 't',
      ),
    );
    adapter.onPatch(
      secondEntryPath,
      (s) => s.reply(200, {'unexpected': true}),
      data: Matchers.any,
    );

    final result = await client.sendMutation(
      'PATCH',
      secondEntryPath,
      body: const {'description': '第二景點離線備註', 'expectedVersion': 4},
      optimistic: OfflineOp('entry.update', daysKey, const {
        'entryId': 202,
        'description': '第二景點離線備註',
      }),
    );

    expect(
      result,
      isNull,
      reason: '共用 optimistic cache 的 mutation 不得越過 pending 直送',
    );
    final queue = await cache.readQueue();
    expect(queue, hasLength(2));
    expect(queue.last.path, secondEntryPath);
    final days = (await cache.readResponse(daysKey))!.data as List;
    final timeline = (days.first as Map)['timeline'] as List;
    expect(
      (timeline.last as Map)['description'],
      '第二景點離線備註',
      reason: '排隊時仍要保留第二景點的 optimistic patch 與 rebase base',
    );
  });

  test('sendMutation:idle queue 收到新修改後會自動啟動 flush', () async {
    const entryPath = '/trips/t/entries/201';
    final blockingAdapter = _BlockingSuccessAdapter();
    final blockingDio = Dio(BaseOptions());
    blockingDio.options.validateStatus = (_) => true;
    blockingDio.httpClientAdapter = blockingAdapter;
    final blockingClient = ApiClient(
      sessionStore: InMemorySessionStore(),
      dio: blockingDio,
      cacheStore: cache,
    );
    final flushSubscription = blockingClient.queueFlushRequests.listen(
      (_) => unawaited(blockingClient.flushQueue()),
    );
    addTearDown(flushSubscription.cancel);
    await cache.writeResponse(daysKey, [
      {
        'dayNum': 1,
        'timeline': [
          {'id': 201, 'description': '第一版離線備註', 'version': 2},
        ],
      },
    ]);
    await cache.appendMutation(
      QueuedMutation(
        id: 'older-pending',
        method: 'PATCH',
        path: entryPath,
        body: const {'description': '第一版離線備註'},
        type: 'entry.update',
        cacheKey: daysKey,
        args: const {'entryId': 201, 'description': '第一版離線備註'},
        createdAt: 't',
      ),
    );

    await blockingClient.sendMutation(
      'PATCH',
      entryPath,
      body: const {'description': '第二版較新備註'},
      optimistic: OfflineOp('entry.update', daysKey, const {
        'entryId': 201,
        'description': '第二版較新備註',
      }),
    );
    for (var attempt = 0; attempt < 20; attempt++) {
      if (blockingAdapter.firstRequestStarted.isCompleted) break;
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }

    expect(
      blockingAdapter.firstRequestStarted.isCompleted,
      isTrue,
      reason: '使用者在線上再次儲存時，不應讓既有 queue 等到下次 resume 才同步',
    );
    blockingAdapter.releaseFirstRequest.complete();
    for (var attempt = 0; attempt < 20; attempt++) {
      if ((await cache.readQueue()).isEmpty) break;
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(await cache.readQueue(), isEmpty);
    expect(blockingAdapter.requests, hasLength(2));
  });

  test('sendMutation:同 optimistic cache 的直送請求必須依序執行', () async {
    const firstEntryPath = '/trips/t/entries/201';
    const secondEntryPath = '/trips/t/entries/202';
    final blockingAdapter = _BlockingSuccessAdapter();
    final blockingDio = Dio(BaseOptions());
    blockingDio.options.validateStatus = (_) => true;
    blockingDio.httpClientAdapter = blockingAdapter;
    final blockingClient = ApiClient(
      sessionStore: InMemorySessionStore(),
      dio: blockingDio,
      cacheStore: cache,
    );

    final firstSave = blockingClient.sendMutation(
      'PATCH',
      firstEntryPath,
      body: const {'description': '第一景點新版'},
      optimistic: OfflineOp('entry.update', daysKey, const {
        'entryId': 201,
        'description': '第一景點新版',
      }),
    );
    await blockingAdapter.firstRequestStarted.future;
    final secondSave = blockingClient.sendMutation(
      'PATCH',
      secondEntryPath,
      body: const {'description': '第二景點新版'},
      optimistic: OfflineOp('entry.update', daysKey, const {
        'entryId': 202,
        'description': '第二景點新版',
      }),
    );
    for (var attempt = 0; attempt < 20; attempt++) {
      if (blockingAdapter.requests.length > 1) break;
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }

    expect(
      blockingAdapter.requests,
      hasLength(1),
      reason: '共用 days cache 的並行成功/離線完成順序不得互相淘汰 optimistic base',
    );
    blockingAdapter.releaseFirstRequest.complete();
    await Future.wait([firstSave, secondSave]);
    expect(blockingAdapter.requests, hasLength(2));
  });

  test('前一筆線上成功、後一筆轉離線時保留 optimistic base 與畫面', () async {
    const firstEntryPath = '/trips/t/entries/201';
    const secondEntryPath = '/trips/t/entries/202';
    final transitionAdapter = _FirstSuccessThenOfflineAdapter();
    final transitionDio = Dio(BaseOptions());
    transitionDio.options.validateStatus = (_) => true;
    transitionDio.httpClientAdapter = transitionAdapter;
    final transitionClient = ApiClient(
      sessionStore: InMemorySessionStore(),
      dio: transitionDio,
      cacheStore: cache,
    );
    await cache.writeResponse(daysKey, [
      {
        'dayNum': 1,
        'timeline': [
          {'id': 201, 'description': '第一景點原始備註', 'version': 2},
          {'id': 202, 'description': '第二景點原始備註', 'version': 4},
        ],
      },
    ]);

    final firstSave = transitionClient.sendMutation(
      'PATCH',
      firstEntryPath,
      body: const {'description': '第一景點新版'},
      optimistic: OfflineOp('entry.update', daysKey, const {
        'entryId': 201,
        'description': '第一景點新版',
      }),
    );
    await transitionAdapter.firstRequestStarted.future;
    final secondSave = transitionClient.sendMutation(
      'PATCH',
      secondEntryPath,
      body: const {'description': '第二景點離線新版'},
      optimistic: OfflineOp('entry.update', daysKey, const {
        'entryId': 202,
        'description': '第二景點離線新版',
      }),
    );
    transitionAdapter.releaseFirstRequest.complete();
    await Future.wait([firstSave, secondSave]);

    final queued = await cache.readQueue();
    expect(queued, hasLength(1));
    expect(queued.single.base?['description'], '第二景點原始備註');
    final days = (await cache.readResponse(daysKey))!.data as List;
    final timeline = (days.first as Map)['timeline'] as List;
    expect((timeline.last as Map)['description'], '第二景點離線新版');
  });

  test('flush 進行中排入同資源的新修改會自動再跑一輪', () async {
    const entryPath = '/trips/t/entries/201';
    final blockingAdapter = _BlockingSuccessAdapter();
    final blockingDio = Dio(BaseOptions());
    blockingDio.options.validateStatus = (_) => true;
    blockingDio.httpClientAdapter = blockingAdapter;
    final blockingClient = ApiClient(
      sessionStore: InMemorySessionStore(),
      dio: blockingDio,
      cacheStore: cache,
    );
    await cache.writeResponse(daysKey, [
      {
        'dayNum': 1,
        'timeline': [
          {'id': 201, 'description': '第一版離線備註', 'version': 2},
        ],
      },
    ]);
    await cache.appendMutation(
      QueuedMutation(
        id: 'older-pending',
        method: 'PATCH',
        path: entryPath,
        body: const {'description': '第一版離線備註'},
        type: 'entry.update',
        cacheKey: daysKey,
        args: const {'entryId': 201, 'description': '第一版離線備註'},
        createdAt: 't',
      ),
    );

    final firstFlush = blockingClient.flushQueue();
    await blockingAdapter.firstRequestStarted.future;
    await blockingClient.sendMutation(
      'PATCH',
      entryPath,
      body: const {'description': '第二版較新備註'},
      optimistic: OfflineOp('entry.update', daysKey, const {
        'entryId': 201,
        'description': '第二版較新備註',
      }),
    );
    blockingAdapter.releaseFirstRequest.complete();
    await firstFlush;
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(
      blockingAdapter.requests,
      hasLength(2),
      reason: '第一輪 snapshot 後加入的 mutation 必須自動觸發下一輪 flush',
    );
    expect(await cache.readQueue(), isEmpty);
  });

  test('flush 收尾與同資源 enqueue 交錯時仍保留 base 並自動送出', () async {
    const entryPath = '/trips/t/entries/201';
    final raceCache = _BlockingResponseReadCache();
    final blockingAdapter = _BlockingSuccessAdapter();
    final blockingDio = Dio(BaseOptions());
    blockingDio.options.validateStatus = (_) => true;
    blockingDio.httpClientAdapter = blockingAdapter;
    final blockingClient = ApiClient(
      sessionStore: InMemorySessionStore(),
      dio: blockingDio,
      cacheStore: raceCache,
    );
    await raceCache.writeResponse(daysKey, [
      {
        'dayNum': 1,
        'timeline': [
          {'id': 201, 'description': '第一版離線備註', 'version': 2},
        ],
      },
    ]);
    await raceCache.appendMutation(
      QueuedMutation(
        id: 'older-pending',
        method: 'PATCH',
        path: entryPath,
        body: const {'description': '第一版離線備註'},
        type: 'entry.update',
        cacheKey: daysKey,
        args: const {'entryId': 201, 'description': '第一版離線備註'},
        createdAt: 't',
      ),
    );

    final firstFlush = blockingClient.flushQueue();
    await blockingAdapter.firstRequestStarted.future;

    raceCache.blockNextResponseRead = true;
    final secondSave = blockingClient.sendMutation(
      'PATCH',
      entryPath,
      body: const {'description': '第二版離線備註'},
      optimistic: OfflineOp('entry.update', daysKey, const {
        'entryId': 201,
        'description': '第二版離線備註',
      }),
    );
    await raceCache.responseReadStarted.future;

    blockingAdapter.releaseFirstRequest.complete();
    await Future.any<void>([
      raceCache.evictionStarted.future,
      Future<void>.delayed(const Duration(milliseconds: 20)),
    ]);
    raceCache.releaseResponseRead.complete();

    await Future.wait([firstFlush, secondSave]);

    expect(blockingAdapter.requests, hasLength(2));
    expect(await raceCache.readQueue(), isEmpty);
    expect(
      raceCache.appendedMutations.last.base?['description'],
      '第一版離線備註',
      reason: 'flush 不得在 enqueue 擷取 base 前先淘汰同資源快取',
    );
  });

  test(
    'getStream crash-recovery 寫回與 flush 收尾交錯時不復活 optimistic cache',
    () async {
      const entryPath = '/trips/t/entries/201';
      final raceCache = _BlockingResponseReadCache();
      final raceDio = Dio(BaseOptions())..options.validateStatus = (_) => true;
      final raceAdapter = DioAdapter(dio: raceDio);
      raceDio.httpClientAdapter = raceAdapter;
      final raceClient = ApiClient(
        sessionStore: InMemorySessionStore(),
        dio: raceDio,
        cacheStore: raceCache,
      );
      await raceCache.writeResponse(daysKey, [
        {
          'dayNum': 1,
          'timeline': [
            {'id': 201, 'description': '伺服器舊備註', 'version': 2},
          ],
        },
      ]);
      await raceCache.appendMutation(
        QueuedMutation(
          id: 'pending-update',
          method: 'PATCH',
          path: entryPath,
          body: const {'description': '已送出的離線備註'},
          type: 'entry.update',
          cacheKey: daysKey,
          args: const {'entryId': 201, 'description': '已送出的離線備註'},
          createdAt: 't',
        ),
      );
      raceAdapter.onPatch(
        entryPath,
        (server) => server.reply(200, {'ok': true}),
        data: Matchers.any,
      );

      raceCache.blockNextResponseWrite = true;
      final staleRead = raceClient
          .getStream('/trips/t/days', query: {'all': '1'})
          .first;
      await raceCache.responseWriteStarted.future;

      final flush = raceClient.flushQueue();
      await Future.any<void>([
        raceCache.evictionStarted.future,
        Future<void>.delayed(const Duration(milliseconds: 20)),
      ]);
      raceCache.releaseResponseWrite.complete();

      await Future.wait([staleRead, flush]);

      expect(await raceCache.readQueue(), isEmpty);
      expect(
        await raceCache.readResponse(daysKey),
        isNull,
        reason: 'flush 已完成後不得留下沒有 queue record 的 optimistic cache',
      );
    },
  );

  test('離線新增臨時 id:冪等(重播=入佇列)且連續新增不碰撞', () async {
    await cache.writeResponse(daysKey, [
      {'dayNum': 1, 'timeline': <dynamic>[]},
    ]);
    // production 路徑:OfflineOp 不帶 tempId,由 sendMutation 入佇列時產生並存進 args。
    OfflineOp prodAdd(String title) =>
        OfflineOp('entry.add', daysKey, {'dayNum': 1, 'title': title});
    adapter.onPost(
      '/trips/t/days/1/entries',
      (s) => s.throws(503, _offline('/trips/t/days/1/entries')),
      data: Matchers.any,
    );

    await client.sendMutation(
      'POST',
      '/trips/t/days/1/entries',
      body: {'title': 'One'},
      optimistic: prodAdd('One'),
    );
    await client.sendMutation(
      'POST',
      '/trips/t/days/1/entries',
      body: {'title': 'Two'},
      optimistic: prodAdd('Two'),
    );

    final queue = await cache.readQueue();
    expect(queue, hasLength(2));
    final id1 = queue[0].args['tempId'];
    final id2 = queue[1].args['tempId'];
    expect(id1, isNotNull);
    expect(id1, isNot(id2)); // 不碰撞

    // getStream 重播:fresh(空)→ 套兩筆 pending → entry id 與 queued tempId 相同、順序穩定
    adapter.onGet(
      '/trips/t/days',
      (s) => s.reply(200, [
        {'dayNum': 1, 'timeline': <dynamic>[]},
      ]),
      queryParameters: {'all': '1'},
    );
    final emissions = await client
        .getStream('/trips/t/days', query: {'all': '1'})
        .toList();
    final timeline =
        ((emissions.last as List).first as Map)['timeline'] as List;
    final replayIds = timeline.map((e) => (e as Map)['id']).toList();
    expect(replayIds, [id1, id2]); // 冪等
  });
}
