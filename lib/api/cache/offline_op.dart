/// 離線寫入的樂觀更新描述:patcher 類型 + 受影響的資源 + 參數。
library;

import 'cache_keys.dart';

/// 樂觀 patch 的目標資源;cache key 的拼法只在這裡一份。
enum OfflineResource {
  /// `GET /trips/:id/days?all=1`(整包 timeline)。
  tripDays,

  /// `GET /trips/:id/notes`(五區聚合)。
  tripNotes;

  /// 對應既有樂觀 patch 類型的唯一資源。
  static OfflineResource forType(String type) => switch (type) {
    'entry.add' || 'entry.update' || 'entry.delete' => tripDays,
    'note.create' || 'note.update' || 'note.delete' => tripNotes,
    _ => throw ArgumentError.value(type, 'type', '未知的離線操作'),
  };

  /// 依資源種類與行程 id 產生唯一的 GET 快取鍵。
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

/// 樂觀更新的操作種類、目標資源與 patch 參數。
class OfflineOp {
  /// 建立操作並確認 patch 類型與目標資源相符。
  OfflineOp(this.type, this.resource, this.tripId, this.args) {
    if (resource != OfflineResource.forType(type)) {
      throw ArgumentError.value(resource, 'resource', '與離線操作種類不符');
    }
  }

  /// 對應 optimistic_patchers 的 registry key(如 'entry.add')。
  final String type;

  /// 要套樂觀 patch 的資源與所屬行程。
  final OfflineResource resource;
  final String tripId;

  /// 從目標資源推導的快取鍵；呼叫端不自行拼接。
  String get cacheKey => resource.cacheKey(tripId);

  /// patcher 所需參數。
  final Map<String, dynamic> args;
}
