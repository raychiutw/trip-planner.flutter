import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/favorites_repository.dart';
import 'package:tripline/features/favorites/favorites_providers.dart';
import 'package:tripline/features/favorites/favorites_screen.dart';
import 'package:tripline/features/favorites/poi_favorite_card.dart';
import 'package:tripline/models/poi_favorite.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_app_bar.dart';

class MockFavoritesRepository extends Mock implements FavoritesRepository {}

const _favorites = [
  PoiFavorite(
    id: 7,
    userId: 'u-1',
    poiId: 501,
    favoritedAt: '2026-06-01T10:00:00Z',
    poiName: '美麗海水族館',
    poiAddress: '沖繩縣國頭郡本部町石川424',
    poiType: 'attraction',
    note: '雨天備案',
    poiRating: 4.6,
  ),
  PoiFavorite(
    id: 8,
    userId: 'u-1',
    poiId: 502,
    favoritedAt: '2026-06-02T10:00:00Z',
    poiName: '暖暮拉麵',
    poiAddress: '那霸市牧志2-16-10',
    poiType: 'restaurant',
    note: '晚餐候補',
  ),
];

List<PoiFavorite> _manyFavorites() => [
  for (var i = 1; i <= 200; i++)
    PoiFavorite(
      id: i,
      userId: 'u-1',
      poiId: 1000 + i,
      favoritedAt: DateTime.utc(
        2026,
        1,
        1,
      ).add(Duration(days: i)).toIso8601String(),
      poiName: '收藏地點 $i',
      poiAddress: i.isEven ? '東京千代田區' : '沖繩縣那霸市',
      poiType: i.isEven ? 'restaurant' : 'attraction',
    ),
];

Widget buildApp({TextScaler textScaler = TextScaler.noScaling}) => MaterialApp(
  theme: AppTheme.light(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: textScaler),
    child: child!,
  ),
  home: const FavoritesScreen(),
);

Future<void> _openFavoritesFilter(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('favorites-sort-action')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('favorites-filter-action')));
  await tester.pumpAndSettle();
}

