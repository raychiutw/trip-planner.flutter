import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/account_repository.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/features/account/settings/change_password_screen.dart';
import 'package:tripline/models/user.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_app_bar.dart';

import '../../../helpers/fake_oauth.dart';

class _MockAccountRepo extends Mock implements AccountRepository {}

class _MockAuthRepo extends Mock implements AuthRepository {}

/// 可以由測試切換「目前登入的是誰」的 AuthNotifier。
class _SwitchableAuthNotifier extends AuthNotifier {
  _SwitchableAuthNotifier(this._initial);
  final UserInfo? _initial;
  @override
  Future<UserInfo?> build() async => _initial;
  void switchTo(UserInfo? user) => state = AsyncData(user);
}

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
      expect(find.textContaining('Google'), findsOneWidget);
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

  test('accountHasPasswordProvider：換成另一個帳號登入要重新取，不沿用上一個帳號的結果', () async {
    const googleOnly = UserInfo(id: 'u2', email: 'g@x.com');
    final authRepo = _MockAuthRepo();
    var calls = 0;
    when(() => authRepo.fetchAccountDeletionPreview()).thenAnswer((_) async {
      calls++;
      return AccountDeletionPreview(
        hasPassword: calls == 1,
        tripsOwned: 0,
        collaboratorsAffected: 0,
      );
    });
    final notifier = _SwitchableAuthNotifier(
      const UserInfo(id: 'u1', email: 'p@x.com'),
    );
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepo),
        authStateProvider.overrideWith(() => notifier),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(accountHasPasswordProvider, (_, _) {});
    addTearDown(sub.close);

    await container.read(authStateProvider.future); // notifier 先建起來，才能切換使用者
    expect(await container.read(accountHasPasswordProvider.future), isTrue);

    notifier.switchTo(googleOnly);
    expect(await container.read(accountHasPasswordProvider.future), isFalse);
    expect(calls, 2);
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
