import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tripline/app/accessibility_scope.dart';
import 'package:tripline/features/map/map_location.dart';
import 'package:tripline/features/trip_detail/trip_map_screen.dart';
import 'package:tripline/features/trip_detail/trip_providers.dart';
import 'package:tripline/features/trips/trips_list_screen.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_app_bar.dart';
import 'package:tripline/ui/tp_glass_surface.dart';

void main() {
  for (final control in [
    (name: '帳號', icon: CupertinoIcons.person_crop_circle),
    (name: '定位', icon: Icons.my_location),
  ]) {
    testWidgets('${control.name}背景在亮暗圖磚間至少透出一半亮度差，圖示仍清楚', (tester) async {
      for (final brightness in Brightness.values) {
        final samples = <Color>[];
        for (final background in [Colors.white, Colors.black]) {
          final raster = await _pump(tester, brightness, background);
          final rect = tester.getRect(find.byIcon(control.icon));
          samples.add(raster.backing(rect));
          debugPrint(
            '${brightness.name} ${control.name} ${background == Colors.white ? 'white' : 'black'} 對比 ${raster.contrast(rect).toStringAsFixed(3)}',
          );
          expect(raster.contrast(rect), greaterThanOrEqualTo(3));
        }
        final transmission = samples.first.r - samples.last.r;
        debugPrint(
          '${brightness.name} ${control.name}透出 ${transmission.toStringAsFixed(3)}',
        );
        expect(transmission, inInclusiveRange(.5, .7));
      }
    });
  }
  testWidgets('真行程地圖的帳號與定位保留一致透出和圖示對比', (tester) async {
    for (final brightness in Brightness.values) {
      final samples = <List<Color>>[];
      for (final background in [Colors.white, Colors.black]) {
        final raster = await _pump(
          tester,
          brightness,
          background,
          fullScreen: true,
        );
        final rects = [
          tester.getRect(find.byIcon(CupertinoIcons.person_crop_circle)),
          tester.getRect(find.byIcon(Icons.my_location)),
        ];
        samples.add(rects.map(raster.backing).toList());
        for (final rect in rects) {
          expect(raster.contrast(rect), greaterThanOrEqualTo(3));
        }
      }
      for (var index = 0; index < 2; index++) {
        expect(
          samples.first[index].r - samples.last[index].r,
          inInclusiveRange(.5, .7),
        );
      }
    }
  });
  testWidgets('兩顆控制各自支援不透明降級、44pt、語意與操作', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      for (final brightness in Brightness.values) {
        for (final reduceTransparency in [false, true]) {
          final samples = <List<Color>>[];
          for (final background in [Colors.white, Colors.black]) {
            var accounts = 0;
            var locations = 0;
            final raster = await _pump(
              tester,
              brightness,
              background,
              highContrast: !reduceTransparency,
              reduceTransparency: reduceTransparency,
              onAccount: () => accounts++,
              onLocate: () => locations++,
            );
            final rects = [
              tester.getRect(find.byIcon(CupertinoIcons.person_crop_circle)),
              tester.getRect(find.byIcon(Icons.my_location)),
            ];
            samples.add(rects.map(raster.backing).toList());
            for (final rect in rects) {
              expect(raster.contrast(rect), greaterThanOrEqualTo(3));
            }
            for (final label in ['帳號', '定位目前位置']) {
              final finder = find.bySemanticsLabel(label);
              expect(finder, findsOneWidget);
              expect(
                tester
                    .getSemantics(finder)
                    .getSemanticsData()
                    .flagsCollection
                    .isButton,
                isTrue,
              );
            }
            expect(
              tester.getSize(find.byType(TpAccountAvatarButton)),
              const Size(44, 44),
            );
            expect(
              tester.getSize(find.byType(TripMapLocateButton)),
              const Size(44, 44),
            );
            await tester.tap(find.byType(TpAccountAvatarButton));
            await tester.pumpAndSettle();
            await tester.tap(find.byType(TripMapLocateButton));
            await tester.pumpAndSettle();
            expect(accounts, 1);
            expect(locations, 1);
          }
          expect(samples.first, samples.last, reason: '提高對比或降低透明度任一啟用皆隔離背景');
        }
      }
    } finally {
      semantics.dispose();
    }
  });
  testWidgets('定位進行中提高對比或降低透明度仍完全隔離底圖', (tester) async {
    for (final brightness in Brightness.values) {
      for (final reduceTransparency in [false, true]) {
        final samples = <Color>[];
        for (final background in [Colors.white, Colors.black]) {
          final raster = await _pump(
            tester,
            brightness,
            background,
            locating: true,
            highContrast: !reduceTransparency,
            reduceTransparency: reduceTransparency,
          );
          samples.add(
            raster.backing(
              tester.getRect(find.byType(CircularProgressIndicator)),
            ),
          );
        }
        expect(
          samples.first,
          samples.last,
          reason: '定位進度不應讓不透明無障礙底色跟著disabled淡化',
        );
      }
    }
  });
  testWidgets('定位進行中保留進度與語意且不能重入', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      var calls = 0;
      await _pump(
        tester,
        Brightness.dark,
        Colors.white,
        locating: true,
        onLocate: () => calls++,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('定位目前位置'))
            .getSemanticsData()
            .flagsCollection
            .isEnabled,
        ui.Tristate.isFalse,
      );
      await tester.tap(find.byType(TripMapLocateButton));
      await tester.pump(const Duration(milliseconds: 300));
      expect(calls, 0);
    } finally {
      semantics.dispose();
    }
  });
}

