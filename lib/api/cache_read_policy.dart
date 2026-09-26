/// GET 讀取與寫入本機快取的成套政策，避免呼叫端組出無意義的 bool 組合。
enum CacheReadPolicy {
  /// 可回退快取，成功回應也寫入快取。
  cached(readsCache: true, writesCache: true),

  /// 只接受網路回應，成功後更新快取。
  networkOnly(readsCache: false, writesCache: true),

  /// 只接受網路回應，也不改寫快取。
  noStore(readsCache: false, writesCache: false);

  const CacheReadPolicy({required this.readsCache, required this.writesCache});

  final bool readsCache;
  final bool writesCache;
}
