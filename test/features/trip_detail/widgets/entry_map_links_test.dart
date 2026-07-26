import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/features/trip_detail/widgets/entry_map_links.dart';
import 'package:tripline/models/entry.dart';
import 'package:url_launcher/url_launcher.dart';

const _poi = EntryPoiInfo(
  poiId: 101,
  name: '沖繩美麗海水族館',
  lat: 26.6942,
  lng: 127.8778,
);

Future<void> _pump(
  WidgetTester tester, {
  required TargetPlatform platform,
  EntryPoiInfo poi = _poi,
  required EntryMapUrlLaunch launch,
  VoidCallback? onError,
}) => tester.pumpWidget(
  MaterialApp(
    theme: ThemeData(platform: platform),
    home: Scaffold(
      body: EntryMapLinks(poi: poi, launch: launch, onError: onError ?? () {}),
    ),
  ),
);

void main() {
  testWidgets('Android 只顯示 Google，按鈕 hit target 至少 44pt', (tester) async {
    Uri? opened;
    await _pump(
      tester,
      platform: TargetPlatform.android,
      launch: (uri, {mode = LaunchMode.platformDefault}) async {
        opened = uri;
        return true;
      },
    );

    expect(find.text('Google'), findsOneWidget);
    expect(find.text('Apple'), findsNothing);
    expect(find.bySemanticsLabel('使用 Google 開啟地圖'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('entry-google-map-101'))).height,
      greaterThanOrEqualTo(44),
    );

    await tester.tap(find.text('Google'));
    await tester.pump();
    expect(opened?.host, 'www.google.com');
    // 名稱優先：座標當 query 時 Google Maps 只落一根無名的針，使用者看到的
    // 是一串數字而不是景點。
    expect(opened?.queryParameters['query'], '沖繩美麗海水族館');
  });

  testWidgets('iOS 顯示 Google 與 Apple，Apple app 失敗後改用網頁', (tester) async {
    final modes = <LaunchMode>[];
    await _pump(
      tester,
      platform: TargetPlatform.iOS,
      launch: (uri, {mode = LaunchMode.platformDefault}) async {
        modes.add(mode);
        return mode == LaunchMode.platformDefault;
      },
    );

    expect(find.text('Google'), findsOneWidget);
    expect(find.text('Apple'), findsOneWidget);
    expect(find.bySemanticsLabel('使用 Apple 開啟地圖'), findsOneWidget);
    await tester.tap(find.text('Apple'));
    await tester.pump();
    expect(modes, [LaunchMode.externalApplication, LaunchMode.platformDefault]);
  });

  testWidgets('完全沒有位置時提供語意；外開失敗回報錯誤', (tester) async {
    var errors = 0;
    await _pump(
      tester,
      platform: TargetPlatform.android,
      poi: const EntryPoiInfo(poiId: 0),
      launch: (uri, {mode = LaunchMode.platformDefault}) async => false,
      onError: () => errors++,
    );
    expect(find.bySemanticsLabel('尚無位置'), findsOneWidget);
    expect(find.text('Google'), findsNothing);

    await _pump(
      tester,
      platform: TargetPlatform.android,
      launch: (uri, {mode = LaunchMode.platformDefault}) async => false,
      onError: () => errors++,
    );
    await tester.tap(find.text('Google'));
    await tester.pump();
    expect(errors, 1);
  });
}
