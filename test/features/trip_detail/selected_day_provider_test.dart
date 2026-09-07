import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/features/trip_detail/selected_day_provider.dart';

void main() {
  group('共用選取日', () {
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

  group('三態:指定某天 / 全部 / 未指定', () {
    test('selectAll 後同一行程是「全部」,dayNumFor 回 null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(selectedDayProvider.notifier).selectAll(tripId: 'okinawa');

      final shared = container.read(selectedDayProvider);
      expect(shared.showsAllDaysFor('okinawa'), isTrue);
      expect(shared.dayNumFor('okinawa'), isNull);
      expect(shared.showsAllDaysFor('kyoto'), isFalse);
    });

    test('未指定時 showsAllDaysFor 為 false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        container.read(selectedDayProvider).showsAllDaysFor('okinawa'),
        isFalse,
      );
    });

    testWidgets('publish:前景寫回,背景分支不寫回', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      late BuildContext foreground;
      late BuildContext background;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              children: [
                Builder(
                  builder: (context) {
                    foreground = context;
                    return const SizedBox();
                  },
                ),
                TickerMode(
                  enabled: false,
                  child: Builder(
                    builder: (context) {
                      background = context;
                      return const SizedBox();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      final notifier = container.read(selectedDayProvider.notifier);

      notifier.publish(background, tripId: 'okinawa', dayNum: 2);
      expect(container.read(selectedDayProvider), isNull, reason: '背景不寫回');

      notifier.publish(foreground, tripId: 'okinawa', dayNum: 2);
      expect(container.read(selectedDayProvider).dayNumFor('okinawa'), 2);

      notifier.publish(foreground, tripId: 'okinawa', dayNum: null);
      expect(
        container.read(selectedDayProvider).showsAllDaysFor('okinawa'),
        isTrue,
      );
    });
  });
}
