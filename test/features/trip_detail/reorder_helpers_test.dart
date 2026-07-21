import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/features/trip_detail/reorder_helpers.dart';

void main() {
  test('moves an entry to the terminal drop target on the same day', () {
    expect(
      moveEntryBetweenDays<int>(
        {
          10: [1, 2, 3, 4],
        },
        sourceDayId: 10,
        sourceIndex: 0,
        targetDayId: 10,
        targetIndex: 4,
      ),
      {
        10: [2, 3, 4, 1],
      },
    );
  });

  test('moves an entry across days and emits both day orders', () {
    final moved = moveEntryBetweenDays<int>(
      {
        10: [1, 2],
        20: [3],
      },
      sourceDayId: 10,
      sourceIndex: 1,
      targetDayId: 20,
      targetIndex: 1,
    );

    expect(moved, {
      10: [1],
      20: [3, 2],
    });
    expect(reorderUpdatesForDays(moved, {10, 20}), [
      (id: 1, sortOrder: 0, dayId: 10),
      (id: 3, sortOrder: 0, dayId: 20),
      (id: 2, sortOrder: 1, dayId: 20),
    ]);
  });

  test('moves an entry into an empty day', () {
    expect(
      moveEntryBetweenDays<int>(
        {
          10: [1],
          20: [],
        },
        sourceDayId: 10,
        sourceIndex: 0,
        targetDayId: 20,
        targetIndex: 0,
      ),
      {
        10: <int>[],
        20: [1],
      },
    );
  });
}
