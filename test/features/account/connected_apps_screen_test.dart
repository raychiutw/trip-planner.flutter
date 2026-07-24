import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/account/connected_apps_screen.dart';
import 'package:tripline/models/oauth.dart';
import 'package:tripline/theme/app_theme.dart';

class MockTripRepository extends Mock implements TripRepository {}

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockTripRepository mockTripRepository;
  late MockAuthRepository mockAuthRepository;

  const connectedApp = ConnectedApp(
    clientId: 'tp_alpha',
    appName: 'Alpha App',
    appDescription: '行程同步工具',
    homepageUrl: 'https://alpha.example.com',
    status: 'active',
    scopes: ['openid', 'email'],
    grantedAt: 1783500000000,
  );

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (retryCount, error) => null,
        overrides: [
          tripRepositoryProvider.overrideWithValue(mockTripRepository),
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ConnectedAppsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    mockTripRepository = MockTripRepository();
    mockAuthRepository = MockAuthRepository();
    when(
      mockAuthRepository.fetchAiAuthorization,
    ).thenAnswer((_) async => false);
    when(mockAuthRepository.authorizeAi).thenAnswer((_) async => true);
    when(
      () => mockTripRepository.fetchConnectedApps(),
    ).thenAnswer((_) async => const [connectedApp]);
    when(
      () => mockTripRepository.revokeConnectedApp(any()),
    ).thenAnswer((_) async {});
  });

  testWidgets('列出已授權 app、使用者可理解的權限與日期', (tester) async {
    await pumpScreen(tester);

    expect(find.text('已連結的應用程式'), findsOneWidget);
    expect(find.text('Alpha App'), findsOneWidget);
    expect(find.text('行程同步工具'), findsOneWidget);
    expect(find.text('識別您的身分（唯一 ID）'), findsOneWidget);
    expect(find.text('您的電子郵件地址'), findsOneWidget);
    expect(find.text('openid'), findsNothing);
    expect(find.textContaining('1783500000000'), findsNothing);
    expect(find.textContaining('2026/7/8'), findsOneWidget);
  });

  testWidgets('顯示 AI owner 授權卡，成功後刷新清單', (tester) async {
    await pumpScreen(tester);

    expect(find.byKey(const ValueKey('ai-authorize-card')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ai-authorize-btn')));
    await tester.pumpAndSettle();

    verify(mockAuthRepository.authorizeAi).called(1);
    verify(() => mockTripRepository.fetchConnectedApps()).called(2);
    expect(find.byKey(const ValueKey('ai-authorize-on')), findsOneWidget);
  });

  testWidgets('AI 授權未完成時保留操作並顯示錯誤', (tester) async {
    when(mockAuthRepository.authorizeAi).thenAnswer((_) async => false);
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('ai-authorize-btn')));
    await tester.pumpAndSettle();

    expect(find.text('授權未完成，請再試一次。'), findsOneWidget);
    expect(find.byKey(const ValueKey('ai-authorize-btn')), findsOneWidget);
  });

  testWidgets('撤銷 app 需確認，確認後呼叫 repository', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('connected-app-revoke-tp_alpha')));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.text('撤銷 Alpha App？'), findsOneWidget);
    expect(find.textContaining('無法復原'), findsOneWidget);

    await tester.tap(find.widgetWithText(CupertinoDialogAction, '撤銷'));
    await tester.pumpAndSettle();

    verify(() => mockTripRepository.revokeConnectedApp('tp_alpha')).called(1);
    expect(find.text('已撤銷 Alpha App'), findsOneWidget);
    expect(find.byKey(const Key('connected-app-row-tp_alpha')), findsNothing);
  });

  testWidgets('撤銷成功後 manual refresh 不會讓舊快取項目復活', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('connected-app-revoke-tp_alpha')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CupertinoDialogAction, '撤銷'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('connected-app-row-tp_alpha')), findsNothing);

    final refreshIndicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    await refreshIndicator.onRefresh();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('connected-app-row-tp_alpha')), findsNothing);
    verify(
      () => mockTripRepository.fetchConnectedApps(),
    ).called(greaterThanOrEqualTo(3));
  });

  testWidgets('撤銷 pending 期間鎖定操作，失敗時保留 app 與重試入口', (tester) async {
    final revokeCompleter = Completer<void>();
    when(
      () => mockTripRepository.revokeConnectedApp('tp_alpha'),
    ).thenAnswer((_) => revokeCompleter.future);
    await pumpScreen(tester);

    final revokeFinder = find.byKey(const Key('connected-app-revoke-tp_alpha'));
    expect(tester.getSize(revokeFinder).height, greaterThanOrEqualTo(44));

    await tester.tap(revokeFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CupertinoDialogAction, '撤銷'));
    await tester.pump();

    expect(tester.widget<TextButton>(revokeFinder).onPressed, isNull);
    expect(
      find.descendant(
        of: revokeFinder,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    verify(() => mockTripRepository.revokeConnectedApp('tp_alpha')).called(1);

    revokeCompleter.completeError(Exception('offline'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('connected-app-row-tp_alpha')), findsOneWidget);
    expect(find.text('撤銷應用程式失敗，請稍後再試'), findsOneWidget);
    expect(tester.widget<TextButton>(revokeFinder).onPressed, isNotNull);
    expect(find.widgetWithText(TextButton, '重試'), findsOneWidget);
  });

  testWidgets('載入失敗仍保留返回與重試，空狀態可辨識', (tester) async {
    when(
      () => mockTripRepository.fetchConnectedApps(),
    ).thenAnswer((_) => Future<List<ConnectedApp>>.error(Exception('offline')));
    await pumpScreen(tester);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const ValueKey('tp-app-bar-back')), findsOneWidget);
    expect(find.text('無法載入已連結的應用程式'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '重試'), findsOneWidget);

    when(
      () => mockTripRepository.fetchConnectedApps(),
    ).thenAnswer((_) async => const <ConnectedApp>[]);
    await tester.tap(find.widgetWithText(TextButton, '重試'));
    await tester.pumpAndSettle();

    expect(find.text('目前沒有已連結的應用程式'), findsOneWidget);
    expect(find.byKey(const ValueKey('tp-app-bar-back')), findsOneWidget);
  });
}
