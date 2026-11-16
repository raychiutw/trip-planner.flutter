// 登出確認框的說明文字（ADR-0019：登出一律撤銷，不再有保留說明）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/api/dpop/proof_key_store.dart';
import 'package:tripline/api/oauth/oauth_providers.dart';
import 'package:tripline/api/oauth/oauth_repository.dart';
import 'package:tripline/api/oauth/oauth_token_store.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/settings_store.dart';
import 'package:tripline/app/app_lock.dart';
import 'package:tripline/app/logout_confirm.dart';
import 'package:tripline/models/oauth_tokens.dart';
import 'package:tripline/models/user.dart';

import '../helpers/fake_biometric.dart';
import '../helpers/fake_oauth.dart';

class _MockAuthRepo extends Mock implements AuthRepository {}

class _MockOAuthRepo extends Mock implements OAuthRepository {}

const _user = UserInfo(id: 'u1', email: 'ray@example.com');

void main() {
  late InMemoryOAuthTokenStore store;
  late InMemorySettingsStore settings;
  late InMemoryProofKeyStore keys;
  late _MockOAuthRepo oauthRepo;
  late _MockAuthRepo authRepo;
  late FakeBiometricAuthenticator bio;

  Widget app(Widget home) => ProviderScope(
    key: UniqueKey(),
    overrides: [
      oauthTokenStoreProvider.overrideWithValue(store),
      proofKeyStoreProvider.overrideWithValue(keys),
      oauthRepositoryProvider.overrideWithValue(oauthRepo),
      authRepositoryProvider.overrideWithValue(authRepo),
      biometricAuthenticatorProvider.overrideWithValue(bio),
      settingsStoreProvider.overrideWithValue(settings),
      ...fakeBrowserLoginOverrides(stubBiometric: false),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [GoRoute(path: '/', builder: (_, _) => home)],
      ),
    ),
  );

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

  /// [biometric]：登入憑證是否受生物辨識保護（＝已開啟生物辨識登入）。
  Future<ProviderContainer> pumpSignedIn(
    WidgetTester tester, {
    required bool biometric,
    required Widget home,
    BiometricKind kind = BiometricKind.faceId,
  }) async {
    store = InMemoryOAuthTokenStore();
    settings = InMemorySettingsStore();
    await store.write(
      OAuthTokens(
        accessToken: 'AT',
        refreshToken: 'RT',
        tokenType: 'DPoP',
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
      ),
    );
    if (biometric) await store.setProtection(TokenProtection.biometric);
    keys = InMemoryProofKeyStore();
    await keys.create();
    oauthRepo = _MockOAuthRepo();
    when(
      () => oauthRepo.revokeToken(
        token: any(named: 'token'),
        clientId: any(named: 'clientId'),
        tokenTypeHint: any(named: 'tokenTypeHint'),
      ),
    ).thenAnswer((_) async {});
    authRepo = _MockAuthRepo();
    when(() => authRepo.currentUser()).thenAnswer((_) async => _user);
    bio = FakeBiometricAuthenticator(kind: kind);
    await tester.pumpWidget(app(home));
    await tester.pumpAndSettle();
    final container = containerOf(tester);
    expect((await container.read(authStateProvider.future)), isNotNull);
    return container;
  }

  group('登出確認的說明文字', () {
    bool? result;
    Future<void> openConfirm(
      WidgetTester tester, {
      required bool biometric,
      bool alwaysAsk = true,
    }) async {
      await pumpSignedIn(
        tester,
        biometric: biometric,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () async => result = await confirmLogout(
                context,
                ref,
                alwaysAsk: alwaysAsk,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    // 登出一律撤銷並清除（ADR-0019）：開啟生物辨識登入者也是一般說明，不再提保留。
    testWidgets('開啟者：一般說明，不提仍可用 Face ID 登入或忘記這支手機', (tester) async {
      await openConfirm(tester, biometric: true);

      expect(find.text('確定要登出嗎？'), findsOneWidget);
      expect(find.textContaining('Face ID'), findsNothing);
      expect(find.textContaining('忘記這支手機'), findsNothing);
    });

    testWidgets('開啟者且 alwaysAsk:false、沒有待同步變更：不打擾，直接放行', (tester) async {
      await openConfirm(tester, biometric: true, alwaysAsk: false);

      expect(result, isTrue);
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('未開啟者且 alwaysAsk:false、沒有待同步變更：不打擾，直接放行', (tester) async {
      await openConfirm(tester, biometric: false, alwaysAsk: false);

      expect(result, isTrue);
      expect(find.byType(Dialog), findsNothing);
      expect(find.textContaining('確定要登出嗎'), findsNothing);
    });

    testWidgets('未開啟者：文字不變', (tester) async {
      await openConfirm(tester, biometric: false);

      expect(find.text('確定要登出嗎？'), findsOneWidget);
      expect(find.textContaining('忘記這支手機'), findsNothing);
    });
  });
}
