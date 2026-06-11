import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/features/favorites/poi_rating_label.dart';
import 'package:tripline/theme/app_theme.dart';

Future<void> _pump(WidgetTester tester, double rating) {
  return tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: PoiRatingLabel(rating: rating)),
  ));
}

void main() {
  testWidgets('顯示一位小數評分 + 星星 icon', (tester) async {
    await _pump(tester, 4.5);
    expect(find.text('4.5'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
  });

  testWidgets('整數評分顯示一位小數', (tester) async {
    await _pump(tester, 4);
    expect(find.text('4.0'), findsOneWidget);
  });
}
