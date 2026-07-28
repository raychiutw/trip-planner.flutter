import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:tripline/features/shell/app_shell.dart';
import 'package:tripline/theme/app_theme.dart';

// #170:root tab 的字符、標籤與選取膠囊必須落在同一個水平基準上。
//
// 斷言全部針對**實際畫出來的幾何**(`tester.getRect` 量到的 render box、膠囊
// 實際被畫出來的 `ShapeDecoration` 方框),不看 `GlassTabBar` 的參數物件 ——
// 參數對、畫面錯是本專案踩過四次的坑。
//
// 「欄位中心」與「膠囊中心」在套件裡是兩個相差 4pt 的基準(見
// `apple_root_tab_bar.dart` 的 `_tabPadding`),所以這裡刻意兩邊都驗:只驗欄位
// 中心的話,把 `tabPadding` 設成 0 也會綠,但膠囊會偏 3pt。

const _labels = ['聊天', '行程', '地圖', '收藏'];

/// 票上訂的容差:中心點誤差不得超過 2pt。
const _tolerance = 2.0;

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
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: _shellRouter(),
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

/// 玻璃列本體(不含外層留白)—— 使用者眼裡的「這條 bar」。
Rect _barRect(WidgetTester tester) => tester.getRect(
  find.descendant(of: _tabBar, matching: find.byType(GlassTabBar)),
);

/// 第 [index] 個 tab 的欄位中心:玻璃列本體平均分成 tab 數等份。
double _columnCentre(WidgetTester tester, int index) {
  final bar = _barRect(tester);
  return bar.left + bar.width * (index + 0.5) / _labels.length;
}

/// 未選取層的字符方框。四個 tab 恆存在。
Rect _iconRect(WidgetTester tester, int index) =>
    tester.getRect(find.byKey(ValueKey('root-tab-${_labels[index]}')));

/// 與該字符同一個 `Column` 底下的標籤方框。
Rect _labelRect(WidgetTester tester, int index) {
  final icon = find.byKey(ValueKey('root-tab-${_labels[index]}'));
  final column = find.ancestor(of: icon, matching: find.byType(Column)).first;
  return tester.getRect(
    find.descendant(of: column, matching: find.text(_labels[index])),
  );
}

/// 選取層(activeIcon)的字符方框。只有選取態附近的 tab 會被畫出來。
Rect _activeIconRect(WidgetTester tester, int index) =>
    tester.getRect(find.byKey(ValueKey('root-tab-active-${_labels[index]}')));

/// 第 [index] 個 tab 的靜止態選取膠囊 —— 直接量它畫出來的方框,不看參數。
Rect _pillRect(WidgetTester tester, int index) =>
    tester.getRect(find.byKey(ValueKey('root-tab-pill-${_labels[index]}')));

/// 玻璃列裡每一個膠囊形 `ShapeDecoration` 實際畫出來的方框與填色。
///
/// 0.23.0 把靜止態 indicator 的形狀從 `LiquidRoundedSuperellipse` 換成
/// `LiquidRoundedRectangle`(#178 升級時發現)。兩種都收 —— 這裡量的是膠囊的
/// 實際方框,不是它用哪個 shape 類別。
List<(Rect, Color)> _paintedPills(WidgetTester tester) {
  final finder = find.descendant(
    of: _tabBar,
    matching: find.byWidgetPredicate((widget) {
      if (widget is! DecoratedBox) return false;
      final decoration = widget.decoration;
      return decoration is ShapeDecoration &&
          decoration.color != null &&
          (decoration.shape is LiquidRoundedSuperellipse ||
              decoration.shape is LiquidRoundedRectangle);
    }),
  );
  return [
    for (final element in finder.evaluate())
      (
        tester.getRect(find.byWidget(element.widget)),
        ((element.widget as DecoratedBox).decoration as ShapeDecoration).color!,
      ),
  ];
}

void _expectAligned(
  WidgetTester tester, {
  required int selectedIndex,
  required String reason,
}) {
  for (var index = 0; index < _labels.length; index++) {
    final icon = _iconRect(tester, index).center.dx;
    final label = _labelRect(tester, index).center.dx;
    final column = _columnCentre(tester, index);
    expect(
      icon,
      closeTo(label, _tolerance),
      reason: '$reason:${_labels[index]} 的字符與標籤不同心',
    );
    expect(
      icon,
      closeTo(column, _tolerance),
      reason: '$reason:${_labels[index]} 的字符偏離自己的欄位中心',
    );
    expect(
      label,
      closeTo(column, _tolerance),
      reason: '$reason:${_labels[index]} 的標籤偏離自己的欄位中心',
    );
  }
  // 選取層畫的是另一份 widget,必須落在同一個基準上。
  final active = _activeIconRect(tester, selectedIndex).center.dx;
  expect(
    active,
    closeTo(_columnCentre(tester, selectedIndex), _tolerance),
    reason: '$reason:選取態字符偏離自己的欄位中心',
  );
}

