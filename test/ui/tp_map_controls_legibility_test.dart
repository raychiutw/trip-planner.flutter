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
import 'package:tripline/features/trip_detail/trip_map_screen.dart';
import 'package:tripline/features/trip_detail/trip_providers.dart';
import 'package:tripline/features/trips/trips_list_screen.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_app_bar.dart';
import 'package:tripline/ui/tp_glass_surface.dart';
import 'package:tripline/ui/tp_horizontal_selector.dart';

void main() {
  testWidgets('真行程地圖把媒體可讀性傳入日期與帳號', (tester) async {
    await _loadFonts(tester);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final boundary = GlobalKey();
    final base = AppTheme.dark();
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
                tripId: 'legibility',
                name: 'Okinawa',
                title: 'Okinawa trip',
              ),
            ]),
          ),
        ],
        child: _routedApp(
          theme: base.copyWith(
            textTheme: base.textTheme.apply(
              fontFamily: 'MapControlsRegression',
            ),
          ),
          home: AppAccessibilityScope(
            reduceTransparency: false,
            child: TpAccountActionScope(
              onOpen: (context) => context.go('/account'),
              child: RepaintBoundary(
                key: boundary,
                child: TripMapScreen(
                  tripId: 'legibility',
                  initialDayNum: 1,
                  // 只替換原生圖磚邊界；scope、header 與日期由真畫面組裝。
                  mapBuilder: (_) => const ColoredBox(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final scene = (
      boundary: boundary,
      date: tester.getRect(find.text('Day 2')),
      account: tester.getRect(find.byIcon(CupertinoIcons.person_crop_circle)),
    );
    final raster = await _capture(tester, scene, 'trip-map-dark-white');
    expect(raster.contrast(scene.date), greaterThanOrEqualTo(4.5));
    expect(raster.contrast(scene.account), greaterThanOrEqualTo(3));
    await tester.tap(find.text('Day 2'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.text('Day 2')).style!.color,
      base.colorScheme.primary,
    );
    await tester.tap(find.byType(TpAccountAvatarButton));
    await tester.pumpAndSettle();
    expect(find.text('帳號目的地'), findsOneWidget);
  });
  testWidgets('深色模式亮色地圖上的未選日期達到文字對比 4.5', (tester) async {
    final scene = await _pumpControls(tester);
    final raster = await _capture(tester, scene, 'dark-white');
    expect(raster.contrast(scene.date), greaterThanOrEqualTo(4.5));
  });
  testWidgets('深色模式亮色地圖上的帳號符號達到圖示對比 3', (tester) async {
    final scene = await _pumpControls(tester);
    final raster = await _capture(tester, scene, 'dark-white');
    expect(raster.contrast(scene.account), greaterThanOrEqualTo(3));
  });
  testWidgets('200% 字級在明暗模式與亮暗媒體背景仍可讀且日期不裁切', (tester) async {
    for (final brightness in Brightness.values) {
      for (final background in [Colors.white, Colors.black]) {
        final scene = await _pumpControls(
          tester,
          brightness: brightness,
          background: background,
          textScaler: const TextScaler.linear(2),
        );
        final raster = await _capture(
          tester,
          scene,
          '${brightness.name}-text200-${background == Colors.white ? 'white' : 'black'}',
        );
        expect(raster.contrast(scene.date), greaterThanOrEqualTo(4.5));
        expect(raster.contrast(scene.account), greaterThanOrEqualTo(3));
        final control = tester.getRect(find.byType(TpHorizontalSelector<int>));
        expect(control.intersect(scene.date), scene.date);
        expect(
          tester
              .renderObject<RenderParagraph>(find.text('Day 2'))
              .didExceedMaxLines,
          isFalse,
        );
        expect(tester.takeException(), isNull);
      }
    }
  });
  for (final brightness in Brightness.values) {
    testWidgets('$brightness 媒體亮暗背景的日期與帳號均可讀且保留 tint 選取', (tester) async {
      final theme = brightness == Brightness.dark
          ? AppTheme.dark()
          : AppTheme.light();
      for (final background in [Colors.white, Colors.black]) {
        final scene = await _pumpControls(
          tester,
          brightness: brightness,
          background: background,
          referenceColor: theme.colorScheme.surfaceContainerLow.withValues(
            alpha: .7,
          ),
        );
        final raster = await _capture(
          tester,
          scene,
          '${brightness.name}-${background == Colors.white ? 'white' : 'black'}',
        );
        expect(raster.contrast(scene.date), greaterThanOrEqualTo(4.5));
        expect(raster.contrast(scene.account), greaterThanOrEqualTo(3));
        final selectedRect = tester.getRect(find.text('Day 1'));
        final scheme = Theme.of(tester.element(find.text('Day 1'))).colorScheme;
        // 與同一 raster 的 70% 色票比較，避免浮點公式和預乘像素的量化差異。
        final expectedBacking = raster.pixel(24, 24);
        for (final rect in [scene.date, scene.account]) {
          final actualBacking = raster.backing(rect);
          for (final channel in [
            (actualBacking.r, expectedBacking.r),
            (actualBacking.g, expectedBacking.g),
            (actualBacking.b, expectedBacking.b),
          ]) {
            expect(channel.$1, closeTo(channel.$2, 1 / 255));
          }
        }
        expect(
          tester.widget<Text>(find.text('Day 1')).style!.color,
          scheme.primary,
        );
        expect(raster.backing(selectedRect), scheme.surfaceContainerHigh);
      }
    });
    for (final reduceTransparency in [false, true]) {
      testWidgets(
        '$brightness ${reduceTransparency ? '降低透明度' : '提高對比'} 獨立隔離亮暗背景並保留操作',
        (tester) async {
          final samples = <(Color, Color)>[];
          for (final background in [Colors.white, Colors.black]) {
            final selections = <int>[];
            final scene = await _pumpControls(
              tester,
              brightness: brightness,
              background: background,
              reduceTransparency: reduceTransparency,
              highContrast: !reduceTransparency,
              onSelected: selections.add,
            );
            final raster = await _capture(
              tester,
              scene,
              '${brightness.name}-${reduceTransparency ? 'reduced' : 'contrast'}-${background == Colors.white ? 'white' : 'black'}',
            );
            samples.add((
              raster.backing(scene.date),
              raster.backing(scene.account),
            ));
            expect(raster.contrast(scene.date), greaterThanOrEqualTo(4.5));
            expect(raster.contrast(scene.account), greaterThanOrEqualTo(3));
            await tester.tap(find.text('Day 2'));
            await tester.pump(const Duration(milliseconds: 500));
            await tester.pumpAndSettle();
            expect(selections, [2]);
          }
          expect(samples.first, samples.last, reason: '任一無障礙降級都不再透出底下圖磚');
        },
      );
    }
    testWidgets('$brightness 非媒體保留原日期與帳號前景', (tester) async {
      await _pumpControls(tester, brightness: brightness, onMedia: false);
      final context = tester.element(find.text('Day 2'));
      final scheme = Theme.of(context).colorScheme;
      expect(
        tester.widget<Text>(find.text('Day 2')).style!.color,
        scheme.onSurfaceVariant,
      );
      final icon = find.byIcon(CupertinoIcons.person_crop_circle);
      expect(tester.widget<Icon>(icon).color, isNull);
      expect(IconTheme.of(tester.element(icon)).color, scheme.onSurface);
    });
  }
  testWidgets('媒體控制維持 44pt、日期水平瀏覽與帳號導航', (tester) async {
    final selections = <int>[];
    await _pumpControls(
      tester,
      onSelected: selections.add,
      onAccount: (context) => context.go('/account'),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('day-2'))).height,
      greaterThanOrEqualTo(44),
    );
    expect(
      tester.getSize(find.byType(TpAccountAvatarButton)),
      const Size(44, 44),
    );
    final start = tester.getTopLeft(find.text('Day 2'));
    await tester.drag(
      find.byType(TpHorizontalSelector<int>),
      const Offset(-240, 0),
    );
    await tester.pumpAndSettle();
    expect(selections, isEmpty, reason: '水平滑動只瀏覽');
    expect(tester.getTopLeft(find.text('Day 2')).dx, lessThan(start.dx));
    await tester.tap(find.text('Day 5'));
    await tester.pumpAndSettle();
    expect(selections, [5]);
    await tester.tap(find.byType(TpAccountAvatarButton));
    await tester.pumpAndSettle();
    expect(find.text('帳號目的地'), findsOneWidget);
  });
}

Widget _routedApp({required ThemeData theme, required Widget home}) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => home),
      GoRoute(
        path: '/account',
        builder: (context, state) => const Scaffold(body: Text('帳號目的地')),
      ),
    ],
  );
  addTearDown(router.dispose);
  return MaterialApp.router(theme: theme, routerConfig: router);
}

