import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/oauth/oauth_config.dart';
import 'package:tripline/api/oauth/oauth_login_service.dart';
import 'package:tripline/api/oauth/oauth_repository.dart';
import 'package:tripline/api/oauth/oauth_token_store.dart';
import 'package:tripline/api/oauth/stored_bearer_token_source.dart';
import 'package:tripline/models/oauth_tokens.dart';

class _MockRepo extends Mock implements OAuthRepository {}

/// 假的授權啟動器：模擬使用者在瀏覽器完成登入後，https callback 帶回來的網址。
class _FakeLauncher implements AuthorizationLauncher {
  Uri? lastAuthorizeUrl;
  String? lastHost;
  String? lastPath;
  Object? error;
  Map<String, String> Function(Uri authorizeUrl)? reply;

  @override
  Future<Uri> authorize(
    Uri authorizeUrl, {
    required String callbackHost,
    required String callbackPath,
  }) async {
    lastAuthorizeUrl = authorizeUrl;
    lastHost = callbackHost;
    lastPath = callbackPath;
    if (error != null) throw error!;
    final params =
        reply?.call(authorizeUrl) ??
        {'code': 'CODE', 'state': authorizeUrl.queryParameters['state']!};
    return Uri.https(callbackHost, callbackPath, params);
  }
}

void main() {
  late _MockRepo repo;
  late InMemoryOAuthTokenStore store;
  late StoredBearerTokenSource source;
  late _FakeLauncher launcher;
  late OAuthLoginService service;

  setUp(() {
    repo = _MockRepo();
    store = InMemoryOAuthTokenStore();
    source = StoredBearerTokenSource(
      store: store,
      repository: repo,
      clientId: 'cid',
    );
    launcher = _FakeLauncher();
    service = OAuthLoginService(
      repository: repo,
      source: source,
      launcher: launcher,
      clientId: 'cid',
    );
    when(
      () => repo.buildAuthorizeUrl(
        clientId: any(named: 'clientId'),
        redirectUri: any(named: 'redirectUri'),
        codeChallenge: any(named: 'codeChallenge'),
        state: any(named: 'state'),
      ),
    ).thenAnswer(
      (i) => Uri.https('api.example', '/api/oauth/authorize', {
        'state': i.namedArguments[#state] as String,
        'redirect_uri': i.namedArguments[#redirectUri] as String,
      }),
    );
    when(
      () => repo.exchangeCode(
        code: any(named: 'code'),
        codeVerifier: any(named: 'codeVerifier'),
        clientId: any(named: 'clientId'),
        redirectUri: any(named: 'redirectUri'),
      ),
    ).thenAnswer(
      (_) async => OAuthTokens(
        accessToken: 'AT',
        refreshToken: 'RT',
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
      ),
    );
  });

  test('用 https callback 的網域與路徑啟動授權，換到 token 後交給憑證來源', () async {
    final tokens = await service.login();

    expect(launcher.lastHost, OAuthConfig.callbackHost);
    expect(launcher.lastPath, OAuthConfig.callbackPath);
    expect(
      launcher.lastAuthorizeUrl!.queryParameters['redirect_uri'],
      startsWith('https://${OAuthConfig.callbackHost}'),
    );
    expect(tokens.accessToken, 'AT');
    expect(await source.accessToken(), 'AT'); // 只在記憶體，不必 refresh
    expect((await store.read())!.refreshToken, 'RT');
  });

  test('callback 的 state 對不上 → 拒絕，不換 token', () async {
    launcher.reply = (_) => {'code': 'CODE', 'state': 'forged'};

    await expectLater(service.login(), throwsA(isA<OAuthLoginException>()));
    verifyNever(
      () => repo.exchangeCode(
        code: any(named: 'code'),
        codeVerifier: any(named: 'codeVerifier'),
        clientId: any(named: 'clientId'),
        redirectUri: any(named: 'redirectUri'),
      ),
    );
  });

  test('授權端回 error → 丟出登入例外，不換 token', () async {
    launcher.reply = (u) => {
      'error': 'access_denied',
      'state': u.queryParameters['state']!,
    };
    await expectLater(service.login(), throwsA(isA<OAuthLoginException>()));
  });

  test('使用者在瀏覽器取消 → 丟出標記為取消的例外，訊息為繁中', () async {
    launcher.error = PlatformException(code: 'CANCELED');

    final error = await service.login().then<Object?>(
      (_) => null,
      onError: (Object e) => e,
    );
    expect(error, isA<OAuthLoginException>());
    expect((error! as OAuthLoginException).cancelled, isTrue);
    expect((error as OAuthLoginException).userMessage, contains('取消'));
  });
}
