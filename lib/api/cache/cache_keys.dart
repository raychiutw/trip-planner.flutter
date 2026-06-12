/// 快取鍵正規化與失效前綴對照（純函式,無 IO,可單測）。
library;

/// 正規化快取鍵:`<METHOD> <path>` + 依 key 排序的 query。
String cacheKeyFor(String method, String path, [Map<String, dynamic>? query]) {
  if (query == null || query.isEmpty) return '$method $path';
  final keys = query.keys.toList()..sort();
  final encoded = keys.map((k) => '$k=${query[k]}').join('&');
  return '$method $path?$encoded';
}

/// prefix 以 path 段邊界比對:相等、或後接 `/`、`?`。
/// 避免 `/trips/abc` 誤刪 `/trips/abcdef/...`。
bool cacheKeyMatchesPrefix(String key, String prefix) =>
    key == prefix || key.startsWith('$prefix/') || key.startsWith('$prefix?');

/// mutation(非 GET/HEAD)成功後應失效的 GET 快取鍵前綴。
List<String> evictionPrefixesFor(String method, String path) {
  if (method == 'GET' || method == 'HEAD') return const [];

  final tripMatch = RegExp(r'^/trips/([^/]+)').firstMatch(path);
  if (tripMatch != null) {
    final trip = '/trips/${tripMatch.group(1)!}';
    if (path.contains('/entries') ||
        path.contains('/days') ||
        path.endsWith('/recompute-travel')) {
      return ['GET $trip/days', 'GET $trip/segments', 'GET $trip/entries'];
    }
    if (path.contains('/notes')) return ['GET $trip/notes'];
    if (path.contains('/segments')) {
      return ['GET $trip/segments', 'GET $trip/days'];
    }
    // /trips/:id 本身(PUT/DELETE)
    return ['GET $trip', 'GET /my-trips', 'GET /trips'];
  }
  if (path == '/trips') return ['GET /my-trips', 'GET /trips'];
  if (path.startsWith('/poi-favorites')) return ['GET /poi-favorites'];
  return const [];
}
