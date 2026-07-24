import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/app/app_version.dart';
import 'package:tripline/features/account/account_sheet.dart';
import 'package:tripline/features/account/account_screen.dart';
import 'package:tripline/models/user.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_app_bar.dart';
import 'package:tripline/ui/tp_settings_group.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockTripRepository extends Mock implements TripRepository {}

void main() {
  late MockAuthRepository mockAuthRepository;
  late MockTripRepository mockTripRepository;

  const verifiedUser = UserInfo(
    id: 'user-1',
    email: 'ray@example.com',
    emailVerified: true,
    displayName: 'Ray',
  );

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    mockTripRepository = MockTripRepository();
    when(() => mockAuthRepository.logout()).thenAnswer((_) async {});
  });

  /// 注入登入中的假 user 後渲染 Account sheet root。
  Future<void> pumpAccountScreen(
    WidgetTester tester, {
    UserInfo user = verifiedUser,
    AppVersion version = const AppVersion(version: '0.9.1', buildNumber: '12'),
  }) async {
    when(() => mockAuthRepository.currentUser()).thenAnswer((_) async => user);
    // 內容較長，放大測試視窗確保全部 row 都在畫面內。
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
          tripRepositoryProvider.overrideWithValue(mockTripRepository),
          appVersionProvider.overrideWith((ref) => Future.value(version)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const AccountScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpAccountEntry(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    when(
      () => mockAuthRepository.currentUser(),
    ).thenAnswer((_) async => verifiedUser);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            appBar: AppBar(
              actions: [
                TpAccountAvatarButton(
                  onPressed: () => showAccountSheet(context),
                ),
              ],
            ),
          ),
        ),
        GoRoute(path: '/account', builder: (_, _) => const AccountScreen()),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
          tripRepositoryProvider.overrideWithValue(mockTripRepository),
          appVersionProvider.overrideWith(
            (ref) => Future.value(
              const AppVersion(version: '0.9.1', buildNumber: '12'),
            ),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.system,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 59, bottom: 34),
              viewPadding: const EdgeInsets.only(top: 59, bottom: 34),
              textScaler: textScaler,
            ),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('帳號入口使用 person.crop.circle 系統圖示與 44pt glass', (tester) async {
    await pumpAccountEntry(tester);

    final accountButton = find.byKey(const ValueKey('account-avatar-button'));
    expect(
      find.descendant(
        of: accountButton,
        matching: find.byIcon(CupertinoIcons.person_crop_circle),
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('帳號'), findsOneWidget);
    final glass = find.descendant(
      of: accountButton,
      matching: find.byKey(const ValueKey('tp-toolbar-glass-button')),
    );
    expect(glass, findsOneWidget);
    expect(tester.getSize(glass), const Size(44, 44));
  });

  testWidgets('帳號 avatar 開啟共用近滿版 HIG sheet 並可由右上關閉', (tester) async {
    await pumpAccountEntry(tester);

    await tester.tap(find.byKey(const ValueKey('account-avatar-button')));
    await tester.pumpAndSettle();

    final sheet = find.byKey(const ValueKey('app-large-sheet'));
    expect(sheet, findsOneWidget);
    expect(find.byType(GlassModalSheetScaffold), findsOneWidget);
    expect(find.byKey(const ValueKey('account-sheet-content')), findsOneWidget);
    expect(find.byKey(const ValueKey('account-sheet-profile')), findsOneWidget);
    expect(find.text('帳號資訊與個人資料'), findsOneWidget);
    expect(find.text('偏好'), findsOneWidget);
    expect(find.text('安全性'), findsOneWidget);
    expect(find.text('版本 0.9.1（12）'), findsOneWidget);
    expect(find.text('行程數'), findsNothing);
    expect(find.text('旅程天數'), findsNothing);
    expect(find.text('旅伴數'), findsNothing);
    expect(find.byKey(const ValueKey('app-large-sheet-close')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('app-large-sheet-drag-indicator')),
      findsNothing,
    );
    expect(
      tester
          .widget<GlassModalSheetScaffold>(find.byType(GlassModalSheetScaffold))
          .showDragIndicator,
      isFalse,
    );
    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(tester.getSize(sheet).height, closeTo(screenHeight * 0.93, 1));

    await tester.tap(find.byKey(const ValueKey('app-large-sheet-close')));
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
  });

  testWidgets('一般寬度使用置中的 form sheet 並保留同一 Navigation Stack', (tester) async {
    await pumpAccountEntry(tester, size: const Size(1024, 768));

    await tester.tap(find.byKey(const ValueKey('account-avatar-button')));
    await tester.pumpAndSettle();

    final regularSheet = find.byKey(
      const ValueKey('app-regular-content-sheet'),
    );
    expect(regularSheet, findsOneWidget);
    expect(find.byType(GlassModalSheetScaffold), findsNothing);
    expect(tester.getSize(regularSheet).width, lessThanOrEqualTo(560));
    expect(tester.getSize(regularSheet).height, lessThan(768));

    await tester.tap(find.byKey(const ValueKey('account-sheet-profile')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('tp-app-bar-title')),
        matching: find.text('個人資料'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('app-large-sheet-back')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('app-large-sheet-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account-sheet-content')), findsOneWidget);
  });

  testWidgets('Account grouped list 在 200% Dynamic Type 維持可捲動與可辨識語意', (
    tester,
  ) async {
    await pumpAccountEntry(tester, textScaler: const TextScaler.linear(2));

    await tester.tap(find.byKey(const ValueKey('account-avatar-button')));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(RegExp('Ray')), findsOneWidget);
    final deleteRow = find.byKey(const ValueKey('settings-delete-account'));
    await tester.scrollUntilVisible(
      deleteRow,
      500,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('account-sheet-content')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('刪除帳號')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('帳號頁底部顯示版本與 build number', (tester) async {
    await pumpAccountScreen(tester);

    expect(find.text('版本 0.9.1（12）'), findsOneWidget);
  });

  testWidgets('build number 為空時只顯示版本', (tester) async {
    await pumpAccountScreen(
      tester,
      version: const AppVersion(version: '0.9.1', buildNumber: ''),
    );

    expect(find.text('版本 0.9.1'), findsOneWidget);
  });

  testWidgets('帳號 sheet 表單子頁維持在圓角面板內並使用取消動作', (tester) async {
    await pumpAccountEntry(tester);

    await tester.tap(find.byKey(const ValueKey('account-avatar-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account-sheet-profile')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-large-sheet')), findsOneWidget);
    final profileTitle = find.descendant(
      of: find.byKey(const ValueKey('tp-app-bar-title')),
      matching: find.text('個人資料'),
    );
    expect(profileTitle, findsOneWidget);
    expect(find.byKey(const ValueKey('app-large-sheet-back')), findsOneWidget);
    expect(find.byKey(const ValueKey('app-large-sheet-close')), findsNothing);
    final cancelAction = find.descendant(
      of: find.byKey(const ValueKey('app-large-sheet-back')),
      matching: find.byKey(const ValueKey('tp-app-bar-cancel')),
    );
    expect(cancelAction, findsOneWidget);
    expect(tester.getSize(cancelAction).height, greaterThanOrEqualTo(44));
    final titleRect = tester.getRect(profileTitle);
    final screenCenter = tester.getCenter(find.byType(MaterialApp)).dx;
    expect(titleRect.center.dx, closeTo(screenCenter, 1));
    expect(
      find.byKey(const ValueKey('app-large-sheet-drag-indicator')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('app-large-sheet-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account-sheet-content')), findsOneWidget);
    expect(find.byKey(const ValueKey('app-large-sheet-close')), findsOneWidget);
  });

  testWidgets('Account 表單子頁以取消返回，且不重複顯示 Close', (tester) async {
    await pumpAccountEntry(tester);

    await tester.tap(find.byKey(const ValueKey('account-avatar-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account-sheet-profile')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-large-sheet-back')), findsOneWidget);
    expect(find.byKey(const ValueKey('tp-app-bar-cancel')), findsOneWidget);
    expect(find.byKey(const ValueKey('app-sheet-close')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('tp-app-bar-cancel')));
    await tester.pumpAndSettle();
    expect(find.text('帳號'), findsOneWidget);
  });

  testWidgets('Account root 顯示 displayName 與 avatar 首字母，不含舊統計', (tester) async {
    await pumpAccountScreen(tester);

    expect(find.text('Ray'), findsOneWidget);
    expect(find.text('R'), findsOneWidget); // avatar 首字母大寫
    expect(find.text('行程數'), findsNothing);
    expect(find.text('旅程天數'), findsNothing);
    expect(find.text('旅伴數'), findsNothing);
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

  testWidgets('帳號設定 rows 可進子頁；通知 row 已轉正', (tester) async {
    await pumpAccountScreen(tester);

    expect(find.byKey(const ValueKey('settings-appearance')), findsNothing);
    expect(find.byKey(const ValueKey('settings-sessions')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('settings-connected-apps')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings-developer-apps')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings-notifications')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings-privacy-policy')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings-delete-account')),
      findsOneWidget,
    );
    expect(find.text('通知'), findsOneWidget);

    expect(find.byType(TpSettingsGroup), findsNWidgets(5));
    final notificationsTile = tester.widget<TpSettingsRow>(
      find.byKey(const ValueKey('settings-notifications')),
    );
    expect(notificationsTile.onTap, isNotNull);
  });

  testWidgets('刪除帳號顯示影響數字並要求密碼，錯誤時保留對話框', (tester) async {
    when(() => mockAuthRepository.fetchAccountDeletionPreview()).thenAnswer(
      (_) async => const AccountDeletionPreview(
        hasPassword: true,
        tripsOwned: 3,
        collaboratorsAffected: 5,
      ),
    );
    when(
      () => mockAuthRepository.deleteAccount(
        hasPassword: any(named: 'hasPassword'),
        confirmation: any(named: 'confirmation'),
      ),
    ).thenThrow(
      const ApiError(
        status: 401,
        code: 'ACCOUNT_DELETE_PASSWORD_INVALID',
        message: 'invalid',
      ),
    );
    await pumpAccountScreen(tester);

    final deleteRow = find.byKey(const ValueKey('settings-delete-account'));
    await tester.ensureVisible(deleteRow);
    await tester.tap(deleteRow);
    await tester.pumpAndSettle();

    expect(find.textContaining('3 個行程'), findsOneWidget);
    expect(find.textContaining('5 位共編者'), findsOneWidget);
    expect(find.text('此操作無法復原。'), findsNothing);
    expect(find.textContaining('此操作無法復原'), findsOneWidget);
    expect(find.text('目前密碼（重新驗證）'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '取消'))
          .autofocus,
      isTrue,
    );
    final confirmButton = find.byKey(
      const ValueKey('delete-account-confirm-button'),
    );
    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('delete-account-confirmation-field')),
      'wrong-password',
    );
    await tester.pump();
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    verify(
      () => mockAuthRepository.deleteAccount(
        hasPassword: true,
        confirmation: 'wrong-password',
      ),
    ).called(1);
    expect(find.text('密碼不正確，請重新輸入'), findsOneWidget);
    expect(find.byKey(const ValueKey('delete-account-dialog')), findsOneWidget);
  });

  testWidgets('純 OAuth 帳號無 fresh-auth 契約時安全阻擋刪除', (tester) async {
    when(() => mockAuthRepository.fetchAccountDeletionPreview()).thenAnswer(
      (_) async => const AccountDeletionPreview(
        hasPassword: false,
        tripsOwned: 0,
        collaboratorsAffected: 0,
      ),
    );
    when(
      () => mockAuthRepository.deleteAccount(
        hasPassword: any(named: 'hasPassword'),
        confirmation: any(named: 'confirmation'),
      ),
    ).thenAnswer((_) async {});
    await pumpAccountScreen(tester);

    final deleteRow = find.byKey(const ValueKey('settings-delete-account'));
    await tester.ensureVisible(deleteRow);
    await tester.tap(deleteRow);
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.text('需要重新驗證才能刪除'), findsOneWidget);
    expect(find.textContaining('目前無法在 App 內安全地重新驗證'), findsOneWidget);
    expect(find.text('查看安全刪除方式'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('delete-account-confirmation-field')),
      findsNothing,
    );
    verifyNever(
      () => mockAuthRepository.deleteAccount(
        hasPassword: any(named: 'hasPassword'),
        confirmation: any(named: 'confirmation'),
      ),
    );
  });

  testWidgets('點登出 row 出現確認對話框，確認後呼叫 logout', (tester) async {
    await pumpAccountScreen(tester);

    await tester.tap(find.text('登出'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.text('確定要登出嗎？'), findsOneWidget);

    await tester.tap(find.widgetWithText(CupertinoDialogAction, '登出'));
    await tester.pumpAndSettle();

    verify(() => mockAuthRepository.logout()).called(1);
    expect(find.byType(CupertinoAlertDialog), findsNothing);
  });

  testWidgets('登出對話框按取消不呼叫 logout', (tester) async {
    await pumpAccountScreen(tester);

    await tester.tap(find.text('登出'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    verifyNever(() => mockAuthRepository.logout());
    expect(find.byType(CupertinoAlertDialog), findsNothing);
    // 取消後仍停留在帳號頁。
    expect(find.text('Ray'), findsOneWidget);
  });
}
