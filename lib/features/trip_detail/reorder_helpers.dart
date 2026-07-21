/// reorder 共用工具:timeline entry 與 notes 各區的拖曳排序都用這支。
library;

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
