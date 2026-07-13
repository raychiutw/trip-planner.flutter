import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/models/segment.dart';
import 'package:tripline/features/trip_detail/widgets/travel_pill.dart';
import 'package:tripline/theme/app_theme.dart';

Future<void> pumpPill(WidgetTester tester, Travel travel) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Center(child: TravelPill(travel: travel)),
      ),
    ),
  );
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

    // 距離顯示（對齊 web「20 分鐘 · 11 km」）
    testWidgets('min 與 distanceM 皆有 → 「N 分鐘 · K km」', (tester) async {
      await pumpPill(
        tester,
        const Travel(type: 'car', min: 20, distanceM: 11000),
      );
      expect(find.text('20 分鐘 · 11 km'), findsOneWidget);
    });

    testWidgets('僅 distanceM(>=1000m) → 整數 km', (tester) async {
      await pumpPill(tester, const Travel(type: 'walk', distanceM: 5500));
      expect(find.text('5 km'), findsOneWidget);
    });

    testWidgets('僅 distanceM(<1000m) → 「M m」', (tester) async {
      await pumpPill(tester, const Travel(type: 'walk', distanceM: 350));
      expect(find.text('350 m'), findsOneWidget);
    });

    testWidgets('min 與 distanceM 皆無、有 desc → desc（fallback 不變）', (
      tester,
    ) async {
      await pumpPill(tester, const Travel(type: 'train', desc: '接駁車'));
      expect(find.text('接駁車'), findsOneWidget);
    });

    testWidgets('min 與 distanceM 與 desc 皆無 → 「移動」（fallback 不變）', (
      tester,
    ) async {
      await pumpPill(tester, const Travel(type: 'ferry'));
      expect(find.text('移動'), findsOneWidget);
    });

    testWidgets('transit submode 顯示具體交通方式', (tester) async {
      await pumpPill(
        tester,
        const Travel(type: 'transit', submode: 'hsr', min: 90),
      );
      expect(find.text('高鐵 · 90 分鐘'), findsOneWidget);
      expect(find.byIcon(Icons.train), findsOneWidget);
    });

    testWidgets('sameplace 顯示中性「不需計算路程」marker', (tester) async {
      await pumpPill(tester, const Travel(type: 'transit', sameplace: true));
      expect(find.text('不需計算路程'), findsOneWidget);
      expect(find.byKey(const ValueKey('travel-no-travel')), findsOneWidget);
      expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
    });

    testWidgets('segment 是顯示 source of truth', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: TravelPill(
              travel: Travel(type: 'car', min: 5),
              segment: TripSegment(
                id: 1,
                mode: 'transit',
                submode: 'metro',
                min: 20,
                computedAt: 1783904400000,
                version: 1,
              ),
            ),
          ),
        ),
      );
      expect(find.text('地鐵 · 20 分鐘'), findsOneWidget);
      expect(find.text('5 分鐘'), findsNothing);
    });

    testWidgets('computedAt 為 null 時隱藏舊估值並標示待更新', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: TravelPill(
              segment: TripSegment(
                id: 1,
                mode: 'driving',
                min: 20,
                distanceM: 5000,
                computedAt: null,
                version: 1,
              ),
            ),
          ),
        ),
      );

      expect(find.text('車程待更新'), findsOneWidget);
      expect(find.textContaining('20'), findsNothing);
      expect(find.textContaining('5 km'), findsNothing);
      expect(find.byKey(const ValueKey('travel-stale')), findsOneWidget);
    });
  });
}
