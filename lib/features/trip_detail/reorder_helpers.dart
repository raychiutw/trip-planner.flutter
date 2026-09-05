/// reorder 共用工具:timeline entry 與 notes 各區的拖曳排序都用這支。
library;

typedef EntryReorderUpdate = ({int id, int sortOrder, int? dayId});

typedef EntryReorderPlan<T> = ({
  Map<int, List<T>> entriesByDayId,
  Set<int> affectedDayIds,
  List<EntryReorderUpdate> updates,
});

/// reorder 後重編連續 sort_order。newIndex 為 ReorderableListView 的 onReorderItem
/// 已調整後的索引（item 移除後的位置）,不需再 -1。
List<({int id, int sortOrder})> reorderedSortOrders(
  List<int> ids,
  int oldIndex,
  int newIndex,
) {
  final list = [...ids];
  final moved = list.removeAt(oldIndex);
  list.insert(newIndex, moved);
  return [for (var i = 0; i < list.length; i++) (id: list[i], sortOrder: i)];
}

Map<int, List<T>> moveEntryBetweenDays<T>(
  Map<int, List<T>> entriesByDayId, {
  required int sourceDayId,
  required int sourceIndex,
  required int targetDayId,
  required int targetIndex,
}) {
  final result = {
    for (final day in entriesByDayId.entries) day.key: List<T>.of(day.value),
  };
  final source = result[sourceDayId]!;
  final moved = source.removeAt(sourceIndex);
  final target = result[targetDayId]!;
  var insertionIndex = targetIndex;
  if (sourceDayId == targetDayId && targetIndex > sourceIndex) {
    insertionIndex--;
  }
  insertionIndex = insertionIndex.clamp(0, target.length);
  target.insert(insertionIndex, moved);
  return result;
}

List<({int id, int sortOrder, int? dayId})> reorderUpdatesForDays(
  Map<int, List<int>> entryIdsByDayId,
  Set<int> affectedDayIds,
) {
  final dayIds = affectedDayIds.toList()..sort();
  return [
    for (final dayId in dayIds)
      for (
        var index = 0;
        index < (entryIdsByDayId[dayId]?.length ?? 0);
        index++
      )
        (id: entryIdsByDayId[dayId]![index], sortOrder: index, dayId: dayId),
  ];
}

/// 拖曳、鍵盤、輔助動作與「移到其他 Day」共用的單次 batch 計畫。
EntryReorderPlan<T> planEntryReorder<T>(
  Map<int, List<T>> entriesByDayId, {
  required int sourceDayId,
  required int sourceIndex,
  required int targetDayId,
  required int targetIndex,
  required int Function(T entry) idOf,
}) {
  final entries = moveEntryBetweenDays(
    entriesByDayId,
    sourceDayId: sourceDayId,
    sourceIndex: sourceIndex,
    targetDayId: targetDayId,
    targetIndex: targetIndex,
  );
  final affectedDayIds = {sourceDayId, targetDayId};
  final updates = reorderUpdatesForDays({
    for (final day in entries.entries)
      day.key: [for (final entry in day.value) idOf(entry)],
  }, affectedDayIds);
  return (
    entriesByDayId: entries,
    affectedDayIds: affectedDayIds,
    updates: updates,
  );
}

/// 重排被拒絕的原因;畫面據此提示,不必自己重新推導索引。
enum EntryReorderRejection {
  targetDayMissing,
  entryMissing,
  entryMovedToAnotherDay,
}

sealed class EntryReorderOutcome<T> {
  const EntryReorderOutcome();
}

final class EntryReorderPlanned<T> extends EntryReorderOutcome<T> {
  const EntryReorderPlanned(this.plan);

  final EntryReorderPlan<T> plan;
}

final class EntryReorderRejected<T> extends EntryReorderOutcome<T> {
  const EntryReorderRejected(this.reason);

  final EntryReorderRejection reason;
}

/// 拖放的 slot(0..len,項目之間的縫)換成「移動後的位置」:同日往下拖時,
/// 自己被移走後後面的項目會往前補一格。
int slotToPosition({
  required int slot,
  required bool sameDay,
  required int sourceIndex,
}) => sameDay && slot > sourceIndex ? slot - 1 : slot;

/// 給定「哪一筆、原本在哪一天、要到哪一天的哪個位置」與當前快照,產出計畫或說明
/// 原因的拒絕。來源索引由這裡依 id 重新找(拖曳資料可能已經過期),呼叫端不再各自
/// 在 -1 / +2 之間補償:上移就是 index - 1、下移就是 index + 1。
EntryReorderOutcome<T> planEntryMove<T>(
  Map<int, List<T>> snapshot, {
  required int entryId,
  required int expectedSourceDayId,
  required int targetDayId,
  required int targetPosition,
  required int Function(T entry) idOf,
}) {
  if (!snapshot.containsKey(targetDayId)) {
    return const EntryReorderRejected(EntryReorderRejection.targetDayMissing);
  }
  int? sourceDayId;
  var sourceIndex = -1;
  for (final day in snapshot.entries) {
    final index = day.value.indexWhere((entry) => idOf(entry) == entryId);
    if (index >= 0) {
      sourceDayId = day.key;
      sourceIndex = index;
      break;
    }
  }
  if (sourceDayId == null) {
    return const EntryReorderRejected(EntryReorderRejection.entryMissing);
  }
  if (sourceDayId != expectedSourceDayId) {
    return const EntryReorderRejected(
      EntryReorderRejection.entryMovedToAnotherDay,
    );
  }
  // moveEntryBetweenDays 吃的是 slot 語意(同日往下會自己減一),這裡把位置轉回去。
  final slot = sourceDayId == targetDayId && targetPosition > sourceIndex
      ? targetPosition + 1
      : targetPosition;
  return EntryReorderPlanned(
    planEntryReorder<T>(
      snapshot,
      sourceDayId: sourceDayId,
      sourceIndex: sourceIndex,
      targetDayId: targetDayId,
      targetIndex: slot,
      idOf: idOf,
    ),
  );
}
