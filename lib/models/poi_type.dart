/// POI 類型映射:Google primaryType / 原始 category → Tripline 白名單。
/// 移植自 web src/lib/poiCategory.ts mapGooglePrimaryTypeToPoiType。
/// 白名單對應後端 pois.type CHECK constraint。
library;

const Set<String> _poiTypeWhitelist = {
  'hotel',
  'restaurant',
  'shopping',
  'parking',
  'attraction',
  'transport',
  'activity',
  'other',
};

/// poi_type → 繁中標籤（收藏/探索 UI 用）。
const Map<String, String> kPoiTypeLabels = {
  'restaurant': '餐廳',
  'attraction': '景點',
  'shopping': '購物',
  'hotel': '飯店',
  'parking': '停車',
  'transport': '交通',
  'activity': '活動',
  'other': '其他',
};

/// 順序敏感:具體類別先於通用。短歧義 token 用 `(?:^|_)x(?:_|$)` 邊界
/// （Google primaryType 是 snake_case,'_' 算 \w,\b 抓不到 token↔底線交界）。
/// RegExp 提升為檔案層級 final,避免每次呼叫重建（hot path:列表渲染逐卡呼叫）。
final _hotelRe = RegExp(
  r'hotel|lodging|hostel|motel|guest_house|resort|tourism|(?:^|_)inn(?:_|$)',
);
final _parkingRe = RegExp(r'parking');
final _transportRe = RegExp(
  r'station|airport|transit|terminal|subway|railway|taxi_stand|bus_stop|transport',
);
final _activityRe = RegExp(
  r'amusement|theme_park|water_park|aquarium|fitness|night_?club|cinema|movie|theater|theatre|stadium|arena|bowling|karaoke|leisure|(?:^|_)(?:zoo|gym|spa|activity)(?:_|$)',
);
final _restaurantRe = RegExp(
  r'restaurant|coffee|bakery|bistro|diner|eatery|izakaya|brunch|amenity|ice_cream|dessert|donut|doughnut|bagel|juice|acai|tea_house|(?:^|_)(?:cafe|bar|food|pub)(?:_|$)',
);
final _shoppingRe = RegExp(
  r'shop|store|mall|market|supermarket|retail|boutique|grocery',
);
final _attractionRe = RegExp(
  r'museum|gallery|temple|shrine|church|mosque|synagogue|worship|monument|landmark|tourist|historic|garden|castle|palace|memorial|park|attraction|sightseeing|scenic',
);
final _cjkOrKanaRe = RegExp(r'[\u3040-\u30ff\u4e00-\u9fff]');
final _asciiLatinRe = RegExp(r'[a-zA-Z]');

String mapGooglePrimaryTypeToPoiType(String? category) {
  if (category == null) return 'attraction';
  final c = category.toLowerCase().trim();
  if (c.isEmpty) return 'attraction';
  if (_poiTypeWhitelist.contains(c)) return c;

  if (_hotelRe.hasMatch(c)) return 'hotel';
  if (_parkingRe.hasMatch(c)) return 'parking';
  if (_transportRe.hasMatch(c)) return 'transport';
  if (_activityRe.hasMatch(c)) return 'activity';
  if (_restaurantRe.hasMatch(c)) return 'restaurant';
  if (_shoppingRe.hasMatch(c)) return 'shopping';
  if (_attractionRe.hasMatch(c)) return 'attraction';

  return 'attraction';
}

/// POI category 的顯示 label。
///
/// `pois.category` 可能是 Google primaryType（英文 snake_case），也可能是
/// 後端/人工 curated 的本地分類（例如「拉麵」「沖繩麵」「すし」）。純 CJK/假名
/// 分類視為可直接顯示；含 ASCII 拉丁字母或雜訊則收斂到 8 類中文 label，避免 UI
/// 外露 `tourist_attraction` 或把「拉麵」誤顯成「景點」。
String? poiCategoryLabel(String? category) {
  final c = category?.trim();
  if (c == null || c.isEmpty) return null;
  if (_cjkOrKanaRe.hasMatch(c) && !_asciiLatinRe.hasMatch(c)) return c;
  return kPoiTypeLabels[mapGooglePrimaryTypeToPoiType(c)];
}
