// #584：OAuth callback 直達 App 的 OS 層整合測試（Android）。
//
// 用真的 OAuthLoginService + WebAuthLauncher，只把 token endpoint 換成本機 stub，
// 再以 intent（Patrol openUrl）送 https://<callbackHost>/oauth/callback?code&state。
// 涵蓋 link 路由到 App、背景恢復；**不涵蓋** App Link 擁有權（assetlinks 與網域），
// 那要一次真機手測。
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:patrol/patrol.dart';
import 'package:tripline/api/oauth/oauth_config.dart';
import 'package:tripline/api/oauth/oauth_providers.dart';
import 'package:tripline/api/oauth/oauth_repository.dart';
import 'package:tripline/api/oauth/oauth_token_store.dart';
import 'package:tripline/app/web_auth_launcher.dart';
import 'package:tripline/features/auth/welcome_screen.dart';
import 'package:tripline/features/trips/trips_list_screen.dart';

import '../integration_test/support/app_flow_fixture.dart';

/// 記下 App 產生的 state（隨機，只有 App 知道），授權頁本身不真的開網站。
class _RecordingRepository extends OAuthRepository {
  _RecordingRepository(Dio dio) : super(dio: dio);

  String? state;

  @override
  Uri buildAuthorizeUrl({
    required String clientId,
    required String redirectUri,
    required String codeChallenge,
    required String state,
    String scope = '',
  }) {
    this.state = state;
    return Uri.parse('https://example.com/oauth-stub');
  }
}

class _Harness {
  _Harness(this.fixture) {
    fixture.realOAuth = true;
    final dio = Dio();
    // http_mock_adapter 的 onPost 回呼在「註冊」時就執行、不是請求到達時；計數與登入狀態
    // 必須掛在 interceptor，否則 tokenCalls 一建立就是 1（三情境的計數斷言會假綠或假紅）。
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path.endsWith('/oauth/token')) {
            tokenCalls++;
            fixture.session.signedIn = true;
          }
          handler.next(options);
        },
      ),
    );
    DioAdapter(dio: dio).onPost(
      '/oauth/token',
      (server) => server.reply(200, {
        'access_token': 'AT',
        'refresh_token': 'RT',
        'expires_in': 900,
      }),
      data: Matchers.any,
    );
    repo = _RecordingRepository(dio);
    fixture.extraOverrides.addAll([
      oauthTokenStoreProvider.overrideWithValue(store),
      oauthRepositoryProvider.overrideWithValue(repo),
      authorizationLauncherProvider.overrideWithValue(const WebAuthLauncher()),
    ]);
  }

  final AppFlowFixture fixture;
  final store = InMemoryOAuthTokenStore();
  late final _RecordingRepository repo;
  int tokenCalls = 0;

  String callbackUrl({required String state}) =>
      'https://${OAuthConfig.callbackHost}${OAuthConfig.callbackPath}'
      '?code=stub-code&state=$state';
}

Future<_Harness> _launch(PatrolIntegrationTester $) async {
  final harness = _Harness(AppFlowFixture.loggedOut());
  addTearDown(harness.fixture.dispose);
  await $.tester.pumpWidget(harness.fixture.app);
  await $.tester.pumpAndSettle();
  expect(find.byType(WelcomeScreen), findsOneWidget);
  return harness;
}

/// 按登入並等到 App 已產生 state（授權視窗已要求開啟）。
Future<String> _startLogin(PatrolIntegrationTester $, _Harness h) async {
  await $.tester.tap(find.byKey(const ValueKey('welcome-login-hero')));
  for (var i = 0; i < 50 && h.repo.state == null; i++) {
    await $.tester.pump(const Duration(milliseconds: 100));
  }
  expect(h.repo.state, isNotNull, reason: '登入後 App 應已產生 state');
  return h.repo.state!;
}

Future<void> _expectTripsList(PatrolIntegrationTester $) async {
  for (var i = 0; i < 100; i++) {
    await $.tester.pump(const Duration(milliseconds: 100));
    if (find.byType(TripsListScreen).evaluate().isNotEmpty) return;
  }
  fail('callback 後未進到行程列表');
}

// #592：iOS 上 openUrl 只會開 Safari、不會進 App（授權 callback 由
// ASWebAuthenticationSession 在 session 內攔截），這三情境在 iOS 不成立，見 docs/mobile-e2e.md。
final _iosSkip = Platform.isIOS;

void main() {
  patrolTest('oauth callback in foreground completes login', skip: _iosSkip, (
    $,
  ) async {
    final h = await _launch($);
    final state = await _startLogin($, h);

    await $.platform.mobile.openUrl(h.callbackUrl(state: state));

    await _expectTripsList($);
    expect(h.tokenCalls, 1);
    expect(await h.store.read(), isNotNull);
  });

  patrolTest('oauth callback after pressHome completes login', skip: _iosSkip, (
    $,
  ) async {
    final h = await _launch($);
    final state = await _startLogin($, h);

    await $.platform.mobile.pressHome();
    await $.platform.mobile.openUrl(h.callbackUrl(state: state));
    await $.platform.mobile.openApp();

    await _expectTripsList($);
    expect(h.tokenCalls, 1);
    expect(await h.store.read(), isNotNull);
  });

  // 行程被殺後的等價狀態：沒有進行中的登入（記憶體裡沒有 state／verifier）就收到
  // callback。注意：測試行程與 App 同行程，無法真的殺掉再送，這裡只驗「冷狀態收到
  // callback 不崩、不登入、不落 token」；真正的 process death 仍需手測。
  patrolTest(
    'oauth callback with no live login stays signed out',
    skip: _iosSkip,
    ($) async {
      final h = await _launch($);

      await $.platform.mobile.openUrl(h.callbackUrl(state: 'orphan-state'));
      await $.tester.pump(const Duration(seconds: 3));

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.byType(TripsListScreen), findsNothing);
      expect(h.tokenCalls, 0);
      expect(await h.store.read(), isNull);
      expect($.tester.takeException(), isNull);
    },
  );
}
