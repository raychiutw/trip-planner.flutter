/// reorder 共用工具:timeline entry 與 notes 各區的拖曳排序都用這支。
library;

/// reorder 後重編連續 sort_order。newIndex 為 ReorderableListView 的 onReorderItem
/// 已調整後的索引（item 移除後的位置）,不需再 -1。
List<({int id, int sortOrder})> reorderedSortOrders(
    List<int> ids, int oldIndex, int newIndex) {
  final list = [...ids];
  final moved = list.removeAt(oldIndex);
  list.insert(newIndex, moved);
  return [for (var i = 0; i < list.length; i++) (id: list[i], sortOrder: i)];
}
