/// POI 類型映射:Google primaryType / 原始 category → Tripline 白名單。
/// 移植自 web src/lib/poiCategory.ts mapGooglePrimaryTypeToPoiType。
/// 白名單對應後端 pois.type CHECK constraint。
library;

const Set<String> _poiTypeWhitelist = {
  'hotel', 'restaurant', 'shopping', 'parking',
  'attraction', 'transport', 'activity', 'other',
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
String mapGooglePrimaryTypeToPoiType(String? category) {
  if (category == null) return 'attraction';
  final c = category.toLowerCase().trim();
  if (c.isEmpty) return 'attraction';
  if (_poiTypeWhitelist.contains(c)) return c;

  if (RegExp(r'hotel|lodging|hostel|motel|guest_house|resort|tourism|(?:^|_)inn(?:_|$)')
      .hasMatch(c)) {
    return 'hotel';
  }
  if (RegExp(r'parking').hasMatch(c)) return 'parking';
  if (RegExp(r'station|airport|transit|terminal|subway|railway|taxi_stand|bus_stop|transport')
      .hasMatch(c)) {
    return 'transport';
  }
  if (RegExp(r'amusement|theme_park|water_park|aquarium|fitness|night_?club|cinema|movie|theater|theatre|stadium|arena|bowling|karaoke|leisure|(?:^|_)(?:zoo|gym|spa|activity)(?:_|$)')
      .hasMatch(c)) {
    return 'activity';
  }
  if (RegExp(r'restaurant|coffee|bakery|bistro|diner|eatery|izakaya|brunch|amenity|ice_cream|dessert|donut|doughnut|bagel|juice|acai|tea_house|(?:^|_)(?:cafe|bar|food|pub)(?:_|$)')
      .hasMatch(c)) {
    return 'restaurant';
  }
  if (RegExp(r'shop|store|mall|market|supermarket|retail|boutique|grocery')
      .hasMatch(c)) {
    return 'shopping';
  }
  if (RegExp(r'museum|gallery|temple|shrine|church|mosque|synagogue|worship|monument|landmark|tourist|historic|garden|castle|palace|memorial|park|attraction|sightseeing|scenic')
      .hasMatch(c)) {
    return 'attraction';
  }

  return 'attraction';
}
