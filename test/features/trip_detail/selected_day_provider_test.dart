import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/features/trip_detail/selected_day_provider.dart';
import 'package:tripline/features/trip_detail/trip_days_lookup.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/entry.dart';

void main() {
  group('共用選取日', () {
    testWidgets('背景分支不能覆蓋目前選取日', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(selectedDayProvider.notifier);
      controller.select(tripId: 'okinawa', dayNum: 1);
      late BuildContext branchContext;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: TickerMode(
              enabled: false,
              child: Builder(
                builder: (context) {
                  branchContext = context;
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );

      controller.publish(
        branchContext,
        const SelectedTripDay(tripId: 'okinawa', dayNum: 3),
      );

      expect(container.read(selectedDayProvider).dayNumFor('okinawa'), 1);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: TickerMode(
              enabled: true,
              child: Builder(
                builder: (context) {
                  branchContext = context;
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );
      controller.publish(
        branchContext,
        const SelectedTripDay(tripId: 'okinawa', dayNum: 3),
      );
      expect(container.read(selectedDayProvider).dayNumFor('okinawa'), 3);
    });

    test('初始選取依查詢日期、停留點、共用值、第一天排序', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(selectedDayProvider.notifier);
      final index = TripDaysIndex(const [
        TripDay(id: 1, dayNum: 1, version: 0),
        TripDay(
          id: 7,
          dayNum: 3,
          version: 0,
          timeline: [
            TimelineEntry(id: 22, sortOrder: 0, title: 'b', version: 0),
          ],
        ),
      ]);

      controller.selectAll(tripId: 'okinawa');

      expect(
        controller.resolveInitial(
          tripId: 'okinawa',
          index: index,
          routeDayNum: 1,
          entryId: 22,
          allowAll: true,
        ),
        const SelectedTripDay(tripId: 'okinawa', dayNum: 1),
      );
      expect(
        controller.resolveInitial(
          tripId: 'okinawa',
          index: index,
          entryId: 22,
          allowAll: true,
        ),
        const SelectedTripDay(tripId: 'okinawa', dayNum: 3),
      );
      expect(
        controller.resolveInitial(
          tripId: 'okinawa',
          index: index,
          allowAll: true,
        ),
        const SelectedAllDays(tripId: 'okinawa'),
      );
      expect(
        controller.resolveInitial(tripId: 'okinawa', index: index),
        const SelectedTripDay(tripId: 'okinawa', dayNum: 1),
      );
    });

    test('全部與未指定是不同狀態，且只屬於目前行程', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(selectedDayProvider.notifier);
      expect(container.read(selectedDayProvider), isNull);

      controller.selectAll(tripId: 'okinawa');

      final selected = container.read(selectedDayProvider);
      expect(selected, isA<SelectedAllDays>());
      expect(selected.showsAllDaysFor('okinawa'), isTrue);
      expect(selected.showsAllDaysFor('tokyo'), isFalse);
      expect(selected.dayNumFor('okinawa'), isNull);
    });

    test('預設沒有選取日', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(selectedDayProvider), isNull);
      expect(container.read(selectedDayProvider).dayNumFor('okinawa'), isNull);
    });

    test('寫入後同一行程讀得到天數', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(selectedDayProvider.notifier)
          .select(tripId: 'okinawa', dayNum: 3);

      expect(container.read(selectedDayProvider).dayNumFor('okinawa'), 3);
    });

    test('型別綁行程：切換行程後不殘留前一個行程的天數', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(selectedDayProvider.notifier)
          .select(tripId: 'okinawa', dayNum: 3);

      expect(container.read(selectedDayProvider).dayNumFor('tokyo'), isNull);

      container
          .read(selectedDayProvider.notifier)
          .select(tripId: 'tokyo', dayNum: 1);

      expect(container.read(selectedDayProvider).dayNumFor('tokyo'), 1);
      expect(container.read(selectedDayProvider).dayNumFor('okinawa'), isNull);
    });

    test('同一組行程與天數不重複通知', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      var notifications = 0;
      container.listen(selectedDayProvider, (_, _) => notifications++);

      final controller = container.read(selectedDayProvider.notifier);
      controller.select(tripId: 'okinawa', dayNum: 2);
      controller.select(tripId: 'okinawa', dayNum: 2);

      expect(notifications, 1);
    });

    test('空的 tripId 不寫入', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(selectedDayProvider.notifier)
          .select(tripId: '', dayNum: 2);

      expect(container.read(selectedDayProvider), isNull);
    });
  });
}
