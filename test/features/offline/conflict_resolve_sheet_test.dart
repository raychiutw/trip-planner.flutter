import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/cache/cache_keys.dart';
import 'package:tripline/api/cache/cache_store.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/session_store.dart';
import 'package:tripline/features/offline/conflict_resolve_sheet.dart';
import 'package:tripline/theme/app_theme.dart';

ConflictRecord _conflict() => ConflictRecord(
  id: 'c1',
  type: 'entry.update',
  path: '/trips/t/entries/7',
  body: const {'title': '我的標題'},
  args: const {'entryId': 7, 'title': '我的標題'},
  cacheKey: cacheKeyFor('GET', '/trips/t/days', const {'all': '1'}),
  ours: const {'title': '我的標題'},
  theirs: const {'title': '對方標題'},
  newVersion: 5,
  conflictFields: const ['title'],
  createdAt: 't',
);

void main() {
  testWidgets('取消衝突選擇只捨棄 pending choice，不呼叫解決 API', (tester) async {
    final cache = InMemoryCacheStore();
    await cache.appendConflict(_conflict());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cacheStoreProvider.overrideWithValue(cache),
          apiClientProvider.overrideWithValue(
            ApiClient(sessionStore: InMemorySessionStore(), cacheStore: cache),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: FilledButton(
                onPressed: () => showConflictResolveSheet(context, ref),
                child: const Text('開啟'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('conflict-keep-theirs-c1')));
    await tester.pump();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.text('捨棄未儲存的變更？'), findsOneWidget);
    await tester.tap(find.text('捨棄'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('conflict-card-c1')), findsNothing);
    expect(await cache.readConflicts(), hasLength(1));
  });
}
