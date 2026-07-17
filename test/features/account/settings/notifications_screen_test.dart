import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/account/settings/notifications_screen.dart';
import 'package:tripline/models/user.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_settings_group.dart';

class _MockTripRepository extends Mock implements TripRepository {}

void main() {
  late _MockTripRepository mockTripRepository;
  late AccountNotificationPreferences prefs;

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (retryCount, error) => null,
        overrides: [
          tripRepositoryProvider.overrideWithValue(mockTripRepository),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const NotificationsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    mockTripRepository = _MockTripRepository();
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

  testWidgets('載入失敗顯示 persistent retry panel', (tester) async {
    when(
      () => mockTripRepository.fetchAccountNotificationPreferences(),
    ).thenThrow(Exception('boom'));

    await pumpScreen(tester);

    expect(find.text('無法載入通知設定'), findsOneWidget);
    expect(find.byKey(const ValueKey('notifications-retry')), findsOneWidget);
  });
}
