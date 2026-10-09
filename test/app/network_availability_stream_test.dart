import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/main.dart';

class _FakeConnectivity implements Connectivity {
  _FakeConnectivity(this.initial);
  final List<ConnectivityResult> initial;
  final changes = StreamController<List<ConnectivityResult>>();

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => initial;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => changes.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('啟動時已離線 → 第一個值就是 false', () async {
    final fake = _FakeConnectivity([ConnectivityResult.none]);
    final first = await networkAvailabilityStream(fake).first;
    expect(first, isFalse);
  });

  test('先送初始值，再接後續變化', () async {
    final fake = _FakeConnectivity([ConnectivityResult.none]);
    final events = <bool>[];
    final sub = networkAvailabilityStream(fake).listen(events.add);
    await pumpEventQueue();
    fake.changes.add([ConnectivityResult.wifi]);
    await pumpEventQueue();
    expect(events, [false, true]);
    await sub.cancel();
  });
}
