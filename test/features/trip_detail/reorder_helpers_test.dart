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

  group('planEntryMove:給拖曳與快照,產出計畫或說明原因的拒絕;索引一律是「移動後的位置」', () {
    const snapshot = {
      10: [1, 2, 3],
      20: [4],
    };
    int idOf(int e) => e;

    test('同日上移:位置 index - 1', () {
      final outcome = planEntryMove<int>(
        snapshot,
        entryId: 3,
        expectedSourceDayId: 10,
        targetDayId: 10,
        targetPosition: 1,
        idOf: idOf,
      );
      expect(outcome, isA<EntryReorderPlanned<int>>());
      expect((outcome as EntryReorderPlanned<int>).plan.entriesByDayId[10], [
        1,
        3,
        2,
      ]);
    });

    test('同日下移:位置 index + 1,不必 +2 補償', () {
      final outcome = planEntryMove<int>(
        snapshot,
        entryId: 1,
        expectedSourceDayId: 10,
        targetDayId: 10,
        targetPosition: 1,
        idOf: idOf,
      );
      expect((outcome as EntryReorderPlanned<int>).plan.entriesByDayId[10], [
        2,
        1,
        3,
      ]);
    });

    test('跨日移動:插到目標位置,兩天都在 updates 裡', () {
      final outcome =
          planEntryMove<int>(
                snapshot,
                entryId: 2,
                expectedSourceDayId: 10,
                targetDayId: 20,
                targetPosition: 0,
                idOf: idOf,
              )
              as EntryReorderPlanned<int>;
      expect(outcome.plan.entriesByDayId, {
        10: [1, 3],
        20: [2, 4],
      });
      expect(outcome.plan.affectedDayIds, {10, 20});
    });

    test('來源已失效(entry 不見 / 換了 Day / 目標 Day 不見)→ 說明原因的拒絕', () {
      expect(
        planEntryMove<int>(
          snapshot,
          entryId: 99,
          expectedSourceDayId: 10,
          targetDayId: 10,
          targetPosition: 0,
          idOf: idOf,
        ),
        isA<EntryReorderRejected>().having(
          (r) => r.reason,
          'reason',
          EntryReorderRejection.entryMissing,
        ),
      );
      expect(
        planEntryMove<int>(
          snapshot,
          entryId: 4,
          expectedSourceDayId: 10,
          targetDayId: 10,
          targetPosition: 0,
          idOf: idOf,
        ),
        isA<EntryReorderRejected>().having(
          (r) => r.reason,
          'reason',
          EntryReorderRejection.entryMovedToAnotherDay,
        ),
      );
      expect(
        planEntryMove<int>(
          snapshot,
          entryId: 1,
          expectedSourceDayId: 10,
          targetDayId: 30,
          targetPosition: 0,
          idOf: idOf,
        ),
        isA<EntryReorderRejected>().having(
          (r) => r.reason,
          'reason',
          EntryReorderRejection.targetDayMissing,
        ),
      );
    });

    test('slotToPosition:拖放的 slot 換成移動後位置;同日往下要扣掉自己', () {
      expect(slotToPosition(slot: 3, sameDay: true, sourceIndex: 0), 2);
      expect(slotToPosition(slot: 0, sameDay: true, sourceIndex: 2), 0);
      expect(slotToPosition(slot: 3, sameDay: false, sourceIndex: 0), 3);
    });
  });
}
