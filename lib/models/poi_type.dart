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

/// Google Places `primaryType` → zh-TW 細類標籤。
///
/// 未收錄的合法 snake_case 會由 [poiCategoryLabel] 顯示成可讀英文，讓缺漏
/// mapping 能直接從 UI 被發現並事後補上。
const Map<String, String> _googlePrimaryTypeLabels = {
  // 餐飲（吃 → 粉）
  'ramen_restaurant': '拉麵店',
  'sushi_restaurant': '壽司',
  'japanese_restaurant': '日式料理',
  'chinese_restaurant': '中式料理',
  'korean_restaurant': '韓式料理',
  'italian_restaurant': '義式料理',
  'french_restaurant': '法式料理',
  'thai_restaurant': '泰式料理',
  'indian_restaurant': '印度料理',
  'vietnamese_restaurant': '越南料理',
  'mexican_restaurant': '墨西哥料理',
  'spanish_restaurant': '西班牙料理',
  'american_restaurant': '美式料理',
  'greek_restaurant': '希臘料理',
  'turkish_restaurant': '土耳其料理',
  'middle_eastern_restaurant': '中東料理',
  'indonesian_restaurant': '印尼料理',
  'asian_restaurant': '亞洲料理',
  'seafood_restaurant': '海鮮料理',
  'steak_house': '牛排館',
  'barbecue_restaurant': '燒烤',
  'hamburger_restaurant': '漢堡',
  'pizza_restaurant': '披薩',
  'fast_food_restaurant': '速食',
  'vegetarian_restaurant': '蔬食',
  'vegan_restaurant': '純素',
  'sandwich_shop': '三明治',
  'breakfast_restaurant': '早餐',
  'brunch_restaurant': '早午餐',
  'diner': '小餐館',
  'buffet_restaurant': '自助餐',
  'cafe': '咖啡廳',
  'coffee_shop': '咖啡廳',
  'cafeteria': '自助餐廳',
  'bakery': '烘焙坊',
  'tea_house': '茶館',
  'bar': '酒吧',
  'pub': '酒館',
  'wine_bar': '酒吧',
  'bar_and_grill': '餐酒館',
  'ice_cream_shop': '冰淇淋',
  'dessert_shop': '甜點',
  'dessert_restaurant': '甜點',
  'donut_shop': '甜甜圈',
  'bagel_shop': '貝果',
  'juice_shop': '果汁',
  'confectionery': '甜點店',
  'candy_store': '糖果店',
  'chocolate_shop': '巧克力',
  'food_court': '美食街',
  'deli': '熟食',
  'meal_takeaway': '外帶',
  'meal_delivery': '外送',
  'food': '餐廳',
  // 景點・文化（看 → 柔褐）
  'tourist_attraction': '景點',
  'aquarium': '水族館',
  'art_gallery': '美術館',
  'museum': '博物館',
  'amusement_park': '遊樂園',
  'zoo': '動物園',
  'water_park': '水上樂園',
  'wildlife_park': '野生動物園',
  'wildlife_refuge': '野生動物保護區',
  'shinto_shrine': '神社',
  'buddhist_temple': '寺廟',
  'hindu_temple': '印度廟',
  'church': '教堂',
  'mosque': '清真寺',
  'synagogue': '猶太會堂',
  'place_of_worship': '宗教場所',
  'historical_landmark': '歷史地標',
  'historical_place': '史蹟',
  'monument': '紀念碑',
  'observation_deck': '觀景台',
  'cultural_landmark': '文化地標',
  'cultural_center': '文化中心',
  'national_park': '國家公園',
  'state_park': '州立公園',
  'park': '公園',
  'garden': '花園',
  'botanical_garden': '植物園',
  'beach': '海灘',
  'hiking_area': '健行步道',
  'plaza': '廣場',
  'tourist_information_center': '遊客中心',
  'planetarium': '天文館',
  'ferris_wheel': '摩天輪',
  'point_of_interest': '景點',
  'landmark': '地標',
  // 購物（買 → 柔褐）
  'shopping_mall': '購物中心',
  'shopping_center': '購物中心',
  'department_store': '百貨公司',
  'supermarket': '超市',
  'convenience_store': '便利商店',
  'grocery_store': '雜貨店',
  'market': '市場',
  'clothing_store': '服飾店',
  'shoe_store': '鞋店',
  'jewelry_store': '珠寶店',
  'book_store': '書店',
  'electronics_store': '電子產品',
  'gift_shop': '禮品店',
  'furniture_store': '家具店',
  'home_goods_store': '家居用品',
  'hardware_store': '五金行',
  'liquor_store': '酒品店',
  'pharmacy': '藥局',
  'drugstore': '藥妝店',
  'pet_store': '寵物店',
  'florist': '花店',
  'cosmetics_store': '美妝店',
  'sporting_goods_store': '運動用品',
  'discount_store': '折扣店',
  'store': '商店',
  'wholesaler': '批發',
  // 住宿（住 → sage）
  'lodging': '飯店',
  'motel': '汽車旅館',
  'hostel': '青年旅館',
  'guest_house': '民宿',
  'bed_and_breakfast': '民宿',
  'resort_hotel': '度假飯店',
  'campground': '露營地',
  'rv_park': '露營車場',
  'cottage': '小屋',
  'inn': '旅館',
  'extended_stay_hotel': '長租旅館',
  // 交通（移動 → sage）
  'airport': '機場',
  'international_airport': '國際機場',
  'train_station': '火車站',
  'subway_station': '地鐵站',
  'bus_station': '巴士站',
  'transit_station': '轉運站',
  'light_rail_station': '輕軌站',
  'ferry_terminal': '渡輪碼頭',
  'taxi_stand': '計程車站',
  'bus_stop': '公車站',
  'gas_station': '加油站',
  'ev_charging_station': '充電站',
  'rest_stop': '休息站',
  'car_rental': '租車',
  // 活動・娛樂（玩 → 柔褐）
  'movie_theater': '電影院',
  'night_club': '夜店',
  'casino': '賭場',
  'bowling_alley': '保齡球館',
  'spa': 'SPA',
  'gym': '健身房',
  'fitness_center': '健身中心',
  'stadium': '體育場',
  'arena': '競技場',
  'concert_hall': '音樂廳',
  'performing_arts_theater': '劇場',
  'karaoke': 'KTV',
  'sports_complex': '運動中心',
  'swimming_pool': '游泳池',
  'ski_resort': '滑雪場',
  'golf_course': '高爾夫球場',
  'marina': '碼頭',
  'amusement_center': '遊樂中心',
  'community_center': '社區中心',
  'event_venue': '活動場地',
  'banquet_hall': '宴會廳',
};

