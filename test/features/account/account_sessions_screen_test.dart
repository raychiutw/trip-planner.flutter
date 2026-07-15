import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/settings_store.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/account/account_sessions_screen.dart';
import 'package:tripline/features/account/settings/theme_mode_controller.dart';
import 'package:tripline/models/user.dart';
import 'package:tripline/theme/app_theme.dart';

class MockTripRepository extends Mock implements TripRepository {}

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
        authStateProvider.overrideWith(
          () => _FakeAuthNotifier(loggedInUser, logoutCalls),
        ),
        settingsStoreProvider.overrideWithValue(InMemorySettingsStore()),
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
    logoutCalls = <void>[];
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
      find.byKey(const Key('account-session-revoke-sid-phone')),
      findsOneWidget,
    );
    expect(find.textContaining('IP 指紋'), findsNothing);
  });

  testWidgets('登出單一非目前裝置會呼叫 repository 並顯示成功提示', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('account-session-row-sid-phone')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-session-revoke-sid-phone')));
    await tester.pumpAndSettle();

    verify(
      () => mockTripRepository.revokeAccountSession('sid-phone'),
    ).called(1);
    expect(find.text('已登出該裝置'), findsOneWidget);
  });

  testWidgets('登出其他裝置需確認，確認後呼叫 repository', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('account-sessions-revoke-others')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('登出其他裝置'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '登出'));
    await tester.pumpAndSettle();

    verify(() => mockTripRepository.revokeOtherAccountSessions()).called(1);
    expect(find.text('已登出其他裝置'), findsOneWidget);
  });

  testWidgets('顯示帳號 email、OAuth 提醒與頁尾深淺模式/登出', (tester) async {
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
      findsOneWidget,
    );
    expect(find.byKey(const Key('account-sessions-logout')), findsOneWidget);
  });

  testWidgets('頁尾可切換深色模式並登出帳號', (tester) async {
    final container = await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('account-sessions-theme-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-sessions-theme-dark')));
    await tester.pumpAndSettle();

    expect(container.read(themeModeProvider), ThemeMode.dark);

    await tester.tap(find.byKey(const Key('account-sessions-logout')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('登出帳號'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '登出'));
    await tester.pumpAndSettle();

    expect(logoutCalls, hasLength(1));
  });
}