Future<_Raster> _pump(
  WidgetTester tester,
  Brightness brightness,
  Color background, {
  bool fullScreen = false,
  bool highContrast = false,
  bool reduceTransparency = false,
  bool locating = false,
  VoidCallback? onAccount,
  VoidCallback? onLocate,
}) async {
  await tester.runAsync(() async {
    final loader = FontLoader('MapIconRegression');
    for (final weight in ['regular', 'bold']) {
      loader.addFont(
        Future.value(
          ByteData.sublistView(
            File('test/fixtures/fonts/roboto-$weight.ttf').readAsBytesSync(),
          ),
        ),
      );
    }
    await loader.load();
    await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
          rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  await tester.binding.setSurfaceSize(
    fullScreen ? const Size(390, 844) : const Size(240, 160),
  );
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final boundary = GlobalKey();
  final content = fullScreen
      ? TripMapScreen(
          tripId: 'transparency',
          initialDayNum: 1,
          mapBuilder: (_) => ColoredBox(color: background),
        )
      : ColoredBox(
          color: background,
          child: Stack(
            children: [
              Positioned(
                left: 40,
                top: 50,
                child: TpAccountAvatarButton(onPressed: onAccount ?? () {}),
              ),
              Positioned(
                left: 140,
                top: 50,
                child: TripMapLocateButton(
                  locating: locating,
                  onPressed: onLocate ?? () {},
                ),
              ),
            ],
          ),
        );
  final home = MediaQuery(
    data: MediaQueryData(highContrast: highContrast),
    child: AppAccessibilityScope(
      reduceTransparency: reduceTransparency,
      child: TpMediaBackdropScope(
        onMedia: true,
        child: TpAccountActionScope(
          onOpen: (_) {},
          child: RepaintBoundary(key: boundary, child: content),
        ),
      ),
    ),
  );
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => home)],
  );
  addTearDown(router.dispose);
  final base = brightness == Brightness.dark
      ? AppTheme.dark()
      : AppTheme.light();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tripDaysProvider.overrideWith(
          (ref, tripId) => Stream.value([
            for (var day = 1; day <= 5; day++)
              TripDay(id: day, dayNum: day, version: 0),
          ]),
        ),
        myTripsProvider.overrideWith(
          (ref) => Stream.value(const [
            TripSummary(
              tripId: 'transparency',
              name: 'Tokyo',
              title: 'Tokyo trip',
            ),
          ]),
        ),
      ],
      child: MaterialApp.router(
        theme: base.copyWith(
          textTheme: base.textTheme.apply(fontFamily: 'MapIconRegression'),
        ),
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  if (!locating) await tester.pumpAndSettle();
  return (await tester.runAsync(() async {
    final image =
        await (boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary)
            .toImage();
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    const directory = String.fromEnvironment('MAP_ICON_ARTIFACTS');
    if (directory.isNotEmpty) {
      await Directory(directory).create(recursive: true);
      final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await File(
        '$directory/${fullScreen ? 'screen' : 'controls'}-${brightness.name}-${background == Colors.white ? "white" : "black"}-$highContrast-$reduceTransparency-$locating.png',
      ).writeAsBytes(png.buffer.asUint8List());
    }
    final raster = _Raster(bytes, image.width);
    image.dispose();
    return raster;
  }))!;
}

class _Raster {
  _Raster(this.bytes, this.width);
  final ByteData bytes;
  final int width;
  Color pixel(int x, int y) {
    final offset = (y * width + x) * 4;
    return Color.fromARGB(
      bytes.getUint8(offset + 3),
      bytes.getUint8(offset),
      bytes.getUint8(offset + 1),
      bytes.getUint8(offset + 2),
    );
  }

  Color backing(Rect rect) =>
      pixel(rect.center.dx.floor(), (rect.top - 5).floor());
  double contrast(Rect rect) {
    final background = backing(rect).computeLuminance();
    final ratios = <double>[];
    for (var y = rect.top.ceil(); y < rect.bottom.floor(); y++) {
      for (var x = rect.left.ceil(); x < rect.right.floor(); x++) {
        final foreground = pixel(x, y).computeLuminance();
        ratios.add(
          foreground > background
              ? (foreground + .05) / (background + .05)
              : (background + .05) / (foreground + .05),
        );
      }
    }
    ratios.sort((a, b) => b.compareTo(a));
    return ratios.take(10).reduce((a, b) => a + b) / 10;
  }
}
