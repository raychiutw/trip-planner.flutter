import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/features/trips/trip_card.dart';
import 'package:tripline/theme/app_theme.dart';

Future<void> pumpCard(
  WidgetTester tester,
  TripSummary trip, {
  TripCardTone tone = TripCardTone.accent,
  VoidCallback? onTap,
  VoidCallback? onLongPress,
}) {
  return tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: TripCard(
        trip: trip,
        tone: tone,
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    ),
  ));
}

void main() {
  group('TripSummary.displayTitle', () {
    test('title 有值 → title(trim)', () {
      expect(
        const TripSummary(tripId: 't', name: 'okinawa', title: '  沖繩  ')
            .displayTitle,
        '沖繩',
      );
    });
    test('title null / 空字串 → 退回 name', () {
      expect(
        const TripSummary(tripId: 't', name: 'okinawa').displayTitle,
        'okinawa',
      );
      expect(
        const TripSummary(tripId: 't', name: 'okinawa', title: '   ')
            .displayTitle,
        'okinawa',
      );
    });
  });

  group('TripCard 渲染與互動', () {
    testWidgets('cover 首字、eyebrow、標題;tap / long-press 回呼', (tester) async {
      var tapped = 0;
      var longPressed = 0;
      await pumpCard(
        tester,
        const TripSummary(
          tripId: 'okinawa',
          name: 'okinawa',
          title: '沖繩家族之旅',
          totalDays: 5,
        ),
        onTap: () => tapped++,
        onLongPress: () => longPressed++,
      );

      expect(find.text('沖繩家族之旅'), findsOneWidget);
      expect(find.text('沖'), findsOneWidget); // cover 首字
      expect(find.text('5 天'), findsOneWidget); // eyebrow

      await tester.tap(find.text('沖繩家族之旅'));
      await tester.longPress(find.text('沖繩家族之旅'));
      expect(tapped, 1);
      expect(longPressed, 1);
    });

    testWidgets('totalDays 為 null → 不顯示 eyebrow', (tester) async {
      await pumpCard(
        tester,
        const TripSummary(tripId: 'b', name: 'busan', title: '釜山美食團'),
      );
      expect(find.text('釜山美食團'), findsOneWidget);
      expect(find.textContaining('天'), findsNothing);
    });
  });
}
