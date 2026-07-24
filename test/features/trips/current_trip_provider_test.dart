import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/cache/cache_store.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/features/trips/current_trip_provider.dart';
import 'package:tripline/models/user.dart';

class _ThrowingCacheStore extends InMemoryCacheStore {
  @override
  Future<CacheEntry?> readResponse(String key) =>
      Future.error(StateError('read failed'));

  @override
  Future<void> writeResponse(String key, Object? data, {DateTime? cachedAt}) =>
      Future.error(StateError('write failed'));
}

class _DelayedCacheStore extends InMemoryCacheStore {
  final response = Completer<CacheEntry?>();

  @override
  Future<CacheEntry?> readResponse(String key) => response.future;
}

class _BlockingWriteCacheStore extends InMemoryCacheStore {
  final firstWriteStarted = Completer<void>();
  final releaseFirstWrite = Completer<void>();
  int writes = 0;

  @override
  Future<void> writeResponse(
    String key,
    Object? data, {
    DateTime? cachedAt,
  }) async {
    writes++;
    if (writes == 1) {
      firstWriteStarted.complete();
      await releaseFirstWrite.future;
    }
    await super.writeResponse(key, data, cachedAt: cachedAt);
  }
}

class _TestAuthNotifier extends AuthNotifier {
  @override
  Future<UserInfo?> build() async => null;

  void setUser(UserInfo? user) => state = AsyncData(user);
}

void main() {
  test('cache 失敗不阻擋目前行程讀取或切換', () async {
    final container = ProviderContainer(
      overrides: [cacheStoreProvider.overrideWithValue(_ThrowingCacheStore())],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(currentTripIdProvider, (_, _) {});
    addTearDown(subscription.close);

    await expectLater(
      container.read(currentTripIdProvider.future),
      completion(isNull),
    );

    await container.read(currentTripIdProvider.notifier).select('tokyo');

    expect(container.read(currentTripIdProvider).value, 'tokyo');
  });

  test('cache 載入中切換行程不會被較舊 cache 覆蓋', () async {
    final store = _DelayedCacheStore();
    final container = ProviderContainer(
      overrides: [cacheStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(currentTripIdProvider, (_, _) {});
    addTearDown(subscription.close);

    container.read(currentTripIdProvider);
    await container.read(currentTripIdProvider.notifier).select('tokyo');
    store.response.complete(
      CacheEntry(data: 'okinawa', cachedAt: DateTime(2026)),
    );
    await Future<void>.delayed(Duration.zero);

    expect(container.read(currentTripIdProvider).value, 'tokyo');
  });

  test('空白行程 id 不會覆蓋目前選擇', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final subscription = container.listen(currentTripIdProvider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(currentTripIdProvider.future);

    await container.read(currentTripIdProvider.notifier).select('tokyo');
    await container.read(currentTripIdProvider.notifier).select('');

    expect(container.read(currentTripIdProvider).value, 'tokyo');
  });

  test('快速連續切換會依序寫入 cache，最後選擇不被舊寫入覆蓋', () async {
    final store = _BlockingWriteCacheStore();
    final container = ProviderContainer(
      overrides: [cacheStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(currentTripIdProvider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(currentTripIdProvider.future);

    final first = container
        .read(currentTripIdProvider.notifier)
        .select('okinawa');
    await store.firstWriteStarted.future;
    final second = container
        .read(currentTripIdProvider.notifier)
        .select('tokyo');
    await Future<void>.delayed(Duration.zero);

    expect(store.writes, 1);
    store.releaseFirstWrite.complete();
    await Future.wait([first, second]);
    expect((await store.readResponse('ui:last-map-trip'))?.data, 'tokyo');
  });

  test('登出清除 cache 後也會清除記憶體中的目前行程', () async {
    final store = InMemoryCacheStore();
    final container = ProviderContainer(
      overrides: [
        cacheStoreProvider.overrideWithValue(store),
        authStateProvider.overrideWith(_TestAuthNotifier.new),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(currentTripIdProvider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(authStateProvider.future);
    final auth =
        container.read(authStateProvider.notifier) as _TestAuthNotifier;
    auth.setUser(
      const UserInfo(id: 'user-a', email: 'a@example.com', displayName: 'A'),
    );
    await container.pump();
    await container.read(currentTripIdProvider.future);
    await container.read(currentTripIdProvider.notifier).select('tokyo');

    await store.clear();
    auth.setUser(null);
    await container.pump();

    expect(await container.read(currentTripIdProvider.future), isNull);
  });
}