Future<({GlobalKey boundary, Rect date, Rect account})> _pumpControls(
  WidgetTester tester, {
  Brightness brightness = Brightness.dark,
  Color background = Colors.white,
  Color? referenceColor,
  bool onMedia = true,
  bool highContrast = false,
  bool reduceTransparency = false,
  TextScaler textScaler = TextScaler.noScaling,
  ValueChanged<int>? onSelected,
  ValueChanged<BuildContext>? onAccount,
}) async {
  await _loadFonts(tester);
  await tester.binding.setSurfaceSize(const Size(390, 250));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final boundary = GlobalKey();
  final base = brightness == Brightness.dark
      ? AppTheme.dark()
      : AppTheme.light();
  await tester.pumpWidget(
    _routedApp(
      theme: base.copyWith(
        textTheme: base.textTheme.apply(fontFamily: 'MapControlsRegression'),
      ),
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(390, 250),
          highContrast: highContrast,
          textScaler: textScaler,
        ),
        child: AppAccessibilityScope(
          reduceTransparency: reduceTransparency,
          child: TpMediaBackdropScope(
            onMedia: onMedia,
            child: TpAccountActionScope(
              onOpen: onAccount ?? (_) {},
              child: RepaintBoundary(
                key: boundary,
                child: ColoredBox(
                  color: background,
                  child: Stack(
                    children: [
                      if (referenceColor != null)
                        Positioned(
                          left: 12,
                          top: 12,
                          width: 24,
                          height: 24,
                          child: ColoredBox(color: referenceColor),
                        ),
                      Positioned(
                        left: 12,
                        top: 80,
                        right: 12,
                        child: TpHorizontalSelector<int>(
                          value: 1,
                          options: [
                            for (var day = 0; day < 12; day++)
                              TpScopeOption(
                                value: day,
                                label: day == 0 ? 'All' : 'Day $day',
                                key: ValueKey('day-$day'),
                              ),
                          ],
                          onSelected: onSelected ?? (_) {},
                        ),
                      ),
                      Positioned(
                        right: 12,
                        top: 12,
                        child: TpBarForeground(
                          onMedia: onMedia,
                          child: const TpAccountAvatarButton(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (
    boundary: boundary,
    date: tester.getRect(find.text('Day 2')),
    account: tester.getRect(find.byIcon(CupertinoIcons.person_crop_circle)),
  );
}

Future<_Raster> _capture(
  WidgetTester tester,
  ({GlobalKey boundary, Rect date, Rect account}) scene,
  String name,
) async {
  final boundary =
      scene.boundary.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final result = _Raster(bytes, image.width);
    const directory = String.fromEnvironment('MAP_CONTROL_ARTIFACTS');
    if (directory.isNotEmpty) {
      debugPrint(
        '$name: 日期 ${result.contrast(scene.date).toStringAsFixed(3)}；帳號 ${result.contrast(scene.account).toStringAsFixed(3)}',
      );
      await Directory(directory).create(recursive: true);
      final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await File('$directory/$name.png').writeAsBytes(png.buffer.asUint8List());
    }
    image.dispose();
    return result;
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
    // 至少十個筆畫內部像素，避免單一亮點或抗鋸齒邊緣冒充可讀前景。
    ratios.sort((a, b) => b.compareTo(a));
    return ratios.take(10).reduce((a, b) => a + b) / 10;
  }
}

Future<void> _loadFonts(WidgetTester tester) async {
  await tester.runAsync(() async {
    // Ahem 無法代表文字與符號可讀性；字型取自 SDK 和既有依賴，無主機絕對路徑。
    final loader = FontLoader('MapControlsRegression');
    for (final weight in ['regular', 'bold']) {
      final font = File.fromUri(
        Uri.file(
          Platform.resolvedExecutable,
        ).resolve('../../material_fonts/roboto-$weight.ttf'),
      );
      loader.addFont(
        Future.value(ByteData.sublistView(font.readAsBytesSync())),
      );
    }
    await loader.load();
    await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
          rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
        ))
        .load();
  });
}
