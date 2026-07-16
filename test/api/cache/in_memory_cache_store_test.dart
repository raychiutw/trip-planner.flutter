import 'package:tripline/api/cache/cache_store.dart';

import 'cache_store_contract.dart';

void main() {
  // 行為契約與 CacheStore 的其他實作共用，確保換實作時行為不漂移。
  cacheStoreContract('InMemoryCacheStore', InMemoryCacheStore.new);
}
