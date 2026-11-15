import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/dpop/proof_key_store.dart';
import 'package:tripline/api/oauth/oauth_login_service.dart';
import 'package:tripline/api/oauth/oauth_repository.dart';
import 'package:tripline/api/oauth/oauth_token_store.dart';
import 'package:tripline/api/oauth/stored_bearer_token_source.dart';
import 'package:tripline/models/oauth_tokens.dart';

class _MockRepo extends Mock implements OAuthRepository {}

class _FakeLauncher implements AuthorizationLauncher {
  Object? error;
  Map<String, String> Function(Uri authorizeUrl)? reply;

  @override
  Future<Uri> authorize(
    Uri authorizeUrl, {
    required String callbackHost,
    required String callbackPath,
  }) async {
    if (error != null) throw error!;
    final params =
        reply?.call(authorizeUrl) ??
        {
          'code': 'CODE',
          'state': authorizeUrl.queryParameters['state']!,
          'biometric_intent': 'enable',
        };
    return Uri.https(callbackHost, callbackPath, params);
  }
}

void main() {
  late _MockRepo repo;
  late InMemoryOAuthTokenStore store;
  late InMemoryProofKeyStore keys;
  late _FakeLauncher launcher;
  late OAuthLoginService service;
  late OAuthTokens oldTokens;

  OAuthTokens newTokens() => OAuthTokens(
    accessToken: 'NEW_AT',
    refreshToken: 'NEW_RT',
    tokenType: 'DPoP',
    expiresAt: DateTime.now().add(const Duration(minutes: 15)),
  );

  setUp(() async {
    repo = _MockRepo();
    store = InMemoryOAuthTokenStore();
    keys = InMemoryProofKeyStore();
    oldTokens = OAuthTokens(
      accessToken: 'OLD_AT',
      refreshToken: 'OLD_RT',
      tokenType: 'DPoP',
      expiresAt: DateTime.now().add(const Duration(minutes: 15)),
    );
    await store.write(oldTokens);
    await keys.create();
    final source = StoredBearerTokenSource(
      store: store,
      repository: repo,
      clientId: 'cid',
      proofKeys: keys,
    );
    launcher = _FakeLauncher();
    service = OAuthLoginService(
      repository: repo,
      source: source,
      launcher: launcher,
      clientId: 'cid',
      proofKeys: keys,
    );
    when(
      () => repo.buildAuthorizeUrl(
        clientId: any(named: 'clientId'),
        redirectUri: any(named: 'redirectUri'),
        codeChallenge: any(named: 'codeChallenge'),
        state: any(named: 'state'),
        biometricHint: any(named: 'biometricHint'),
        reauthIntent: any(named: 'reauthIntent'),
        expectedAccount: any(named: 'expectedAccount'),
      ),
    ).thenAnswer(
      (i) => Uri.https('api.example', '/api/oauth/authorize', {
        'state': i.namedArguments[#state] as String,
      }),
    );
    when(
      () => repo.exchangeCode(
        code: any(named: 'code'),
        codeVerifier: any(named: 'codeVerifier'),
        clientId: any(named: 'clientId'),
        redirectUri: any(named: 'redirectUri'),
        proofKey: any(named: 'proofKey'),
      ),
    ).thenAnswer((_) async => newTokens());
    when(
      () => repo.revokeToken(
        token: any(named: 'token'),
        clientId: any(named: 'clientId'),
        tokenTypeHint: any(named: 'tokenTypeHint'),
      ),
    ).thenAnswer((_) async {});
  });

  Future<void> reauth({String intent = 'enable', String? hint}) =>
      service.reauthenticate(
        intent: intent,
        expectedAccount: 'u1',
        biometricHint: hint,
      );

  Future<Object?> reauthError({String intent = 'enable'}) => reauth(
    intent: intent,
  ).then<Object?>((_) => null, onError: (Object e) => e);

  void verifyNoExchangeOrRevoke() {
    verifyNever(
      () => repo.exchangeCode(
        code: any(named: 'code'),
        codeVerifier: any(named: 'codeVerifier'),
        clientId: any(named: 'clientId'),
        redirectUri: any(named: 'redirectUri'),
        proofKey: any(named: 'proofKey'),
      ),
    );
    verifyNever(
      () => repo.revokeToken(
        token: any(named: 'token'),
        clientId: any(named: 'clientId'),
        tokenTypeHint: any(named: 'tokenTypeHint'),
      ),
    );
  }

  Future<void> expectCurrentLoginUntouched() async {
    expect((await store.read())!.refreshToken, 'OLD_RT');
  }

  test('重新驗證遇 access_denied → 視為取消（cancelled 為 true）', () async {
    launcher.reply = (u) => {
      'error': 'access_denied',
      'state': u.queryParameters['state']!,
    };
    final e = await reauthError();
    expect((e! as OAuthLoginException).cancelled, isTrue);
    verifyNoExchangeOrRevoke();
  });

  test('授權網址帶 意圖、expected_account、biometric_hint', () async {
    launcher.reply = (u) => {
      'code': 'CODE',
      'state': u.queryParameters['state']!,
      'biometric_intent': 'disable',
    };
    await reauth(intent: 'disable', hint: 'faceid');

    verify(
      () => repo.buildAuthorizeUrl(
        clientId: 'cid',
        redirectUri: any(named: 'redirectUri'),
        codeChallenge: any(named: 'codeChallenge'),
        state: any(named: 'state'),
        biometricHint: 'faceid',
        reauthIntent: 'disable',
        expectedAccount: 'u1',
      ),
    ).called(1);
  });

  test('callback 帶相同意圖：成功，不兌換授權碼、不撤銷，目前登入的憑證與金鑰原封不動', () async {
    launcher.reply = (u) => {
      'code': 'CODE',
      'state': u.queryParameters['state']!,
      'biometric_intent': 'disable',
    };
    final oldKey = await keys.load();

    await reauth(intent: 'disable');

    await expectCurrentLoginUntouched();
    expect(await keys.load(), same(oldKey), reason: '重新驗證不能換掉目前登入的金鑰');
    verifyNoExchangeOrRevoke();
  });

  for (final flag in <String?>[null, 'disable', '']) {
    test('callback 旗標為 ${flag ?? '缺漏'}、意圖 enable：拒絕，不兌換不撤銷', () async {
      launcher.reply = (u) => {
        'code': 'CODE',
        'state': u.queryParameters['state']!,
        'biometric_intent': ?flag,
      };

      expect(await reauthError(), isA<OAuthLoginException>());
      verifyNoExchangeOrRevoke();
      await expectCurrentLoginUntouched();
    });
  }

  test('使用者關掉授權視窗：取消例外原樣往上丟，目前登入原封不動', () async {
    launcher.error = OAuthLoginException('取消', cancelled: true);

    final e = await reauthError();

    expect((e! as OAuthLoginException).cancelled, isTrue);
    await expectCurrentLoginUntouched();
  });

  test('授權端回 error：失敗（不是帳號不符），目前登入原封不動', () async {
    launcher.reply = (u) => {
      'error': 'invalid_request',
      'state': u.queryParameters['state']!,
    };

    final e = await reauthError() as OAuthLoginException;

    expect(e.accountMismatch, isFalse);
    await expectCurrentLoginUntouched();
  });

  group('callback 帶 error=reauth_account_mismatch（api 判定帳號不符）', () {
    void replyMismatch({String? state}) {
      launcher.reply = (u) => {
        'error': 'reauth_account_mismatch',
        'state': state ?? u.queryParameters['state']!,
      };
    }

    test('丟 accountMismatch 與提示文字；不兌換授權碼、目前登入原封不動', () async {
      replyMismatch();

      final e = await reauthError() as OAuthLoginException;

      expect(e.accountMismatch, isTrue);
      expect(e.cancelled, isFalse);
      expect(e.userMessage, '登入的帳號與目前帳號不同');
      verifyNoExchangeOrRevoke();
      await expectCurrentLoginUntouched();
    });

    test('state 對不上：照常拒絕，不當成帳號不符', () async {
      replyMismatch(state: 'forged');

      final e = await reauthError() as OAuthLoginException;

      expect(e.accountMismatch, isFalse);
      verifyNoExchangeOrRevoke();
      await expectCurrentLoginUntouched();
    });

    test('一般登入收到同樣的 error：維持一般錯誤（不是取消、不是帳號不符）', () async {
      replyMismatch();

      final e =
          await service.login().then<Object?>(
                (_) => null,
                onError: (Object e) => e,
              )
              as OAuthLoginException;

      expect(e.accountMismatch, isFalse);
      expect(e.cancelled, isFalse);
    });
  });
}
