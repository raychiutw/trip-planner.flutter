import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/api/credential_store.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/app/app_lock.dart';
import 'package:tripline/app/biometric_login.dart';
import 'package:tripline/features/auth/login_screen.dart';
import 'package:tripline/models/user.dart';

import '../../helpers/fake_biometric.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

const _user = UserInfo(id: 'u1', email: 'a@example.com');
final _button = find.byKey(const ValueKey('login-biometric-button'));

void main() {
  late _MockAuthRepository repo;
  late InMemoryCredentialStore store;
  late FakeBiometricAuthenticator bio;

  setUp(() {
    repo = _MockAuthRepository();
    store = InMemoryCredentialStore();
    bio = FakeBiometricAuthenticator();
    when(() => repo.currentUser()).thenAnswer((_) async => null);
    when(
      () => repo.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => _user);
  });

  Future<ProviderContainer> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
          credentialStoreProvider.overrideWithValue(store),
          biometricAuthenticatorProvider.overrideWithValue(bio),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(path: '/', builder: (_, _) => const LoginScreen()),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(LoginScreen)));
  }

  testWidgets('沒有存帳密：不顯示生物辨識登入', (tester) async {
    await pump(tester);
    expect(_button, findsNothing);
  });

  testWidgets('已存帳密：顯示「使用 Face ID 登入」，點擊驗證後用存下的帳密登入', (tester) async {
    await store.write(
      const SavedCredentials(email: 'a@example.com', password: 'pw1'),
    );
    await pump(tester);
    expect(find.text('使用 Face ID 登入'), findsOneWidget);

    await tester.tap(_button);
    await tester.pumpAndSettle();

    expect(bio.authenticateCalls, 1);
    verify(() => repo.login(email: 'a@example.com', password: 'pw1')).called(1);
  });

  testWidgets('驗證取消：不送出登入', (tester) async {
    await store.write(
      const SavedCredentials(email: 'a@example.com', password: 'pw1'),
    );
    bio.outcomes.add(BiometricOutcome.cancelled);
    await pump(tester);

    await tester.tap(_button);
    await tester.pumpAndSettle();

    verifyNever(
      () => repo.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });

  testWidgets('裝置沒有生物辨識：即使有存帳密也不顯示', (tester) async {
    await store.write(
      const SavedCredentials(email: 'a@example.com', password: 'pw1'),
    );
    bio.kind = null;
    await pump(tester);
    expect(_button, findsNothing);
  });

  testWidgets('手動輸入密碼登入成功：登記帳密，準備詢問是否開啟', (tester) async {
    final container = await pump(tester);
    await tester.enterText(
      find.byKey(const ValueKey('login-email-field')),
      'a@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password-field')),
      'pw1',
    );
    await tester.tap(find.byKey(const ValueKey('login-submit-button')));
    await tester.pumpAndSettle();

    expect(container.read(biometricLoginProvider).promptPending, isTrue);
  });
}
