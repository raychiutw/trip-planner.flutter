import 'package:drift/native.dart';
import 'package:tripline/api/cache/drift_cache_store.dart';

import 'cache_store_contract.dart';

void main() {
  // 跑與 InMemoryCacheStore 一字不差的同一份契約 —— 這是 drop-in 替換的證明。
  cacheStoreContract(
    'DriftCacheStore',
    () => DriftCacheStore(CacheDatabase(NativeDatabase.memory())),
    dispose: (store) => (store as DriftCacheStore).close(),
  );
}
