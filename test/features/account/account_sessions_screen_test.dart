import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/account_repository.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/account/account_sessions_screen.dart';
import 'package:tripline/features/account/connected_apps_screen.dart';
import 'package:tripline/models/oauth.dart';
import 'package:tripline/models/user.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_app_bar.dart';

class MockTripRepository extends Mock
    implements TripRepository, AccountRepository {}

class MockAuthRepository extends Mock implements AuthRepository {}

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._user, this.logoutCalls);

  final UserInfo? _user;
  final List<void> logoutCalls;

  @override
  Future<UserInfo?> build() async => _user;

  @override
  Future<void> logout() async {
    logoutCalls.add(null);
    state = const AsyncData(null);
  }
}

void main() {
  late MockTripRepository mockTripRepository;
  late MockAuthRepository mockAuthRepository;
  late List<void> logoutCalls;

  const currentSession = AccountSession(
    sid: 'sid-current',
    uaSummary: 'Chrome on Windows',
    ipHashPrefix: 'a1b2c3',
    createdAt: '2026-07-01T10:00:00Z',
    lastSeenAt: '2026-07-08T09:30:00Z',
    isCurrent: true,
  );
  const phoneSession = AccountSession(
    sid: 'sid-phone',
    uaSummary: 'Safari on iPhone',
    createdAt: '2026-07-02T10:00:00Z',
    lastSeenAt: '2026-07-08T08:00:00Z',
    isCurrent: false,
  );
  const loggedInUser = UserInfo(
    id: 'user-1',
    email: 'traveler@example.com',
    emailVerified: true,
    displayName: 'Ray',
  );

  Future<ProviderContainer> pumpScreen(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        tripRepositoryProvider.overrideWithValue(mockTripRepository),
        accountRepositoryProvider.overrideWithValue(mockTripRepository),
        authRepositoryProvider.overrideWithValue(mockAuthRepository),
        authStateProvider.overrideWith(
          () => _FakeAuthNotifier(loggedInUser, logoutCalls),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const AccountSessionsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  setUp(() {
    mockTripRepository = MockTripRepository();
    mockAuthRepository = MockAuthRepository();
    logoutCalls = <void>[];
    when(
      mockAuthRepository.fetchAiAuthorization,
    ).thenAnswer((_) async => false);
    when(() => mockTripRepository.fetchAccountSessions()).thenAnswer(
      (_) async => const AccountSessionsPage(
        currentSid: 'sid-current',
        sessions: [currentSession, phoneSession],
      ),
    );
    when(
      () => mockTripRepository.revokeAccountSession(any()),
    ).thenAnswer((_) async {});
    when(
      () => mockTripRepository.revokeOtherAccountSessions(),
    ).thenAnswer((_) async => 1);
    when(
      () => mockTripRepository.fetchConnectedApps(),
    ).thenAnswer((_) async => const <ConnectedApp>[]);
  });

  testWidgets('裝置列表不直接鋪 destructive action，詳情才顯示登出', (tester) async {
    await pumpScreen(tester);

    expect(find.text('登入裝置'), findsOneWidget);
    expect(find.text('Chrome on Windows'), findsOneWidget);
    expect(find.text('Safari on iPhone'), findsOneWidget);
    expect(find.text('目前裝置'), findsOneWidget);
    expect(find.textContaining('IP 指紋'), findsNothing);
    expect(find.textContaining('T10:00:00Z'), findsNothing);
    expect(
      find.byKey(const Key('account-session-revoke-sid-current')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('account-session-revoke-sid-phone')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('account-sessions-revoke-others')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('account-session-row-sid-phone')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('account-session-details')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('app-sheet-close')), findsNothing);
    expect(find.text('取消'), findsNothing);
    expect(
      find.byKey(const Key('account-session-revoke-sid-phone')),
      findsOneWidget,
    );
    expect(find.textContaining('IP 指紋'), findsNothing);
  });

  testWidgets('裝置詳情與已連結應用沿用同一個 Account Navigation Stack', (tester) async {
    var closeCalls = 0;
    final container = ProviderContainer(
      overrides: [
        tripRepositoryProvider.overrideWithValue(mockTripRepository),
        accountRepositoryProvider.overrideWithValue(mockTripRepository),
        authRepositoryProvider.overrideWithValue(mockAuthRepository),
        authStateProvider.overrideWith(
          () => _FakeAuthNotifier(loggedInUser, logoutCalls),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: TpLargeSheetNavigationScope(
            onClose: () => closeCalls++,
            child: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => const AccountSessionsScreen(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('account-session-row-sid-phone')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('account-session-details')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('app-large-sheet-back')), findsOneWidget);
    expect(closeCalls, 0);

    await tester.tap(find.byKey(const ValueKey('app-large-sheet-back')));
    await tester.pumpAndSettle();
    expect(find.byType(AccountSessionsScreen), findsOneWidget);
    expect(closeCalls, 0);

    await tester.tap(find.byKey(const Key('account-sessions-connected-apps')));
    await tester.pumpAndSettle();
    expect(find.byType(ConnectedAppsScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('app-large-sheet-back')), findsOneWidget);
    expect(closeCalls, 0);

    await tester.tap(find.byKey(const ValueKey('app-large-sheet-back')));
    await tester.pumpAndSettle();
    expect(find.byType(AccountSessionsScreen), findsOneWidget);
    expect(closeCalls, 0);
  });

  testWidgets('登出單一非目前裝置會呼叫 repository 並顯示成功提示', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('account-session-row-sid-phone')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-session-revoke-sid-phone')));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.textContaining('無法復原'), findsOneWidget);
    verifyNever(() => mockTripRepository.revokeAccountSession(any()));

    await tester.tap(find.widgetWithText(CupertinoDialogAction, '登出'));
    await tester.pumpAndSettle();

    verify(
      () => mockTripRepository.revokeAccountSession('sid-phone'),
    ).called(1);
    expect(find.text('已登出該裝置'), findsOneWidget);
    expect(find.byKey(const ValueKey('account-session-details')), findsNothing);
  });

  testWidgets('登出裝置失敗會保留詳情、錯誤與可重試的 44pt 操作', (tester) async {
    when(
      () => mockTripRepository.revokeAccountSession('sid-phone'),
    ).thenThrow(Exception('offline'));
    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('account-session-row-sid-phone')));
    await tester.pumpAndSettle();
    final revokeFinder = find.byKey(
      const Key('account-session-revoke-sid-phone'),
    );
    expect(tester.getSize(revokeFinder).height, greaterThanOrEqualTo(44));

    await tester.tap(revokeFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CupertinoDialogAction, '登出'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('account-session-details')),
      findsOneWidget,
    );
    expect(find.text('登出裝置失敗，請稍後再試'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '重試'), findsOneWidget);
    expect(tester.widget<FilledButton>(revokeFinder).onPressed, isNotNull);
  });

  testWidgets('登出其他裝置缺少 server-bound reauth 時安全阻擋且不呼叫 API', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('account-sessions-revoke-others')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('revoke-other-sessions-blocked-dialog')),
      findsOneWidget,
    );
    expect(find.text('需要重新驗證才能登出其他裝置'), findsOneWidget);
    expect(find.textContaining('缺少可綁定伺服器操作'), findsOneWidget);
    expect(find.textContaining('逐一登出'), findsOneWidget);
    verifyNever(() => mockTripRepository.revokeOtherAccountSessions());
  });

  testWidgets('顯示帳號 email、OAuth 提醒與頁尾登出', (tester) async {
    await pumpScreen(tester);

    expect(
      find.byKey(const Key('account-sessions-user-email')),
      findsOneWidget,
    );
    expect(find.text('traveler@example.com'), findsOneWidget);
    expect(
      find.byKey(const Key('account-sessions-oauth-note')),
      findsOneWidget,
    );
    expect(find.textContaining('OAuth 已連結應用不受影響'), findsOneWidget);
    expect(
      find.byKey(const Key('account-sessions-theme-footer')),
      findsNothing,
    );
    expect(find.byKey(const Key('account-sessions-logout')), findsOneWidget);
  });

  testWidgets('頁尾可登出帳號', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('account-sessions-logout')));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.text('登出帳號'), findsOneWidget);

    await tester.tap(find.widgetWithText(CupertinoDialogAction, '登出'));
    await tester.pumpAndSettle();

    expect(logoutCalls, hasLength(1));
  });
}
