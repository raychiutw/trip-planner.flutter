import 'package:flutter/cupertino.dart' show CupertinoDialogAction;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/step_up.dart';
import 'package:tripline/app/passkey_reauth_platform.dart';
import 'package:tripline/app/step_up_dialog.dart';
import 'package:tripline/theme/app_theme.dart';

import '../helpers/fake_passkey_reauth_platform.dart';

class MockStepUpRepository extends Mock implements StepUpRepository {}

void main() {
  late MockStepUpRepository repo;
  late FakePasskeyReauthPlatform platform;
  final navKey = GlobalKey<NavigatorState>();

  const proof = StepUpProof(proof: 'issued', expiresIn: 300);
  const withPasskey = <String, dynamic>{
    'challenge': 'ch',
    'allowCredentials': [
      {'type': 'public-key', 'id': 'cred-1'},
    ],
  };
  const noPasskey = <String, dynamic>{
    'challenge': 'ch',
    'allowCredentials': <dynamic>[],
  };

  ApiError apiError(int status, String code) =>
      ApiError(status: status, code: code, message: 'server');

  /// 開對話框並回傳「最後結果」的 future 與是否已完成的旗標。
  Future<({Future<StepUpProof?> result})> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navKey,
        theme: AppTheme.light(),
        home: const Scaffold(body: SizedBox()),
      ),
    );
    final prompter = DialogStepUpPrompter(
      repository: repo,
      platform: platform,
      contextOf: () => navKey.currentContext,
    );
    final result = prompter.prompt();
    await tester.pumpAndSettle();
    return (result: result);
  }

  Finder key(String k) => find.byKey(ValueKey(k));

  setUp(() {
    repo = MockStepUpRepository();
    platform = FakePasskeyReauthPlatform();
    when(() => repo.options()).thenAnswer((_) async => withPasskey);
  });

  group('passkey 路徑', () {
    testWidgets('有 passkey → 預設用 passkey：簽署後換證明並結束', (tester) async {
      platform.outcome = const PasskeyAsserted(fakeAssertion);
      when(() => repo.passkey(any())).thenAnswer((_) async => proof);
      final opened = await open(tester);

      expect(key('step-up-passkey'), findsOneWidget);
      expect(key('step-up-password-field'), findsNothing);
      await tester.tap(key('step-up-passkey'));
      await tester.pumpAndSettle();

      expect(platform.lastOptions, withPasskey);
      verify(() => repo.passkey(fakeAssertion)).called(1);
      expect((await opened.result)?.proof, 'issued');
      expect(key('step-up-dialog'), findsNothing);
    });

    testWidgets('系統對話框取消 → 留在框內、不顯示錯誤、不呼叫 api', (tester) async {
      platform.outcome = const PasskeyAssertCancelled();
      await open(tester);

      await tester.tap(key('step-up-passkey'));
      await tester.pumpAndSettle();

      expect(key('step-up-dialog'), findsOneWidget);
      expect(key('step-up-error'), findsNothing);
      verifyNever(() => repo.passkey(any()));
    });

    testWidgets('平台失敗 → 提示並可改用密碼', (tester) async {
      platform.outcome = const PasskeyAssertFailed();
      await open(tester);

      await tester.tap(key('step-up-passkey'));
      await tester.pumpAndSettle();

      expect(find.textContaining('無法使用 passkey 驗證'), findsOneWidget);
      await tester.tap(key('step-up-switch'));
      await tester.pumpAndSettle();
      expect(key('step-up-password-field'), findsOneWidget);
    });

    testWidgets('REAUTH_INVALID → 驗證沒有通過；再試會重新取挑戰（挑戰單次有效）', (tester) async {
      platform.outcome = const PasskeyAsserted(fakeAssertion);
      when(
        () => repo.passkey(any()),
      ).thenAnswer((_) async => throw apiError(403, 'REAUTH_INVALID'));
      await open(tester);

      await tester.tap(key('step-up-passkey'));
      await tester.pumpAndSettle();
      expect(find.textContaining('驗證沒有通過'), findsOneWidget);

      await tester.tap(key('step-up-passkey'));
      await tester.pumpAndSettle();

      // 第一次用 open 時取的，第二次送過 api 後作廢、重取。
      verify(() => repo.options()).called(2);
      expect(platform.authenticateCalls, 2);
    });

    testWidgets('429 → 稍後再試', (tester) async {
      platform.outcome = const PasskeyAsserted(fakeAssertion);
      when(
        () => repo.passkey(any()),
      ).thenAnswer((_) async => throw apiError(429, 'REAUTH_RATE_LIMITED'));
      await open(tester);

      await tester.tap(key('step-up-passkey'));
      await tester.pumpAndSettle();

      expect(find.textContaining('請稍後再試'), findsOneWidget);
    });
  });

  group('密碼路徑', () {
    setUp(() {
      when(() => repo.options()).thenAnswer((_) async => noPasskey);
    });

    testWidgets('沒有 passkey → 直接是密碼欄，沿用「目前密碼（重新驗證）」文案', (tester) async {
      await open(tester);

      expect(key('step-up-passkey'), findsNothing);
      expect(find.text('目前密碼（重新驗證）'), findsOneWidget);
      // 空密碼不能送出。
      final submit = tester.widget<CupertinoDialogAction>(
        key('step-up-password-submit'),
      );
      expect(submit.onPressed, isNull);
    });

    testWidgets('輸入密碼 → 換證明並結束；密碼框是遮蔽的', (tester) async {
      when(() => repo.password('pw-123')).thenAnswer((_) async => proof);
      final opened = await open(tester);

      final field = tester.widget<EditableText>(
        find.descendant(
          of: key('step-up-password-field'),
          matching: find.byType(EditableText),
        ),
      );
      expect(field.obscureText, isTrue);
      await tester.enterText(key('step-up-password-field'), 'pw-123');
      await tester.pump();
      await tester.tap(key('step-up-password-submit'));
      await tester.pumpAndSettle();

      verify(() => repo.password('pw-123')).called(1);
      expect((await opened.result)?.proof, 'issued');
    });

    testWidgets('REAUTH_INVALID → 驗證沒有通過，留在框內可再輸入', (tester) async {
      when(
        () => repo.password(any()),
      ).thenAnswer((_) async => throw apiError(403, 'REAUTH_INVALID'));
      await open(tester);

      await tester.enterText(key('step-up-password-field'), 'bad');
      await tester.pump();
      await tester.tap(key('step-up-password-submit'));
      await tester.pumpAndSettle();

      expect(find.textContaining('驗證沒有通過'), findsOneWidget);
      expect(key('step-up-password-field'), findsOneWidget);
    });

    testWidgets('429 → 請稍後再試', (tester) async {
      when(
        () => repo.password(any()),
      ).thenAnswer((_) async => throw apiError(429, 'REAUTH_RATE_LIMITED'));
      await open(tester);

      await tester.enterText(key('step-up-password-field'), 'x');
      await tester.pump();
      await tester.tap(key('step-up-password-submit'));
      await tester.pumpAndSettle();

      expect(find.textContaining('請稍後再試'), findsOneWidget);
    });

    testWidgets('409 REAUTH_NO_PASSWORD（只用第三方登入）→ 說明沒有可驗證的方式', (tester) async {
      when(
        () => repo.password(any()),
      ).thenAnswer((_) async => throw apiError(409, 'REAUTH_NO_PASSWORD'));
      await open(tester);

      await tester.enterText(key('step-up-password-field'), 'x');
      await tester.pump();
      await tester.tap(key('step-up-password-submit'));
      await tester.pumpAndSettle();

      expect(find.textContaining('沒有設定密碼'), findsOneWidget);
      expect(find.textContaining('新增一組'), findsOneWidget);
    });

    testWidgets('有 passkey 的帳號也能改用密碼', (tester) async {
      when(() => repo.options()).thenAnswer((_) async => withPasskey);
      when(() => repo.password('pw')).thenAnswer((_) async => proof);
      final opened = await open(tester);

      await tester.tap(key('step-up-switch'));
      await tester.pumpAndSettle();
      await tester.enterText(key('step-up-password-field'), 'pw');
      await tester.pump();
      await tester.tap(key('step-up-password-submit'));
      await tester.pumpAndSettle();

      expect((await opened.result)?.proof, 'issued');
    });
  });

  testWidgets('取消 → 回傳 null，不呼叫任何驗證 api', (tester) async {
    final opened = await open(tester);

    await tester.tap(key('step-up-cancel'));
    await tester.pumpAndSettle();

    expect(await opened.result, isNull);
    verifyNever(() => repo.passkey(any()));
    verifyNever(() => repo.password(any()));
    expect(platform.authenticateCalls, 0);
  });

  testWidgets('取挑戰失敗 → 顯示錯誤並退到密碼', (tester) async {
    when(
      () => repo.options(),
    ).thenAnswer((_) async => throw apiError(429, 'REAUTH_RATE_LIMITED'));
    await open(tester);

    expect(find.textContaining('請稍後再試'), findsOneWidget);
    expect(key('step-up-password-field'), findsOneWidget);
  });

  testWidgets('go_router 的 navigator 取得 context（main() 的接線方式）→ 對話框開得出來', (
    tester,
  ) async {
    when(() => repo.options()).thenAnswer((_) async => noPasskey);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: SizedBox()),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
    final prompter = DialogStepUpPrompter(
      repository: repo,
      platform: platform,
      contextOf: () => router.routerDelegate.navigatorKey.currentContext,
    );

    final result = prompter.prompt();
    await tester.pumpAndSettle();

    expect(key('step-up-dialog'), findsOneWidget);
    await tester.tap(key('step-up-cancel'));
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });

  test('還沒有 navigator（context 取不到）→ 視為取消，不丟例外', () async {
    final prompter = DialogStepUpPrompter(
      repository: repo,
      platform: platform,
      contextOf: () => null,
    );
    expect(await prompter.prompt(), isNull);
  });
}