void main() {
  group('#170 root tab 字符與標籤對齊同一個基準', () {
    testWidgets('未選取與選取的四個 tab 都對齊自己的欄位中心', (tester) async {
      await _pumpShell(tester);
      _expectAligned(tester, selectedIndex: 0, reason: '初始選取第 0 個');

      for (var index = 1; index < _labels.length; index++) {
        await tester.tapAt(_iconRect(tester, index).center);
        await tester.pumpAndSettle();
        _expectAligned(tester, selectedIndex: index, reason: '選取第 $index 個');
      }
    });

    testWidgets('放大字級後仍然對齊', (tester) async {
      await _pumpShell(tester, textScale: 2);
      _expectAligned(tester, selectedIndex: 0, reason: '字級 2.0');
    });

    testWidgets('inline(regular 寬度)版面也對齊', (tester) async {
      await _pumpShell(tester, size: const Size(900, 1200));
      _expectAligned(tester, selectedIndex: 0, reason: 'inline');
    });

    testWidgets('選取膠囊與字符同心,且不寬於自己的欄位', (tester) async {
      await _pumpShell(tester);
      final bar = _barRect(tester);
      final columnWidth = bar.width / _labels.length;
      final pill = _pillRect(tester, 0);

      expect(
        pill.center.dx,
        closeTo(_iconRect(tester, 0).center.dx, _tolerance),
        reason: '膠囊與它框住的字符必須同心',
      );
      // #160:膠囊不得寬於自己的欄位,否則會壓到左右鄰居。
      expect(pill.width, lessThanOrEqualTo(columnWidth));
      expect(pill.width, greaterThan(columnWidth * 0.6));
    });

    // #179:PR #164 宣稱把膠囊收到約欄寬 70%,實際上只有拖曳中生效 —— 套件的
    // `AnimatedGlassIndicator` 靜止時走 `RelativeRect.fill`,實測 390pt 螢幕下
    // 膠囊 87.5pt / 欄寬 89.5pt = 98%。以下三條全部量**畫出來的方框**。
    testWidgets('靜止態膠囊約佔欄寬 70%', (tester) async {
      await _pumpShell(tester);
      final columnWidth = _barRect(tester).width / _labels.length;

      for (var index = 0; index < _labels.length; index++) {
        if (index > 0) {
          await tester.tapAt(_iconRect(tester, index).center);
          await tester.pumpAndSettle();
        }
        final pill = _pillRect(tester, index);
        expect(
          pill.width / columnWidth,
          closeTo(0.70, 0.03),
          reason: '第 $index 個 tab:膠囊實際寬度 ${pill.width} / 欄寬 $columnWidth',
        );
      }
    });

    testWidgets('靜止態膠囊與玻璃列上下同心', (tester) async {
      for (final scale in [1.0, 2.0]) {
        await _pumpShell(tester, textScale: scale);
        final bar = _barRect(tester);
        final pill = _pillRect(tester, 0);
        // 膠囊畫在字符底下,而字符只是「字符 + 標籤」那一疊的上半;算錯垂直
        // 位移,膠囊就會整顆偏上。
        expect(
          pill.center.dy,
          closeTo(bar.center.dy, _tolerance),
          reason: '字級 $scale:膠囊沒有與玻璃列同心',
        );
        expect(pill.height, lessThan(bar.height), reason: '字級 $scale:膠囊高過玻璃列');
      }
    });

    testWidgets('沒有第二顆整格寬的膠囊被畫出來', (tester) async {
      await _pumpShell(tester);
      final columnWidth = _barRect(tester).width / _labels.length;

      for (final (rect, color) in _paintedPills(tester)) {
        if (color.a == 0) continue;
        // 套件自己那顆靜止態指示器必須是透明的,否則整格寬的底又回來了。
        expect(
          rect.width,
          lessThan(columnWidth * 0.9),
          reason: '有一顆 alpha ${color.a} 的膠囊寬 ${rect.width},欄寬 $columnWidth',
        );
      }
    });
  });

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
