import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/requests_repository.dart';
import 'package:tripline/features/requests/request_lifecycle.dart';
import 'package:tripline/models/trip_request.dart';

class _MockRepo extends Mock implements RequestsRepository {}

TripRequest _req(RequestStatus status, {TerminalReason? reason}) => TripRequest(
  id: 7,
  tripId: 't',
  message: 'hi',
  status: status,
  terminalReason: reason,
);

Future<void> _flush() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockRepo repo;
  late StreamController<TripRequestEvent> events;
  late List<Completer<void>> waits;
  late List<Duration> delays;

  setUp(() {
    repo = _MockRepo();
    events = StreamController<TripRequestEvent>();
    waits = [];
    delays = [];
    when(() => repo.watchRequestEvents(7)).thenAnswer((_) => events.stream);
  });

  ProviderContainer makeContainer() {
    final c = ProviderContainer(
      overrides: [
        requestsRepositoryProvider.overrideWithValue(repo),
        requestLifecycleProvider(7).overrideWith(
          () => RequestLifecycle(
            7,
            wait: (delay) {
              final w = Completer<void>();
              waits.add(w);
              delays.add(delay);
              return w.future;
            },
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('工單公開狀態保留排隊、處理進度與終態原始錯誤', () async {
    when(
      () => repo.fetchRequest(7),
    ).thenAnswer((_) async => _req(RequestStatus.open));
    final c = makeContainer();
    final sub = c.listen(requestLifecycleProvider(7), (_, _) {});
    await _flush();
    expect((sub.read() as RequestInFlight).status, RequestStatus.open);
    events.add(const TripRequestEvent(status: RequestStatus.processing));
    await _flush();
    expect((sub.read() as RequestInFlight).status, RequestStatus.processing);
    events.add(
      const TripRequestEvent(
        status: RequestStatus.failed,
        error: 'NOTES_AI_NO_VALID_ITEMS',
      ),
    );
    await _flush();
    expect(
      (sub.read() as RequestTerminal).errorMessage,
      'NOTES_AI_NO_VALID_ITEMS',
    );
  });

  test('種子讀取已終結 → 直接 terminal,不開 SSE', () async {
    when(
      () => repo.fetchRequest(7),
    ).thenAnswer((_) async => _req(RequestStatus.completed));
    final c = makeContainer();
    final sub = c.listen(requestLifecycleProvider(7), (_, _) {});
    await _flush();

    final state = sub.read();
    expect(state, isA<RequestTerminal>());
    expect((state as RequestTerminal).status, RequestStatus.completed);
    verifyNever(() => repo.watchRequestEvents(any()));
  });

  test('進行中 → SSE 終結事件 → terminal', () async {
    when(
      () => repo.fetchRequest(7),
    ).thenAnswer((_) async => _req(RequestStatus.processing));
    final c = makeContainer();
    final sub = c.listen(requestLifecycleProvider(7), (_, _) {});
    await _flush();
    expect(sub.read(), isA<RequestInFlight>());

    events.add(const TripRequestEvent(status: RequestStatus.completed));
    await _flush();
    expect(sub.read(), isA<RequestTerminal>());
  });

  test('SSE 已確認 failed，補讀工單後保留逾時原因', () async {
    final terminalRead = Completer<TripRequest>();
    var reads = 0;
    when(() => repo.fetchRequest(7)).thenAnswer((_) {
      reads++;
      return reads == 1
          ? Future.value(_req(RequestStatus.processing))
          : terminalRead.future;
    });
    final c = makeContainer();
    final sub = c.listen(requestLifecycleProvider(7), (_, _) {});
    await _flush();

    events.add(const TripRequestEvent(status: RequestStatus.failed));
    await _flush();
    expect(
      (sub.read() as RequestTerminal).status,
      RequestStatus.failed,
      reason: '補讀尚未完成時也必須保留 SSE 已確認的終態',
    );

    terminalRead.complete(
      _req(RequestStatus.failed, reason: TerminalReason.timedOut),
    );
    await _flush();
    expect(
      (sub.read() as RequestTerminal).terminalReason,
      TerminalReason.timedOut,
    );
  });

  test('重建後停止等待，舊 SSE 原因補讀不能覆蓋目前的本機終態', () async {
    final terminalRead = Completer<TripRequest>();
    var reads = 0;
    when(() => repo.fetchRequest(7)).thenAnswer((_) {
      reads++;
      return reads == 2
          ? terminalRead.future
          : Future.value(_req(RequestStatus.processing));
    });
    when(() => repo.stopWaiting(7)).thenThrow(Exception('offline'));
    final c = makeContainer();
    final sub = c.listen(requestLifecycleProvider(7), (_, _) {});
    await _flush();
    events.add(const TripRequestEvent(status: RequestStatus.failed));
    await _flush();

    final currentEvents = StreamController<TripRequestEvent>();
    when(
      () => repo.watchRequestEvents(7),
    ).thenAnswer((_) => currentEvents.stream);
    c.invalidate(requestLifecycleProvider(7));
    await _flush();
    expect(sub.read(), isA<RequestInFlight>());
    expect(
      await c.read(requestLifecycleProvider(7).notifier).stopWaiting(),
      isFalse,
    );

    terminalRead.complete(
      _req(RequestStatus.failed, reason: TerminalReason.timedOut),
    );
    await _flush();
    final terminal = sub.read() as RequestTerminal;
    expect(terminal.terminalReason, TerminalReason.cancelled);
    expect(terminal.serverConfirmed, isFalse);
    await currentEvents.close();
  });

  test('SSE 原因補讀失敗，仍保留已確認的 failed 終態', () async {
    var reads = 0;
    when(() => repo.fetchRequest(7)).thenAnswer((_) async {
      reads++;
      if (reads > 1) throw Exception('offline');
      return _req(RequestStatus.processing);
    });
    final c = makeContainer();
    final sub = c.listen(requestLifecycleProvider(7), (_, _) {});
    await _flush();
    events.add(const TripRequestEvent(status: RequestStatus.failed));
    await _flush();

    expect(reads, 2, reason: '已嘗試補讀一次完整工單');
    expect((sub.read() as RequestTerminal).status, RequestStatus.failed);
    expect((sub.read() as RequestTerminal).terminalReason, isNull);
    expect(waits, isEmpty, reason: '終態原因讀不到也不重新開始等待');
  });

  test('SSE 完成後持續讀不到資料列會停止補讀，保留已確認終態', () async {
    var reads = 0;
    when(() => repo.fetchRequest(7)).thenAnswer((_) async {
      reads++;
      if (reads > 1) throw Exception('offline');
      return _req(RequestStatus.processing);
    });
    final c = makeContainer();
    final sub = c.listen(requestLifecycleProvider(7), (_, _) {});
    await _flush();

    events.add(const TripRequestEvent(status: RequestStatus.completed));
    await _flush();
    expect(sub.read(), isA<RequestTerminal>());
    unawaited(c.read(requestLifecycleProvider(7).notifier).hydrateTerminal());
    await _flush();
    expect(reads, greaterThan(1), reason: '已嘗試補讀終態資料列');
    var advanced = 0;
    while (advanced < 10 && waits.length > advanced) {
      waits[advanced++].complete();
      await _flush();
    }
    expect(advanced, lessThan(10), reason: '永久錯誤必須停止排定讀取');
    final stoppedAt = reads;
    await _flush();
    expect(reads, stoppedAt);
    expect(sub.read(), isA<RequestTerminal>());
  });

  test('回前景讀取途中收到 SSE failed，共用讀取補齊跨裝置停止原因', () async {
    final pending = Completer<TripRequest>();
    var reads = 0;
    when(() => repo.fetchRequest(7)).thenAnswer((_) {
      reads++;
      return reads == 1
          ? Future.value(_req(RequestStatus.processing))
          : pending.future;
    });
    final c = makeContainer();
    final sub = c.listen(requestLifecycleProvider(7), (_, _) {});
    await _flush();
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      WidgetsBinding.instance.handleAppLifecycleStateChanged(state);
    }
    await _flush();
    events.add(const TripRequestEvent(status: RequestStatus.failed));
    await _flush();
    expect(reads, 2, reason: '原因補讀共用已送出的讀取，不另開第二次請求');

    pending.complete(
      _req(RequestStatus.failed, reason: TerminalReason.cancelled),
    );
    await _flush();
    final terminal = sub.read() as RequestTerminal;
    expect(terminal.terminalReason, TerminalReason.cancelled);
    expect(terminal.serverConfirmed, isTrue);
  });

  test('SSE 前已送出的讀取回舊進行中資料，終態後再補讀一次原因', () async {
    final foregroundRead = Completer<TripRequest>();
    final terminalRead = Completer<TripRequest>();
    var reads = 0;
    when(() => repo.fetchRequest(7)).thenAnswer((_) {
      reads++;
      return switch (reads) {
        1 => Future.value(_req(RequestStatus.processing)),
        2 => foregroundRead.future,
        _ => terminalRead.future,
      };
    });
    final c = makeContainer();
    final sub = c.listen(requestLifecycleProvider(7), (_, _) {});
    await _flush();
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      WidgetsBinding.instance.handleAppLifecycleStateChanged(state);
    }
    await _flush();
    events.add(const TripRequestEvent(status: RequestStatus.failed));
    await _flush();
    expect(reads, 2, reason: '先共用已送出的前景讀取');
    expect((sub.read() as RequestTerminal).status, RequestStatus.failed);

    foregroundRead.complete(_req(RequestStatus.processing));
    await _flush();
    terminalRead.complete(
      _req(RequestStatus.failed, reason: TerminalReason.timedOut),
    );
    await _flush();
    expect(
      (sub.read() as RequestTerminal).terminalReason,
      TerminalReason.timedOut,
    );
    expect(reads, 3, reason: '舊進行中資料不能作為終態查詢結果，只追加一次補讀');
    expect(waits, isEmpty);
  });

  test('SSE 斷線未終結 → 改輪詢,等待可注入', () async {
    var calls = 0;
    when(() => repo.fetchRequest(7)).thenAnswer((_) async {
      calls++;
      return _req(
        calls >= 3 ? RequestStatus.completed : RequestStatus.processing,
      );
    });
    final c = makeContainer();
    final sub = c.listen(requestLifecycleProvider(7), (_, _) {});
    await _flush();
    await events.close();
    await _flush();

    expect(waits, hasLength(1), reason: '斷線後進入輪詢,先等一拍');
    waits[0].complete();
    await _flush();
    expect(sub.read(), isA<RequestInFlight>());
    expect(waits, hasLength(2));
    waits[1].complete();
    await _flush();
    expect(sub.read(), isA<RequestTerminal>());
    expect(calls, 3);
  });

  test('停止等待:伺服器確認 → terminal cancelled,回 true', () async {
    when(
      () => repo.fetchRequest(7),
    ).thenAnswer((_) async => _req(RequestStatus.processing));
    when(() => repo.stopWaiting(7)).thenAnswer((_) async {});
    final c = makeContainer();
    final sub = c.listen(requestLifecycleProvider(7), (_, _) {});
    await _flush();

    final confirmed = await c
        .read(requestLifecycleProvider(7).notifier)
        .stopWaiting();
    expect(confirmed, isTrue);
    final state = sub.read() as RequestTerminal;
    expect(state.terminalReason, TerminalReason.cancelled);
    expect(state.serverConfirmed, isTrue);
  });

  test('停止等待:伺服器沒確認 → 仍本機終結,回 false', () async {
    when(
      () => repo.fetchRequest(7),
    ).thenAnswer((_) async => _req(RequestStatus.processing));
    when(() => repo.stopWaiting(7)).thenThrow(Exception('offline'));
    final c = makeContainer();
    final sub = c.listen(requestLifecycleProvider(7), (_, _) {});
    await _flush();

    final confirmed = await c
        .read(requestLifecycleProvider(7).notifier)
        .stopWaiting();
    expect(confirmed, isFalse);
    final state = sub.read() as RequestTerminal;
    expect(state.terminalReason, TerminalReason.cancelled);
    expect(state.serverConfirmed, isFalse);
  });

  test('app 回前景 → 重讀一次;已終結就收掉', () async {
    var calls = 0;
    when(() => repo.fetchRequest(7)).thenAnswer((_) async {
      calls++;
      return _req(
        calls >= 2 ? RequestStatus.failed : RequestStatus.processing,
        reason: calls >= 2 ? TerminalReason.timedOut : null,
      );
    });
    final c = makeContainer();
    final sub = c.listen(requestLifecycleProvider(7), (_, _) {});
    await _flush();
    expect(sub.read(), isA<RequestInFlight>());

    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      WidgetsBinding.instance.handleAppLifecycleStateChanged(state);
    }
    await _flush();

    expect(calls, 2);
    final state = sub.read() as RequestTerminal;
    expect(state.terminalReason, TerminalReason.timedOut);
  });

  test('種子讀取失敗 → 當作進行中並開 SSE', () async {
    when(() => repo.fetchRequest(7)).thenThrow(Exception('offline'));
    final c = makeContainer();
    final sub = c.listen(requestLifecycleProvider(7), (_, _) {});
    await _flush();

    expect(sub.read(), isA<RequestInFlight>());
    verify(() => repo.watchRequestEvents(7)).called(1);
  });

  test('SSE 開不起來或中途出錯 → 改輪詢;輪詢途中讀取失敗一次不中斷', () async {
    var calls = 0;
    when(() => repo.fetchRequest(7)).thenAnswer((_) async {
      calls++;
      if (calls == 2) throw Exception('blip');
      return _req(
        calls >= 3 ? RequestStatus.completed : RequestStatus.processing,
      );
    });
    final c = makeContainer();
    final sub = c.listen(requestLifecycleProvider(7), (_, _) {});
    await _flush();
    events.addError(Exception('sse'));
    await _flush();

    expect(waits, hasLength(1), reason: 'onError 也要進輪詢');
    waits[0].complete();
    await _flush();
    expect(sub.read(), isA<RequestInFlight>(), reason: '第二次讀取丟例外,還在跑');
    expect(waits, hasLength(2));
    waits[1].complete();
    await _flush();
    expect(sub.read(), isA<RequestTerminal>());
  });

  test('SSE 事件對應:只帶 error → failed / error;processing 事件不終結', () async {
    when(
      () => repo.fetchRequest(7),
    ).thenAnswer((_) async => _req(RequestStatus.processing));
    final c = makeContainer();
    final sub = c.listen(requestLifecycleProvider(7), (_, _) {});
    await _flush();

    events.add(const TripRequestEvent(status: RequestStatus.processing));
    await _flush();
    expect(sub.read(), isA<RequestInFlight>());

    events.add(const TripRequestEvent(error: 'boom'));
    await _flush();
    final state = sub.read() as RequestTerminal;
    expect(state.status, RequestStatus.failed);
    expect(state.terminalReason, TerminalReason.error);
  });

  test('讀取還在飛時 container 被丟掉 → 不丟例外', () async {
    final pending = Completer<TripRequest>();
    when(() => repo.fetchRequest(7)).thenAnswer((_) => pending.future);
    final stop = Completer<void>();
    when(() => repo.stopWaiting(7)).thenAnswer((_) => stop.future);
    final c = ProviderContainer(
      overrides: [requestsRepositoryProvider.overrideWithValue(repo)],
    );
    c.listen(requestLifecycleProvider(7), (_, _) {});
    await _flush();
    final stopping = c.read(requestLifecycleProvider(7).notifier).stopWaiting();
    c.dispose();
    pending.complete(_req(RequestStatus.completed));
    stop.complete();
    await _flush();
    // dispose 後兩條 continuation 都不能碰 state;走到這裡沒有例外就是通過。
    expect(await stopping, isTrue);
  });

  test('停止等待途中 SSE 先送終結 → 保留伺服器的終結態', () async {
    when(
      () => repo.fetchRequest(7),
    ).thenAnswer((_) async => _req(RequestStatus.processing));
    final stop = Completer<void>();
    when(() => repo.stopWaiting(7)).thenAnswer((_) => stop.future);
    final c = makeContainer();
    final sub = c.listen(requestLifecycleProvider(7), (_, _) {});
    await _flush();

    final stopping = c.read(requestLifecycleProvider(7).notifier).stopWaiting();
    events.add(const TripRequestEvent(status: RequestStatus.completed));
    await _flush();
    stop.completeError(Exception('already terminal'));
    await stopping;

    final state = sub.read() as RequestTerminal;
    expect(state.status, RequestStatus.completed);
    expect(state.serverConfirmed, isTrue);
  });

  test('provider 被 invalidate 後重建 → 重新讀取,不會卡在 InFlight', () async {
    var calls = 0;
    when(() => repo.fetchRequest(7)).thenAnswer((_) async {
      calls++;
      return _req(
        calls >= 2 ? RequestStatus.completed : RequestStatus.processing,
      );
    });
    final c = makeContainer();
    final sub = c.listen(requestLifecycleProvider(7), (_, _) {});
    await _flush();
    expect(sub.read(), isA<RequestInFlight>());

    c.invalidate(requestLifecycleProvider(7));
    await _flush();

    expect(calls, 2);
    expect(sub.read(), isA<RequestTerminal>());
  });

  test('SSE 一開就丟例外 → 改輪詢,不當失敗', () async {
    when(
      () => repo.fetchRequest(7),
    ).thenAnswer((_) async => _req(RequestStatus.processing));
    when(() => repo.watchRequestEvents(7)).thenThrow(StateError('no sse'));
    final c = makeContainer();
    final sub = c.listen(requestLifecycleProvider(7), (_, _) {});
    await _flush();

    expect(sub.read(), isA<RequestInFlight>());
    expect(waits, hasLength(1));
  });

  test('輪詢中被 invalidate → 舊迴圈作廢,不會變成兩條迴圈', () async {
    var calls = 0;
    when(() => repo.fetchRequest(7)).thenAnswer((_) async {
      calls++;
      return _req(RequestStatus.processing);
    });
    when(
      () => repo.watchRequestEvents(7),
    ).thenAnswer((_) => const Stream<TripRequestEvent>.empty());
    final c = makeContainer();
    c.listen(requestLifecycleProvider(7), (_, _) {});
    await _flush();
    expect(waits, hasLength(1), reason: 'SSE 立刻收線 → 輪詢');

    c.invalidate(requestLifecycleProvider(7));
    await _flush();
    expect(waits, hasLength(2), reason: '重建後自己的輪詢');
    final before = calls;

    waits[0].complete(); // 舊迴圈醒來
    await _flush();
    expect(calls, before, reason: '舊迴圈不得再打 API');

    waits[1].complete();
    await _flush();
    expect(calls, before + 1);
  });

  test('停止等待後遲到的 SSE 終結事件不覆蓋本機終結態', () async {
    when(
      () => repo.fetchRequest(7),
    ).thenAnswer((_) async => _req(RequestStatus.processing));
    when(() => repo.stopWaiting(7)).thenAnswer((_) async {});
    final c = makeContainer();
    final sub = c.listen(requestLifecycleProvider(7), (_, _) {});
    await _flush();
    await c.read(requestLifecycleProvider(7).notifier).stopWaiting();

    events.add(const TripRequestEvent(status: RequestStatus.completed));
    await _flush();

    final state = sub.read() as RequestTerminal;
    expect(state.terminalReason, TerminalReason.cancelled);
  });

  test('輪詢間隔退避:4s 起每次加倍,30s 封頂', () async {
    when(
      () => repo.fetchRequest(7),
    ).thenAnswer((_) async => _req(RequestStatus.processing));
    final c = makeContainer();
    c.listen(requestLifecycleProvider(7), (_, _) {});
    await _flush();
    await events.close();
    await _flush();
    for (var i = 0; i < 5; i++) {
      waits[i].complete();
      await _flush();
    }

    expect(delays.map((d) => d.inSeconds).toList(), [4, 8, 16, 30, 30, 30]);
  });

  test('讀取還在飛時再觸發重讀(回前景)→ 不重複打 API', () async {
    final pending = Completer<TripRequest>();
    var calls = 0;
    when(() => repo.fetchRequest(7)).thenAnswer((_) {
      calls++;
      return pending.future;
    });
    final c = makeContainer();
    c.listen(requestLifecycleProvider(7), (_, _) {});
    await _flush();
    expect(calls, 1, reason: '種子讀取還在飛');
    // 同狀態不會再派送,要先 inactive 再 resumed 才算一次真正的回前景。
    for (final s in [AppLifecycleState.inactive, AppLifecycleState.resumed]) {
      WidgetsBinding.instance.handleAppLifecycleStateChanged(s);
    }
    await _flush();

    expect(calls, 1, reason: '回前景共用飛行中的那一次');
    pending.complete(_req(RequestStatus.processing));
    await _flush();
  });

  test('重建前的讀取晚回來，回前景仍共用重建後尚未完成的讀取', () async {
    final previous = Completer<TripRequest>();
    final current = Completer<TripRequest>();
    var calls = 0;
    when(() => repo.fetchRequest(7)).thenAnswer((_) {
      calls++;
      return calls == 1 ? previous.future : current.future;
    });
    final c = makeContainer();
    final sub = c.listen(requestLifecycleProvider(7), (_, _) {});
    await _flush();
    c.invalidate(requestLifecycleProvider(7));
    await _flush();
    expect(calls, 2);

    previous.complete(_req(RequestStatus.completed));
    await _flush();
    expect(sub.read(), isA<RequestInFlight>(), reason: '舊讀取不能終結新生命週期');
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      WidgetsBinding.instance.handleAppLifecycleStateChanged(state);
    }
    await _flush();
    expect(calls, 2, reason: '舊讀取完成不能清除目前仍在等待的共用讀取');

    current.complete(_req(RequestStatus.completed));
    await _flush();
    expect(sub.read(), isA<RequestTerminal>());
  });

  test('app 進背景時輪詢暫停,回前景重讀一次並重設退避', () async {
    var calls = 0;
    when(() => repo.fetchRequest(7)).thenAnswer((_) async {
      calls++;
      return _req(RequestStatus.processing);
    });
    final c = makeContainer();
    c.listen(requestLifecycleProvider(7), (_, _) {});
    await _flush();
    await events.close();
    await _flush();
    waits[0].complete();
    await _flush();
    expect(delays, hasLength(2), reason: '第二輪等待(8s)已排上');

    // 真機由 _handleLifecycleMessage 補齊中間狀態;測試要自己走完,
    // 不然 AppLifecycleListener 會 assert 跳級轉換非法。
    for (final s in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      WidgetsBinding.instance.handleAppLifecycleStateChanged(s);
    }
    final before = calls;
    waits[1].complete();
    await _flush();
    expect(calls, before, reason: '背景中等待到期也不打 API');
    expect(delays, hasLength(2), reason: '背景中不再排新的等待');

    for (final s in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      WidgetsBinding.instance.handleAppLifecycleStateChanged(s);
    }
    await _flush();
    expect(calls, before + 1, reason: '回前景只補讀一次');
    expect(delays.last.inSeconds, 4, reason: '退避從頭算');
  });
}
