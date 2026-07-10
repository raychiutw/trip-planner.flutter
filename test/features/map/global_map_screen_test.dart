import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/features/favorites/favorites_providers.dart';
import 'package:tripline/features/map/global_map_screen.dart';
import 'package:tripline/models/poi_favorite.dart';
import 'package:tripline/theme/app_theme.dart';

class _TransparentTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(TileProvider.transparentImage);
}

const _withCoords = PoiFavorite(
  id: 1,
  userId: 'u',
  poiId: 10,
  favoritedAt: '2026-01-01',
  poiName: '首里城',
  poiLat: 26.2,
  poiLng: 127.7,
  poiType: 'attraction',
  poiRating: 4.5,
  usages: [PoiFavoriteUsage(tripId: 'okinawa', tripName: '沖繩')],
);
const _noCoords = PoiFavorite(
  id: 2,
  userId: 'u',
  poiId: 11,
  favoritedAt: '2026-01-01',
  poiName: '無座標',
);

void main() {
  Widget buildApp(List<PoiFavorite> favs) {
    return ProviderScope(
      overrides: [favoritesProvider.overrideWith((ref) => Stream.value(favs))],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: GlobalMapScreen(tileProvider: _TransparentTileProvider()),
      ),
    );
  }

  testWidgets('有座標的收藏 → 顯示 marker(無座標者跳過)', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(buildApp(const [_withCoords, _noCoords]));
    await tester.pumpAndSettle();

    final marker = find.byKey(const ValueKey('map-fav-1'));
    expect(marker, findsOneWidget);
    expect(find.byKey(const ValueKey('map-fav-2')), findsNothing);
    expect(tester.getSize(marker), const Size.square(44));
    expect(
      tester.getSemantics(marker),
      matchesSemantics(
        label: '收藏地點，首里城',
        isSelected: false,
        hasSelectedState: true,
        isButton: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('點 marker → 顯示選中卡(名稱 + 所屬行程)', (tester) async {
    await tester.pumpWidget(buildApp(const [_withCoords]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('map-fav-1')));
    await tester.pumpAndSettle();

    expect(find.text('首里城'), findsOneWidget);
    expect(find.textContaining('沖繩'), findsOneWidget);
  });

  testWidgets('無可顯示座標 → 提示', (tester) async {
    await tester.pumpWidget(buildApp(const [_noCoords]));
    await tester.pumpAndSettle();

    expect(find.text('還沒有地點可顯示'), findsOneWidget);
    expect(find.byType(FlutterMap), findsNothing);
  });
}
