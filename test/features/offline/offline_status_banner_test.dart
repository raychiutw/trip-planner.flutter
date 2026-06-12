import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/cache/cache_keys.dart';
import 'package:tripline/api/cache/cache_store.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/session_store.dart';
import 'package:tripline/features/offline/offline_status_banner.dart';
import 'package:tripline/features/offline/offline_sync.dart';
import 'package:tripline/theme/app_theme.dart';

QueuedMutation _mut(String id) => QueuedMutation(
  id: id,
  method: 'POST',
  path: '/trips/t/days/1/entries',
  body: const {'title': 'x'},
  type: 'entry.add',
  cacheKey: cacheKeyFor('GET', '/trips/t/days', {'all': '1'}),
  args: const {'dayNum': 1},
  createdAt: 't',
);

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late InMemoryCacheStore cache;
  late ProviderContainer container;

  setUp(() {
    dio = Dio(BaseOptions())..options.validateStatus = (_) => true;
    adapter = DioAdapter(dio: dio);
    cache = InMemoryCacheStore();
    container = ProviderContainer(
      overrides: [
        cacheStoreProvider.overrideWithValue(cache),
        apiClientProvider.overrideWithValue(
          ApiClient(
            sessionStore: InMemorySessionStore(),
            dio: dio,
            cacheStore: cache,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: OfflineStatusBanner(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('無待同步、無衝突 → 不顯示', (tester) async {
    await pump(tester);
    expect(find.byKey(const ValueKey('offline-pending-banner')), findsNothing);
    expect(find.byKey(const ValueKey('offline-conflict-banner')), findsNothing);
  });

  testWidgets('有待同步 → 顯示筆數 + 立即重試', (tester) async {
    await cache.appendMutation(_mut('1'));
    await cache.appendMutation(_mut('2'));
    await pump(tester);
    expect(
      find.byKey(const ValueKey('offline-pending-banner')),
      findsOneWidget,
    );
    expect(find.text('2 筆變更待同步'), findsOneWidget);
    expect(find.text('立即重試'), findsOneWidget);
  });

  testWidgets('點立即重試 → flush 後排空、橫幅消失', (tester) async {
    await cache.appendMutation(_mut('1'));
    adapter.onPost(
      '/trips/t/days/1/entries',
      (s) => s.reply(200, {'ok': true}),
      data: Matchers.any,
    );
    await pump(tester);
    expect(find.text('1 筆變更待同步'), findsOneWidget);

    await tester.tap(find.text('立即重試'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('offline-pending-banner')), findsNothing);
    expect(await cache.readQueue(), isEmpty);
  });

  testWidgets('有衝突 → 顯示衝突 + 知道了清除', (tester) async {
    await pump(tester);
    container.read(syncConflictsProvider.notifier).set([_mut('c1')]);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('offline-conflict-banner')),
      findsOneWidget,
    );
    expect(find.text('1 筆變更同步失敗(衝突)'), findsOneWidget);

    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('offline-conflict-banner')), findsNothing);
  });
}