/// 順序敏感:具體類別先於通用。短歧義 token 用 `(?:^|_)x(?:_|$)` 邊界
/// （Google primaryType 是 snake_case,'_' 算 \w,\b 抓不到 token↔底線交界）。
/// RegExp 提升為檔案層級 final,避免每次呼叫重建（hot path:列表渲染逐卡呼叫）。
final _hotelRe = RegExp(
  r'hotel|lodging|hostel|motel|guest_house|bed_and_breakfast|resort|tourism|(?:^|_)inn(?:_|$)',
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
final _snakeCaseRe = RegExp(
  r'^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$',
  caseSensitive: false,
);

String _humanizePrimaryType(String raw) => raw
    .split('_')
    .where((word) => word.isNotEmpty)
    .map((word) => '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
    .join(' ');

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
/// 分類視為可直接顯示；常見 primaryType 顯示細類中文，未收錄的合法
/// snake_case 顯示可讀英文，其餘雜訊才收斂到 8 類中文 label。
String? poiCategoryLabel(String? category) {
  final c = category?.trim();
  if (c == null || c.isEmpty) return null;
  if (_cjkOrKanaRe.hasMatch(c) && !_asciiLatinRe.hasMatch(c)) return c;
  final key = c.toLowerCase();
  final fine = _googlePrimaryTypeLabels[key];
  if (fine != null) return fine;
  if (_poiTypeWhitelist.contains(key)) return kPoiTypeLabels[key];
  if (_snakeCaseRe.hasMatch(c)) return _humanizePrimaryType(c);
  return kPoiTypeLabels[mapGooglePrimaryTypeToPoiType(c)];
}
