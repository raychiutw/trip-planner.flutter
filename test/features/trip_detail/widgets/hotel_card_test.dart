import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/features/trip_detail/widgets/hotel_card.dart';
import 'package:tripline/theme/app_theme.dart';

Future<void> pumpHotel(WidgetTester tester, DayHotel hotel) {
  return tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: HotelCard(hotel: hotel)),
  ));
}

void main() {
  group('HotelCard', () {
    testWidgets('name + checkout + note 全顯示,並有 ValueKey', (tester) async {
      await pumpHotel(
        tester,
        const DayHotel(
          id: 7,
          name: 'ANA 萬座海濱洲際',
          checkout: '11:00',
          note: '海景房',
        ),
      );
      expect(find.text('ANA 萬座海濱洲際'), findsOneWidget);
      expect(find.text('退房 11:00'), findsOneWidget);
      expect(find.text('海景房'), findsOneWidget);
      expect(find.byKey(const ValueKey('hotel-card-7')), findsOneWidget);
      expect(find.byIcon(Icons.bed_outlined), findsOneWidget);
    });

    testWidgets('checkout / note 為 null → 不顯示對應列', (tester) async {
      await pumpHotel(tester, const DayHotel(id: 8, name: '青年旅館'));
      expect(find.text('青年旅館'), findsOneWidget);
      expect(find.textContaining('退房'), findsNothing);
    });
  });
}
