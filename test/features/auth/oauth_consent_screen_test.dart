import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/features/auth/oauth_consent_screen.dart';
import 'package:tripline/models/oauth.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_app_bar.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository mockAuthRepository;
  late OAuthConsentRequest request;

  setUpAll(() {
    registerFallbackValue(
      const OAuthConsentRequest(
        clientId: 'tp_alpha',
        redirectUri: 'https://app.example.com/callback',
        scope: 'openid',
        state: 'abc123',
        responseType: 'code',
      ),
    );
  });

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    request = OAuthConsentRequest.fromUri(
      Uri.parse(
        'https://trip.example/oauth/consent?client_id=tp_alpha'
        '&redirect_uri=https%3A%2F%2Fapp.example.com%2Fcallback'
        '&scope=openid%20email'
        '&state=abc123'
        '&response_type=code',
      ),
    );
    when(
      () => mockAuthRepository.fetchOAuthClientName(any()),
    ).thenAnswer((_) async => 'Tokyo Planner');
    when(
      () => mockAuthRepository.submitOAuthConsent(
        any(),
        decision: any(named: 'decision'),
      ),
    ).thenAnswer(
      (_) async => const OAuthConsentResult(
        statusCode: 302,
        redirectLocation: '/api/oauth/authorize?client_id=tp_alpha',
      ),
    );
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: OAuthConsentScreen(request: request),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('顯示 OAuth 授權請求與 scope 說明', (tester) async {
    await pumpScreen(tester);

    expect(find.text('授權請求'), findsOneWidget);
    expect(find.text('Tokyo Planner'), findsOneWidget);
    expect(find.text('未知應用程式 (client_id=tp_alpha)'), findsNothing);
    expect(find.text('識別您的身分（唯一 ID）'), findsOneWidget);
    expect(find.text('您的電子郵件地址'), findsOneWidget);
  });

  testWidgets('OAuth consent 使用 inline Header 的取消與 trailing 文字動作', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.byKey(const ValueKey('tp-app-bar-cancel')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(TpAppBar),
        matching: find.byKey(const Key('oauth-consent-allow')),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('account-avatar-button')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('tp-app-bar-cancel')));
    await tester.pumpAndSettle();

    verify(
      () => mockAuthRepository.submitOAuthConsent(request, decision: 'deny'),
    ).called(1);
  });

  testWidgets('client-info 查詢失敗保留未知應用程式 fallback', (tester) async {
    when(
      () => mockAuthRepository.fetchOAuthClientName(any()),
    ).thenThrow(Exception('offline'));

    await pumpScreen(tester);

    expect(find.text('未知應用程式 (client_id=tp_alpha)'), findsOneWidget);
    expect(find.byKey(const Key('oauth-consent-allow')), findsOneWidget);
  });

  testWidgets('OAuth deep link 不完整時取消安全返回且不送 API', (tester) async {
    request = OAuthConsentRequest.fromUri(
      Uri.parse('https://trip.example/oauth/consent?client_id=tp_alpha'),
    );
    await pumpScreen(tester);

    final allow = tester.widget<TpToolbarTextButton>(
      find.byKey(const Key('oauth-consent-allow')),
    );
    expect(allow.onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('tp-app-bar-cancel')));
    await tester.pumpAndSettle();

    verifyNever(
      () => mockAuthRepository.submitOAuthConsent(
        any(),
        decision: any(named: 'decision'),
      ),
    );
  });

  testWidgets('同意授權送出 allow 並顯示 redirect location', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('oauth-consent-allow')));
    await tester.pumpAndSettle();

    verify(
      () => mockAuthRepository.submitOAuthConsent(request, decision: 'allow'),
    ).called(1);
    expect(find.text('已送出授權'), findsOneWidget);
    expect(
      find.text('/api/oauth/authorize?client_id=tp_alpha'),
      findsOneWidget,
    );
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('oauth-consent-result')))
          .getSemanticsData()
          .flagsCollection
          .isLiveRegion,
      isTrue,
    );
  });

  testWidgets('授權 submitting 時防止重複送出', (tester) async {
    final pending = Completer<OAuthConsentResult>();
    when(
      () => mockAuthRepository.submitOAuthConsent(
        any(),
        decision: any(named: 'decision'),
      ),
    ).thenAnswer((_) => pending.future);
    await pumpScreen(tester);

    final allow = find.byKey(const Key('oauth-consent-allow'));
    await tester.tap(allow);
    await tester.tap(allow);

    verify(
      () => mockAuthRepository.submitOAuthConsent(request, decision: 'allow'),
    ).called(1);

    pending.complete(
      const OAuthConsentResult(
        statusCode: 302,
        redirectLocation: '/api/oauth/authorize?client_id=tp_alpha',
      ),
    );
    await tester.pumpAndSettle();
  });
}
