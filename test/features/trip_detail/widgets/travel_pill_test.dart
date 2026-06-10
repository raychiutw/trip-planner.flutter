import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/features/trip_detail/widgets/travel_pill.dart';
import 'package:tripline/theme/app_theme.dart';

Future<void> pumpPill(WidgetTester tester, Travel travel) {
  return tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: Center(child: TravelPill(travel: travel))),
  ));
}

void main() {
  group('TravelPill.iconForType', () {
    test('已知類型對應 icon', () {
      expect(TravelPill.iconForType('walk'), Icons.directions_walk);
      expect(TravelPill.iconForType('car'), Icons.directions_car);
      expect(TravelPill.iconForType('drive'), Icons.directions_car);
      expect(TravelPill.iconForType('taxi'), Icons.local_taxi);
      expect(TravelPill.iconForType('bus'), Icons.directions_bus);
      expect(TravelPill.iconForType('train'), Icons.train);
      expect(TravelPill.iconForType('tram'), Icons.tram);
      expect(TravelPill.iconForType('flight'), Icons.flight);
      expect(TravelPill.iconForType('ferry'), Icons.directions_boat);
      expect(TravelPill.iconForType('bike'), Icons.directions_bike);
    });

    test('未知類型 → Icons.route', () {
      expect(TravelPill.iconForType('teleport'), Icons.route);
    });
  });

  group('TravelPill 渲染', () {
    testWidgets('有 min → 「N 分鐘」', (tester) async {
      await pumpPill(tester, const Travel(type: 'walk', min: 12));
      expect(find.text('12 分鐘'), findsOneWidget);
      expect(find.byIcon(Icons.directions_walk), findsOneWidget);
    });

    testWidgets('無 min 有 desc → desc', (tester) async {
      await pumpPill(tester, const Travel(type: 'train', desc: '搭單軌到首里'));
      expect(find.text('搭單軌到首里'), findsOneWidget);
    });

    testWidgets('min 與 desc 皆無 → 「移動」', (tester) async {
      await pumpPill(tester, const Travel(type: 'bus'));
      expect(find.text('移動'), findsOneWidget);
    });
  });
}
