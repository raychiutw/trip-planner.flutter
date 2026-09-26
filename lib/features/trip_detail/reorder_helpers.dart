/// 筆記各區的拖曳排序工具。
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
