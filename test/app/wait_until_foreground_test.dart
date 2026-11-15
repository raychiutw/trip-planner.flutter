import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/app/biometric_login.dart';

/// 從 web 授權頁回來的當下 Activity 還在切換，這時叫指紋驗證會被系統中斷。
/// `waitUntilForeground` 要等到 App 真的回到前景才完成。
void main() {
  testWidgets('App 在背景時不會完成，回到前景後才完成', (tester) async {
    final binding = tester.binding;
    // 生命週期要依序送（不補中間狀態、同狀態不派送）。
    for (final s in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      binding.handleAppLifecycleStateChanged(s);
    }

    var done = false;
    unawaited0(waitUntilForeground().then((_) => done = true));
    await tester.pump(const Duration(seconds: 1));
    expect(done, isFalse, reason: '還在背景');

    for (final s in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      binding.handleAppLifecycleStateChanged(s);
    }
    await tester.pump(const Duration(seconds: 1));
    expect(done, isTrue, reason: '回到前景（含短暫穩定時間）後完成');
  });

  testWidgets('已在前景：很快完成，不會卡住', (tester) async {
    var done = false;
    unawaited0(waitUntilForeground().then((_) => done = true));
    await tester.pump(const Duration(seconds: 1));
    expect(done, isTrue);
  });

  testWidgets('一直沒回前景：逾時後放行，不會永遠卡住', (tester) async {
    final binding = tester.binding;
    for (final s in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      binding.handleAppLifecycleStateChanged(s);
    }
    var done = false;
    unawaited0(waitUntilForeground().then((_) => done = true));
    await tester.pump(const Duration(seconds: 10));
    expect(done, isTrue);
  });
}

void unawaited0(Future<void> f) {}
