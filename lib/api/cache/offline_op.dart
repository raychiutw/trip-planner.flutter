/// 離線寫入的樂觀更新描述:patcher 類型 + 受影響的 GET 快取 key + 參數。
library;

import 'cache_keys.dart';

/// 樂觀 patch 的目標資源;cache key 的拼法只在這裡一份。
enum OfflineResource {
  /// `GET /trips/:id/days?all=1`(整包 timeline)。
  tripDays,

  /// `GET /trips/:id/notes`(五區聚合)。
  tripNotes;

  String cacheKey(String tripId) {
    final encoded = Uri.encodeComponent(tripId);
    return switch (this) {
      tripDays => cacheKeyFor('GET', '/trips/$encoded/days', const {
        'all': '1',
      }),
      tripNotes => cacheKeyFor('GET', '/trips/$encoded/notes'),
    };
  }
}

class OfflineOp {
  const OfflineOp(this.type, this.cacheKey, this.args);

  /// 以資源命名,不手拼 cache key。
  OfflineOp.of(this.type, OfflineResource resource, String tripId, this.args)
    : cacheKey = resource.cacheKey(tripId);

  /// 對應 optimistic_patchers 的 registry key(如 'entry.add')。
  final String type;

  /// 要套樂觀 patch 的 GET 快取 key(如 days 的 cacheKey)。
  final String cacheKey;

  /// patcher 所需參數。
  final Map<String, dynamic> args;
}
