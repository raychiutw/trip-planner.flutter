import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/dpop/jwk_thumbprint.dart';
import 'package:tripline/api/dpop/proof_key.dart';
import 'package:tripline/api/dpop/proof_key_store.dart';
import 'package:tripline/api/oauth/oauth_login_service.dart';
import 'package:tripline/api/oauth/oauth_repository.dart';
import 'package:tripline/api/oauth/oauth_token_store.dart';
import 'package:tripline/api/oauth/pkce.dart';
import 'package:tripline/api/oauth/stored_bearer_token_source.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/settings_store.dart';
import 'package:tripline/app/passkey_assertion.dart';
import 'package:tripline/app/passkey_login.dart';
import 'package:tripline/app/passkey_platform.dart';
import 'package:tripline/models/oauth_tokens.dart';

import '../helpers/fake_oauth.dart';
import '../helpers/fake_passkey_platform.dart';

class _MockRepo extends Mock implements OAuthRepository {}

OAuthTokens _tokens({String type = 'DPoP'}) => OAuthTokens(
  accessToken: 'AT',
  refreshToken: 'RT',
  tokenType: type,
  expiresAt: DateTime.now().add(const Duration(minutes: 15)),
);

void main() {
  late _MockRepo repo;
  late InMemoryOAuthTokenStore store;
  late InMemoryProofKeyStore keys;
  late InMemorySettingsStore settings;
  late FakePasskeyPlatform platform;
  late PasskeyLoginService service;

  setUp(() {
    repo = _MockRepo();
    store = InMemoryOAuthTokenStore();
    keys = InMemoryProofKeyStore();
    settings = InMemorySettingsStore();
    platform = FakePasskeyPlatform()
      ..assertion = const PasskeyAsserted(fakeAssertionCredential);
    service = PasskeyLoginService(
      repository: repo,
      source: StoredBearerTokenSource(
        store: store,
        repository: repo,
        clientId: 'cid',
        proofKeys: keys,
      ),
      platform: platform,
      proofKeys: keys,
      settings: settings,
      clientId: 'cid',
    );
    when(() => repo.passkeyOptions()).thenAnswer(
      (_) async => {'challenge': 'ch', 'rpId': 'r', 'allowCredentials': []},
    );
    when(
      () => repo.passkeyLogin(
        clientId: any(named: 'clientId'),
        credential: any(named: 'credential'),
        codeChallenge: any(named: 'codeChallenge'),
        dpopJkt: any(named: 'dpopJkt'),
      ),
    ).thenAnswer((_) async => 'CODE');
    when(
      () => repo.exchangeCode(
        code: any(named: 'code'),
        codeVerifier: any(named: 'codeVerifier'),
        clientId: any(named: 'clientId'),
        redirectUri: any(named: 'redirectUri'),
        proofKey: any(named: 'proofKey'),
      ),
    ).thenAnswer((_) async => _tokens());
  });

  void stubLoginError(Object error) => when(
    () => repo.passkeyLogin(
      clientId: any(named: 'clientId'),
      credential: any(named: 'credential'),
      codeChallenge: any(named: 'codeChallenge'),
      dpopJkt: any(named: 'dpopJkt'),
    ),
  ).thenThrow(error);

  VerificationResult verifyLoginCalled() => verify(
    () => repo.passkeyLogin(
      clientId: captureAny(named: 'clientId'),
      credential: captureAny(named: 'credential'),
      codeChallenge: captureAny(named: 'codeChallenge'),
      dpopJkt: captureAny(named: 'dpopJkt'),
    ),
  );

  void stubExchange(Object Function() answer) => when(
    () => repo.exchangeCode(
      code: any(named: 'code'),
      codeVerifier: any(named: 'codeVerifier'),
      clientId: any(named: 'clientId'),
      redirectUri: any(named: 'redirectUri'),
      proofKey: any(named: 'proofKey'),
    ),
  ).thenAnswer((_) async => answer() as OAuthTokens);

  group('登入流程', () {
    test(
      '成功：options → assertion → login(帶 PKCE challenge 與 dpop_jkt) → 以 verifier 換票，憑證交給來源，記旗標',
      () async {
        final tokens = await service.login();

        expect(platform.lastAuthenticateOptions!['challenge'], 'ch');
        final login = verifyLoginCalled().captured;
        expect(login[0], 'cid');
        expect(login[1], fakeAssertionCredential);
        final exchange = verify(
          () => repo.exchangeCode(
            code: captureAny(named: 'code'),
            codeVerifier: captureAny(named: 'codeVerifier'),
            clientId: any(named: 'clientId'),
            redirectUri: captureAny(named: 'redirectUri'),
            proofKey: captureAny(named: 'proofKey'),
          ),
        ).captured;
        expect(exchange[0], 'CODE');
        expect(
          login[2],
          codeChallengeS256(exchange[1] as String),
          reason: 'login 送出的 challenge 必須對應換票的 verifier',
        );
        expect(exchange[2], isNull, reason: 'passkey 簽的 code 沒有 redirect_uri');
        final key = exchange[3] as ProofKey;
        expect(login[3], jwkThumbprint(key), reason: 'dpop_jkt 必須是換票所用金鑰的指紋');
        expect(await keys.load(), same(key), reason: '伺服器綁定了就保留金鑰');
        expect(tokens.accessToken, 'AT');
        expect((await store.read())!.refreshToken, 'RT');
        expect(await settings.read(kPasskeyLoginHintKey), '1');
      },
    );

    test('伺服器沒綁定 DPoP（Bearer）：刪掉剛建的金鑰', () async {
      stubExchange(() => _tokens(type: 'Bearer'));

      await service.login();

      expect(await keys.load(), isNull);
    });

    test('使用者取消：不呼叫 login、不建金鑰，視為取消', () async {
      platform.assertion = const PasskeyAssertCancelled();

      await expectLater(
        service.login(),
        throwsA(
          isA<OAuthLoginException>().having(
            (e) => e.cancelled,
            'cancelled',
            true,
          ),
        ),
      );

      verifyNever(
        () => repo.passkeyLogin(
          clientId: any(named: 'clientId'),
          credential: any(named: 'credential'),
          codeChallenge: any(named: 'codeChallenge'),
          dpopJkt: any(named: 'dpopJkt'),
        ),
      );
      expect(await keys.load(), isNull);
    });

    test('平台失敗：不呼叫 login，丟出非取消的登入例外，旗標保留', () async {
      await settings.write(kPasskeyLoginHintKey, '1');
      platform.assertion = const PasskeyAssertFailed();

      await expectLater(
        service.login(),
        throwsA(
          isA<OAuthLoginException>().having(
            (e) => e.cancelled,
            'cancelled',
            false,
          ),
        ),
      );

      verifyNever(
        () => repo.passkeyLogin(
          clientId: any(named: 'clientId'),
          credential: any(named: 'credential'),
          codeChallenge: any(named: 'codeChallenge'),
          dpopJkt: any(named: 'dpopJkt'),
        ),
      );
      expect(await settings.read(kPasskeyLoginHintKey), '1');
    });

    test('401 PASSKEY_LOGIN_INVALID：通用訊息（不洩漏帳號資訊），刪金鑰、旗標與既有憑證都保留', () async {
      await settings.write(kPasskeyLoginHintKey, '1');
      await store.write(_tokens());
      stubLoginError(
        const ApiError(
          status: 401,
          code: 'PASSKEY_LOGIN_INVALID',
          message: 'm',
        ),
      );

      await expectLater(
        service.login(),
        throwsA(
          isA<OAuthLoginException>()
              .having((e) => e.cancelled, 'cancelled', false)
              .having((e) => e.userMessage, 'userMessage', contains('passkey'))
              .having(
                (e) => e.userMessage,
                'userMessage',
                isNot(contains('帳號')),
              ),
        ),
      );

      expect(await keys.load(), isNull);
      expect(await settings.read(kPasskeyLoginHintKey), '1');
      expect((await store.read())!.refreshToken, 'RT');
    });

    test('429：提示稍後再試', () async {
      stubLoginError(
        const ApiError(status: 429, code: 'LOGIN_RATE_LIMITED', message: 'm'),
      );

      await expectLater(
        service.login(),
        throwsA(
          isA<OAuthLoginException>().having(
            (e) => e.userMessage,
            'userMessage',
            contains('稍後'),
          ),
        ),
      );
    });

    test('換票失敗：刪金鑰、不記旗標', () async {
      when(
        () => repo.exchangeCode(
          code: any(named: 'code'),
          codeVerifier: any(named: 'codeVerifier'),
          clientId: any(named: 'clientId'),
          redirectUri: any(named: 'redirectUri'),
          proofKey: any(named: 'proofKey'),
        ),
      ).thenThrow(
        const ApiError(status: 400, code: 'invalid_grant', message: 'm'),
      );

      await expectLater(service.login(), throwsA(isA<OAuthLoginException>()));

      expect(await keys.load(), isNull);
      expect(await settings.read(kPasskeyLoginHintKey), isNull);
    });

    test('options 取得失敗（斷線）：通用失敗，不進原生層', () async {
      when(() => repo.passkeyOptions()).thenThrow(Exception('offline'));

      await expectLater(service.login(), throwsA(isA<OAuthLoginException>()));

      expect(platform.authenticateCalls, 0);
    });
  });

  group('入口顯示條件（本機提示旗標）', () {
    Future<bool> entry({
      required bool flag,
      required bool supported,
      InMemorySettingsStore? store,
    }) async {
      final s = store ?? InMemorySettingsStore();
      if (flag) await s.write(kPasskeyLoginHintKey, '1');
      final container = ProviderContainer(
        overrides: [
          settingsStoreProvider.overrideWithValue(s),
          passkeyPlatformProvider.overrideWithValue(
            FakePasskeyPlatform()..supported = supported,
          ),
        ],
      );
      addTearDown(container.dispose);
      return container.read(passkeyLoginEntryProvider.future);
    }

    test('有旗標且平台支援 → 顯示', () async {
      expect(await entry(flag: true, supported: true), isTrue);
    });

    test('沒旗標 → 不顯示', () async {
      expect(await entry(flag: false, supported: true), isFalse);
    });

    test('平台不支援 → 不顯示', () async {
      expect(await entry(flag: true, supported: false), isFalse);
    });

    test('markPasskeyLoginHint 之後才顯示', () async {
      final s = InMemorySettingsStore();
      expect(await entry(flag: false, supported: true, store: s), isFalse);
      await markPasskeyLoginHint(s);
      expect(await entry(flag: false, supported: true, store: s), isTrue);
    });

    test('登出不清旗標：登出後入口仍在', () async {
      final s = InMemorySettingsStore();
      await s.write(kPasskeyLoginHintKey, '1');
      final container = ProviderContainer(
        overrides: [
          settingsStoreProvider.overrideWithValue(s),
          passkeyPlatformProvider.overrideWithValue(FakePasskeyPlatform()),
          ...signedInOverrides(),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authStateProvider.notifier).logout();

      expect(await s.read(kPasskeyLoginHintKey), '1');
      expect(await container.read(passkeyLoginEntryProvider.future), isTrue);
    });
  });
}
