import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/dpop/proof_key.dart';
import 'package:tripline/api/dpop/proof_key_store.dart';
import 'package:tripline/api/oauth/oauth_config.dart';
import 'package:tripline/api/oauth/oauth_login_service.dart';
import 'package:tripline/api/oauth/oauth_repository.dart';
import 'package:tripline/api/oauth/oauth_token_store.dart';
import 'package:tripline/api/oauth/stored_bearer_token_source.dart';
import 'package:tripline/models/oauth_tokens.dart';

class _Launcher implements AuthorizationLauncher {
  @override
  Future<Uri> authorize(
    Uri authorizeUrl, {
    required String callbackHost,
    required String callbackPath,
  }) async => Uri.https(callbackHost, callbackPath, {
    'code': 'CODE',
    'state': authorizeUrl.queryParameters['state']!,
  });
}

class _Hardware implements ProofKeyStore {
  _Hardware({this.supported = true});
  final bool supported;
  ProofKey? key;
  int deletes = 0;

  @override
  Future<ProofKey?> load() async => key;

  @override
  Future<ProofKey> create() async {
    if (!supported) throw const ProofKeyUnsupportedException();
    return key = _FakeHardwareKey();
  }

  @override
  Future<void> delete() async {
    deletes++;
    key = null;
  }
}

/// load 暫時讀不到（裝置鎖定等），不代表金鑰不存在。
class _LockedKeys implements ProofKeyStore {
  @override
  Future<ProofKey?> load() async => throw const ProofKeyLockedException();
  @override
  Future<ProofKey> create() async => throw const ProofKeyLockedException();
  @override
  Future<void> delete() async {}
}

class _FakeHardwareKey implements ProofKey {
  final _inner = SoftwareProofKey.generate();
  @override
  String get kind => 'hardware';
  @override
  Map<String, String> get publicJwk => _inner.publicJwk;
  @override
  Future<Uint8List> sign(Uint8List input) => _inner.sign(input);
}

Map<String, dynamic> _claims(String jwt) =>
    jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(jwt.split('.')[1]))),
        )
        as Map<String, dynamic>;

Map<String, dynamic> _header(String jwt) =>
    jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(jwt.split('.')[0]))),
        )
        as Map<String, dynamic>;

