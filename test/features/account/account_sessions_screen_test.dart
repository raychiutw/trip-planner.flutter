import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/account/account_sessions_screen.dart';
import 'package:tripline/models/user.dart';
import 'package:tripline/theme/app_theme.dart';

class MockTripRepository extends Mock implements TripRepository {}

void main() {
  late MockTripRepository mockTripRepository;

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

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tripRepositoryProvider.overrideWithValue(mockTripRepository),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const AccountSessionsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    mockTripRepository = MockTripRepository();
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

  testWidgets('列出登入裝置並只讓非目前裝置顯示登出按鈕', (tester) async {
    await pumpScreen(tester);

    expect(find.text('登入裝置'), findsOneWidget);
    expect(find.text('Chrome on Windows'), findsOneWidget);
    expect(find.text('Safari on iPhone'), findsOneWidget);
    expect(find.text('目前裝置'), findsOneWidget);
    expect(
      find.byKey(const Key('account-session-revoke-sid-current')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('account-session-revoke-sid-phone')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('account-sessions-revoke-others')),
      findsOneWidget,
    );
    expect(find.textContaining('2026-07-08T'), findsNothing);
    expect(find.textContaining('IP 指紋'), findsNothing);
    expect(find.textContaining('最近活動：'), findsWidgets);
  });

  testWidgets('登出單一非目前裝置會呼叫 repository 並顯示成功提示', (tester) async {
    await pumpScreen(tester);

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
}
