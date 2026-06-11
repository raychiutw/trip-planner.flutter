/// 加入行程 models 與導航參數。
library;

import 'poi_search_result.dart';

/// 409 `conflictWith`：時段與既有 entry 重疊。
class TripEntryConflict {
  const TripEntryConflict({
    required this.entryId,
    this.time,
    required this.title,
    required this.dayNum,
  });

  final int entryId;
  final String? time; // "HH:MM-HH:MM" 或單一 或 null
  final String title;
  final int dayNum;

  factory TripEntryConflict.fromJson(Map<String, dynamic> json) {
    return TripEntryConflict(
      entryId: (json['entryId'] as num).toInt(),
      time: json['time'] as String?,
      title: json['title'] as String? ?? '',
      dayNum: (json['dayNum'] as num?)?.toInt() ?? 0,
    );
  }
}

/// AddToTripScreen 的導航參數（go_router extra）。
sealed class AddToTripArgs {
  const AddToTripArgs();
}

/// 從收藏進：已有 favorite id。
class AddToTripFavorite extends AddToTripArgs {
  const AddToTripFavorite({required this.favoriteId, required this.displayName});
  final int favoriteId;
  final String displayName;
}

/// 從探索 POI 進：直接建 entry（不經收藏）。
class AddToTripDirect extends AddToTripArgs {
  const AddToTripDirect({required this.poi});
  final PoiSearchResult poi;
}
