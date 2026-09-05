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

  setUp(() {
    repo = _MockRepo();
    events = StreamController<TripRequestEvent>();
    waits = [];
    when(() => repo.watchRequestEvents(7)).thenAnswer((_) => events.stream);
  });

  ProviderContainer makeContainer() {
    final c = ProviderContainer(
      overrides: [
        requestsRepositoryProvider.overrideWithValue(repo),
        requestPollWaitProvider.overrideWithValue(() {
          final w = Completer<void>();
          waits.add(w);
          return w.future;
        }),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

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

    WidgetsBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
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
}
