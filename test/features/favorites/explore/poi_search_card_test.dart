import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/poi_search_result.dart';
import 'package:tripline/features/favorites/explore/poi_search_card.dart';
import 'package:tripline/theme/app_theme.dart';

Future<void> pumpCard(
  WidgetTester tester, {
  required bool isSaved,
  VoidCallback? onToggle,
}) {
  return tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: PoiSearchCard(
        poi: const PoiSearchResult(
          placeId: 'p1', name: '暖暮拉麵', address: '那霸市',
          category: 'ramen_restaurant', rating: 4.5,
        ),
        isSaved: isSaved,
        isSaving: false,
        onToggleFavorite: onToggle ?? () {},
      ),
    ),
  ));
}

void main() {
  testWidgets('顯示名稱/類型label/評分;未收藏 = border heart', (tester) async {
    await pumpCard(tester, isSaved: false);
    expect(find.text('暖暮拉麵'), findsOneWidget);
    expect(find.text('餐廳'), findsOneWidget); // ramen_restaurant → restaurant → 餐廳
    expect(find.text('4.5'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byKey(const ValueKey('poi-card-p1')), findsOneWidget);
  });

  testWidgets('已收藏 = filled heart', (tester) async {
    await pumpCard(tester, isSaved: true);
    expect(find.byIcon(Icons.favorite), findsOneWidget);
  });

  testWidgets('點 heart → onToggleFavorite', (tester) async {
    var toggled = 0;
    await pumpCard(tester, isSaved: false, onToggle: () => toggled++);
    await tester.tap(find.byKey(const ValueKey('poi-heart-p1')));
    expect(toggled, 1);
  });
}
