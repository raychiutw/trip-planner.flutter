import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/settings_store.dart';
import 'package:tripline/app/app_lock.dart';
import 'package:tripline/features/account/settings/app_lock_row.dart';
import 'package:tripline/models/user.dart';
import 'package:tripline/app/app_lock_host.dart';

import '../helpers/fake_biometric.dart';

const _user = UserInfo(id: 'u1', email: 'a@example.com');

/// 可從測試端切換登入狀態；起始 loading → data，等同冷啟動還原 session。
class _FakeAuth extends AuthNotifier {
  _FakeAuth(this._initial);
  final UserInfo? _initial;
  int logoutCalls = 0;

  @override
  Future<UserInfo?> build() async => _initial;

  void set(UserInfo? user) => state = AsyncData(user);

  @override
  Future<void> logout() async {
    logoutCalls++;
    state = const AsyncData(null);
  }
}

class _Rig {
  _Rig({
    UserInfo? user = _user,
    bool enabled = false,
    BiometricKind? kind = BiometricKind.faceId,
    List<BiometricOutcome>? outcomes,
    InMemorySettingsStore? store,
    this.textScale = 1,
  }) : bio = FakeBiometricAuthenticator(kind: kind, outcomes: outcomes),
       store = store ?? InMemorySettingsStore(),
       auth = _FakeAuth(user),
       enabledAtStart = enabled;

  final FakeBiometricAuthenticator bio;
  final InMemorySettingsStore store;
  final _FakeAuth auth;
  final bool enabledAtStart;
  final double textScale;
  DateTime now = DateTime(2026, 10, 24, 9);

  Widget build() => ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => auth),
      settingsStoreProvider.overrideWithValue(store),
      biometricAuthenticatorProvider.overrideWithValue(bio),
      appLockClockProvider.overrideWithValue(() => now),
      appLockProvider.overrideWith(
        () => AppLockController(initialEnabled: enabledAtStart),
      ),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: AppLockHost(child: child!),
      ),
      home: const Scaffold(
        body: Column(children: [Text('SECRET'), AppLockRow()]),
      ),
    ),
  );
}

