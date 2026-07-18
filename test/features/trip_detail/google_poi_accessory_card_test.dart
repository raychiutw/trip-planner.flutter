import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/features/map/map_adapter.dart';
import 'package:tripline/features/trip_detail/google_poi_accessory_card.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/theme/tokens.dart';

const _selection = GoogleMapPoiSelection(
  placeId: 'ChIJ-test',
  name: '清水寺',
  point: TripMapPoint(34.9948, 135.785),
);

Widget _buildCard({
  ThemeData? theme,
  TextScaler textScaler = TextScaler.noScaling,
  bool highContrast = false,
  VoidCallback? onClose,
  VoidCallback? onOpen,
}) => MaterialApp(
  theme: theme ?? AppTheme.light(),
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: 320,
        height: 144,
        child: GooglePoiAccessoryCard(
          selection: _selection,
          onClose: onClose ?? () {},
          onOpen: onOpen ?? () {},
        ),
      ),
    ),
  ),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: textScaler, highContrast: highContrast),
    child: child!,
  ),
);

void main() {
  testWidgets('200% 字級保留 44pt 關閉與外開操作', (tester) async {
    await tester.pumpWidget(_buildCard(textScaler: const TextScaler.linear(2)));

    expect(tester.takeException(), isNull);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('google-poi-close')))
          .shortestSide,
      greaterThanOrEqualTo(TpSpacing.tapMin),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('google-poi-open'))).height,
      greaterThanOrEqualTo(TpSpacing.tapMin),
    );
  });

  testWidgets('外開操作有離開 Tripline 的完整語意標籤', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_buildCard());

    expect(
      find.bySemanticsLabel('在 Google 地圖開啟清水寺，將離開 Tripline'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('淺色、深色與高對比模式都能操作', (tester) async {
    var closes = 0;
    var opens = 0;
    for (final configuration in [
      (theme: AppTheme.light(), highContrast: false),
      (theme: AppTheme.dark(), highContrast: false),
      (theme: AppTheme.light(), highContrast: true),
    ]) {
      await tester.pumpWidget(
        _buildCard(
          theme: configuration.theme,
          highContrast: configuration.highContrast,
          onClose: () => closes++,
          onOpen: () => opens++,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('google-poi-close')));
      await tester.tap(find.byKey(const ValueKey('google-poi-open')));
      expect(tester.takeException(), isNull);
    }

    expect(closes, 3);
    expect(opens, 3);
  });
}