void main() {
  group('FavoritesScreen', () {
    testWidgets('header 的排序與新增共用一片玻璃，中間只有間距、沒有分隔線', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            favoritesProvider.overrideWith((ref) => Stream.value(_favorites)),
          ],
          child: buildApp(),
        ),
      );
      await tester.pump();

      final group = find.byKey(const ValueKey('favorites-header-group'));
      expect(group, findsOneWidget);

      // 兩顆相關動作都在同一片容器裡。
      for (final key in ['favorites-sort-action', 'favorites-add-action']) {
        expect(
          find.descendant(of: group, matching: find.byKey(ValueKey(key))),
          findsOneWidget,
          reason: key,
        );
      }

      // 一片玻璃：群組提供容器，裡面的按鈕不再各自畫一顆玻璃。
      expect(
        find.descendant(of: group, matching: find.byType(GlassContainer)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: group,
          matching: find.byKey(const ValueKey('tp-toolbar-glass-button')),
        ),
        findsNothing,
        reason: '群組內不該再有各自的玻璃按鈕，否則玻璃疊玻璃',
      );

      // 只以間距分隔 —— HIG Toolbars 不提分隔線。
      expect(
        find.descendant(of: group, matching: find.byType(VerticalDivider)),
        findsNothing,
      );
      expect(
        find.descendant(of: group, matching: find.byType(Divider)),
        findsNothing,
      );

      // 帳號鈕自成一組，不入群組。
      expect(
        find.descendant(
          of: group,
          matching: find.byType(TpAccountAvatarButton),
        ),
        findsNothing,
      );
      expect(find.byType(TpAccountAvatarButton), findsOneWidget);

      // 兩顆按鈕都仍是完整 44pt 觸控目標。
      for (final key in ['favorites-sort-action', 'favorites-add-action']) {
        expect(
          tester.getSize(find.byKey(ValueKey(key))).height,
          greaterThanOrEqualTo(44),
          reason: key,
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('窄寬度加大字級時維持折疊，不套用群組', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            favoritesProvider.overrideWith((ref) => Stream.value(_favorites)),
          ],
          child: buildApp(textScaler: const TextScaler.linear(1.6)),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('favorites-header-group')),
        findsNothing,
        reason: 'header 只剩一顆按鈕時不套用群組',
      );
      expect(find.byKey(const ValueKey('favorites-add-action')), findsNothing);
      expect(
        find.byKey(const ValueKey('favorites-sort-action')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('渲染收藏清單 N 卡', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            favoritesProvider.overrideWith((ref) => Stream.value(_favorites)),
          ],
          child: buildApp(),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('tp-root-glass-header')),
        findsOneWidget,
      );
      expect(find.text('收藏'), findsOneWidget);
      expect(find.byKey(const ValueKey('tp-app-bar-back')), findsNothing);
      expect(find.byKey(const ValueKey('tp-app-bar-close')), findsNothing);
      expect(find.byType(PoiFavoriteCard), findsNWidgets(2));
      expect(
        find.byKey(const ValueKey('favorites-grouped-list')),
        findsOneWidget,
      );
      expect(find.text('最近收藏'), findsOneWidget);
      expect(find.text('2 個地點'), findsOneWidget);
      expect(
        tester
            .widgetList<PoiFavoriteCard>(find.byType(PoiFavoriteCard))
            .every((card) => card.grouped),
        isTrue,
      );
      expect(find.text('美麗海水族館'), findsOneWidget);
      expect(find.text('暖暮拉麵'), findsOneWidget);
      expect(find.byType(FilterChip), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      expect(
        find.byKey(const ValueKey('favorites-search-action')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('favorites-sort-action')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('favorites-add-action')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('favorites-search-input')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('account-avatar-button')),
        findsOneWidget,
      );
    });

    testWidgets('320pt / 200% 字級將新增收進更多選單且 Header 不溢位', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            favoritesProvider.overrideWith((ref) => Stream.value(_favorites)),
          ],
          child: buildApp(textScaler: const TextScaler.linear(2)),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('favorites-search-action')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('favorites-search-input')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('favorites-sort-action')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('favorites-add-action')), findsNothing);
      expect(
        find.byKey(const ValueKey('account-avatar-button')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('favorites-sort-action')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('favorites-add-menu-action')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('搜尋收藏會比對名稱、地址與備註', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            favoritesProvider.overrideWith((ref) => Stream.value(_favorites)),
          ],
          child: buildApp(),
        ),
      );
      await tester.pump();

      final searchInput = find.byKey(const ValueKey('favorites-search-input'));
      expect(searchInput, findsOneWidget);
      expect(find.text('收藏'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('favorites-add-action')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('favorites-search-cancel')),
        findsNothing,
      );

      await tester.enterText(searchInput, '牧志');
      await tester.pump();

      expect(find.text('搜尋結果'), findsOneWidget);
      expect(find.text('1 個地點'), findsOneWidget);
      expect(find.byType(PoiFavoriteCard), findsOneWidget);
      expect(find.text('暖暮拉麵'), findsOneWidget);
      expect(find.text('美麗海水族館'), findsNothing);

      await tester.enterText(searchInput, '雨天');
      await tester.pump();

      expect(find.byType(PoiFavoriteCard), findsOneWidget);
      expect(find.text('美麗海水族館'), findsOneWidget);
      expect(find.text('暖暮拉麵'), findsNothing);

      await tester.enterText(searchInput, '');
      await tester.pump();
      expect(find.text('收藏'), findsOneWidget);
      expect(searchInput, findsOneWidget);
      expect(find.byType(PoiFavoriteCard), findsNWidgets(2));
    });

    testWidgets('鍵盤 Search 可送出，清除搜尋不改變既有篩選', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            favoritesProvider.overrideWith((ref) => Stream.value(_favorites)),
          ],
          child: buildApp(),
        ),
      );
      await tester.pump();

      await _openFavoritesFilter(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('favorites-type-restaurant')));
      await tester.tap(find.byKey(const ValueKey('favorites-filter-apply')));
      await tester.pumpAndSettle();

      final searchInput = find.byKey(const ValueKey('favorites-search-input'));
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: searchInput,
                matching: find.byType(EditableText),
              ),
            )
            .textInputAction,
        TextInputAction.search,
      );
      await tester.enterText(searchInput, '暖暮');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(find.text('暖暮拉麵'), findsOneWidget);

      await tester.tap(find.byIcon(CupertinoIcons.xmark_circle_fill));
      await tester.pump();

      expect(find.text('已篩選：餐廳'), findsOneWidget);
      expect(find.text('暖暮拉麵'), findsOneWidget);
      expect(find.text('美麗海水族館'), findsNothing);
    });

    testWidgets('類型篩選只保留指定類型並可切回全部', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            favoritesProvider.overrideWith((ref) => Stream.value(_favorites)),
          ],
          child: buildApp(),
        ),
      );
      await tester.pump();

      await _openFavoritesFilter(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('favorites-type-restaurant')));
      await tester.tap(find.byKey(const ValueKey('favorites-filter-apply')));
      await tester.pumpAndSettle();

      expect(find.byType(PoiFavoriteCard), findsOneWidget);
      expect(find.text('暖暮拉麵'), findsOneWidget);
      expect(find.text('美麗海水族館'), findsNothing);

      await _openFavoritesFilter(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('favorites-type-all')));
      await tester.tap(find.byKey(const ValueKey('favorites-filter-apply')));
      await tester.pumpAndSettle();

      expect(find.byType(PoiFavoriteCard), findsNWidgets(2));
    });

    testWidgets('地區篩選只保留指定地區並可切回全部', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            favoritesProvider.overrideWith((ref) => Stream.value(_favorites)),
          ],
          child: buildApp(),
        ),
      );
      await tester.pump();

      await _openFavoritesFilter(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('favorites-region-沖繩')));
      await tester.tap(find.byKey(const ValueKey('favorites-filter-apply')));
      await tester.pumpAndSettle();

      expect(find.byType(PoiFavoriteCard), findsOneWidget);
      expect(find.text('美麗海水族館'), findsOneWidget);
      expect(find.text('暖暮拉麵'), findsNothing);

      await _openFavoritesFilter(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('favorites-region-all')));
      await tester.tap(find.byKey(const ValueKey('favorites-filter-apply')));
      await tester.pumpAndSettle();

      expect(find.byType(PoiFavoriteCard), findsNWidgets(2));
    });

    testWidgets('empty → 還沒有收藏 hero', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            favoritesProvider.overrideWith(
              (ref) => Stream.value(const <PoiFavorite>[]),
            ),
          ],
          child: buildApp(),
        ),
      );
      await tester.pump();

      expect(find.byType(PoiFavoriteCard), findsNothing);
      expect(find.text('還沒有收藏的地點'), findsOneWidget);
      expect(find.text('去探索'), findsOneWidget); // 引導去已上線的探索
      expect(find.textContaining('即將推出'), findsNothing); // 過時文案已移除
    });

    testWidgets('error → 重試後成功', (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        ProviderScope(
          retry: (retryCount, error) => null,
          overrides: [
            favoritesProvider.overrideWith((ref) {
              attempts++;
              if (attempts == 1) return Stream.error(Exception('network'));
              return Stream.value(_favorites);
            }),
          ],
          child: buildApp(),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('重試'), findsOneWidget);
      await tester.tap(find.text('重試'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(PoiFavoriteCard), findsNWidgets(2));
    });

    testWidgets('卡片刪除先顯示具名確認，保留不會呼叫 API', (tester) async {
      final mockRepo = MockFavoritesRepository();
      when(mockRepo.watchFavorites).thenAnswer((_) => Stream.value(_favorites));
      when(() => mockRepo.deleteFavorite(any())).thenAnswer((_) async {});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [favoritesRepositoryProvider.overrideWithValue(mockRepo)],
          child: buildApp(),
        ),
      );
      await tester.pump();
      expect(find.byType(PoiFavoriteCard), findsNWidgets(2));

      await tester.tap(find.byKey(const ValueKey('favorite-remove-7')));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.text('刪除「美麗海水族館」？'), findsOneWidget);
      expect(find.text('將從收藏移除「美麗海水族館」。刪除後無法復原。'), findsOneWidget);
      await tester.tap(find.text('保留'));
      await tester.pumpAndSettle();

      verifyNever(() => mockRepo.deleteFavorite(any()));
      expect(find.byKey(const ValueKey('favorite-card-7')), findsOneWidget);
    });

    testWidgets('server 成功前保留卡片並鎖定重送，成功後才移除且沒有復原', (tester) async {
      final mockRepo = MockFavoritesRepository();
      final deletion = Completer<void>();
      when(mockRepo.watchFavorites).thenAnswer((_) => Stream.value(_favorites));
      when(() => mockRepo.deleteFavorite(7)).thenAnswer((_) => deletion.future);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [favoritesRepositoryProvider.overrideWithValue(mockRepo)],
          child: buildApp(),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('favorite-remove-7')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(CupertinoAlertDialog),
          matching: find.text('刪除'),
        ),
      );
      await tester.pump();

      verify(() => mockRepo.deleteFavorite(7)).called(1);
      expect(find.byKey(const ValueKey('favorite-card-7')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('favorite-delete-progress-7')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('favorite-remove-7')),
        warnIfMissed: false,
      );
      await tester.pump();
      verifyNever(() => mockRepo.deleteFavorite(7));

      deletion.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('favorite-card-7')), findsNothing);
      expect(find.text('復原'), findsNothing);
      expect(find.textContaining('Undo'), findsNothing);
    });

    testWidgets('左滑只揭露刪除，VoiceOver 與按鈕都進入同一確認', (tester) async {
      final mockRepo = MockFavoritesRepository();
      when(mockRepo.watchFavorites).thenAnswer((_) => Stream.value(_favorites));
      when(() => mockRepo.deleteFavorite(any())).thenAnswer((_) async {});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [favoritesRepositoryProvider.overrideWithValue(mockRepo)],
          child: buildApp(),
        ),
      );
      await tester.pump();

      expect(
        tester
            .widgetList<Semantics>(find.byType(Semantics))
            .any(
              (widget) =>
                  widget.properties.customSemanticsActions?.keys.any(
                    (action) => action.label == '刪除',
                  ) ??
                  false,
            ),
        isTrue,
      );
      await tester.drag(
        find.byKey(const ValueKey('favorite-dismiss-7')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();
      verifyNever(() => mockRepo.deleteFavorite(any()));
      await tester.tap(
        find.byKey(
          const ValueKey<Object>((
            'swipe-delete-action',
            ValueKey('favorite-dismiss-7'),
          )),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.text('刪除「美麗海水族館」？'), findsOneWidget);
      await tester.tap(find.text('保留'));
      await tester.pumpAndSettle();

      verifyNever(() => mockRepo.deleteFavorite(any()));
      expect(find.byKey(const ValueKey('favorite-card-7')), findsOneWidget);
    });

    testWidgets('左滑刪除成功後才移除卡片', (tester) async {
      final mockRepo = MockFavoritesRepository();
      when(mockRepo.watchFavorites).thenAnswer((_) => Stream.value(_favorites));
      when(() => mockRepo.deleteFavorite(7)).thenAnswer((_) async {});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [favoritesRepositoryProvider.overrideWithValue(mockRepo)],
          child: buildApp(),
        ),
      );
      await tester.pump();

      await tester.drag(
        find.byKey(const ValueKey('favorite-dismiss-7')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey<Object>((
            'swipe-delete-action',
            ValueKey('favorite-dismiss-7'),
          )),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(CupertinoAlertDialog),
          matching: find.text('刪除'),
        ),
      );
      await tester.pumpAndSettle();

      verify(() => mockRepo.deleteFavorite(7)).called(1);
      expect(find.byKey(const ValueKey('favorite-card-7')), findsNothing);
      expect(find.text('復原'), findsNothing);
    });

    testWidgets('左滑刪除失敗保留卡片並提供重試', (tester) async {
      final mockRepo = MockFavoritesRepository();
      when(mockRepo.watchFavorites).thenAnswer((_) => Stream.value(_favorites));
      when(
        () => mockRepo.deleteFavorite(7),
      ).thenAnswer((_) async => throw Exception('network'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [favoritesRepositoryProvider.overrideWithValue(mockRepo)],
          child: buildApp(),
        ),
      );
      await tester.pump();

      await tester.drag(
        find.byKey(const ValueKey('favorite-dismiss-7')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey<Object>((
            'swipe-delete-action',
            ValueKey('favorite-dismiss-7'),
          )),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(CupertinoAlertDialog),
          matching: find.text('刪除'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('favorite-card-7')), findsOneWidget);
      expect(find.text('無法刪除「美麗海水族館」，收藏仍保留。'), findsOneWidget);
      expect(find.text('重試'), findsOneWidget);
    });

    testWidgets('長按選單的 destructive 刪除使用相同確認與結果', (tester) async {
      final mockRepo = MockFavoritesRepository();
      when(mockRepo.watchFavorites).thenAnswer((_) => Stream.value(_favorites));
      when(() => mockRepo.deleteFavorite(7)).thenAnswer((_) async {});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [favoritesRepositoryProvider.overrideWithValue(mockRepo)],
          child: buildApp(),
        ),
      );
      await tester.pump();

      await tester.longPress(find.byKey(const ValueKey('favorite-card-7')));
      await tester.pumpAndSettle();
      expect(find.text('刪除'), findsOneWidget);
      await tester.tap(find.text('刪除'));
      await tester.pumpAndSettle();

      expect(find.text('刪除「美麗海水族館」？'), findsOneWidget);
      expect(find.text('將從收藏移除「美麗海水族館」。刪除後無法復原。'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(CupertinoAlertDialog),
          matching: find.text('刪除'),
        ),
      );
      await tester.pumpAndSettle();

      verify(() => mockRepo.deleteFavorite(7)).called(1);
      expect(find.byKey(const ValueKey('favorite-card-7')), findsNothing);
      expect(find.text('復原'), findsNothing);
    });

    testWidgets('長按選單取消刪除不會呼叫 API', (tester) async {
      final mockRepo = MockFavoritesRepository();
      when(mockRepo.watchFavorites).thenAnswer((_) => Stream.value(_favorites));
      when(() => mockRepo.deleteFavorite(any())).thenAnswer((_) async {});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [favoritesRepositoryProvider.overrideWithValue(mockRepo)],
          child: buildApp(),
        ),
      );
      await tester.pump();

      await tester.longPress(find.byKey(const ValueKey('favorite-card-7')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('刪除'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保留'));
      await tester.pumpAndSettle();

      verifyNever(() => mockRepo.deleteFavorite(any()));
      expect(find.byKey(const ValueKey('favorite-card-7')), findsOneWidget);
    });

    testWidgets('長按選單刪除失敗保留卡片並提供重試', (tester) async {
      final mockRepo = MockFavoritesRepository();
      when(mockRepo.watchFavorites).thenAnswer((_) => Stream.value(_favorites));
      when(
        () => mockRepo.deleteFavorite(7),
      ).thenAnswer((_) async => throw Exception('network'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [favoritesRepositoryProvider.overrideWithValue(mockRepo)],
          child: buildApp(),
        ),
      );
      await tester.pump();

      await tester.longPress(find.byKey(const ValueKey('favorite-card-7')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('刪除'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(CupertinoAlertDialog),
          matching: find.text('刪除'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('favorite-card-7')), findsOneWidget);
      expect(find.text('無法刪除「美麗海水族館」，收藏仍保留。'), findsOneWidget);
      expect(find.text('重試'), findsOneWidget);
    });

    testWidgets('刪除失敗保留卡片與選取並提供重試', (tester) async {
      final mockRepo = MockFavoritesRepository();
      var attempts = 0;
      when(mockRepo.watchFavorites).thenAnswer((_) => Stream.value(_favorites));
      when(() => mockRepo.deleteFavorite(7)).thenAnswer((_) async {
        attempts++;
        if (attempts == 1) throw Exception('network');
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [favoritesRepositoryProvider.overrideWithValue(mockRepo)],
          child: buildApp(),
        ),
      );
      await tester.pump();

      await tester.longPress(find.byKey(const ValueKey('favorite-card-7')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('選取'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('favorite-remove-7')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(CupertinoAlertDialog),
          matching: find.text('刪除'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('favorite-card-7')), findsOneWidget);
      expect(
        tester
            .widget<Checkbox>(find.byKey(const ValueKey('favorite-select-7')))
            .value,
        isTrue,
      );
      expect(find.text('無法刪除「美麗海水族館」，收藏仍保留。'), findsOneWidget);
      expect(find.text('重試'), findsOneWidget);

      await tester.tap(find.text('重試'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(CupertinoAlertDialog),
          matching: find.text('刪除'),
        ),
      );
      await tester.pumpAndSettle();

      expect(attempts, 2);
      expect(find.byKey(const ValueKey('favorite-card-7')), findsNothing);
    });

    testWidgets('排序選單顯示目前勾選並切換為最早加入', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            favoritesProvider.overrideWith((ref) => Stream.value(_favorites)),
          ],
          child: buildApp(),
        ),
      );
      await tester.pump();

      expect(
        tester.getTopLeft(find.text('暖暮拉麵')).dy,
        lessThan(tester.getTopLeft(find.text('美麗海水族館')).dy),
      );

      await tester.tap(find.byKey(const ValueKey('favorites-sort-action')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('favorites-sort-newest')),
        findsOneWidget,
      );
      expect(find.byIcon(CupertinoIcons.check_mark), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('favorites-sort-oldest')));
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.text('美麗海水族館')).dy,
        lessThan(tester.getTopLeft(find.text('暖暮拉麵')).dy),
      );
    });

    testWidgets('選取多個收藏 → 確認批次刪除 → 逐筆 deleteFavorite + refresh', (
      tester,
    ) async {
      final mockRepo = MockFavoritesRepository();
      var fetchCount = 0;
      when(mockRepo.watchFavorites).thenAnswer((_) {
        fetchCount++;
        return Stream.value(_favorites);
      });
      when(() => mockRepo.deleteFavorite(any())).thenAnswer((_) async {});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [favoritesRepositoryProvider.overrideWithValue(mockRepo)],
          child: buildApp(),
        ),
      );
      await tester.pump();

      await tester.longPress(find.byKey(const ValueKey('favorite-card-7')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('選取'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('favorite-select-8')));
      await tester.pump();

      expect(find.byKey(const ValueKey('favorites-toolbar')), findsOneWidget);
      expect(find.text('已選 2 個'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('favorites-delete-selected')));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.text('刪除 2 個收藏？'), findsOneWidget);
      expect(find.text('將刪除「美麗海水族館」、「暖暮拉麵」。刪除後無法復原。'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(CupertinoAlertDialog),
          matching: find.text('刪除'),
        ),
      );
      await tester.pumpAndSettle();

      verify(() => mockRepo.deleteFavorite(7)).called(1);
      verify(() => mockRepo.deleteFavorite(8)).called(1);
      expect(fetchCount, 2); // 初載 + 批次刪除後 invalidate refresh
      expect(find.byKey(const ValueKey('favorite-card-7')), findsNothing);
      expect(find.byKey(const ValueKey('favorite-card-8')), findsNothing);
      expect(find.text('復原'), findsNothing);
    });

    testWidgets('批次刪除按鈕有可讀語意，取消後保留選取且不呼叫 API', (tester) async {
      final semantics = tester.ensureSemantics();
      final mockRepo = MockFavoritesRepository();
      when(mockRepo.watchFavorites).thenAnswer((_) => Stream.value(_favorites));
      when(() => mockRepo.deleteFavorite(any())).thenAnswer((_) async {});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [favoritesRepositoryProvider.overrideWithValue(mockRepo)],
          child: buildApp(),
        ),
      );
      await tester.pump();

      await tester.longPress(find.byKey(const ValueKey('favorite-card-7')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('選取'));
      await tester.pumpAndSettle();

      final deleteButton = find.byKey(
        const ValueKey('favorites-delete-selected'),
      );
      expect(tester.getSemantics(deleteButton).label, contains('刪除'));
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('保留'));
      await tester.pumpAndSettle();

      verifyNever(() => mockRepo.deleteFavorite(any()));
      expect(find.byKey(const ValueKey('favorite-card-7')), findsOneWidget);
      expect(
        tester
            .widget<Checkbox>(find.byKey(const ValueKey('favorite-select-7')))
            .value,
        isTrue,
      );
      semantics.dispose();
    });

    testWidgets('批次刪除 pending 時所有公開入口共用同一鎖，不會重複送出', (tester) async {
      final mockRepo = MockFavoritesRepository();
      final deletion = Completer<void>();
      when(mockRepo.watchFavorites).thenAnswer((_) => Stream.value(_favorites));
      when(() => mockRepo.deleteFavorite(7)).thenAnswer((_) => deletion.future);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [favoritesRepositoryProvider.overrideWithValue(mockRepo)],
          child: buildApp(),
        ),
      );
      await tester.pump();

      await tester.longPress(find.byKey(const ValueKey('favorite-card-7')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('選取'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('favorites-delete-selected')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(CupertinoAlertDialog),
          matching: find.text('刪除'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      verify(() => mockRepo.deleteFavorite(7)).called(1);
      expect(find.byKey(const ValueKey('favorite-card-7')), findsOneWidget);
      expect(find.byType(CupertinoAlertDialog), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('favorite-remove-7')),
        warnIfMissed: false,
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(CupertinoAlertDialog), findsNothing);
      verifyNever(() => mockRepo.deleteFavorite(7));

      deletion.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('favorite-card-7')), findsNothing);
    });

    testWidgets('批次刪除只移除成功項目，失敗項目保留選取與重試', (tester) async {
      final mockRepo = MockFavoritesRepository();
      var secondAttempts = 0;
      when(mockRepo.watchFavorites).thenAnswer((_) => Stream.value(_favorites));
      when(() => mockRepo.deleteFavorite(7)).thenAnswer((_) async {});
      when(() => mockRepo.deleteFavorite(8)).thenAnswer((_) async {
        secondAttempts++;
        if (secondAttempts == 1) throw Exception('network');
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [favoritesRepositoryProvider.overrideWithValue(mockRepo)],
          child: buildApp(),
        ),
      );
      await tester.pump();

      await tester.longPress(find.byKey(const ValueKey('favorite-card-7')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('選取'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('favorite-select-8')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('favorites-delete-selected')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(CupertinoAlertDialog),
          matching: find.text('刪除'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('favorite-card-7')), findsNothing);
      expect(find.byKey(const ValueKey('favorite-card-8')), findsOneWidget);
      expect(
        tester
            .widget<Checkbox>(find.byKey(const ValueKey('favorite-select-8')))
            .value,
        isTrue,
      );
      expect(find.text('已選 1 個'), findsOneWidget);
      expect(find.text('1 個收藏刪除失敗，資料仍保留。'), findsOneWidget);
      expect(find.text('重試'), findsOneWidget);

      await tester.tap(find.text('重試'));
      await tester.pumpAndSettle();
      expect(find.text('刪除 1 個收藏？'), findsOneWidget);
      expect(find.text('將刪除「暖暮拉麵」。刪除後無法復原。'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(CupertinoAlertDialog),
          matching: find.text('刪除'),
        ),
      );
      await tester.pumpAndSettle();

      expect(secondAttempts, 2);
      expect(find.byKey(const ValueKey('favorite-card-8')), findsNothing);
    });

    testWidgets('收藏達 200 筆時分頁，每頁 24 筆且篩選重置頁碼', (tester) async {
      final favorites = _manyFavorites();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            favoritesProvider.overrideWith((ref) => Stream.value(favorites)),
          ],
          child: buildApp(),
        ),
      );
      await tester.pump();

      expect(find.text('收藏地點 200'), findsOneWidget);
      expect(find.text('收藏地點 176'), findsNothing);

      final pagination = find.byKey(const ValueKey('favorites-pagination'));
      final scrollView = find.byType(CustomScrollView);
      for (var i = 0; i < 8 && pagination.evaluate().isEmpty; i++) {
        await tester.drag(scrollView, const Offset(0, -500));
        await tester.pump();
      }
      expect(pagination, findsOneWidget);
      expect(find.text('1-24 / 200'), findsOneWidget);
      expect(find.text('第 1 / 9 頁'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('favorites-page-next')));
      await tester.pump();

      expect(find.text('25-48 / 200'), findsOneWidget);
      expect(find.text('第 2 / 9 頁'), findsOneWidget);

      await tester.fling(scrollView, const Offset(0, 5000), 10000);
      await tester.pumpAndSettle();

      final searchInput = find.byKey(const ValueKey('favorites-search-input'));
      await tester.enterText(searchInput, '收藏地點 1');
      await tester.pump();

      expect(find.text('收藏地點 1', skipOffstage: false), findsWidgets);
      for (var i = 0; i < 8 && pagination.evaluate().isEmpty; i++) {
        await tester.drag(scrollView, const Offset(0, -500));
        await tester.pump();
      }
      expect(find.text('第 1 / 5 頁'), findsOneWidget);
      expect(find.byType(PoiFavoriteCard), findsWidgets);
    });

    testWidgets('Header 新增 action → 導到 /favorites/explore', (tester) async {
      final mockRepo = MockFavoritesRepository();
      when(mockRepo.watchFavorites).thenAnswer((_) => Stream.value(const []));

      final router = GoRouter(
        initialLocation: '/favorites',
        routes: [
          GoRoute(
            path: '/favorites',
            builder: (context, state) => const FavoritesScreen(),
            routes: [
              GoRoute(
                path: 'explore',
                builder: (context, state) =>
                    const Scaffold(body: Text('EXPLORE-PROBE')),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [favoritesRepositoryProvider.overrideWithValue(mockRepo)],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('favorites-add-action')));
      await tester.pumpAndSettle();
      expect(find.text('EXPLORE-PROBE'), findsOneWidget);
    });

    testWidgets('empty「去探索」→ 導到 /favorites/explore', (tester) async {
      final mockRepo = MockFavoritesRepository();
      when(mockRepo.watchFavorites).thenAnswer((_) => Stream.value(const []));

      final router = GoRouter(
        initialLocation: '/favorites',
        routes: [
          GoRoute(
            path: '/favorites',
            builder: (context, state) => const FavoritesScreen(),
            routes: [
              GoRoute(
                path: 'explore',
                builder: (context, state) =>
                    const Scaffold(body: Text('EXPLORE-PROBE')),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [favoritesRepositoryProvider.overrideWithValue(mockRepo)],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('favorites-empty-explore')));
      await tester.pumpAndSettle();
      expect(find.text('EXPLORE-PROBE'), findsOneWidget);
    });
  });
}
