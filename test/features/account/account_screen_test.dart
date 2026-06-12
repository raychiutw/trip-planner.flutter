import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/features/account/account_screen.dart';
import 'package:tripline/models/user.dart';
import 'package:tripline/theme/app_theme.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository mockAuthRepository;

  const verifiedUser = UserInfo(
    id: 'user-1',
    email: 'ray@example.com',
    emailVerified: true,
    displayName: 'Ray',
  );

  const defaultStats = AccountStats(
    tripCount: 5,
    totalDays: 12,
    collaboratorCount: 3,
  );

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    when(() => mockAuthRepository.logout()).thenAnswer((_) async {});
  });

  /// 注入登入中的假 user 與假統計後渲染 AccountScreen。
  Future<void> pumpAccountScreen(
    WidgetTester tester, {
    UserInfo user = verifiedUser,
    AccountStats stats = defaultStats,
  }) async {
    when(() => mockAuthRepository.currentUser()).thenAnswer((_) async => user);
    // 內容較長，放大測試視窗確保全部 row 都在畫面內。
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
          accountStatsProvider.overrideWith((ref) => Future.value(stats)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const AccountScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('顯示 displayName、email、avatar 首字母與三個統計值', (tester) async {
    await pumpAccountScreen(tester);

    expect(find.text('Ray'), findsOneWidget);
    expect(find.text('ray@example.com'), findsOneWidget);
    expect(find.text('R'), findsOneWidget); // avatar 首字母大寫

    expect(find.text('行程數'), findsOneWidget);
    expect(find.text('旅程天數'), findsOneWidget);
    expect(find.text('旅伴數'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('無 displayName 時顯示 email local part 與其首字母大寫', (tester) async {
    const userWithoutName = UserInfo(
      id: 'user-2',
      email: 'ray@example.com',
      emailVerified: true,
    );
    await pumpAccountScreen(tester, user: userWithoutName);

    expect(find.text('ray'), findsOneWidget);
    expect(find.text('R'), findsOneWidget);
  });

  testWidgets('emailVerified=false 顯示未驗證警示 chip', (tester) async {
    const unverifiedUser = UserInfo(
      id: 'user-3',
      email: 'ray@example.com',
      emailVerified: false,
      displayName: 'Ray',
    );
    await pumpAccountScreen(tester, user: unverifiedUser);

    expect(find.text('Email 未驗證'), findsOneWidget);
  });

  testWidgets('emailVerified=true 不顯示未驗證警示 chip', (tester) async {
    await pumpAccountScreen(tester);

    expect(find.text('Email 未驗證'), findsNothing);
  });

  testWidgets('個人資料/外觀 可點;通知 仍「即將推出」', (tester) async {
    await pumpAccountScreen(tester);

    // 個人資料 + 外觀 轉成可導航設定列
    expect(find.byKey(const ValueKey('settings-profile')), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-appearance')), findsOneWidget);
    // 通知 仍為即將推出(唯一一個)
    expect(find.text('通知'), findsOneWidget);
    expect(find.text('即將推出'), findsOneWidget);

    final notificationsTile =
        tester.widget<ListTile>(find.widgetWithText(ListTile, '通知'));
    expect(notificationsTile.enabled, isFalse);
  });

  testWidgets('點登出 row 出現確認對話框，確認後呼叫 logout', (tester) async {
    await pumpAccountScreen(tester);

    await tester.tap(find.text('登出'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('確定要登出嗎？'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '登出'));
    await tester.pumpAndSettle();

    verify(() => mockAuthRepository.logout()).called(1);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('登出對話框按取消不呼叫 logout', (tester) async {
    await pumpAccountScreen(tester);

    await tester.tap(find.text('登出'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    verifyNever(() => mockAuthRepository.logout());
    expect(find.byType(AlertDialog), findsNothing);
    // 取消後仍停留在帳號頁。
    expect(find.text('Ray'), findsOneWidget);
  });
}
