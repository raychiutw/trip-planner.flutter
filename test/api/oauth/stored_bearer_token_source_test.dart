import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/oauth/oauth_repository.dart';
import 'package:tripline/api/oauth/oauth_token_store.dart';
import 'package:tripline/api/oauth/stored_bearer_token_source.dart';
import 'package:tripline/models/oauth_tokens.dart';

class _MockRepo extends Mock implements OAuthRepository {}

OAuthTokens _tokens({
  String access = 'AT',
  String? refresh = 'RT',
  required Duration ttl,
}) =>
    OAuthTokens(
      accessToken: access,
      refreshToken: refresh,
      expiresAt: DateTime.now().add(ttl),
    );

void main() {
  late OAuthTokenStore store;
  late _MockRepo repo;
  late StoredBearerTokenSource source;

  setUp(() {
    store = InMemoryOAuthTokenStore();
    repo = _MockRepo();
    source = StoredBearerTokenSource(
        store: store, repository: repo, clientId: 'cid');
  });

  test('未過期 → 直接回 access(不 refresh)', () async {
    await store.write(_tokens(ttl: const Duration(hours: 1)));
    expect(await source.accessToken(), 'AT');
    verifyNever(() => repo.refresh(
        refreshToken: any(named: 'refreshToken'),
        clientId: any(named: 'clientId')));
  });

  test('過期 → refresh 成功 → 回新 access 並寫回', () async {
    await store.write(_tokens(access: 'OLD', ttl: const Duration(seconds: -1)));
    when(() => repo.refresh(
              refreshToken: any(named: 'refreshToken'),
              clientId: any(named: 'clientId'),
            ))
        .thenAnswer((_) async =>
            _tokens(access: 'NEW', refresh: 'RT2', ttl: const Duration(hours: 1)));

    expect(await source.accessToken(), 'NEW');
    expect((await store.read())!.accessToken, 'NEW');
  });

  test('無 refresh token → refresh false', () async {
    await store.write(_tokens(refresh: null, ttl: const Duration(hours: 1)));
    expect(await source.refresh(), isFalse);
  });

  test('refresh 失敗 → clear + false', () async {
    await store.write(_tokens(ttl: const Duration(seconds: -1)));
    when(() => repo.refresh(
          refreshToken: any(named: 'refreshToken'),
          clientId: any(named: 'clientId'),
        )).thenThrow(Exception('expired'));

    expect(await source.refresh(), isFalse);
    expect(await store.read(), isNull); // 已清空
  });

  test('無 tokens → accessToken null', () async {
    expect(await source.accessToken(), isNull);
  });
}
