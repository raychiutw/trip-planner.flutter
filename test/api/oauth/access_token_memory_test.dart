import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/oauth/oauth_repository.dart';
import 'package:tripline/api/oauth/oauth_token_store.dart';
import 'package:tripline/api/oauth/stored_bearer_token_source.dart';
import 'package:tripline/models/oauth_tokens.dart';

class _MockRepo extends Mock implements OAuthRepository {}

OAuthTokens _tok(String access, {String refresh = 'RT'}) => OAuthTokens(
  accessToken: access,
  refreshToken: refresh,
  idToken: 'ID',
  expiresAt: DateTime.now().add(const Duration(minutes: 15)),
);

void main() {
  late _MockRepo repo;
  setUp(() {
    repo = _MockRepo();
    when(
      () => repo.refresh(
        refreshToken: any(named: 'refreshToken'),
        clientId: any(named: 'clientId'),
        proofKey: any(named: 'proofKey'),
      ),
    ).thenAnswer((_) async => _tok('FRESH', refresh: 'RT2'));
  });

  StoredBearerTokenSource sourceOn(OAuthTokenStore store) =>
      StoredBearerTokenSource(store: store, repository: repo, clientId: 'cid');

  test('登入後 adopt：access token 只在記憶體，store 只留 refresh', () async {
    final store = InMemoryOAuthTokenStore();
    final source = sourceOn(store);

    await source.adopt(_tok('AT'));

    expect(await source.accessToken(), 'AT');
    verifyNever(
      () => repo.refresh(
        refreshToken: any(named: 'refreshToken'),
        clientId: any(named: 'clientId'),
        proofKey: any(named: 'proofKey'),
      ),
    );
    final persisted = (await store.read())!;
    expect(persisted.accessToken, isEmpty);
    expect(persisted.refreshToken, 'RT');
  });

  test('重開 app（新的 source、同一個 store）：先 refresh 才有 access token', () async {
    final store = InMemoryOAuthTokenStore();
    await sourceOn(store).adopt(_tok('AT'));

    final restarted = sourceOn(store);
    expect(await restarted.accessToken(), 'FRESH');
    verify(
      () => repo.refresh(
        refreshToken: 'RT',
        clientId: 'cid',
        proofKey: any(named: 'proofKey'),
      ),
    ).called(1);
  });

  test('登出清掉 store 後，記憶體裡的 access token 不能繼續用', () async {
    final store = InMemoryOAuthTokenStore();
    final source = sourceOn(store);
    await source.adopt(_tok('AT'));

    await store.clear();

    expect(await source.accessToken(), isNull);
  });

  test('refresh 被拒（疑似重放或已撤銷）：清掉憑證並通知登出', () async {
    final store = InMemoryOAuthTokenStore();
    final source = sourceOn(store);
    await source.adopt(
      OAuthTokens(
        accessToken: 'OLD',
        refreshToken: 'RT',
        expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
      ),
    );
    when(
      () => repo.refresh(
        refreshToken: any(named: 'refreshToken'),
        clientId: any(named: 'clientId'),
        proofKey: any(named: 'proofKey'),
      ),
    ).thenThrow(
      const ApiError(status: 400, code: 'invalid_grant', message: 'replayed'),
    );
    var signedOut = 0;
    source.signedOut.listen((_) => signedOut++);

    expect(await source.refresh(), isFalse);
    await Future<void>.delayed(Duration.zero);

    expect(await store.read(), isNull);
    expect(await source.accessToken(), isNull);
    expect(signedOut, 1);
  });

  test('refresh 回應沒有新 refresh token（伺服器不輪替）：沿用舊的，下次還換得到', () async {
    final store = InMemoryOAuthTokenStore();
    final source = sourceOn(store);
    await source.adopt(
      OAuthTokens(
        accessToken: 'OLD',
        refreshToken: 'RT',
        expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
      ),
    );
    when(
      () => repo.refresh(
        refreshToken: any(named: 'refreshToken'),
        clientId: any(named: 'clientId'),
        proofKey: any(named: 'proofKey'),
      ),
    ).thenAnswer(
      (_) async => OAuthTokens(
        accessToken: 'NEW',
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
      ),
    );

    expect(await source.accessToken(), 'NEW');
    expect((await store.read())!.refreshToken, 'RT');
  });

  test('refresh 進行中發生登出：憑證不能被寫回去而復活', () async {
    final store = InMemoryOAuthTokenStore();
    final source = sourceOn(store);
    await source.adopt(
      OAuthTokens(
        accessToken: 'OLD',
        refreshToken: 'RT',
        expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
      ),
    );
    final gate = Completer<OAuthTokens>();
    when(
      () => repo.refresh(
        refreshToken: any(named: 'refreshToken'),
        clientId: any(named: 'clientId'),
        proofKey: any(named: 'proofKey'),
      ),
    ).thenAnswer((_) => gate.future);

    final pending = source.accessToken();
    await Future<void>.delayed(Duration.zero);
    await store.clear(); // 使用者登出
    gate.complete(_tok('LATE', refresh: 'RT2'));

    expect(await pending, isNull);
    expect(await store.read(), isNull);
  });

  test('受保護的憑證還沒解鎖：取不到 access token，但不清憑證、不通知登出', () async {
    final store = _LockedStore();
    final source = sourceOn(store);
    var signedOut = 0;
    source.signedOut.listen((_) => signedOut++);

    expect(await source.accessToken(), isNull);
    await Future<void>.delayed(Duration.zero);

    expect(store.cleared, isFalse);
    expect(signedOut, 0);
  });
}

class _LockedStore extends InMemoryOAuthTokenStore {
  bool cleared = false;

  @override
  Future<OAuthTokens?> read() async => throw const TokenStoreLockedException();

  @override
  Future<void> clear() async => cleared = true;
}
