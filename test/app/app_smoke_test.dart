/// App smoke test：已登入狀態 pump TriplineApp，顯示 5-tab NavigationBar。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/main.dart';
import 'package:tripline/models/user.dart';

/// 固定回傳已登入使用者的假 AuthNotifier（不打 API）。
class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<UserInfo?> build() async => const UserInfo(
    id: 'user-1',
    email: 'traveler@example.com',
    emailVerified: true,
    displayName: 'Ray',
  );
}

class _MockTripRepository extends Mock implements TripRepository {}

void main() {
  testWidgets('已登入時顯示 5-tab NavigationBar', (tester) async {
    final mockTripRepository = _MockTripRepository();
    when(mockTripRepository.watchMyTrips).thenAnswer((_) => Stream.value([]));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_FakeAuthNotifier.new),
          tripRepositoryProvider.overrideWithValue(mockTripRepository),
        ],
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byType(NavigationDestination),
      ),
      findsNWidgets(5),
    );
    for (final tabLabel in ['聊天', '行程', '地圖', '收藏', '帳號']) {
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(tabLabel),
        ),
        findsOneWidget,
        reason: 'NavigationBar 應包含「$tabLabel」tab',
      );
    }
  });
}
