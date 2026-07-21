import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/api/cache/cache_store.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/models/user.dart';

class _MockAuthRepo extends Mock implements AuthRepository {}

QueuedMutation _mut(String id) => QueuedMutation(
  id: id,
  method: 'POST',
  path: '/p',
  type: 'entry.add',
  cacheKey: 'GET /k',
  args: const {},
  createdAt: 't',
);

void main() {
  // 換帳號(同裝置、身分變)時,authState.build 的 owner-check 應清掉前帳號的
  // 回應快取 + 離線佇列,避免 A 的資料/待同步編輯外洩給 B。
  test('身分改變 → 清前帳號快取 + 佇列、owner 更新為新帳號', () async {
    final cache = InMemoryCacheStore();
    await cache.writeResponse('__cache_owner__', 'A|a@x.com');
    await cache.writeResponse('GET /my-trips', [
      {'id': 'a-trip'},
    ]);
    await cache.appendMutation(_mut('1'));

    final repo = _MockAuthRepo();
    when(
      () => repo.currentUser(),
    ).thenAnswer((_) async => const UserInfo(id: 'B', email: 'b@x.com'));

    final c = ProviderContainer(
      overrides: [
        cacheStoreProvider.overrideWithValue(cache),
        authRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(c.dispose);

    final user = await c.read(authStateProvider.future);
    expect(user!.id, 'B');
    expect(await cache.readResponse('GET /my-trips'), isNull); // A 的快取已清
    expect(await cache.readQueue(), isEmpty); // A 的佇列已清
    expect((await cache.readResponse('__cache_owner__'))!.data, 'B|b@x.com');
  });

  test('同一帳號 → 保留快取與佇列(不誤清)', () async {
    final cache = InMemoryCacheStore();
    await cache.writeResponse('__cache_owner__', 'B|b@x.com');
    await cache.writeResponse('GET /my-trips', [
      {'id': 'b-trip'},
    ]);
    await cache.appendMutation(_mut('1'));

    final repo = _MockAuthRepo();
    when(
      () => repo.currentUser(),
    ).thenAnswer((_) async => const UserInfo(id: 'B', email: 'b@x.com'));

    final c = ProviderContainer(
      overrides: [
        cacheStoreProvider.overrideWithValue(cache),
        authRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(c.dispose);

    await c.read(authStateProvider.future);
    expect(await cache.readResponse('GET /my-trips'), isNotNull); // 未清
    expect(await cache.readQueue(), hasLength(1)); // 待同步保留
  });

  test('session 過期後直接登入另一帳號 → 清前帳號快取與佇列', () async {
    final cache = InMemoryCacheStore();
    await cache.writeResponse('__cache_owner__', 'A|a@x.com');
    await cache.writeResponse('GET /my-trips', [
      {'id': 'a-trip'},
    ]);
    await cache.appendMutation(_mut('1'));

    final repo = _MockAuthRepo();
    when(() => repo.currentUser()).thenAnswer((_) async => null);
    when(
      () => repo.login(email: 'b@x.com', password: 'secret'),
    ).thenAnswer((_) async => const UserInfo(id: 'B', email: 'b@x.com'));

    final c = ProviderContainer(
      overrides: [
        cacheStoreProvider.overrideWithValue(cache),
        authRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(c.dispose);

    expect(await c.read(authStateProvider.future), isNull);
    await c.read(authStateProvider.notifier).login('b@x.com', 'secret');

    expect(c.read(authStateProvider).value?.id, 'B');
    expect(await cache.readResponse('GET /my-trips'), isNull);
    expect(await cache.readQueue(), isEmpty);
    expect((await cache.readResponse('__cache_owner__'))!.data, 'B|b@x.com');
  });

  test('首次登入(無前 owner)→ 不清,只設 owner', () async {
    final cache = InMemoryCacheStore();
    await cache.writeResponse('GET /my-trips', [
      {'id': 'seeded'},
    ]);

    final repo = _MockAuthRepo();
    when(
      () => repo.currentUser(),
    ).thenAnswer((_) async => const UserInfo(id: 'A', email: 'a@x.com'));

    final c = ProviderContainer(
      overrides: [
        cacheStoreProvider.overrideWithValue(cache),
        authRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(c.dispose);

    await c.read(authStateProvider.future);
    expect(await cache.readResponse('GET /my-trips'), isNotNull);
    expect((await cache.readResponse('__cache_owner__'))!.data, 'A|a@x.com');
  });
}
