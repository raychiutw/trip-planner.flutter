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
