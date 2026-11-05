import '../../helpers/semantics_flags.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/cache/cache_keys.dart';
import 'package:tripline/api/cache/cache_store.dart';
import 'package:tripline/api/providers.dart';
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
    final semantics = tester.ensureSemantics();
    final cache = InMemoryCacheStore();
    await cache.appendConflict(_conflict());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cacheStoreProvider.overrideWithValue(cache),
          apiClientProvider.overrideWithValue(ApiClient(cacheStore: cache)),
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
    final theirs = find.byKey(const ValueKey('conflict-keep-theirs-c1'));
    final ours = find.byKey(const ValueKey('conflict-keep-ours-c1'));
    expect(tester.isSelectedOf(theirs), isTrue);
    expect(tester.isSelectedOf(ours), isFalse);
    // A20：已選項要有文字與勾選記號，不能只靠按鈕填色。
    final chosen = find.byKey(const ValueKey('conflict-chosen-c1'));
    expect(
      find.descendant(of: chosen, matching: find.text('已選：對方的')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: chosen,
        matching: find.byIcon(CupertinoIcons.checkmark_circle_fill),
      ),
      findsOneWidget,
    );
    // 輔助技術：「已選」整列是一個節點，label 就是文字，勾選圖示是裝飾不另念。
    final chosenNode = tester.getSemantics(chosen);
    expect(chosenNode.label, '已選：對方的');
    expect(
      find.descendant(
        of: chosen,
        matching: find.byWidgetPredicate(
          (w) => w is ExcludeSemantics && w.excluding,
        ),
      ),
      findsWidgets,
    );
    await tester.tap(ours);
    await tester.pump();
    expect(find.text('已選：你的'), findsOneWidget);
    expect(tester.getSemantics(chosen).label, '已選：你的');
    expect(find.text('已選：對方的'), findsNothing);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.text('捨棄未儲存的變更？'), findsOneWidget);
    await tester.tap(find.text('捨棄'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('conflict-card-c1')), findsNothing);
    expect(await cache.readConflicts(), hasLength(1));
    semantics.dispose();
  });
}
