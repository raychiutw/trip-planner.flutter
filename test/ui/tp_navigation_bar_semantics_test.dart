import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/app/accessibility_scope.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_app_bar.dart';
import 'package:tripline/ui/tp_glass_surface.dart';
import 'package:tripline/ui/tp_root_scaffold.dart';

void main() {
  testWidgets('浮動 header 的一般標題與返回在媒體上使用完整白色前景', (tester) async {
    await tester.pumpWidget(_header());
    expect(_textColor(tester, find.text('行程')), Colors.white);
    expect(_iconColor(tester, CupertinoIcons.back), Colors.white);
  });

  testWidgets('媒體標題與動作群組保留暗化且無障礙各自完全遮住背景', (tester) async {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      for (final mode in ['一般', '提高對比', '降低透明度']) {
        final samples = <List<Color>>[];
        for (final background in [Colors.white, Colors.black]) {
          final boundary = GlobalKey();
          await tester.pumpWidget(
            _header(
              theme: theme,
              highContrast: mode == '提高對比',
              reduceTransparency: mode == '降低透明度',
              background: background,
              boundary: boundary,
              standaloneHeader: true,
              actions: [_actions()],
            ),
          );
          await tester.pumpAndSettle();
          final foreground = mode == '一般'
              ? Colors.white
              : theme.colorScheme.onSurface;
          expect(_textColor(tester, find.text('行程')), foreground);
          expect(_iconColor(tester, CupertinoIcons.share), foreground);
          expect(_iconColor(tester, CupertinoIcons.printer), foreground);
          samples.add(await _backgroundPixels(tester, boundary));
        }
        for (var index = 0; index < 2; index++) {
          if (mode == '一般') {
            expect(
              samples.first[index].r - samples.last[index].r,
              closeTo(.65, .02),
              reason: '${theme.brightness.name} 的標題及群組保留既有 35% 媒體暗化',
            );
          } else {
            expect(samples.first[index], samples.last[index], reason: mode);
          }
        }
      }
    }
  });

  testWidgets('浮動與固定 bar 在兩種寬度保留前景、44pt、鍵盤及讀屏操作', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final size in [const Size(390, 844), const Size(1024, 768)]) {
        await tester.binding.setSurfaceSize(size);
        for (final fixed in [false, true]) {
          final calls = <String>[];
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  padding: const EdgeInsets.only(top: 44),
                  textScaler: const TextScaler.linear(2),
                ),
                child: child!,
              ),
              home: TpMediaBackdropScope(
                onMedia: !fixed,
                child: TpAccountActionScope(
                  onOpen: (_) => calls.add('帳號'),
                  child: fixed
                      ? Scaffold(
                          appBar: TpAppBar(
                            title: const Text('行程'),
                            role: TpAppBarRole.detail,
                            onBack: () => calls.add('返回'),
                            actions: [_actions(onAction: calls.add)],
                            accountEntry: const TpAccountAvatarButton(),
                          ),
                        )
                      : TpRootScaffold(
                          header: TpRootHeaderConfig(
                            title: const Text('行程'),
                            leading: TpToolbarIconButton(
                              plain: true,
                              tooltip: '返回',
                              icon: CupertinoIcons.back,
                              onPressed: () => calls.add('返回'),
                            ),
                            actions: [_actions(onAction: calls.add)],
                          ),
                          body: const SizedBox.expand(),
                        ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final foreground = fixed
              ? AppTheme.light().colorScheme.onSurface
              : Colors.white;
          expect(_textColor(tester, find.text('行程')), foreground);
          expect(_iconColor(tester, CupertinoIcons.share), foreground);
          expect(
            _iconColor(tester, CupertinoIcons.person_crop_circle),
            foreground,
          );
          expect(tester.getRect(find.text('行程')).top, greaterThanOrEqualTo(44));
          for (final label in ['返回', '分享', '列印', '帳號']) {
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await tester.sendKeyEvent(LogicalKeyboardKey.enter);
            await tester.pumpAndSettle();
            expect(calls.last, label);
          }
          expect(calls, ['返回', '分享', '列印', '帳號']);
          for (final label in ['分享', '列印', '帳號']) {
            final finder = find.bySemanticsLabel(label);
            final node = tester.getSemantics(finder);
            expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
            expect(node.rect.width, greaterThanOrEqualTo(44));
            expect(node.rect.height, greaterThanOrEqualTo(44));
            node.owner!.performAction(node.id, ui.SemanticsAction.tap);
            await tester.pumpAndSettle();
          }
          expect(calls, ['返回', '分享', '列印', '帳號', '分享', '列印', '帳號']);
          expect(tester.takeException(), isNull);
        }
      }
    } finally {
      semantics.dispose();
    }
  });
}

TpToolbarActionGroup _actions({ValueChanged<String>? onAction}) =>
    TpToolbarActionGroup(
      children: [
        TpToolbarGlassButton(
          tooltip: '分享',
          onPressed: () => onAction?.call('分享'),
          child: const Icon(CupertinoIcons.share),
        ),
        TpToolbarGlassButton(
          tooltip: '列印',
          onPressed: () => onAction?.call('列印'),
          child: const Icon(CupertinoIcons.printer),
        ),
      ],
    );

Widget _header({
  bool onMedia = true,
  bool highContrast = false,
  bool reduceTransparency = false,
  ThemeData? theme,
  Color background = Colors.white,
  GlobalKey? boundary,
  bool standaloneHeader = false,
  List<Widget> actions = const [],
}) => MaterialApp(
  theme: theme ?? AppTheme.light(),
  home: AppAccessibilityScope(
    reduceTransparency: reduceTransparency,
    child: MediaQuery(
      data: MediaQueryData(highContrast: highContrast),
      child: TpMediaBackdropScope(
        onMedia: onMedia,
        child: RepaintBoundary(
          key: boundary,
          child: Builder(
            builder: (context) {
              final header = TpRootHeaderConfig(
                title: const Text('行程'),
                actions: actions,
                leading: TpToolbarIconButton(
                  plain: true,
                  tooltip: '返回',
                  icon: CupertinoIcons.back,
                  onPressed: () {},
                ),
              );
              return standaloneHeader
                  ? Scaffold(
                      body: ColoredBox(
                        color: background,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: TpRootGlassHeader(config: header),
                          ),
                        ),
                      ),
                    )
                  : TpRootScaffold(
                      header: header,
                      body: ColoredBox(color: background),
                    );
            },
          ),
        ),
      ),
    ),
  ),
);

Future<List<Color>> _backgroundPixels(
  WidgetTester tester,
  GlobalKey key,
) async {
  final rects = [
    tester.getRect(find.byKey(const ValueKey('tp-glass-surface'))),
    tester.getRect(find.byType(TpToolbarActionGroup)),
  ];
  return (await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary)
            .toImage();
    final ByteData bytes = (await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!;
    final colors = rects.map((rect) {
      final offset =
          ((rect.top + 5).floor() * image.width + rect.center.dx.floor()) * 4;
      return Color.fromARGB(
        255,
        bytes.getUint8(offset),
        bytes.getUint8(offset + 1),
        bytes.getUint8(offset + 2),
      );
    }).toList();
    image.dispose();
    return colors;
  }))!;
}

Color? _textColor(WidgetTester tester, Finder finder) =>
    tester.renderObject<RenderParagraph>(finder).text.style?.color;

Color? _iconColor(WidgetTester tester, IconData icon) => _textColor(
  tester,
  find.descendant(of: find.byIcon(icon), matching: find.byType(RichText)),
);
