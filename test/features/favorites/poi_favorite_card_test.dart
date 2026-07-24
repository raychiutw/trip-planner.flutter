import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/poi_favorite.dart';
import 'package:tripline/features/favorites/poi_favorite_card.dart';
import 'package:tripline/theme/app_theme.dart';

Future<void> pumpCard(
  WidgetTester tester,
  PoiFavorite favorite, {
  VoidCallback? onRemove,
  VoidCallback? onAddToTrip,
  String matchQuery = '',
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: PoiFavoriteCard(
          favorite: favorite,
          onRemove: onRemove ?? () {},
          onAddToTrip: onAddToTrip,
          matchQuery: matchQuery,
        ),
      ),
    ),
  );
}

const _favorite = PoiFavorite(
  id: 7,
  userId: 'u-1',
  poiId: 501,
  favoritedAt: '2026-06-01T10:00:00Z',
  note: '想去',
  poiName: '美麗海水族館',
  poiAddress: '沖繩縣國頭郡本部町石川424',
  poiType: 'attraction',
  poiRating: 4.6,
  usages: [
    PoiFavoriteUsage(tripId: 'okinawa', tripName: '沖繩', dayNum: 1),
    PoiFavoriteUsage(tripId: 'kyoto', tripName: '京都'),
  ],
);

void main() {
  group('PoiFavoriteCard', () {
    testWidgets('顯示名稱、評分、note、usages 摘要、ValueKey', (tester) async {
      await pumpCard(tester, _favorite);
      expect(find.text('美麗海水族館'), findsOneWidget);
      expect(find.text('4.6'), findsOneWidget);
      expect(find.text('想去'), findsOneWidget);
      expect(find.text('用於 2 個行程'), findsOneWidget);
      expect(find.byKey(const ValueKey('favorite-card-7')), findsOneWidget);
    });

    testWidgets('usages 空 → 不顯示行程摘要', (tester) async {
      await pumpCard(
        tester,
        const PoiFavorite(
          id: 8,
          userId: 'u-1',
          poiId: 502,
          favoritedAt: '2026-06-02T10:00:00Z',
          poiName: '無人地點',
        ),
      );
      expect(find.text('無人地點'), findsOneWidget);
      expect(find.textContaining('用於'), findsNothing);
    });

    testWidgets('S1 搜尋結果只加深符合字串並維持單行', (tester) async {
      await pumpCard(tester, _favorite, matchQuery: '水族');

      final title = tester.widget<Text>(
        find.byKey(const ValueKey('favorite-title-7')),
      );
      expect(title.maxLines, 1);
      expect(title.overflow, TextOverflow.ellipsis);
      final span = title.textSpan! as TextSpan;
      final children = span.children!.cast<TextSpan>();
      expect(children.map((child) => child.text).toList(), ['美麗海', '水族', '館']);
      expect(children[1].style?.fontWeight, FontWeight.w600);
      expect(children[1].style?.color, AppTheme.light().colorScheme.onSurface);
    });

    testWidgets('S1 地址命中時顯示地址並加深符合字串', (tester) async {
      await pumpCard(tester, _favorite, matchQuery: '沖繩');

      final address = tester.widget<Text>(
        find.byKey(const ValueKey('favorite-address-7')),
      );
      final span = address.textSpan! as TextSpan;
      final matched = span.children!.cast<TextSpan>()[0];
      expect(matched.text, '沖繩');
      expect(matched.style?.fontWeight, FontWeight.w600);
      expect(matched.style?.color, AppTheme.light().colorScheme.onSurface);
    });

    testWidgets('所有 POI 類型的 leading 都使用同一 Tripline accent', (tester) async {
      await pumpCard(
        tester,
        const PoiFavorite(
          id: 9,
          userId: 'u-1',
          poiId: 503,
          favoritedAt: '2026-06-03T10:00:00Z',
          poiName: '沖繩飯店',
          poiType: 'hotel',
        ),
      );

      final leading = tester.widget<Container>(
        find.byKey(const ValueKey('favorite-leading-9')),
      );
      final decoration = leading.decoration! as BoxDecoration;
      final colors = AppTheme.light().colorScheme;
      expect(decoration.color, colors.primaryContainer);
      expect(
        tester
            .widget<Icon>(
              find.descendant(
                of: find.byKey(const ValueKey('favorite-leading-9')),
                matching: find.byType(Icon),
              ),
            )
            .color,
        colors.onPrimaryContainer,
      );
      expect(
        tester
            .widget<Icon>(
              find.descendant(
                of: find.byKey(const ValueKey('favorite-remove-9')),
                matching: find.byType(Icon),
              ),
            )
            .color,
        colors.onPrimaryContainer,
      );
    });

    testWidgets('點 heart → onRemove 被呼叫', (tester) async {
      var removed = 0;
      await pumpCard(tester, _favorite, onRemove: () => removed++);
      await tester.tap(find.byKey(const ValueKey('favorite-remove-7')));
      expect(removed, 1);
    });

    testWidgets('加入行程不常駐顯示,長按才觸發 context action', (tester) async {
      var added = 0;
      await pumpCard(tester, _favorite, onAddToTrip: () => added++);
      expect(
        find.byKey(const ValueKey('favorite-add-to-trip-7')),
        findsNothing,
      );
      await tester.longPress(find.byKey(const ValueKey('favorite-card-7')));
      expect(added, 1);
    });
  });
}
