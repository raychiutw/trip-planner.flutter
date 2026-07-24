import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/app/notification_permission.dart';
import 'package:tripline/features/account/settings/notifications_screen.dart';
import 'package:tripline/models/user.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_settings_group.dart';

class _MockTripRepository extends Mock implements TripRepository {}

class _FakeNotificationPermissionService
    implements NotificationPermissionService {
  NotificationPermissionStatus status = NotificationPermissionStatus.granted;
  NotificationPermissionStatus requestResult =
      NotificationPermissionStatus.granted;
  Object? statusError;
  Object? requestError;
  int statusCalls = 0;
  int requestCalls = 0;
  int openSettingsCalls = 0;

  @override
  Future<NotificationPermissionStatus> getStatus() async {
    statusCalls++;
    if (statusError case final error?) throw error;
    return status;
  }

  @override
  Future<NotificationPermissionStatus> request() async {
    requestCalls++;
    if (requestError case final error?) throw error;
    status = requestResult;
    return requestResult;
  }

  @override
  Future<void> openSettings() async {
    openSettingsCalls++;
  }
}

void main() {
  late _MockTripRepository mockTripRepository;
  late _FakeNotificationPermissionService permissionService;
  late AccountNotificationPreferences prefs;

  Future<void> pumpScreen(
    WidgetTester tester, {
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (retryCount, error) => null,
        overrides: [
          tripRepositoryProvider.overrideWithValue(mockTripRepository),
          notificationPermissionServiceProvider.overrideWithValue(
            permissionService,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          ),
          home: const NotificationsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    mockTripRepository = _MockTripRepository();
    permissionService = _FakeNotificationPermissionService();
    prefs = const AccountNotificationPreferences(
      tripUpdates: true,
      invitations: false,
      system: true,
      updatedAt: '2026-07-09T00:00:00Z',
    );
    when(
      () => mockTripRepository.fetchAccountNotificationPreferences(),
    ).thenAnswer((_) async => prefs);
    when(
      () => mockTripRepository.updateAccountNotificationPreferences(
        tripUpdates: any(named: 'tripUpdates'),
        invitations: any(named: 'invitations'),
        system: any(named: 'system'),
      ),
    ).thenAnswer((invocation) async {
      prefs = prefs.copyWith(
        tripUpdates:
            invocation.namedArguments[#tripUpdates] as bool? ??
            prefs.tripUpdates,
        invitations:
            invocation.namedArguments[#invitations] as bool? ??
            prefs.invitations,
        system: invocation.namedArguments[#system] as bool? ?? prefs.system,
        updatedAt: '2026-07-09T01:00:00Z',
      );
      return prefs;
    });
  });

  testWidgets('通知設定頁載入目前偏好並顯示 switches', (tester) async {
    await pumpScreen(tester);

    expect(find.byKey(const ValueKey('notifications-page')), findsOneWidget);
    expect(find.text('通知設定'), findsOneWidget);
    expect(find.text('行程更新通知'), findsOneWidget);
    expect(find.text('旅伴邀請'), findsOneWidget);
    expect(find.text('系統通知'), findsOneWidget);
    expect(find.byType(TpSettingsGroup), findsOneWidget);
    expect(find.byType(Card), findsNothing);

    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const ValueKey('notif-switch-trip-updates')),
          )
          .value,
      isTrue,
    );
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const ValueKey('notif-switch-invitations')),
          )
          .value,
      isFalse,
    );
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const ValueKey('notif-switch-system')),
          )
          .value,
      isTrue,
    );
  });

  testWidgets('切換通知會 PATCH 對應欄位並刷新畫面', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('notif-switch-invitations')));
    await tester.pumpAndSettle();

    verify(
      () => mockTripRepository.updateAccountNotificationPreferences(
        invitations: true,
      ),
    ).called(1);
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const ValueKey('notif-switch-invitations')),
          )
          .value,
      isTrue,
    );
    expect(find.text('通知設定已更新'), findsOneWidget);
  });

  testWidgets('首次啟用通知先說明用途，確認後才請求系統權限', (tester) async {
    permissionService
      ..status = NotificationPermissionStatus.notDetermined
      ..requestResult = NotificationPermissionStatus.granted;
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('notif-switch-invitations')));
    await tester.pumpAndSettle();

    expect(find.text('允許 Tripline 傳送通知？'), findsOneWidget);
    expect(permissionService.requestCalls, 0);
    verifyNever(
      () => mockTripRepository.updateAccountNotificationPreferences(
        invitations: true,
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, '允許通知'));
    await tester.pumpAndSettle();

    expect(permissionService.requestCalls, 1);
    verify(
      () => mockTripRepository.updateAccountNotificationPreferences(
        invitations: true,
      ),
    ).called(1);
  });

  testWidgets('通知權限被拒後不重複要求，並提供前往系統設定', (tester) async {
    permissionService
      ..status = NotificationPermissionStatus.notDetermined
      ..requestResult = NotificationPermissionStatus.denied;
    await pumpScreen(tester);

    final switchFinder = find.byKey(const ValueKey('notif-switch-invitations'));
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '允許通知'));
    await tester.pumpAndSettle();

    expect(permissionService.requestCalls, 1);
    expect(find.text('通知權限尚未開啟'), findsOneWidget);
    verifyNever(
      () => mockTripRepository.updateAccountNotificationPreferences(
        invitations: true,
      ),
    );

    await tester.tap(switchFinder);
    await tester.pumpAndSettle();
    expect(permissionService.requestCalls, 1);
    expect(find.text('允許 Tripline 傳送通知？'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('notifications-open-settings')));
    await tester.pump();
    expect(permissionService.openSettingsCalls, 1);
  });

  testWidgets('初次顯示與回到前景會同步系統通知權限', (tester) async {
    permissionService.status = NotificationPermissionStatus.denied;
    await pumpScreen(tester);

    expect(permissionService.statusCalls, 1);
    expect(find.text('通知權限尚未開啟'), findsOneWidget);
    expect(permissionService.requestCalls, 0);

    permissionService.status = NotificationPermissionStatus.granted;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(permissionService.statusCalls, 2);
    expect(find.text('通知權限尚未開啟'), findsNothing);
  });

  testWidgets('權限狀態失敗的 Retry 會重新讀取 OS 權限', (tester) async {
    permissionService.statusError = Exception('permission unavailable');
    await pumpScreen(tester);

    expect(permissionService.statusCalls, 1);
    expect(find.text('無法讀取通知權限，請稍後再試'), findsOneWidget);

    permissionService
      ..statusError = null
      ..status = NotificationPermissionStatus.granted;
    await tester.tap(find.byKey(const ValueKey('notifications-retry')));
    await tester.pumpAndSettle();

    expect(permissionService.statusCalls, 2);
    expect(find.text('無法讀取通知權限，請稍後再試'), findsNothing);
  });

  testWidgets('關閉既有通知不檢查或請求系統權限', (tester) async {
    permissionService.status = NotificationPermissionStatus.denied;
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('notif-switch-trip-updates')));
    await tester.pumpAndSettle();

    expect(permissionService.statusCalls, 1);
    expect(permissionService.requestCalls, 0);
    verify(
      () => mockTripRepository.updateAccountNotificationPreferences(
        tripUpdates: false,
      ),
    ).called(1);
  });

  testWidgets('載入失敗顯示 persistent retry panel', (tester) async {
    when(
      () => mockTripRepository.fetchAccountNotificationPreferences(),
    ).thenThrow(Exception('boom'));

    await pumpScreen(tester);

    expect(find.text('無法載入通知設定'), findsOneWidget);
    expect(find.byKey(const ValueKey('notifications-retry')), findsOneWidget);
  });

  testWidgets('200% Dynamic Type 下通知 switches 維持可捲動且不裁切', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpScreen(tester, textScaler: const TextScaler.linear(2));

    expect(find.text('行程更新通知'), findsOneWidget);
    expect(find.byKey(const ValueKey('notifications-page')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
