import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/app/stream_retry_coordinator.dart';

void main() {
  test('重試排程與讀取共用等待，SWR 資料不提早結束動作', () async {
    var refreshes = 0;
    final retry = StreamRetryCoordinator(() => refreshes++);
    final source = StreamController<int>();
    final first = retry.retry();
    expect(retry.retry(), same(first));
    expect(refreshes, 1);
    final values = <int>[];
    final subscription = retry.track(() => source.stream).listen(values.add);
    var finished = false;
    unawaited(first.then((_) => finished = true));
    source.add(1);
    await Future<void>.delayed(Duration.zero);
    expect(values, [1]);
    expect(finished, isFalse);
    expect(retry.retry(), same(first));
    source.add(1);
    await source.close();
    await first;
    expect(values, [1, 1]);
    expect(finished, isTrue);
    await subscription.cancel();
    retry.dispose();
  });

  test('舊讀取的延遲取消不能結束新讀取', () async {
    var refreshes = 0;
    final retry = StreamRetryCoordinator(() => refreshes++);
    final cancelGate = Completer<void>();
    final oldSource = StreamController<int>(onCancel: () => cancelGate.future);
    final oldSubscription = retry.track(() => oldSource.stream).listen((_) {});
    final oldAttempt = retry.retry();
    final newSource = StreamController<int>();
    final newSubscription = retry.track(() => newSource.stream).listen((_) {});
    final newAttempt = retry.retry();
    expect(newAttempt, isNot(same(oldAttempt)));
    var newFinished = false;
    unawaited(newAttempt.then((_) => newFinished = true));
    final cancellation = oldSubscription.cancel();
    await oldAttempt;
    expect(retry.retry(), same(newAttempt));
    cancelGate.complete();
    await cancellation;
    await Future<void>.delayed(Duration.zero);
    expect(newFinished, isFalse);
    expect(refreshes, 0);
    await newSource.close();
    await newAttempt;
    await newSubscription.cancel();
    await oldSource.close();
    retry.dispose();
  });

  test('同步開啟失敗原樣轉送，每次同錯誤仍結束重試', () async {
    var refreshes = 0;
    final retry = StreamRetryCoordinator(() => refreshes++);
    final failure = StateError('failed to open');
    final stack = StackTrace.current;
    for (var i = 0; i < 2; i++) {
      final attempt = retry.retry();
      final errors = <Object>[];
      final stacks = <StackTrace>[];
      final done = Completer<void>();
      retry
          .track<int>(() => Error.throwWithStackTrace(failure, stack))
          .listen(
            (_) => fail('失敗的來源不可產生資料'),
            onError: (Object error, StackTrace trace) {
              errors.add(error);
              stacks.add(trace);
            },
            onDone: done.complete,
          );
      await attempt;
      await done.future;
      expect(errors.single, same(failure));
      expect(stacks.single, same(stack));
    }
    expect(refreshes, 2);
    retry.dispose();
  });

  test('排程後尚未訂閱就 dispose 會結束等待且不開啟來源', () async {
    var refreshes = 0;
    var opens = 0;
    final retry = StreamRetryCoordinator(() => refreshes++);
    final pending = retry.retry();
    final tracked = retry.track<int>(() {
      opens++;
      return const Stream.empty();
    });
    retry.dispose();
    await pending;
    expect(await tracked.toList(), isEmpty);
    expect(opens, 0);
    await retry.retry();
    expect(refreshes, 1);
  });

  test('串流錯誤原樣轉送且不必等待 done 才能再次重試', () async {
    var refreshes = 0;
    final retry = StreamRetryCoordinator(() => refreshes++);
    final source = StreamController<int>();
    final failure = StateError('network failed');
    final stack = StackTrace.current;
    final errors = <Object>[];
    final stacks = <StackTrace>[];
    final subscription = retry
        .track(() => source.stream)
        .listen(
          (_) {},
          onError: (Object error, StackTrace trace) {
            errors.add(error);
            stacks.add(trace);
          },
        );
    final attempt = retry.retry();
    source.addError(failure, stack);
    await attempt;
    await Future<void>.delayed(Duration.zero);
    expect(errors.single, same(failure));
    expect(stacks.single, same(stack));
    final next = retry.retry();
    expect(refreshes, 1);
    await source.close();
    await subscription.cancel();
    expect(retry.retry(), same(next));
    retry.dispose();
    await next;
  });
}
