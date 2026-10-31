import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
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
      ),
    ).thenAnswer((_) async => _tok('FRESH', refresh: 'RT2'));
  });

  StoredBearerTokenSource sourceOn(OAuthTokenStore store) =>
      StoredBearerTokenSource(store: store, repository: repo, clientId: 'cid');

  test('SecureOAuthTokenStore 落地的內容不含 access token', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final store = SecureOAuthTokenStore();
    await store.write(_tok('SECRET_ACCESS'));

    final raw = await const FlutterSecureStorage().read(
      key: 'tripline_oauth_tokens',
    );
    expect(raw, isNot(contains('SECRET_ACCESS')));
    final json = jsonDecode(raw!) as Map<String, dynamic>;
    expect(json.containsKey('access_token'), isFalse);
    expect(json['refresh_token'], 'RT');
    expect((await store.read())!.refreshToken, 'RT');
  });

  test('登入後 adopt：access token 只在記憶體，store 只留 refresh', () async {
    final store = InMemoryOAuthTokenStore();
    final source = sourceOn(store);

    await source.adopt(_tok('AT'));

    expect(await source.accessToken(), 'AT');
    verifyNever(
      () => repo.refresh(
        refreshToken: any(named: 'refreshToken'),
        clientId: any(named: 'clientId'),
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
    verify(() => repo.refresh(refreshToken: 'RT', clientId: 'cid')).called(1);
  });

  test('登出清掉 store 後，記憶體裡的 access token 不能繼續用', () async {
    final store = InMemoryOAuthTokenStore();
    final source = sourceOn(store);
    await source.adopt(_tok('AT'));

    await store.clear();

    expect(await source.accessToken(), isNull);
  });
}
