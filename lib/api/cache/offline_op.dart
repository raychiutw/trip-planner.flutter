/// 離線寫入的樂觀更新描述:patcher 類型 + 受影響的 GET 快取 key + 參數。
library;

class OfflineOp {
  const OfflineOp(this.type, this.cacheKey, this.args);

  /// 對應 optimistic_patchers 的 registry key(如 'entry.add')。
  final String type;

  /// 要套樂觀 patch 的 GET 快取 key(如 days 的 cacheKey)。
  final String cacheKey;

  /// patcher 所需參數。
  final Map<String, dynamic> args;
}
