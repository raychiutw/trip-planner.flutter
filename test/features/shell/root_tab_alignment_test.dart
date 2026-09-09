import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tripline/features/shell/app_shell.dart';
import 'package:tripline/theme/app_theme.dart';

// #305：以公開語意、實際文字與觸控結果驗證；不限制套件選取膠囊比例。

const _labels = ['聊天', '行程', '地圖', '收藏'];

GoRouter _shellRouter() {
  StatefulShellBranch probe(String path, String marker) => StatefulShellBranch(
    routes: [GoRoute(path: path, builder: (_, _) => Text(marker))],
  );
  return GoRouter(
    initialLocation: '/chat',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          probe('/chat', 'PROBE-CHAT'),
          probe('/trips', 'PROBE-TRIPS'),
          probe('/map', 'PROBE-MAP'),
          probe('/favorites', 'PROBE-FAV'),
        ],
      ),
    ],
  );
}

Future<void> _pumpShell(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = _shellRouter();
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final _tabBar = find.byKey(const ValueKey('apple-root-tab-bar'));

void main() {
  testWidgets('選取標籤實際使用品牌tint前景', (tester) async {
    await _pumpShell(tester);
    final colors = tester
        .widgetList<Text>(
          find.descendant(of: _tabBar, matching: find.text('聊天')),
        )
        .map((text) => text.style?.color)
        .toSet();
    expect(colors, contains(AppTheme.light().colorScheme.primary));
  });

  testWidgets('320pt 與300%文字保留標籤實際字級及44pt觸控區', (tester) async {
    await _pumpShell(tester, size: const Size(320, 568), textScale: 3);
    for (final label in _labels) {
      final tab = find.bySemanticsLabel(label);
      final target = tester.getRect(tab);
      expect(target.width, greaterThanOrEqualTo(44));
      expect(target.height, greaterThanOrEqualTo(44));
      final text = find
          .descendant(of: _tabBar, matching: find.text(label))
          .first;
      final paragraph = tester.renderObject<RenderParagraph>(text);
      final origin = paragraph.localToGlobal(Offset.zero);
      final right = paragraph.localToGlobal(Offset(paragraph.size.width, 0));
      expect(
        (right - origin).distance,
        closeTo(paragraph.size.width, 0.1),
        reason: '$label 不得在套用Dynamic Type後又縮字',
      );
      expect(paragraph.didExceedMaxLines, isFalse);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('regular root tab 可拖曳選取並顯示目的頁面', (tester) async {
    await _pumpShell(tester, size: const Size(900, 1200));
    final start = tester.getCenter(find.bySemanticsLabel('聊天'));
    final end = tester.getCenter(find.bySemanticsLabel('行程'));
    await tester.dragFrom(start, end - start);
    await tester.pumpAndSettle();
    expect(find.text('PROBE-TRIPS'), findsOneWidget);
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(900, 1200),
  ]) {
    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets('四個tab在$size、文字$scale完整可讀且可操作', (tester) async {
        final semantics = tester.ensureSemantics();
        await _pumpShell(tester, size: size, textScale: scale);
        for (var selected = 0; selected < _labels.length; selected++) {
          final label = _labels[selected];
          final target = find.bySemanticsLabel(label);
          await tester.tapAt(tester.getCenter(target));
          await tester.pumpAndSettle();
          expect(
            find.text(
              ['PROBE-CHAT', 'PROBE-TRIPS', 'PROBE-MAP', 'PROBE-FAV'][selected],
            ),
            findsOneWidget,
          );
          expect(
            tester
                .getSemantics(target)
                .getSemanticsData()
                .flagsCollection
                .isSelected,
            Tristate.isTrue,
          );
          double previousRight = 0;
          for (final name in _labels) {
            final rect = tester.getRect(find.bySemanticsLabel(name));
            expect(rect.width, greaterThanOrEqualTo(44));
            expect(rect.height, greaterThanOrEqualTo(44));
            expect(rect.left, greaterThanOrEqualTo(previousRight));
            previousRight = rect.right;
            final text = find
                .descendant(of: _tabBar, matching: find.text(name))
                .first;
            final paragraph = tester.renderObject<RenderParagraph>(text);
            final topLeft = paragraph.localToGlobal(Offset.zero);
            final bottomRight = paragraph.localToGlobal(
              paragraph.size.bottomRight(Offset.zero),
            );
            expect(rect.contains(topLeft), isTrue, reason: '$name 標籤左上角在可操作區內');
            expect(
              rect.contains(bottomRight),
              isTrue,
              reason: '$name 標籤右下角在可操作區內',
            );
            expect(paragraph.didExceedMaxLines, isFalse);
          }
        }
        expect(tester.takeException(), isNull);
        semantics.dispose();
      });
    }
  }

  testWidgets('root tab 的字符全部來自同一個字型家族', (tester) async {
    // `SFIcons` 的 glyph 墨跡沒有置中在字框裡：在 60pt 下模擬器實測
    // `sf_suitcase_fill` 偏右 **+9.7pt**、`sf_suitcase` 偏右 +8.8pt，而三個
    // `CupertinoIcons`（chat_bubble_fill／map_fill／heart_fill）都在 ±0.3pt
    // 內。換算到 tab bar 的 24pt 字符約偏 4.8pt，與 chrome 截圖量到的 5pt 吻合。
    //
    // 這不是版面問題（#170 修的是欄位對齊），是字型本身。混用兩個字型家族
    // 就會有一個字符對不齊，所以整排統一。
    await _pumpShell(tester);

    final icons = tester
        .widgetList<Icon>(
          find.descendant(of: _tabBar, matching: find.byType(Icon)),
        )
        .map((icon) => icon.icon)
        .whereType<IconData>()
        .toList();

    expect(icons, isNotEmpty);
    for (final icon in icons) {
      expect(
        icon.fontFamily,
        'CupertinoIcons',
        reason: 'root tab 混用字型家族會讓其中一個字符對不齊：$icon',
      );
    }
  });
}
