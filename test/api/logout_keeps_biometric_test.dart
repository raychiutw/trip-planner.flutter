// 開啟生物辨識登入者登出時保留憑證，按「登入」直接用生物辨識解鎖（ADR-0020、#650）。
// 認證 owner 層：記憶體 token store＋mock oauth repository。
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/api/dpop/proof_key_store.dart';
import 'package:tripline/api/oauth/oauth_config.dart';
import 'package:tripline/api/oauth/oauth_login_service.dart';
import 'package:tripline/api/oauth/oauth_providers.dart';
import 'package:tripline/api/oauth/oauth_repository.dart';
import 'package:tripline/api/oauth/oauth_token_store.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/models/oauth_tokens.dart';
import 'package:tripline/models/user.dart';

class _MockOAuthRepo extends Mock implements OAuthRepository {}

class _MockAuthRepo extends Mock implements AuthRepository {}

/// web 登入頁：直接回帶授權碼的 callback（使用者在瀏覽器完成登入）。
class _WebLogin implements AuthorizationLauncher {
  int calls = 0;

  @override
  Future<Uri> authorize(
    Uri authorizeUrl, {
    required String callbackHost,
    required String callbackPath,
  }) async {
    calls++;
    return Uri.https(callbackHost, callbackPath, {
      'code': 'CODE',
      'state': authorizeUrl.queryParameters['state']!,
    });
  }
}

/// 記錄讀取次數：讀受生物辨識保護的憑證會跳出系統驗證。
class _CountingStore extends InMemoryOAuthTokenStore {
  int reads = 0;

  /// 生物特徵變更：下一次受保護讀取時系統回報項目失效，儲存層自行清掉並回 null。
  bool invalidateNextRead = false;

  /// 登出後密封標記寫不進去（Keychain／Keystore 錯誤）。
  bool failSealedMarkerWrite = false;

  @override
  Future<void> setSealedAfterLogout(bool kept) async {
    if (kept && failSealedMarkerWrite) throw Exception('vault write failed');
    return super.setSealedAfterLogout(kept);
  }

  @override
  Future<OAuthTokens?> read() async {
    reads++;
    if (invalidateNextRead) {
      invalidateNextRead = false;
      await clear();
      return null;
    }
    return super.read();
  }
}

