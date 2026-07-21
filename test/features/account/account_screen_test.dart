import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/settings_store.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/app/app_version.dart';
import 'package:tripline/features/account/account_screen.dart';
import 'package:tripline/features/account/settings/theme_mode_controller.dart';
import 'package:tripline/models/user.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_account_avatar_button.dart';
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

  const defaultStats = AccountStats(
    tripCount: 5,
    totalDays: 12,
    collaboratorCount: 3,
  );

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    mockTripRepository = MockTripRepository();
    when(() => mockAuthRepository.logout()).thenAnswer((_) async {});
  });

  /// 注入登入中的假 user 與假統計後渲染 AccountScreen。
  Future<void> pumpAccountScreen(
    WidgetTester tester, {
    UserInfo user = verifiedUser,
    AccountStats stats = defaultStats,
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
          settingsStoreProvider.overrideWithValue(InMemorySettingsStore()),
          tripRepositoryProvider.overrideWithValue(mockTripRepository),
          accountStatsProvider.overrideWith((ref) => Future.value(stats)),
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

  Future<void> pumpAccountEntry(WidgetTester tester) async {
    when(
      () => mockAuthRepository.currentUser(),
    ).thenAnswer((_) async => verifiedUser);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            appBar: AppBar(actions: const [TpAccountAvatarButton()]),
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
          accountStatsProvider.overrideWith(
            (ref) => Future.value(defaultStats),
          ),
          appVersionProvider.overrideWith(
            (ref) => Future.value(
              const AppVersion(version: '0.9.1', buildNumber: '12'),
            ),
          ),
        ],
        child: Consumer(
          builder: (context, ref, _) => MaterialApp.router(
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ref.watch(themeModeProvider),
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: const EdgeInsets.only(top: 59, bottom: 34),
                viewPadding: const EdgeInsets.only(top: 59, bottom: 34),
              ),
              child: child!,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('帳號入口顯示帳號首字母並和 toolbar 功能鍵同為 44pt glass', (tester) async {
    await pumpAccountEntry(tester);

    final accountButton = find.byKey(const ValueKey('account-avatar-button'));
    expect(
      find.descendant(of: accountButton, matching: find.text('R')),
      findsOneWidget,
    );
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

  testWidgets('帳號 sheet 子頁維持在圓角面板內並使用圓形返回鍵', (tester) async {
    await pumpAccountEntry(tester);

    await tester.tap(find.byKey(const ValueKey('account-avatar-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-appearance')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-large-sheet')), findsOneWidget);
    expect(find.text('外觀'), findsOneWidget);
    expect(find.byKey(const ValueKey('app-large-sheet-back')), findsOneWidget);
    expect(find.byKey(const ValueKey('app-large-sheet-close')), findsOneWidget);
    final backGlass = find.descendant(
      of: find.byKey(const ValueKey('app-large-sheet-back')),
      matching: find.byKey(const ValueKey('tp-toolbar-glass-button')),
    );
    final closeGlass = find.descendant(
      of: find.byKey(const ValueKey('app-large-sheet-close')),
      matching: find.byKey(const ValueKey('tp-toolbar-glass-button')),
    );
    expect(backGlass, findsOneWidget);
    expect(closeGlass, findsOneWidget);
    expect(tester.getSize(backGlass), const Size(44, 44));
    expect(tester.getSize(closeGlass), const Size(44, 44));
    final titleRect = tester.getRect(find.text('外觀'));
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

  testWidgets('account child uses Back while Close dismisses the whole sheet', (
    tester,
  ) async {
    await pumpAccountEntry(tester);

    await tester.tap(find.byKey(const ValueKey('account-avatar-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-appearance')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tp-app-bar-back')), findsOneWidget);
    expect(find.byKey(const ValueKey('app-sheet-close')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tp-app-bar-back')));
    await tester.pumpAndSettle();
    expect(find.text('帳號'), findsOneWidget);
  });

  testWidgets('帳號大型 sheet 在外觀切換後同步更新 glass 與頁面亮度', (tester) async {
    await pumpAccountEntry(tester);

    await tester.tap(find.byKey(const ValueKey('account-avatar-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-appearance')));
    await tester.pumpAndSettle();

    var sheet = tester.widget<GlassModalSheetScaffold>(
      find.byType(GlassModalSheetScaffold),
    );
    expect(sheet.settings?.glassColor, const Color(0xC7FFFBF5));
    expect(
      Theme.of(
        tester.element(find.byKey(const ValueKey('theme-light'))),
      ).brightness,
      Brightness.light,
    );

    await tester.tap(find.byKey(const ValueKey('theme-dark')));
    await tester.pumpAndSettle();

    sheet = tester.widget<GlassModalSheetScaffold>(
      find.byType(GlassModalSheetScaffold),
    );
    expect(sheet.settings?.glassColor, const Color(0xB3121214));
    expect(
      Theme.of(
        tester.element(find.byKey(const ValueKey('theme-dark'))),
      ).brightness,
      Brightness.dark,
    );

    await tester.tap(find.byKey(const ValueKey('theme-light')));
    await tester.pumpAndSettle();

    sheet = tester.widget<GlassModalSheetScaffold>(
      find.byType(GlassModalSheetScaffold),
    );
    expect(sheet.settings?.glassColor, const Color(0xC7FFFBF5));
    expect(
      Theme.of(
        tester.element(find.byKey(const ValueKey('theme-light'))),
      ).brightness,
      Brightness.light,
    );
  });

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

  testWidgets('iOS Large 的帳號名稱與次要資訊使用 HIG 字級', (tester) async {
    await pumpAccountScreen(tester);

    expect(tester.widget<Text>(find.text('Ray')).style?.fontSize, 22);
    expect(
      tester.widget<Text>(find.text('ray@example.com')).style?.fontSize,
      15,
    );
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

  testWidgets('點名稱編輯按鈕可 inline 改名並靜默儲存', (tester) async {
    when(
      () => mockTripRepository.updateProfile(
        displayName: any(named: 'displayName'),
      ),
    ).thenAnswer(
      (_) async => const UserInfo(
        id: 'user-1',
        email: 'ray@example.com',
        emailVerified: true,
        displayName: 'Ray Chiu',
      ),
    );
    await pumpAccountScreen(tester);

    await tester.tap(find.byKey(const ValueKey('account-edit-name-btn')));
    await tester.pumpAndSettle();

    final input = find.byKey(const ValueKey('account-edit-name-input'));
    expect(input, findsOneWidget);
    expect(find.text('Ray'), findsOneWidget);

    await tester.enterText(input, 'Ray Chiu');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    verify(
      () => mockTripRepository.updateProfile(displayName: 'Ray Chiu'),
    ).called(1);
    expect(input, findsNothing);
    expect(find.text('Ray Chiu'), findsOneWidget);
  });

  testWidgets('inline 改名按 Escape 取消且不呼叫 API', (tester) async {
    await pumpAccountScreen(tester);

    await tester.tap(find.byKey(const ValueKey('account-edit-name-btn')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('account-edit-name-input')),
      'Draft Name',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('account-edit-name-input')), findsNothing);
    expect(find.text('Ray'), findsOneWidget);
    verifyNever(
      () => mockTripRepository.updateProfile(
        displayName: any(named: 'displayName'),
      ),
    );
  });

  testWidgets('inline 改名清空時送出 null displayName', (tester) async {
    when(() => mockTripRepository.updateProfile(displayName: null)).thenAnswer(
      (_) async => const UserInfo(
        id: 'user-1',
        email: 'ray@example.com',
        emailVerified: true,
      ),
    );
    await pumpAccountScreen(tester);

    await tester.tap(find.byKey(const ValueKey('account-edit-name-btn')));
    await tester.pumpAndSettle();
    final input = find.byKey(const ValueKey('account-edit-name-input'));
    await tester.enterText(input, '   ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    verify(() => mockTripRepository.updateProfile(displayName: null)).called(1);
    expect(input, findsNothing);
    expect(find.text('ray'), findsOneWidget);
  });

  testWidgets('帳號設定 rows 可進子頁；通知 row 已轉正', (tester) async {
    await pumpAccountScreen(tester);

    expect(find.byKey(const ValueKey('settings-profile')), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-appearance')), findsOneWidget);
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

  testWidgets('純 OAuth 帳號只有輸入大寫 DELETE 才可確認', (tester) async {
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

    final field = find.byKey(
      const ValueKey('delete-account-confirmation-field'),
    );
    final confirmButton = find.byKey(
      const ValueKey('delete-account-confirm-button'),
    );
    await tester.enterText(field, 'delete');
    await tester.pump();
    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);
    await tester.enterText(field, 'DELETE');
    await tester.pump();
    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNotNull);
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    verify(
      () => mockAuthRepository.deleteAccount(
        hasPassword: false,
        confirmation: 'DELETE',
      ),
    ).called(1);
    expect(find.byKey(const ValueKey('delete-account-dialog')), findsNothing);
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
