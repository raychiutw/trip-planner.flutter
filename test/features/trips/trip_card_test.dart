import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/features/trips/trip_card.dart';
import 'package:tripline/theme/app_theme.dart';

Future<void> pumpCard(
  WidgetTester tester,
  TripSummary trip, {
  String? currentUserId,
  VoidCallback? onTap,
  VoidCallback? onLongPress,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: Scaffold(
        body: TripCard(
          trip: trip,
          currentUserId: currentUserId,
          onTap: onTap,
          onLongPress: onLongPress,
        ),
      ),
    ),
  );
}

void main() {
  group('TripSummary.displayTitle', () {
    test('title 有值 → title(trim)', () {
      expect(
        const TripSummary(
          tripId: 't',
          name: 'okinawa',
          title: '  沖繩  ',
        ).displayTitle,
        '沖繩',
      );
    });
    test('title null / 空字串 → 退回 name', () {
      expect(
        const TripSummary(tripId: 't', name: 'okinawa').displayTitle,
        'okinawa',
      );
      expect(
        const TripSummary(
          tripId: 't',
          name: 'okinawa',
          title: '   ',
        ).displayTitle,
        'okinawa',
      );
    });
  });

  group('TripCard 渲染與互動', () {
    testWidgets('緊湊卡片顯示 eyebrow、標題,不顯示大型首字 cover', (tester) async {
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
      expect(find.text('沖'), findsNothing);
      expect(find.text('5 天'), findsOneWidget); // eyebrow
      final cover = tester.widget<Container>(
        find.byKey(const ValueKey('trip-card-cover-okinawa')),
      );
      expect(
        (cover.decoration! as BoxDecoration).color,
        AppTheme.light().colorScheme.surfaceContainerHigh,
      );

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

    testWidgets('200% 動態字級不會造成版面溢位', (tester) async {
      await pumpCard(
        tester,
        const TripSummary(
          tripId: 'large-text',
          name: 'large-text',
          title: '沖繩無障礙家族之旅',
          countries: '日本',
          totalDays: 5,
          startDate: '2026-04-23',
          endDate: '2026-04-27',
        ),
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('TripCard eyebrow（countries · N 天）', () {
    testWidgets('countries 有值 → 「{countries} · {N} 天」', (tester) async {
      await pumpCard(
        tester,
        const TripSummary(
          tripId: 'okinawa',
          name: 'okinawa',
          title: '沖繩家族之旅',
          totalDays: 5,
          countries: 'JP',
        ),
      );
      expect(find.text('JP · 5 天'), findsOneWidget);
    });

    testWidgets('countries 為 null → 只顯示「{N} 天」', (tester) async {
      await pumpCard(
        tester,
        const TripSummary(
          tripId: 'okinawa',
          name: 'okinawa',
          title: '沖繩家族之旅',
          totalDays: 5,
        ),
      );
      expect(find.text('5 天'), findsOneWidget);
    });

    testWidgets('countries 有值但 totalDays 為 null → 只顯示 countries', (
      tester,
    ) async {
      await pumpCard(
        tester,
        const TripSummary(
          tripId: 'okinawa',
          name: 'okinawa',
          title: '沖繩家族之旅',
          countries: 'JP',
        ),
      );
      expect(find.text('JP'), findsOneWidget);
    });
  });

  group('TripCard 建立者標示', () {
    testWidgets('ownerUserId == currentUserId → 顯示「由你建立」', (tester) async {
      await pumpCard(
        tester,
        const TripSummary(
          tripId: 'okinawa',
          name: 'okinawa',
          title: '沖繩家族之旅',
          totalDays: 5,
          ownerUserId: 'u-ray',
          ownerDisplayName: 'Ray Chiu',
        ),
        currentUserId: 'u-ray',
      );
      expect(find.text('由你建立'), findsOneWidget);
      expect(find.text('Ray Chiu'), findsNothing);
    });

    testWidgets(
      'ownerUserId != currentUserId → 顯示 ownerDisplayName + 首字 avatar',
      (tester) async {
        await pumpCard(
          tester,
          const TripSummary(
            tripId: 'okinawa',
            name: 'okinawa',
            title: '沖繩家族之旅',
            totalDays: 5,
            ownerUserId: 'u-amy',
            ownerDisplayName: 'Amy Wang',
          ),
          currentUserId: 'u-ray',
        );
        expect(find.text('由你建立'), findsNothing);
        expect(find.text('Amy Wang'), findsOneWidget);
        // 首字 avatar（非抓圖）
        expect(find.byType(CircleAvatar), findsOneWidget);
        expect(find.text('A'), findsOneWidget);
      },
    );

    testWidgets('ownerUserId / ownerDisplayName 皆缺 → 不顯示建立者列', (tester) async {
      await pumpCard(
        tester,
        const TripSummary(
          tripId: 'okinawa',
          name: 'okinawa',
          title: '沖繩家族之旅',
          totalDays: 5,
        ),
        currentUserId: 'u-ray',
      );
      expect(find.text('由你建立'), findsNothing);
      expect(find.byType(CircleAvatar), findsNothing);
    });

    testWidgets('非自己但 ownerDisplayName 缺 → 不顯示建立者列', (tester) async {
      await pumpCard(
        tester,
        const TripSummary(
          tripId: 'okinawa',
          name: 'okinawa',
          title: '沖繩家族之旅',
          totalDays: 5,
          ownerUserId: 'u-amy',
        ),
        currentUserId: 'u-ray',
      );
      expect(find.text('由你建立'), findsNothing);
      expect(find.byType(CircleAvatar), findsNothing);
    });
  });

  group('TripCard 日期範圍', () {
    testWidgets('startDate + endDate 都有 → 「startDate – endDate」', (
      tester,
    ) async {
      await pumpCard(
        tester,
        const TripSummary(
          tripId: 'okinawa',
          name: 'okinawa',
          title: '沖繩家族之旅',
          totalDays: 5,
          startDate: '2026-04-23',
          endDate: '2026-04-27',
        ),
      );
      expect(find.text('2026-04-23 – 2026-04-27'), findsOneWidget);
    });

    testWidgets('startDate / endDate 缺 → 不顯示日期範圍', (tester) async {
      await pumpCard(
        tester,
        const TripSummary(
          tripId: 'okinawa',
          name: 'okinawa',
          title: '沖繩家族之旅',
          totalDays: 5,
        ),
      );
      expect(find.textContaining('–'), findsNothing);
    });
  });
}