String _idToken({String sub = 'u1', String email = 'ray@example.com'}) {
  String enc(Map<String, Object?> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp =
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
      1000;
  return '${enc({'alg': 'none'})}.${enc({'sub': sub, 'email': email, 'aud': OAuthConfig.clientId, 'exp': exp})}.sig';
}

OAuthTokens _tokens({
  String refresh = 'RT',
  String sub = 'u1',
  String email = 'ray@example.com',
}) => OAuthTokens(
  accessToken: 'AT',
  refreshToken: refresh,
  idToken: _idToken(sub: sub, email: email),
  tokenType: 'DPoP',
  expiresAt: DateTime.now().add(const Duration(minutes: 15)),
);

void main() {
  late _CountingStore store;
  late InMemoryProofKeyStore keys;
  late _MockOAuthRepo oauthRepo;
  late _MockAuthRepo authRepo;
  late _WebLogin web;
  var refreshes = 0;

  setUp(() async {
    refreshes = 0;
    web = _WebLogin();
    store = _CountingStore();
    await store.write(_tokens());
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
    when(
      () => oauthRepo.refresh(
        refreshToken: any(named: 'refreshToken'),
        clientId: any(named: 'clientId'),
        proofKey: any(named: 'proofKey'),
      ),
    ).thenAnswer((_) async {
      refreshes++;
      return _tokens(refresh: 'RT${refreshes + 1}');
    });
    when(
      () => oauthRepo.buildAuthorizeUrl(
        clientId: any(named: 'clientId'),
        redirectUri: any(named: 'redirectUri'),
        codeChallenge: any(named: 'codeChallenge'),
        state: any(named: 'state'),
        biometricHint: any(named: 'biometricHint'),
        theme: any(named: 'theme'),
      ),
    ).thenAnswer(
      (i) => Uri.https('api.example', '/api/oauth/authorize', {
        'state': i.namedArguments[#state] as String,
      }),
    );
    authRepo = _MockAuthRepo();
    when(
      () => authRepo.currentUser(),
    ).thenAnswer((_) async => const UserInfo(id: 'u1', email: 'x@y.z'));
  });

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        oauthTokenStoreProvider.overrideWithValue(store),
        proofKeyStoreProvider.overrideWithValue(keys),
        oauthRepositoryProvider.overrideWithValue(oauthRepo),
        authRepositoryProvider.overrideWithValue(authRepo),
        authorizationLauncherProvider.overrideWithValue(web),
        webThemeProvider.overrideWithValue(() => 'light'),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  void verifyNeverRevoked() => verifyNever(
    () => oauthRepo.revokeToken(
      token: any(named: 'token'),
      clientId: any(named: 'clientId'),
      tokenTypeHint: any(named: 'tokenTypeHint'),
    ),
  );

  group('開啟生物辨識登入者登出', () {
    setUp(() async => store.setProtection(TokenProtection.biometric));

    test('不呼叫撤銷，憑證與 DPoP 金鑰仍在，狀態為未登入', () async {
      final c = container();
      expect(await c.read(authStateProvider.future), isNotNull);

      await c.read(authStateProvider.notifier).logout();

      expect(c.read(authStateProvider).value, isNull);
      expect(c.read(authStateProvider).hasError, isFalse);
      verifyNeverRevoked();
      expect(await keys.load(), isNotNull, reason: '金鑰要跟憑證一起留下');
      expect(store.protection, TokenProtection.biometric, reason: '仍只接受生物辨識');
      expect((await store.read())?.refreshToken, 'RT2', reason: '憑證要留下');
    });

    test('保留標記寫不進去：改走撤銷並清除，不留下冷啟動會自動解鎖的憑證', () async {
      store.failSealedMarkerWrite = true;
      final c = container();
      await c.read(authStateProvider.future);

      await c.read(authStateProvider.notifier).logout();

      expect(c.read(authStateProvider).value, isNull);
      verify(
        () => oauthRepo.revokeToken(
          token: any(named: 'token'),
          clientId: any(named: 'clientId'),
          tokenTypeHint: any(named: 'tokenTypeHint'),
        ),
      ).called(1);
      expect(await store.read(), isNull, reason: '憑證要清掉');
      expect(await keys.load(), isNull, reason: '金鑰要清掉');
      expect(c.read(authLockedProvider), isFalse);
    });

    test('登出後 API 取 token 不讀受保護憑證（不跳生物辨識）', () async {
      final c = container();
      await c.read(authStateProvider.future);
      await c.read(authStateProvider.notifier).logout();
      store.reads = 0;

      expect(await c.read(bearerTokenSourceProvider).accessToken(), isNull);
      expect(store.reads, 0);
    });

    test('登出後歡迎頁的登入鈕走解鎖（標成還沒解開）', () async {
      final c = container();
      await c.read(authStateProvider.future);

      await c.read(authStateProvider.notifier).logout();

      expect(c.read(authLockedProvider), isTrue);
    });

    test('按登入解鎖：讀受保護憑證 → refresh → 已登入，不開瀏覽器', () async {
      final c = container();
      await c.read(authStateProvider.future);
      await c.read(authStateProvider.notifier).logout();
      store.reads = 0;
      final before = refreshes;

      await c.read(authStateProvider.notifier).unlock();

      expect(c.read(authStateProvider).value?.email, 'ray@example.com');
      expect(store.reads, greaterThan(0), reason: '要經過受保護讀取（生物辨識）');
      expect(refreshes, before + 1, reason: '通過即 refresh');
      expect(c.read(authLockedProvider), isFalse);
    });

    group('按登入時憑證已失效：清除並回到未登入（歡迎頁據此開 web 登入頁）', () {
      Future<ProviderContainer> loggedOut() async {
        final c = container();
        await c.read(authStateProvider.future);
        await c.read(authStateProvider.notifier).logout();
        return c;
      }

      Future<void> expectCleared(ProviderContainer c) async {
        expect(c.read(authStateProvider).value, isNull);
        expect(await store.read(), isNull, reason: '保留的憑證要清掉');
        expect(await keys.load(), isNull, reason: '金鑰與憑證一起清掉');
        expect(await store.hasSealedAfterLogout(), isFalse);
        expect(store.protection, TokenProtection.passcode);
        expect(c.read(authLockedProvider), isFalse, reason: '不再走解鎖');
      }

      test('refresh 被拒（過期、被 web 撤銷）', () async {
        final c = await loggedOut();
        when(
          () => oauthRepo.refresh(
            refreshToken: any(named: 'refreshToken'),
            clientId: any(named: 'clientId'),
            proofKey: any(named: 'proofKey'),
          ),
        ).thenThrow(
          const ApiError(status: 400, code: 'invalid_grant', message: 'x'),
        );

        await c.read(authStateProvider.notifier).unlock();

        await expectCleared(c);
      });

      test('生物特徵變更使金鑰失效', () async {
        final c = await loggedOut();
        store.invalidateNextRead = true;

        await c.read(authStateProvider.notifier).unlock();

        await expectCleared(c);
      });
    });

    group('主動登出後冷啟動', () {
      Future<void> logoutThenRestart() async {
        final c = container();
        await c.read(authStateProvider.future);
        await c.read(authStateProvider.notifier).logout();
        await store.lock(); // 重開 App：受保護的憑證要再驗證才讀得到
        store.reads = 0;
      }

      test('不讀受保護憑證、不跳生物辨識，停在未登入且登入鈕走解鎖', () async {
        await logoutThenRestart();
        final c = container();

        expect(await c.read(authStateProvider.future), isNull);
        expect(store.reads, 0);
        expect(c.read(authLockedProvider), isTrue);
      });

      test('0.42.0 的舊版保留遷移不得誤刪登出後密封的憑證與金鑰', () async {
        await logoutThenRestart();
        final c = container();

        await c.read(authStateProvider.future);

        expect(await store.hasLegacyKeptMarker(), isFalse);
        expect(await keys.load(), isNotNull, reason: '金鑰要留著');
        expect(await store.read(), isNotNull, reason: '憑證要留著');
      });

      test('冷啟動後按登入解鎖 → 已登入；再下一次冷啟動照常自動還原', () async {
        await logoutThenRestart();
        final c = container();
        await c.read(authStateProvider.future);

        await c.read(authStateProvider.notifier).unlock();
        expect(c.read(authStateProvider).value, isNotNull);

        await store.lock();
        store.reads = 0;
        final next = container();
        expect(await next.read(authStateProvider.future), isNotNull);
        expect(store.reads, greaterThan(0), reason: '沒登出的冷啟動照舊讀憑證（跳生物辨識）');
      });
    });
  });

  group('未開啟生物辨識登入者登出', () {
    test('撤銷並清除，登入鈕不走解鎖', () async {
      final c = container();
      expect(await c.read(authStateProvider.future), isNotNull);

      await c.read(authStateProvider.notifier).logout();

      verify(
        () => oauthRepo.revokeToken(
          token: 'RT',
          clientId: OAuthConfig.clientId,
          tokenTypeHint: 'refresh_token',
        ),
      ).called(1);
      expect(await store.read(), isNull);
      expect(await keys.load(), isNull);
      expect(c.read(authLockedProvider), isFalse);
    });
  });

  test('切換帳號（clear: true）：開啟者也撤銷並清除', () async {
    await store.setProtection(TokenProtection.biometric);
    final c = container();
    await c.read(authStateProvider.future);

    await c.read(authStateProvider.notifier).logout(clear: true);

    verify(
      () => oauthRepo.revokeToken(
        token: any(named: 'token'),
        clientId: any(named: 'clientId'),
        tokenTypeHint: any(named: 'tokenTypeHint'),
      ),
    ).called(1);
    expect(await store.read(), isNull);
    expect(await keys.load(), isNull);
  });

  group('保留憑證後改用 web 登入（生物辨識取消或失敗，#651）', () {
    /// web 登入頁換發的新憑證（授權碼交換的結果）。
    void webReturns(OAuthTokens tokens) => when(
      () => oauthRepo.exchangeCode(
        code: any(named: 'code'),
        codeVerifier: any(named: 'codeVerifier'),
        clientId: any(named: 'clientId'),
        redirectUri: any(named: 'redirectUri'),
        proofKey: any(named: 'proofKey'),
      ),
    ).thenAnswer((_) async => tokens);

    /// u1 開啟生物辨識登入後登出（保留），按登入時生物辨識取消。
    Future<ProviderContainer> keptThenCancelled() async {
      await store.setProtection(TokenProtection.biometric);
      final c = container();
      await c.read(authStateProvider.future);
      await c.read(authStateProvider.notifier).logout();
      store.unlockSucceeds = false;
      await c.read(authStateProvider.notifier).unlock();
      expect(c.read(authStateProvider).value, isNull);
      expect(await store.hasSealedAfterLogout(), isTrue, reason: '取消後保留的憑證先不刪');
      return c;
    }

    test('同一帳號登入：保留的憑證換成新的，生物辨識登入維持開啟、保留標記清掉', () async {
      final c = await keptThenCancelled();
      final previousKey = await keys.load();
      webReturns(_tokens(refresh: 'RT-new'));

      await c.read(authStateProvider.notifier).signInWithBrowser();

      expect(c.read(authStateProvider).value?.id, 'u1');
      expect((await store.read())?.refreshToken, 'RT-new', reason: '舊的不殘留');
      expect(store.protection, TokenProtection.biometric);
      expect(await store.hasSealedAfterLogout(), isFalse);
      expect(await keys.load(), isNot(same(previousKey)), reason: '金鑰隨新憑證換新');
    });

    test('不同帳號登入：前一個人的憑證、金鑰與保留標記清掉，新帳號不沿用生物辨識保護', () async {
      final c = await keptThenCancelled();
      final previousKey = await keys.load();
      webReturns(_tokens(refresh: 'RT-u2', sub: 'u2', email: 'b@example.com'));

      await c.read(authStateProvider.notifier).signInWithBrowser();

      expect(web.calls, 1);
      expect(c.read(authStateProvider).value?.id, 'u2');
      expect((await store.read())?.refreshToken, 'RT-u2');
      expect(
        store.protection,
        TokenProtection.passcode,
        reason: '不得沿用前一個人的生物辨識登入',
      );
      expect(await store.hasSealedAfterLogout(), isFalse);
      expect(
        await keys.load(),
        isNot(same(previousKey)),
        reason: '前一個人的金鑰不得留下',
      );
    });
  });
}