void main() {
  late List<RequestOptions> sent;
  late Map<String, dynamic> Function(RequestOptions) reply;
  late int statusCode;
  late OAuthRepository repo;
  late InMemoryOAuthTokenStore store;
  late InMemoryProofKeyStore keys;
  late StoredBearerTokenSource source;

  Map<String, dynamic> tokenBody(String type) => {
    'access_token': 'AT',
    'refresh_token': 'RT',
    'token_type': type,
    'expires_in': 900,
  };

  setUp(() {
    sent = [];
    statusCode = 200;
    reply = (_) => tokenBody('DPoP');
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          sent.add(o);
          h.resolve(
            Response(requestOptions: o, statusCode: statusCode, data: reply(o)),
          );
        },
      ),
    );
    repo = OAuthRepository(dio: dio, origin: 'https://api.example');
    store = InMemoryOAuthTokenStore();
    keys = InMemoryProofKeyStore();
    source = StoredBearerTokenSource(
      store: store,
      repository: repo,
      clientId: 'cid',
      proofKeys: keys,
    );
  });

  OAuthLoginService loginService(ProofKeyStore k) => OAuthLoginService(
    repository: repo,
    source: source,
    launcher: _Launcher(),
    clientId: 'cid',
    proofKeys: k,
  );

  group('token 請求附 proof', () {
    test('code 兌換：帶 DPoP header，htm=POST、htu=token 端點、沒有 ath', () async {
      await loginService(keys).login();

      final proof = sent.single.headers['DPoP'] as String;
      expect(_header(proof)['typ'], 'dpop+jwt');
      expect(_claims(proof)['htm'], 'POST');
      expect(_claims(proof)['htu'], 'https://api.example/api/oauth/token');
      expect(_claims(proof).containsKey('ath'), isFalse);
      expect(_header(proof)['jwk'], (await keys.load())!.publicJwk);
    });

    test('沒有金鑰（舊流程）時不帶 DPoP header', () async {
      final r = await repo.refresh(refreshToken: 'RT', clientId: 'cid');

      expect(sent.single.headers.containsKey('DPoP'), isFalse);
      expect(r.accessToken, 'AT');
    });
  });

  group('依 token_type 決定', () {
    test('回 DPoP：保留金鑰，登入後 tokenType 是 DPoP', () async {
      final tokens = await loginService(keys).login();

      expect(tokens.isDpop, isTrue);
      expect(await keys.load(), isNotNull);
    });

    test('兌換失敗：金鑰不留', () async {
      statusCode = 400;
      reply = (_) => {'error': 'invalid_grant'};

      await expectLater(loginService(keys).login(), throwsA(anything));

      expect(await keys.load(), isNull);
    });

    test('回 Bearer：金鑰用不到，立刻刪掉，不留孤兒', () async {
      reply = (_) => tokenBody('Bearer');

      final tokens = await loginService(keys).login();

      expect(tokens.isDpop, isFalse);
      expect(await keys.load(), isNull);
    });
  });

  group('proofKey()（給 ApiClient 決定 scheme）', () {
    test('DPoP 登入後回登入時的金鑰', () async {
      await loginService(keys).login();

      expect(
        (await source.proofKey())!.publicJwk,
        (await keys.load())!.publicJwk,
      );
    });

    test('Bearer 登入後回 null', () async {
      reply = (_) => tokenBody('Bearer');
      await loginService(keys).login();

      expect(await source.proofKey(), isNull);
    });

    test('登出後回 null', () async {
      await loginService(keys).login();
      await source.clear();

      expect(await source.proofKey(), isNull);
    });
  });

  group('refresh', () {
    test('DPoP 憑證 refresh：用登入時同一把金鑰簽 proof', () async {
      await loginService(keys).login();
      final jwk = (await keys.load())!.publicJwk;
      sent.clear();
      // 讓 access token 過期，強迫 refresh
      await store.write(
        OAuthTokens(
          accessToken: '',
          refreshToken: 'RT',
          tokenType: 'DPoP',
          expiresAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      );
      final fresh = StoredBearerTokenSource(
        store: store,
        repository: repo,
        clientId: 'cid',
        proofKeys: keys,
      );

      expect(await fresh.accessToken(), 'AT');

      final proof = sent.single.headers['DPoP'] as String;
      expect(_header(proof)['jwk'], jwk);
      expect(sent.single.data['grant_type'], 'refresh_token');
    });

    test('金鑰遺失：不打網路，清憑證並通知登出', () async {
      await store.write(
        OAuthTokens(
          accessToken: '',
          refreshToken: 'RT',
          tokenType: 'DPoP',
          expiresAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      );
      var signedOut = 0;
      source.signedOut.listen((_) => signedOut++);

      expect(await source.accessToken(), isNull);
      await Future<void>.delayed(Duration.zero);

      expect(sent, isEmpty);
      expect(await store.read(), isNull);
      expect(signedOut, 1);
    });

    test('refresh 被拒（400）：憑證與金鑰一併刪除', () async {
      await loginService(keys).login();
      await store.write(
        OAuthTokens(
          accessToken: '',
          refreshToken: 'RT',
          tokenType: 'DPoP',
          expiresAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      );
      final fresh = StoredBearerTokenSource(
        store: store,
        repository: repo,
        clientId: 'cid',
        proofKeys: keys,
      );
      statusCode = 400;
      reply = (_) => {'error': 'invalid_grant'};

      expect(await fresh.accessToken(), isNull);

      expect(await store.read(), isNull);
      expect(await keys.load(), isNull);
    });

    test('金鑰暫時讀不到（鎖屏）：不登出、不清憑證，之後再試', () async {
      await store.write(
        OAuthTokens(
          accessToken: '',
          refreshToken: 'RT',
          tokenType: 'DPoP',
          expiresAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      );
      final locked = StoredBearerTokenSource(
        store: store,
        repository: repo,
        clientId: 'cid',
        proofKeys: _LockedKeys(),
      );
      var signedOut = 0;
      locked.signedOut.listen((_) => signedOut++);

      expect(await locked.accessToken(), isNull);
      await Future<void>.delayed(Duration.zero);

      expect(sent, isEmpty);
      expect((await store.read())!.refreshToken, 'RT');
      expect(signedOut, 0);
    });

    test('proofKey()：金鑰暫時讀不到回 null，不丟例外', () async {
      final locked = StoredBearerTokenSource(
        store: store,
        repository: repo,
        clientId: 'cid',
        proofKeys: _LockedKeys(),
      );
      await locked.adopt(
        OAuthTokens(
          accessToken: 'AT',
          refreshToken: 'RT',
          tokenType: 'DPoP',
          expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        ),
      );

      expect(await locked.proofKey(), isNull);
    });

    test('舊的 refresh 被拒時，若期間已用新帳號重新登入：不清掉新的憑證與金鑰', () async {
      await loginService(keys).login();
      await store.write(
        OAuthTokens(
          accessToken: '',
          refreshToken: 'RT',
          tokenType: 'DPoP',
          expiresAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      );
      final fresh = StoredBearerTokenSource(
        store: store,
        repository: repo,
        clientId: 'cid',
        proofKeys: keys,
      );
      statusCode = 400;
      reply = (_) {
        // 回應之前，使用者已登出並重新登入（換了 refresh token）。
        store.write(
          OAuthTokens(
            accessToken: '',
            refreshToken: 'RT-NEW',
            tokenType: 'DPoP',
            expiresAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
        );
        return {'error': 'invalid_grant'};
      };

      await fresh.accessToken();

      expect((await store.read())!.refreshToken, 'RT-NEW');
      expect(await keys.load(), isNotNull);
    });

    test('clear()：清憑證、記憶體與金鑰', () async {
      await loginService(keys).login();

      await source.clear();

      expect(await store.read(), isNull);
      expect(await keys.load(), isNull);
    });
  });

  group('FallbackProofKeyStore：硬體優先，沒有就退軟體', () {
    test('硬體可用：用硬體金鑰', () async {
      final hw = _Hardware();
      final fb = FallbackProofKeyStore(
        hardware: hw,
        software: InMemoryProofKeyStore(),
      );

      expect((await fb.create()).kind, 'hardware');
      expect((await fb.load())!.kind, 'hardware');
    });

    test('硬體不支援：退回軟體金鑰', () async {
      final fb = FallbackProofKeyStore(
        hardware: _Hardware(supported: false),
        software: InMemoryProofKeyStore(),
      );

      expect((await fb.create()).kind, 'software');
      expect((await fb.load())!.kind, 'software');
    });

    test('delete 兩邊都刪', () async {
      final hw = _Hardware();
      final sw = InMemoryProofKeyStore();
      final fb = FallbackProofKeyStore(hardware: hw, software: sw);
      await fb.create();
      await sw.create();

      await fb.delete();

      expect(await hw.load(), isNull);
      expect(await sw.load(), isNull);
    });

    test('create 前先刪舊金鑰（每次登入都是新金鑰）', () async {
      final sw = InMemoryProofKeyStore();
      final fb = FallbackProofKeyStore(
        hardware: _Hardware(supported: false),
        software: sw,
      );
      final first = (await fb.create()).publicJwk;
      final second = (await fb.create()).publicJwk;

      expect(second, isNot(first));
    });
  });

  group('SoftwareProofKeyStore：落地到 vault', () {
    test('create 後重建 store 仍讀得回同一把金鑰；delete 後沒有', () async {
      final vault = MemoryVault();
      final a = SoftwareProofKeyStore(vault: vault);
      final created = await a.create();

      final b = SoftwareProofKeyStore(vault: vault);
      expect((await b.load())!.publicJwk, created.publicJwk);

      await b.delete();
      expect(await SoftwareProofKeyStore(vault: vault).load(), isNull);
    });
  });

  test('OAuthConfig 仍可用（確保 import 不被 lint 移除）', () {
    expect(OAuthConfig.clientId, isNotEmpty);
  });
}

class MemoryVault implements SecretVault {
  final data = <String, String>{};
  @override
  Future<String?> read(
    String key, {
    required TokenProtection protection,
  }) async => data[key];
  @override
  Future<void> write(
    String key,
    String value, {
    required TokenProtection protection,
  }) async => data[key] = value;
  @override
  Future<void> delete(String key) async => data.remove(key);
}
