import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/features/trip_detail/trip_days_lookup.dart';
import 'package:tripline/features/trip_detail/trip_providers.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/models/trip.dart';

void main() {
  test('共用索引以 dayNum 找到停留點所在日與每日停留點', () {
    const days = [
      TripDay(
        id: 1,
        dayNum: 1,
        version: 0,
        timeline: [TimelineEntry(id: 11, sortOrder: 0, title: 'a', version: 0)],
      ),
      TripDay(
        id: 7,
        dayNum: 3,
        version: 0,
        timeline: [TimelineEntry(id: 22, sortOrder: 0, title: 'b', version: 0)],
      ),
    ];

    final index = TripDaysIndex(days);

    expect(index.dayNumContaining(22), 3);
    expect(index.dayNumContaining(99), isNull);
    expect(index.entriesForDay(3).single.id, 22);
    expect(index.entriesForDay(2), isEmpty);
  });

  test('衍生 provider 使用同一份行程日發射', () async {
    const days = [
      TripDay(
        id: 7,
        dayNum: 3,
        version: 0,
        timeline: [TimelineEntry(id: 22, sortOrder: 0, title: 'b', version: 0)],
      ),
    ];
    final container = ProviderContainer(
      overrides: [
        tripDaysProvider.overrideWith((ref, tripId) => Stream.value(days)),
      ],
    );
    addTearDown(container.dispose);
    container.listen(tripDaysIndexProvider('okinawa'), (_, _) {});

    await container.read(tripDaysProvider('okinawa').future);

    final index = container.read(tripDaysIndexProvider('okinawa')).requireValue;
    expect(index.dayNumContaining(22), 3);
  });

  test('行程標題依詳情、摘要、名稱順序回退並略過空字串', () {
    const summary = TripSummary(tripId: 'trip-1', name: '摘要名稱', title: '摘要標題');
    expect(
      tripDisplayTitle(
        detail: const Trip(id: 'trip-1', name: '詳情名稱', title: '詳情標題'),
        summary: summary,
      ),
      '詳情標題',
    );
    expect(
      tripDisplayTitle(
        detail: const Trip(id: 'trip-1', name: '詳情名稱', title: '  '),
        summary: summary,
      ),
      '摘要標題',
    );
    expect(
      tripDisplayTitle(
        detail: const Trip(id: 'trip-1', name: '詳情名稱'),
      ),
      '詳情名稱',
    );
    expect(tripDisplayTitle(), '行程');
  });
}
