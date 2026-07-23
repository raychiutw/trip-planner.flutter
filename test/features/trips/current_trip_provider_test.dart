import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/cache/cache_store.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/features/trips/current_trip_provider.dart';

class _ThrowingCacheStore extends InMemoryCacheStore {
  @override
  Future<CacheEntry?> readResponse(String key) =>
      Future.error(StateError('read failed'));

  @override
  Future<void> writeResponse(String key, Object? data, {DateTime? cachedAt}) =>
      Future.error(StateError('write failed'));
}

void main() {
  test('cache 失敗不阻擋目前行程讀取或切換', () async {
    final container = ProviderContainer(
      overrides: [cacheStoreProvider.overrideWithValue(_ThrowingCacheStore())],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(currentTripIdProvider.future),
      completion(isNull),
    );

    await container.read(currentTripIdProvider.notifier).select('tokyo');

    expect(container.read(currentTripIdProvider).value, 'tokyo');
  });
}
