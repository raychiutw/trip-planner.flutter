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
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: PoiFavoriteCard(
          favorite: favorite,
          onRemove: onRemove ?? () {},
          onAddToTrip: onAddToTrip,
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

    testWidgets('note 不顯示內部 request 編號', (tester) async {
      await pumpCard(
        tester,
        const PoiFavorite(
          id: 9,
          userId: 'u-1',
          poiId: 503,
          favoritedAt: '2026-06-03T10:00:00Z',
          poiName: '旅館',
          note: '旅伴請求加入收藏 (req #184)',
        ),
      );

      expect(find.text('旅伴請求加入收藏'), findsOneWidget);
      expect(find.textContaining('req #'), findsNothing);
    });

    testWidgets('取消收藏改為左滑，列尾不再顯示 competing heart', (tester) async {
      var removed = 0;
      await pumpCard(tester, _favorite, onRemove: () => removed++);
      expect(find.byKey(const ValueKey('favorite-remove-7')), findsNothing);
      await tester.drag(
        find.byKey(const ValueKey('favorite-swipe-7')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();
      expect(removed, 1);
    });

    testWidgets('有 onAddToTrip → 點加入行程鈕觸發', (tester) async {
      var added = 0;
      await pumpCard(tester, _favorite, onAddToTrip: () => added++);
      await tester.tap(find.byKey(const ValueKey('favorite-add-to-trip-7')));
      expect(added, 1);
    });
  });
}
