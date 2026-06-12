import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/oauth/oauth_repository.dart';
import 'package:tripline/api/oauth/oauth_token_store.dart';
import 'package:tripline/api/oauth/stored_bearer_token_source.dart';
import 'package:tripline/models/oauth_tokens.dart';

class _MockRepo extends Mock implements OAuthRepository {}

/// 寫入永遠失敗的 store(測 write 失敗不清空)。
class _WriteFailStore implements OAuthTokenStore {
  _WriteFailStore(this._tokens);
  OAuthTokens? _tokens;
  bool cleared = false;
  @override
  Future<OAuthTokens?> read() async => _tokens;
  @override
  Future<void> write(OAuthTokens tokens) async => throw Exception('disk full');
  @override
  Future<void> clear() async {
    cleared = true;
    _tokens = null;
  }
}

OAuthTokens _tok({
  String access = 'AT',
  String? refresh = 'RT',
  required Duration ttl,
}) => OAuthTokens(
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
      store: store,
      repository: repo,
      clientId: 'cid',
    );
  });

  test('未過期 → 直接回 access(不 refresh)', () async {
    await store.write(_tok(ttl: const Duration(hours: 1)));
    expect(await source.accessToken(), 'AT');
    verifyNever(
      () => repo.refresh(
        refreshToken: any(named: 'refreshToken'),
        clientId: any(named: 'clientId'),
      ),
    );
  });

  test('過期 → refresh 成功 → 新 access 寫回', () async {
    await store.write(_tok(access: 'OLD', ttl: const Duration(seconds: -1)));
    when(
      () => repo.refresh(
        refreshToken: any(named: 'refreshToken'),
        clientId: any(named: 'clientId'),
      ),
    ).thenAnswer(
      (_) async =>
          _tok(access: 'NEW', refresh: 'RT2', ttl: const Duration(hours: 1)),
    );
    expect(await source.accessToken(), 'NEW');
    expect((await store.read())!.accessToken, 'NEW');
  });

  test('refresh 回應無 id_token → 沿用舊 idToken(身分不丟)', () async {
    await store.write(
      OAuthTokens(
        accessToken: 'OLD',
        refreshToken: 'RT',
        idToken: 'OLD_ID',
        expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
      ),
    );
    when(
      () => repo.refresh(
        refreshToken: any(named: 'refreshToken'),
        clientId: any(named: 'clientId'),
      ),
    ).thenAnswer(
      (_) async => OAuthTokens(
        accessToken: 'NEW',
        refreshToken: 'RT2',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ),
    ); // 無 id_token
    expect(await source.refresh(), isTrue);
    expect((await store.read())!.idToken, 'OLD_ID');
  });

  test('無 refresh token → false', () async {
    await store.write(_tok(refresh: null, ttl: const Duration(hours: 1)));
    expect(await source.refresh(), isFalse);
  });

  test('refresh 端 401 → clear（真的失效）', () async {
    await store.write(_tok(ttl: const Duration(seconds: -1)));
    when(
      () => repo.refresh(
        refreshToken: any(named: 'refreshToken'),
        clientId: any(named: 'clientId'),
      ),
    ).thenThrow(
      const ApiError(status: 401, code: 'invalid_grant', message: 'x'),
    );
    expect(await source.refresh(), isFalse);
    expect(await store.read(), isNull);
  });

  test('refresh 暫時性錯誤(網路)→ 保留 token,不清空', () async {
    await store.write(_tok(ttl: const Duration(seconds: -1)));
    when(
      () => repo.refresh(
        refreshToken: any(named: 'refreshToken'),
        clientId: any(named: 'clientId'),
      ),
    ).thenThrow(Exception('network'));
    expect(await source.refresh(), isFalse);
    expect(await store.read(), isNotNull); // 未清空
  });

  test('write 失敗 → 不清空,本輪仍回新 access', () async {
    final failStore = _WriteFailStore(
      _tok(access: 'OLD', ttl: const Duration(seconds: -1)),
    );
    final src = StoredBearerTokenSource(
      store: failStore,
      repository: repo,
      clientId: 'cid',
    );
    when(
      () => repo.refresh(
        refreshToken: any(named: 'refreshToken'),
        clientId: any(named: 'clientId'),
      ),
    ).thenAnswer(
      (_) async => _tok(access: 'NEW', ttl: const Duration(hours: 1)),
    );
    expect(await src.accessToken(), 'NEW');
    expect(failStore.cleared, isFalse);
  });

  test('並發過期 → single-flight(repo.refresh 僅 1 次)', () async {
    await store.write(_tok(ttl: const Duration(seconds: -1)));
    var calls = 0;
    when(
      () => repo.refresh(
        refreshToken: any(named: 'refreshToken'),
        clientId: any(named: 'clientId'),
      ),
    ).thenAnswer((_) async {
      calls++;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return _tok(access: 'NEW', ttl: const Duration(hours: 1));
    });
    final results = await Future.wait([
      source.accessToken(),
      source.accessToken(),
      source.accessToken(),
    ]);
    expect(results, ['NEW', 'NEW', 'NEW']);
    expect(calls, 1);
  });

  test('無 tokens → null', () async {
    expect(await source.accessToken(), isNull);
  });
}
