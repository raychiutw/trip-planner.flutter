import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/account_repository.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/features/account/settings/change_password_screen.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_app_bar.dart';

import '../../../helpers/fake_oauth.dart';

class _MockAccountRepo extends Mock implements AccountRepository {}

void main() {
  late _MockAccountRepo accountRepo;

  const oldPassword = 'old-password-12345';
  const newPassword = 'brand-new-pass-678';

  setUp(() => accountRepo = _MockAccountRepo());

  Widget buildApp() {
    final router = GoRouter(
      initialLocation: '/settings/password',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('帳號首頁')),
          routes: [
            GoRoute(
              path: 'settings/password',
              builder: (_, _) => const ChangePasswordScreen(),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    return ProviderScope(
      retry: (_, _) => null,
      overrides: [
        ...signedInOverrides(),
        accountRepositoryProvider.overrideWithValue(accountRepo),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
  }

  final current = find.byKey(const ValueKey('change-password-current'));
  final next = find.byKey(const ValueKey('change-password-new'));
  final submit = find.byKey(const ValueKey('change-password-submit'));

  bool submitEnabled(WidgetTester tester) =>
      tester.widget<TpToolbarTextButton>(submit).onPressed != null;
  TextField inner(WidgetTester tester, Finder f) => tester.widget<TextField>(f);

  Future<void> fill(WidgetTester tester, String cur, String nw) async {
    await tester.enterText(current, cur);
    await tester.enterText(next, nw);
    await tester.pump();
  }

  ApiError apiError(int status, String code) =>
      ApiError(status: status, code: code, message: code);

  testWidgets('欄位預設遮蔽，帶 currentPassword／newPassword 的自動填入提示', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(inner(tester, current).obscureText, isTrue);
    expect(inner(tester, next).obscureText, isTrue);
    expect(
      inner(tester, current).autofillHints,
      contains(AutofillHints.password),
    );
    expect(
      inner(tester, next).autofillHints,
      contains(AutofillHints.newPassword),
    );
  });

  testWidgets('說明字不被截成一行（HIG 截圖發現：後半句被省略號吃掉）', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    final decoration = inner(tester, next).decoration!;
    expect(decoration.helperMaxLines, greaterThanOrEqualTo(3));
    expect(decoration.helperText, contains('這台維持登入'));
  });

  testWidgets('顯示／隱藏切換新密碼', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('change-password-visibility-toggle')),
    );
    await tester.pump();
    expect(inner(tester, next).obscureText, isFalse);
    await tester.tap(
      find.byKey(const ValueKey('change-password-visibility-toggle')),
    );
    await tester.pump();
    expect(inner(tester, next).obscureText, isTrue);
  });

  testWidgets('主要動作：任一欄空白時停用；兩欄都有填就啟用，即使內容不合法（按了看原因）', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    expect(submitEnabled(tester), isFalse);

    await fill(tester, oldPassword, '');
    expect(submitEnabled(tester), isFalse);
    await fill(tester, '', newPassword);
    expect(submitEnabled(tester), isFalse);
    await fill(tester, oldPassword, 'short');
    expect(submitEnabled(tester), isTrue);
  });

  testWidgets('新密碼少於 8 字元：打字中不跳錯，離開欄位後才提示；按主要動作也提示且不送出', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await fill(tester, oldPassword, 'short');
    expect(find.text('新密碼至少 8 字元'), findsNothing);

    await tester.tap(current); // 離開新密碼欄位
    await tester.pump();
    expect(find.text('新密碼至少 8 字元'), findsOneWidget);
    expect(submitEnabled(tester), isTrue);
    verifyNever(
      () => accountRepo.changePassword(
        currentPassword: any(named: 'currentPassword'),
        newPassword: any(named: 'newPassword'),
      ),
    );
  });

  testWidgets('不離開欄位直接按主要動作：本地規則不過就提示、不送出', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await fill(tester, oldPassword, 'short');
    await tester.tap(submit);
    await tester.pump();

    expect(find.text('新密碼至少 8 字元'), findsOneWidget);
    verifyNever(
      () => accountRepo.changePassword(
        currentPassword: any(named: 'currentPassword'),
        newPassword: any(named: 'newPassword'),
      ),
    );
  });

  testWidgets('新密碼與目前密碼相同：按主要動作提示且不送出；改對後提示消失', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await fill(tester, oldPassword, oldPassword);
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('新密碼不能和目前密碼相同'), findsOneWidget);
    verifyNever(
      () => accountRepo.changePassword(
        currentPassword: any(named: 'currentPassword'),
        newPassword: any(named: 'newPassword'),
      ),
    );

    await fill(tester, oldPassword, newPassword);
    expect(find.text('新密碼不能和目前密碼相同'), findsNothing);
  });

  testWidgets('成功：帶兩個密碼呼叫 changePassword，提示成功並回上一頁', (tester) async {
    when(
      () => accountRepo.changePassword(
        currentPassword: any(named: 'currentPassword'),
        newPassword: any(named: 'newPassword'),
      ),
    ).thenAnswer((_) async {});
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await fill(tester, oldPassword, newPassword);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    verify(
      () => accountRepo.changePassword(
        currentPassword: oldPassword,
        newPassword: newPassword,
      ),
    ).called(1);
    expect(find.text('帳號首頁'), findsOneWidget);
    expect(find.textContaining('密碼已更新'), findsOneWidget);
  });

  group('失敗：就地顯示、保留已輸入內容、不離開頁面', () {
    Future<void> failWith(WidgetTester tester, Object error) async {
      when(
        () => accountRepo.changePassword(
          currentPassword: any(named: 'currentPassword'),
          newPassword: any(named: 'newPassword'),
        ),
      ).thenThrow(error);
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      await fill(tester, oldPassword, newPassword);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      // 沒有離開、輸入還在、可以再送
      expect(find.text('帳號首頁'), findsNothing);
      expect(inner(tester, current).controller!.text, oldPassword);
      expect(inner(tester, next).controller!.text, newPassword);
      expect(submitEnabled(tester), isTrue);
    }

    testWidgets('目前密碼不正確（403 CHANGE_PASSWORD_CURRENT_INVALID）', (tester) async {
      await failWith(tester, apiError(403, 'CHANGE_PASSWORD_CURRENT_INVALID'));
      expect(find.text('目前密碼不正確'), findsOneWidget);
    });

    testWidgets('被限流（429 CHANGE_PASSWORD_RATE_LIMITED）', (tester) async {
      await failWith(tester, apiError(429, 'CHANGE_PASSWORD_RATE_LIMITED'));
      expect(find.text('嘗試次數過多，請稍後再試'), findsOneWidget);
    });

    testWidgets('沒有密碼的帳號（409 CHANGE_PASSWORD_NO_PASSWORD）', (tester) async {
      await failWith(tester, apiError(409, 'CHANGE_PASSWORD_NO_PASSWORD'));
      expect(find.text('此帳號沒有設定密碼'), findsOneWidget);
    });

    // 本地已先擋過短／相同；server 仍回這兩個碼時（規則不同步）：有繁中說明就照用，
    // 沒有就落到通用文案，不露出 code。
    testWidgets('server 回 CHANGE_PASSWORD_TOO_SHORT 且帶繁中說明：顯示 server 的說明', (
      tester,
    ) async {
      await failWith(
        tester,
        const ApiError(
          status: 400,
          code: 'CHANGE_PASSWORD_TOO_SHORT',
          message: '新密碼至少 10 字元',
        ),
      );
      expect(find.text('新密碼至少 10 字元'), findsOneWidget);
    });

    testWidgets('server 回 CHANGE_PASSWORD_SAME 沒有繁中說明：通用文案，不露出 code', (
      tester,
    ) async {
      await failWith(tester, apiError(400, 'CHANGE_PASSWORD_SAME'));
      expect(find.text('無法變更密碼，請稍後再試'), findsOneWidget);
      expect(find.textContaining('CHANGE_PASSWORD_SAME'), findsNothing);
    });

    testWidgets('其他錯誤與網路失敗：通用的稍後再試', (tester) async {
      await failWith(tester, Exception('socket'));
      expect(find.text('無法變更密碼，請稍後再試'), findsOneWidget);
    });
  });

  testWidgets('被限流：依後端的 Retry-After 告訴使用者要等多久', (tester) async {
    when(
      () => accountRepo.changePassword(
        currentPassword: any(named: 'currentPassword'),
        newPassword: any(named: 'newPassword'),
      ),
    ).thenThrow(
      const ApiError(
        status: 429,
        code: 'CHANGE_PASSWORD_RATE_LIMITED',
        message: 'x',
        retryAfterSeconds: 1800,
      ),
    );
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await fill(tester, oldPassword, newPassword);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('嘗試次數過多，請在 30 分鐘後再試'), findsOneWidget);
  });

  testWidgets('兩個密碼欄位在同一個 AutofillGroup，密碼管理員才能配對目前／新密碼', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    for (final field in [current, next]) {
      expect(
        find.ancestor(of: field, matching: find.byType(AutofillGroup)),
        findsOneWidget,
      );
    }
    expect(
      tester.element(current).findAncestorWidgetOfExactType<AutofillGroup>(),
      same(tester.element(next).findAncestorWidgetOfExactType<AutofillGroup>()),
    );
  });

  testWidgets('送出期間不能重複送出', (tester) async {
    final gate = Completer<void>();
    when(
      () => accountRepo.changePassword(
        currentPassword: any(named: 'currentPassword'),
        newPassword: any(named: 'newPassword'),
      ),
    ).thenAnswer((_) => gate.future);
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await fill(tester, oldPassword, newPassword);

    await tester.tap(submit);
    await tester.pump();
    expect(submitEnabled(tester), isFalse);
    await tester.tap(submit, warnIfMissed: false);
    await tester.pump();

    verify(
      () => accountRepo.changePassword(
        currentPassword: any(named: 'currentPassword'),
        newPassword: any(named: 'newPassword'),
      ),
    ).called(1);
    gate.complete();
    await tester.pumpAndSettle();
  });
}
