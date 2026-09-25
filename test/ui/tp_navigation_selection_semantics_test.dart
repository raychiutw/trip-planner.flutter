import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/app/accessibility_scope.dart';
import 'package:tripline/features/shell/apple_root_tab_bar.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_glass_surface.dart';

void main() {
  testWidgets('上下 root tab 保留媒體暗化與前景，無障礙各自隔離亮暗背景', (tester) async {
    for (final inline in [false, true]) {
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        for (final mode in ['一般', '提高對比', '降低透明度']) {
          final samples = <Color>[];
          for (final background in [Colors.white, Colors.black]) {
            final boundary = GlobalKey();
            await tester.pumpWidget(
              MaterialApp(
                theme: theme,
                home: MediaQuery(
                  data: MediaQueryData(highContrast: mode == '提高對比'),
                  child: AppAccessibilityScope(
                    reduceTransparency: mode == '降低透明度',
                    child: TpMediaBackdropScope(
                      onMedia: true,
                      child: RepaintBoundary(
                        key: boundary,
                        child: ColoredBox(
                          color: background,
                          child: Center(
                            child: SizedBox(
                              width: 390,
                              child: AppleRootTabBar(
                                inline: inline,
                                selectedIndex: 0,
                                onSelected: (_) {},
                              ),
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
            final paragraph = tester.renderObject<RenderParagraph>(
              find.text('行程').first,
            );
            expect(
              paragraph.text.style?.color,
              mode == '一般' ? Colors.white : theme.colorScheme.onSurface,
              reason: '未選取標籤的最終前景須與媒體或不透明底成套切換',
            );
            samples.add(await _tabBackground(tester, boundary, '行程'));
          }
          if (mode == '一般') {
            expect(
              samples.first.r - samples.last.r,
              closeTo(.65, .02),
              reason: 'root tab 保留既有 35% 媒體暗化',
            );
          } else {
            expect(samples.first, samples.last, reason: mode);
          }
          expect(tester.takeException(), isNull);
        }
      }
    }
  });
}

Future<Color> _tabBackground(
  WidgetTester tester,
  GlobalKey key,
  String label,
) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final rect = tester.getRect(find.bySemanticsLabel(label));
  final point = boundary.globalToLocal(Offset(rect.center.dx, rect.top + 7));
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final offset = (point.dy.floor() * image.width + point.dx.floor()) * 4;
    final color = Color.fromARGB(
      255,
      bytes.getUint8(offset),
      bytes.getUint8(offset + 1),
      bytes.getUint8(offset + 2),
    );
    image.dispose();
    return color;
  }))!;
}
