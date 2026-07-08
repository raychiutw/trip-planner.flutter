import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/features/account/settings/notifications_screen.dart';
import 'package:tripline/theme/app_theme.dart';

void main() {
  testWidgets('通知設定頁顯示規劃中的通知類型', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const NotificationsScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('notifications-page')), findsOneWidget);
    expect(find.text('通知設定'), findsOneWidget);
    expect(find.text('即將推出'), findsNWidgets(4));

    expect(find.byKey(const ValueKey('notif-row-trip-update')), findsOneWidget);
    expect(find.text('行程更新通知'), findsOneWidget);
    expect(find.text('旅伴改了行程、AI 排程完成'), findsOneWidget);

    expect(find.byKey(const ValueKey('notif-row-invitation')), findsOneWidget);
    expect(find.text('旅伴邀請'), findsOneWidget);
    expect(find.text('收到新的共編邀請'), findsOneWidget);

    expect(find.byKey(const ValueKey('notif-row-system')), findsOneWidget);
    expect(find.text('系統通知'), findsOneWidget);
    expect(find.text('Tripline 維護、版本更新'), findsOneWidget);
  });
}
