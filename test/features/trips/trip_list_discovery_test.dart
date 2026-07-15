import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tripline/features/trips/trips_list_screen.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/theme/app_theme.dart';

Widget _buildApp(List<TripSummary> trips) {
  final router = GoRouter(
    initialLocation: '/trips',
    routes: [
      GoRoute(
        path: '/trips',
        builder: (context, state) => const TripsListScreen(),
      ),
      GoRoute(
        path: '/new-trip',
        builder: (context, state) => const Scaffold(body: Text('new-trip')),
      ),
      GoRoute(
        path: '/trips/:tripId',
        builder: (context, state) => const Scaffold(body: Text('trip-detail')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [myTripsProvider.overrideWith((ref) => Stream.value(trips))],
    child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
}

void main() {
  testWidgets('空行程清單直接提供建立入口', (tester) async {
    await tester.pumpWidget(_buildApp(const []));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('trips-empty-create')));
    await tester.pumpAndSettle();

    expect(find.text('new-trip'), findsOneWidget);
  });

  testWidgets('行程卡以可見 More 按鈕開啟進階操作', (tester) async {
    await tester.pumpWidget(
      _buildApp(const [
        TripSummary(tripId: 'okinawa', name: 'okinawa', title: '沖繩'),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('trip-card-more-okinawa')));
    await tester.pumpAndSettle();

    expect(find.text('分享'), findsOneWidget);
    expect(find.text('共編設定'), findsOneWidget);
    expect(find.text('AI 健檢'), findsOneWidget);
  });
}