Future<void> _background(WidgetTester tester) async {
  for (final s in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
  await tester.pump();
}

Future<void> _foreground(WidgetTester tester) async {
  for (final s in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
  await tester.pumpAndSettle();
}

final _lockScreen = find.byKey(const ValueKey('app-lock-screen'));
final _prompt = find.byKey(const ValueKey('app-lock-prompt'));

void main() {
  testWidgets('預設關閉：不鎖、不顯示鎖定畫面', (tester) async {
    final rig = _Rig();
    await tester.pumpWidget(rig.build());
    await tester.pumpAndSettle();

    expect(_lockScreen, findsNothing);
    expect(rig.bio.authenticateCalls, 0);
  });

  group('App 切換器截圖遮蔽', () {
    final cover = find.byKey(const ValueKey('app-lock-privacy-cover'));

    testWidgets('已開啟：離開前景（inactive）時蓋住內容，回前景後移除', (tester) async {
      final rig = _Rig(enabled: true);
      await tester.pumpWidget(rig.build());
      await tester.pumpAndSettle();
      expect(cover, findsNothing);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(cover, findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(cover, findsNothing);
    });

    testWidgets('未開啟：inactive 不遮蔽', (tester) async {
      final rig = _Rig();
      await tester.pumpWidget(rig.build());
      await tester.pumpAndSettle();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(cover, findsNothing);
    });
  });

  testWidgets('開啟後冷啟動鎖定，自動喚起驗證，成功才解鎖', (tester) async {
    final rig = _Rig(enabled: true);
    await tester.pumpWidget(rig.build());
    await tester.pump();
    expect(_lockScreen, findsOneWidget);

    await tester.pumpAndSettle();
    expect(rig.bio.authenticateCalls, 1);
    expect(_lockScreen, findsNothing);
  });

  for (final outcome in [BiometricOutcome.cancelled, BiometricOutcome.failed]) {
    testWidgets('驗證${outcome.name}：停留在鎖定畫面、不登出，按鈕可重試', (tester) async {
      final rig = _Rig(enabled: true, outcomes: [outcome]);
      await tester.pumpWidget(rig.build());
      await tester.pumpAndSettle();

      expect(_lockScreen, findsOneWidget);
      expect(rig.auth.logoutCalls, 0);
      expect(
        tester.container().read(authStateProvider).value,
        isNotNull,
        reason: 'session 保留',
      );

      await tester.tap(find.text('使用 Face ID 解鎖'));
      await tester.pumpAndSettle();
      expect(rig.bio.authenticateCalls, 2);
      expect(_lockScreen, findsNothing);
    });
  }

  testWidgets('鎖定畫面遮住並封鎖底下內容', (tester) async {
    final rig = _Rig(enabled: true, outcomes: [BiometricOutcome.cancelled]);
    await tester.pumpWidget(rig.build());
    await tester.pumpAndSettle();

    final guard = tester.widget<IgnorePointer>(
      find.byKey(const ValueKey('app-lock-content-guard')),
    );
    expect(guard.ignoring, isTrue);
    final semantics = tester.widget<ExcludeSemantics>(
      find.byKey(const ValueKey('app-lock-content-semantics')),
    );
    expect(semantics.excluding, isTrue);
  });

  testWidgets('最大字級下鎖定畫面與登出確認框不溢出', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final rig = _Rig(
      enabled: true,
      outcomes: [BiometricOutcome.cancelled],
      textScale: 2.5,
    );
    await tester.pumpWidget(rig.build());
    await tester.pumpAndSettle();
    expect(_lockScreen, findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('登出'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('app-lock-logout-dialog')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('鎖定畫面可登出：確認後登出並解除鎖定、清掉開啟旗標', (tester) async {
    final rig = _Rig(enabled: true, outcomes: [BiometricOutcome.cancelled]);
    await tester.pumpWidget(rig.build());
    await tester.pumpAndSettle();

    await tester.tap(find.text('登出'));
    await tester.pumpAndSettle();
    expect(rig.auth.logoutCalls, 0, reason: '先確認');
    await tester.tap(find.byKey(const ValueKey('app-lock-dialog-confirm')));
    await tester.pumpAndSettle();

    expect(rig.auth.logoutCalls, 1);
    expect(_lockScreen, findsNothing);
    expect(await rig.store.read('app_lock_enabled'), '0');
  });

  testWidgets('登出後不再鎖：已登出的使用者不看到鎖定畫面', (tester) async {
    final rig = _Rig(user: null, enabled: true);
    await tester.pumpWidget(rig.build());
    await tester.pumpAndSettle();
    expect(_lockScreen, findsNothing);
  });

  group('回前景', () {
    testWidgets('背景不到 1 分鐘不鎖', (tester) async {
      final rig = _Rig(enabled: true);
      await tester.pumpWidget(rig.build());
      await tester.pumpAndSettle();
      expect(_lockScreen, findsNothing);
      final before = rig.bio.authenticateCalls;
      // 若誤鎖，驗證取消會讓鎖定畫面留著，守門才看得到。
      rig.bio.outcomes.add(BiometricOutcome.cancelled);

      await _background(tester);
      rig.now = rig.now.add(const Duration(seconds: 59));
      await _foreground(tester);
      expect(_lockScreen, findsNothing);
      expect(rig.bio.authenticateCalls, before);
    });

    testWidgets('背景超過 1 分鐘再回前景才鎖並喚起驗證', (tester) async {
      final rig = _Rig(enabled: true);
      await tester.pumpWidget(rig.build());
      await tester.pumpAndSettle();
      final before = rig.bio.authenticateCalls;
      rig.bio.outcomes.add(BiometricOutcome.cancelled);

      await _background(tester);
      rig.now = rig.now.add(const Duration(minutes: 1, seconds: 1));
      await _foreground(tester);

      expect(_lockScreen, findsOneWidget);
      expect(rig.bio.authenticateCalls, before + 1);
    });

    testWidgets('關閉時背景再久也不鎖', (tester) async {
      final rig = _Rig();
      await tester.pumpWidget(rig.build());
      await tester.pumpAndSettle();

      await _background(tester);
      rig.now = rig.now.add(const Duration(hours: 3));
      await _foreground(tester);
      expect(_lockScreen, findsNothing);
    });

    testWidgets('裝置不再有生物辨識與密碼：自動關閉並通知，不把人鎖在外面', (tester) async {
      final rig = _Rig(enabled: true);
      await tester.pumpWidget(rig.build());
      await tester.pumpAndSettle();

      await _background(tester);
      rig.bio.kind = null;
      rig.now = rig.now.add(const Duration(minutes: 5));
      await _foreground(tester);

      expect(_lockScreen, findsNothing);
      expect(await rig.store.read('app_lock_enabled'), '0');
      expect(find.textContaining('已關閉'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });
  });

  group('設定開關', () {
    testWidgets('標籤依裝置種類顯示，預設關閉', (tester) async {
      final rig = _Rig(kind: BiometricKind.touchId);
      await tester.pumpWidget(rig.build());
      await tester.pumpAndSettle();

      expect(find.text('Touch ID 解鎖'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    });

    testWidgets('開啟前要先驗證：取消則維持關閉、成功才開啟並持久化', (tester) async {
      final rig = _Rig(outcomes: [BiometricOutcome.cancelled]);
      await tester.pumpWidget(rig.build());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      expect(await rig.store.read('app_lock_enabled'), isNull);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      expect(await rig.store.read('app_lock_enabled'), '1');
      expect(_lockScreen, findsNothing, reason: '剛驗證完不再鎖');
    });

    testWidgets('關閉也要先驗證', (tester) async {
      final rig = _Rig(enabled: true);
      await tester.pumpWidget(rig.build());
      await tester.pumpAndSettle();
      rig.bio.outcomes.add(BiometricOutcome.failed);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      expect(await rig.store.read('app_lock_enabled'), '0');
    });

    testWidgets('裝置不可用：開關停用並說明原因', (tester) async {
      final rig = _Rig(kind: null);
      await tester.pumpWidget(rig.build());
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
      expect(find.textContaining('尚未設定'), findsOneWidget);
    });
  });

  group('新登入後詢問', () {
    testWidgets('新登入後問一次；稍後再說不開啟，之後登出再登入也不再問', (tester) async {
      final rig = _Rig(user: null);
      await tester.pumpWidget(rig.build());
      await tester.pumpAndSettle();
      expect(_prompt, findsNothing);

      rig.auth.set(_user);
      await tester.pumpAndSettle();
      expect(_prompt, findsOneWidget);
      expect(find.text('要用 Face ID 解鎖 Tripline 嗎？'), findsOneWidget);
      // 開關實際在「帳號 → 安全性」群組，文案指的路徑必須存在。
      expect(find.textContaining('帳號 → 安全性'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('app-lock-dialog-cancel')));
      await tester.pumpAndSettle();
      expect(_prompt, findsNothing);
      expect(await rig.store.read('app_lock_enabled'), isNull);
      expect(await rig.store.read('app_lock_prompted'), '1');

      rig.auth.set(null);
      await tester.pumpAndSettle();
      rig.auth.set(_user);
      await tester.pumpAndSettle();
      expect(_prompt, findsNothing);
    });

    testWidgets('選開啟：先驗證成功才開啟，且標記已問過', (tester) async {
      final rig = _Rig(user: null);
      await tester.pumpWidget(rig.build());
      await tester.pumpAndSettle();
      rig.auth.set(_user);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('app-lock-dialog-confirm')));
      await tester.pumpAndSettle();
      expect(rig.bio.authenticateCalls, 1);
      expect(await rig.store.read('app_lock_enabled'), '1');
      expect(await rig.store.read('app_lock_prompted'), '1');
    });

    testWidgets('選開啟但驗證取消：維持關閉，仍標記已問過', (tester) async {
      final rig = _Rig(user: null, outcomes: [BiometricOutcome.cancelled]);
      await tester.pumpWidget(rig.build());
      await tester.pumpAndSettle();
      rig.auth.set(_user);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('app-lock-dialog-confirm')));
      await tester.pumpAndSettle();
      expect(await rig.store.read('app_lock_enabled'), isNull);
      expect(await rig.store.read('app_lock_prompted'), '1');
    });

    testWidgets('冷啟動還原既有 session 不詢問', (tester) async {
      final rig = _Rig();
      await tester.pumpWidget(rig.build());
      await tester.pumpAndSettle();
      expect(_prompt, findsNothing);
      expect(await rig.store.read('app_lock_prompted'), isNull);
    });

    testWidgets('裝置不可用：不詢問也不記錄已問過', (tester) async {
      final rig = _Rig(user: null, kind: null);
      await tester.pumpWidget(rig.build());
      await tester.pumpAndSettle();
      rig.auth.set(_user);
      await tester.pumpAndSettle();

      expect(_prompt, findsNothing);
      expect(await rig.store.read('app_lock_prompted'), isNull);
    });

    testWidgets('登出清掉開啟旗標但保留已問過', (tester) async {
      final rig = _Rig(enabled: true, outcomes: []);
      await tester.pumpWidget(rig.build());
      await tester.pumpAndSettle();
      await rig.store.write('app_lock_prompted', '1');

      rig.auth.set(null);
      await tester.pumpAndSettle();
      expect(await rig.store.read('app_lock_enabled'), '0');
      expect(await rig.store.read('app_lock_prompted'), '1');
    });
  });
}
