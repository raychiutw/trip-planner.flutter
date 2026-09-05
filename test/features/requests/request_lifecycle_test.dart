import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_error.dart';
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

  test('讀取遇 401 → 標記 authExpired,不再開 SSE', () async {
    when(() => repo.fetchRequest(7)).thenThrow(
      const ApiError(status: 401, code: 'AUTH_REQUIRED', message: 'login'),
    );
    final c = makeContainer();
    final sub = c.listen(requestLifecycleProvider(7), (_, _) {});
    await _flush();

    final state = sub.read();
    expect(state, isA<RequestInFlight>());
    expect((state as RequestInFlight).authExpired, isTrue);
    verifyNever(() => repo.watchRequestEvents(any()));
  });
}
