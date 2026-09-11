import 'dart:io';
import 'dart:async';
import 'dart:ui' show Tristate, SemanticsAction;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:tripline/app/accessibility_scope.dart';
import 'package:tripline/app/adaptive.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/theme/tokens.dart';
import 'package:tripline/ui/tp_action_item.dart';
import 'package:tripline/ui/tp_app_bar.dart';
import 'package:tripline/ui/tp_glass_surface.dart';

Widget _menuHost({
  required List<TpActionItem<String>> items,
  required ValueChanged<String> onSelected,
  List<TpActionItem<String>> quickActions = const [],
  double textScale = 1,
  bool reduceMotion = false,
  bool boldText = false,
  ThemeData? theme,
  Alignment alignment = Alignment.topRight,
}) => MaterialApp(
  theme: theme ?? AppTheme.light(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(textScale),
      disableAnimations: reduceMotion,
      boldText: boldText,
    ),
    child: child!,
  ),
  home: Scaffold(
    body: Align(
      alignment: alignment,
      child: TpMoreMenuButton<String>(
        key: const ValueKey('host-more-menu'),
        items: items,
        quickActions: quickActions,
        onSelected: onSelected,
      ),
    ),
  ),
);

/// 行程卡那組 medium 版型：上排三個快捷動作，下方匯出與分組刪除。
const _quickActions = [
  TpActionItem(
    key: ValueKey('quick-share'),
    value: 'share',
    label: '分享',
    icon: CupertinoIcons.share,
  ),
  TpActionItem(
    key: ValueKey('quick-collab'),
    value: 'collab',
    label: '共編',
    semanticLabel: '共編設定',
    icon: CupertinoIcons.person_2,
  ),
  TpActionItem(
    key: ValueKey('quick-health'),
    value: 'health',
    label: 'AI 健檢',
    icon: CupertinoIcons.sparkles,
  ),
];
const _quickMenuItems = [
  TpActionItem(
    value: 'export',
    label: '匯出 JSON',
    icon: CupertinoIcons.square_arrow_down,
  ),
  TpActionItem(
    value: 'delete',
    label: '刪除行程',
    icon: CupertinoIcons.delete,
    dividerBefore: true,
    role: TpActionRole.destructive,
  ),
];

void main() {
  testWidgets('large sheet 返回與關閉字符保留品牌 tint 且分別可操作', (tester) async {
    var backs = 0;
    var closes = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: TpLargeSheetNavigationScope(
          onClose: () => closes++,
          child: Scaffold(
            appBar: TpAppBar(
              title: const Text('行程詳情'),
              role: TpAppBarRole.detail,
              onBack: () => backs++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final symbol in [CupertinoIcons.back, CupertinoIcons.xmark]) {
      final glyph = tester.widget<RichText>(
        find.descendant(
          of: find.byIcon(symbol),
          matching: find.byType(RichText),
        ),
      );
      expect(
        glyph.text.style?.color,
        AppTheme.light().colorScheme.primary,
        reason: 'sheet 的返回與關閉實際字符使用同一品牌前景',
      );
    }
    await tester.tap(find.byKey(const ValueKey('tp-app-bar-back')));
    await tester.pumpAndSettle();
    expect(backs, 1);
    expect(closes, 0);
    await tester.tap(find.byKey(const ValueKey('app-large-sheet-close')));
    await tester.pumpAndSettle();
    expect(closes, 1);
  });
  testWidgets('群組內的 bar button 可用 Tab 與 Enter 個別啟用', (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: TpToolbarActionGroup(
              children: [
                TpToolbarGlassButton(
                  tooltip: '分享',
                  onPressed: () => calls.add('分享'),
                  child: const Icon(CupertinoIcons.share),
                ),
                TpToolbarGlassButton(
                  tooltip: '列印',
                  onPressed: () => calls.add('列印'),
                  child: const Icon(CupertinoIcons.printer),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(calls, ['分享']);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(calls, ['分享', '列印']);
    await tester.pumpAndSettle();
  });

  testWidgets('固定 bar 依群組自然寬度保留放大文字動作', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          appBar: TpAppBar(
            role: TpAppBarRole.detail,
            title: const Text('行程'),
            actions: [
              TpToolbarActionGroup(
                children: [
                  TpToolbarTextButton(label: '加入行程', onPressed: () => calls++),
                  TpToolbarTextButton(label: '預覽', onPressed: () => calls++),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    for (final label in ['加入行程', '預覽']) {
      final rect = tester.getRect(find.text(label));
      final bar = tester.getRect(find.byType(TpAppBar));
      expect(bar.contains(rect.topLeft), isTrue);
      expect(bar.contains(rect.bottomRight - const Offset(0.1, 0.1)), isTrue);
      expect(
        tester
            .renderObject<RenderParagraph>(find.text(label))
            .didExceedMaxLines,
        isFalse,
      );
      await tester.tap(find.text(label));
    }
    expect(calls, 2);
  });

  testWidgets('動作群組在放大文字時保留完整標籤與各自可點區域', (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: Center(
              child: TpToolbarActionGroup(
                children: [
                  TpToolbarTextButton(
                    label: '加入行程',
                    onPressed: () => calls.add('加入'),
                  ),
                  TpToolbarTextButton(
                    label: '預覽',
                    onPressed: () => calls.add('預覽'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final group = tester.getRect(find.byType(TpToolbarActionGroup));
    final labels = ['加入行程', '預覽'];
    for (final label in labels) {
      expect(
        tester
            .renderObject<RenderParagraph>(find.text(label))
            .didExceedMaxLines,
        isFalse,
        reason: '動作標籤不可因固定 icon 寬度而省略',
      );
      final text = tester.getRect(find.text(label));
      final button = tester.getRect(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(TpToolbarTextButton),
        ),
      );
      expect(button.contains(text.topLeft), isTrue);
      expect(
        button.contains(text.bottomRight - const Offset(0.1, 0.1)),
        isTrue,
      );
      expect(group.contains(button.center), isTrue);
      expect(button.height, greaterThanOrEqualTo(44));
      await tester.tap(find.text(label));
    }
    expect(calls, ['加入', '預覽']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('讀屏選取立即派發一次，不等待關閉動畫', (tester) async {
    final semantics = tester.ensureSemantics();
    var calls = 0;
    await tester.pumpWidget(
      _menuHost(
        items: const [TpActionItem(value: 'print', label: '列印')],
        onSelected: (_) => calls++,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('host-more-menu')));
    await tester.pumpAndSettle();
    final node = tester.getSemantics(find.bySemanticsLabel('列印').first);
    node.owner!.performAction(node.id, SemanticsAction.tap);
    expect(calls, 1);
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('列印'), findsNothing);
    semantics.dispose();
  });

  testWidgets('外部入口連續開啟同一選單仍立即派發且不重複', (tester) async {
    final controller = TpMoreMenuController();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TpMoreMenuButton<String>(
            controller: controller,
            items: const [TpActionItem(value: 'print', label: '列印')],
            onSelected: (_) => calls++,
          ),
        ),
      ),
    );
    for (var attempt = 1; attempt <= 2; attempt++) {
      controller.open();
      await tester.pumpAndSettle();
      await tester.tap(find.text('列印'));
      expect(calls, attempt);
      await tester.tap(find.text('列印'), warnIfMissed: false);
      expect(calls, attempt);
      await tester.pumpAndSettle();
      expect(find.text('列印'), findsNothing);
    }
  });

  testWidgets('巢狀路由立即切頁後沒有殘留選單或觸控遮罩', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    var calls = 0;
    var destinationTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Row(
          children: [
            const SizedBox(width: 80),
            Expanded(
              child: Navigator(
                key: navigator,
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (context) => Scaffold(
                    body: Align(
                      alignment: Alignment.topRight,
                      child: TpMoreMenuButton<String>(
                        items: const [
                          TpActionItem(value: 'next', label: '開啟明細'),
                        ],
                        onSelected: (_) {
                          calls++;
                          navigator.currentState!.push(
                            MaterialPageRoute<void>(
                              builder: (_) => Scaffold(
                                body: Center(
                                  child: TextButton(
                                    onPressed: () => destinationTaps++,
                                    child: const Text('明細操作'),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.byType(TpMoreMenuButton<String>));
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.text('開啟明細'));
    expect(rect.right, lessThanOrEqualTo(800));
    await tester.tap(find.text('開啟明細'));
    expect(calls, 1);
    await tester.pumpAndSettle();
    expect(find.text('開啟明細'), findsNothing);
    await tester.tap(find.text('明細操作'));
    expect(destinationTaps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('降低動態效果時按住選單項目不縮放文字', (tester) async {
    await tester.pumpWidget(
      _menuHost(
        items: const [TpActionItem(value: 'print', label: '列印')],
        reduceMotion: true,
        onSelected: (_) {},
      ),
    );
    await tester.tap(find.byKey(const ValueKey('host-more-menu')));
    await tester.pumpAndSettle();
    final before = tester.getRect(find.text('列印'));
    final gesture = await tester.startGesture(before.center);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final pressed = tester.getRect(find.text('列印'));
    expect(pressed.width, closeTo(before.width, 0.01));
    expect(pressed.height, closeTo(before.height, 0.01));
    await gesture.cancel();
    await tester.pumpAndSettle();
  });

  testWidgets('相同controller更新項目與入口狀態不留下舊動作', (tester) async {
    final semantics = tester.ensureSemantics();
    final controller = TpMoreMenuController();
    var calls = 0;
    var revised = false;
    var enabled = true;
    late StateSetter update;
    void select(String value) => calls++;
    const oldItems = [TpActionItem(value: 'a', label: '移動')];
    const updatedItems = [
      TpActionItem(
        value: 'a',
        label: '移動',
        enabled: false,
        selected: true,
        semanticLabel: '移動，目前沒有其他天',
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Scaffold(
              body: Align(
                alignment: Alignment.topRight,
                child: TpMoreMenuButton<String>(
                  key: const ValueKey('host-more-menu'),
                  items: revised ? updatedItems : [...oldItems],
                  onSelected: select,
                  controller: controller,
                  enabled: enabled,
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('host-more-menu')));
    await tester.pumpAndSettle();
    expect(find.text('移動'), findsOneWidget);
    update(() {});
    await tester.pumpAndSettle();
    expect(find.text('移動'), findsOneWidget);
    update(() => revised = true);
    await tester.pumpAndSettle();
    expect(find.text('移動'), findsNothing);
    controller.open();
    await tester.pumpAndSettle();
    final flags = tester
        .getSemantics(find.bySemanticsLabel('移動，目前沒有其他天').first)
        .getSemanticsData()
        .flagsCollection;
    expect(flags.isEnabled, Tristate.isFalse);
    expect(flags.isSelected, Tristate.isTrue);
    await tester.tap(find.text('移動'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    update(() => enabled = false);
    await tester.pumpAndSettle();
    expect(find.text('移動'), findsNothing);
    controller.open();
    await tester.pumpAndSettle();
    expect(find.text('移動'), findsNothing);
    expect(calls, 0);
    semantics.dispose();
  });

  testWidgets('開啟時系統顯示設定改變會關閉並以新設定重開', (tester) async {
    const items = [TpActionItem(value: 'a', label: '顯示設定選項')];
    await tester.pumpWidget(_menuHost(items: items, onSelected: (_) {}));
    await tester.tap(find.byKey(const ValueKey('host-more-menu')));
    await tester.pumpAndSettle();
    expect(find.text('顯示設定選項'), findsOneWidget);
    await tester.pumpWidget(
      _menuHost(items: items, onSelected: (_) {}, textScale: 2, boldText: true),
    );
    await tester.pumpAndSettle();
    expect(find.text('顯示設定選項'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('host-more-menu')));
    await tester.pumpAndSettle();
    final itemContext = tester.element(find.text('顯示設定選項'));
    expect(MediaQuery.boldTextOf(itemContext), isTrue);
    expect(MediaQuery.textScalerOf(itemContext).scale(10), 20);
    expect(tester.takeException(), isNull);
  });

  testWidgets('粗體長標籤依實際字重換行而不省略', (tester) async {
    // flutter test 的 Ahem 不區分字重；使用 SDK 隨附字型驗證真實字寬。
    await tester.runAsync(() async {
      final loader = FontLoader('MenuBoldRegression');
      // 檔名大小寫須與 SDK 字型壓縮檔一致，Linux 才能正確載入。
      for (final weight in ['Regular', 'Bold']) {
        final font = File.fromUri(
          Uri.file(
            Platform.resolvedExecutable,
          ).resolve('../../material_fonts/Roboto-$weight.ttf'),
        );
        loader.addFont(
          Future.value(ByteData.sublistView(font.readAsBytesSync())),
        );
      }
      await loader.load();
    });
    final base = AppTheme.light();
    final theme = base.copyWith(
      textTheme: base.textTheme.copyWith(
        bodyLarge: base.textTheme.bodyLarge!.copyWith(
          fontFamily: 'MenuBoldRegression',
          fontSize: 16.6,
        ),
      ),
    );
    const label = 'Booking maximum capacity';
    await tester.pumpWidget(
      _menuHost(
        items: const [
          TpActionItem(value: 'booking', label: label, selected: true),
        ],
        theme: theme,
        boldText: true,
        onSelected: (_) {},
      ),
    );
    await tester.tap(find.byKey(const ValueKey('host-more-menu')));
    await tester.pumpAndSettle();
    final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
    expect(paragraph.didExceedMaxLines, isFalse);
    final check = tester.getRect(find.byIcon(CupertinoIcons.check_mark));
    expect(
      tester.getRect(find.text(label)).right,
      lessThanOrEqualTo(check.left),
    );
    expect(tester.takeException(), isNull);
  });

  group('選單公開操作', () {
    const items = [
      TpActionItem(value: 'a', label: '筆記', icon: Icons.description_outlined),
      TpActionItem(value: 'b', label: '列印', icon: Icons.print),
    ];

    testWidgets('點選單外面任何地方都可關閉', (tester) async {
      await tester.pumpWidget(_menuHost(items: items, onSelected: (_) {}));
      await tester.tap(find.byKey(const ValueKey('host-more-menu')));
      await tester.pumpAndSettle();
      expect(find.text('筆記'), findsOneWidget);

      // 點在遠離面板的左下角。
      await tester.tapAt(const Offset(20, 560));
      await tester.pumpAndSettle();
      expect(find.text('筆記'), findsNothing);
    });

    testWidgets('Esc 可關閉，方向鍵可走動', (tester) async {
      String? selected;
      await tester.pumpWidget(
        _menuHost(items: items, onSelected: (value) => selected = value),
      );
      await tester.tap(find.byKey(const ValueKey('host-more-menu')));
      await tester.pumpAndSettle();

      // 面板開啟時焦點落在 FocusScope 本身，第一次方向鍵才走到第一項。
      // 要驗「走得到第二項」才守得住 —— 只驗「按了不丟例外」是恆真的。
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(selected, 'b', reason: '方向鍵要能一路走到第二項並以 Enter 啟動');

      await tester.tap(find.byKey(const ValueKey('host-more-menu')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('筆記'), findsNothing);
    });

    testWidgets('項目朗讀為按鈕，停用項目的停用原因仍被朗讀', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _menuHost(
          items: const [
            TpActionItem(
              value: 'move',
              label: '移動到其他日',
              icon: Icons.calendar_today,
              semanticLabel: '移動到其他日，只有一天時無法移動',
              enabled: false,
            ),
          ],
          onSelected: (_) {},
        ),
      );
      await tester.tap(find.byKey(const ValueKey('host-more-menu')));
      await tester.pumpAndSettle();

      final flags = tester
          .getSemantics(find.bySemanticsLabel('移動到其他日，只有一天時無法移動'))
          .getSemanticsData()
          .flagsCollection;
      expect(flags.isButton, isTrue, reason: '項目要被朗讀為按鈕');
      expect(flags.isEnabled, Tristate.isFalse, reason: '停用狀態要傳達出去');
      handle.dispose();
    });

    testWidgets('文字縮放 1.0／1.3／2.0 下，點擊命中的都是該項目自己的值', (tester) async {
      for (final scale in [1.0, 1.3, 2.0]) {
        String? selected;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          _menuHost(
            items: items,
            textScale: scale,
            onSelected: (value) => selected = value,
          ),
        );
        await tester.tap(find.byKey(const ValueKey('host-more-menu')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('列印'));
        await tester.pumpAndSettle();
        expect(selected, 'b', reason: 'textScale=$scale 必須嚴格命中自己的值');
      }
    });

    testWidgets('長標籤在最窄螢幕與兩倍文字完整可讀可點', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const label = '把這個停留點複製到另一個行程的某一天';
      String? selected;
      await tester.pumpWidget(
        _menuHost(
          items: const [
            TpActionItem(value: 'copy', label: label, icon: Icons.copy),
          ],
          textScale: 2,
          alignment: Alignment.bottomRight,
          onSelected: (value) => selected = value,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('host-more-menu')));
      await tester.pumpAndSettle();
      final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
      expect(paragraph.didExceedMaxLines, isFalse);
      final rect = tester.getRect(find.text(label));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(568));
      await tester.tap(find.text(label));
      expect(selected, 'copy');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('選單開啟期間畫面被外部換掉，不殘留攔截層', (tester) async {
      await tester.pumpWidget(_menuHost(items: items, onSelected: (_) {}));
      await tester.tap(find.byKey(const ValueKey('host-more-menu')));
      await tester.pumpAndSettle();
      expect(find.text('筆記'), findsOneWidget);

      // 等同 root tab 在選單開著時被切走。刻意不用 TextButton —— 它會與選單
      // 項目的 element 被重用，`AnimatedDefaultTextStyle` 插值失敗的例外會蓋掉
      // 這支測試真正要驗的東西。
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GestureDetector(
              key: const ValueKey('after-switch'),
              behavior: HitTestBehavior.opaque,
              onTap: () => tapped = true,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('筆記'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('after-switch')));
      expect(tapped, isTrue, reason: '殘留的 TapRegion 會把這一下點擊吃掉');
    });
  });

  group('選單快捷動作', () {
    testWidgets('上排三格 icon＋短文字並排於清單之上，點選派發一次並關閉', (tester) async {
      final selected = <String>[];
      await tester.pumpWidget(
        _menuHost(
          items: _quickMenuItems,
          quickActions: _quickActions,
          onSelected: selected.add,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('host-more-menu')));
      await tester.pumpAndSettle();

      for (final label in ['分享', '共編', 'AI 健檢', '匯出 JSON', '刪除行程']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      for (final symbol in [
        CupertinoIcons.share,
        CupertinoIcons.person_2,
        CupertinoIcons.sparkles,
      ]) {
        expect(find.byIcon(symbol), findsOneWidget, reason: '$symbol');
      }

      // 三格同一列、依序由左到右，且每格至少 44×44。
      final share = tester.getRect(find.byKey(const ValueKey('quick-share')));
      final collab = tester.getRect(find.byKey(const ValueKey('quick-collab')));
      final health = tester.getRect(find.byKey(const ValueKey('quick-health')));
      expect(share.top, closeTo(collab.top, 0.5));
      expect(collab.top, closeTo(health.top, 0.5));
      expect(share.right, lessThanOrEqualTo(collab.left + 0.5));
      expect(collab.right, lessThanOrEqualTo(health.left + 0.5));
      for (final rect in [share, collab, health]) {
        expect(rect.width, greaterThanOrEqualTo(44));
        expect(rect.height, greaterThanOrEqualTo(44));
      }
      // 字符在文字上方。
      expect(
        tester.getRect(find.byIcon(CupertinoIcons.share)).bottom,
        lessThanOrEqualTo(tester.getRect(find.text('分享')).top + 0.5),
      );
      // 清單項目位於快捷列之下。
      expect(
        tester.getRect(find.text('匯出 JSON')).top,
        greaterThanOrEqualTo(share.bottom),
      );

      await tester.tap(find.text('共編'));
      expect(selected, ['collab']);
      await tester.tap(find.text('共編'), warnIfMissed: false);
      expect(selected, ['collab'], reason: '同一次開啟只派發一次');
      await tester.pumpAndSettle();
      expect(find.text('共編'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('兩倍文字放不下時整排改為同順序直列，文字不裁切且全部可點', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final selected = <String>[];
      await tester.pumpWidget(
        _menuHost(
          items: _quickMenuItems,
          quickActions: _quickActions,
          textScale: 2,
          alignment: Alignment.bottomRight,
          onSelected: selected.add,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('host-more-menu')));
      await tester.pumpAndSettle();

      final share = tester.getRect(find.byKey(const ValueKey('quick-share')));
      final collab = tester.getRect(find.byKey(const ValueKey('quick-collab')));
      final health = tester.getRect(find.byKey(const ValueKey('quick-health')));
      expect(share.bottom, lessThanOrEqualTo(collab.top + 0.5));
      expect(collab.bottom, lessThanOrEqualTo(health.top + 0.5));
      expect(share.left, closeTo(collab.left, 0.5));
      expect(
        tester.getRect(find.text('匯出 JSON')).top,
        greaterThanOrEqualTo(health.bottom),
        reason: '直列後仍維持快捷動作在前、清單在後',
      );
      for (final label in ['分享', '共編', 'AI 健檢', '匯出 JSON', '刪除行程']) {
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(label),
        );
        expect(paragraph.didExceedMaxLines, isFalse, reason: label);
        final rect = tester.getRect(find.text(label));
        expect(rect.left, greaterThanOrEqualTo(0), reason: label);
        expect(rect.right, lessThanOrEqualTo(320), reason: label);
        expect(rect.top, greaterThanOrEqualTo(0), reason: label);
        expect(rect.bottom, lessThanOrEqualTo(568), reason: label);
      }
      for (final rect in [share, collab, health]) {
        expect(rect.height, greaterThanOrEqualTo(44));
      }
      expect(find.bySemanticsLabel('共編設定'), findsOneWidget);

      await tester.tap(find.text('AI 健檢'));
      expect(selected, ['health']);
      await tester.pumpAndSettle();
      expect(find.text('AI 健檢'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('方向鍵可走到快捷動作並以 Enter 啟用，Esc 仍可關閉', (tester) async {
      final selected = <String>[];
      await tester.pumpWidget(
        _menuHost(
          items: _quickMenuItems,
          quickActions: _quickActions,
          onSelected: selected.add,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('host-more-menu')));
      await tester.pumpAndSettle();

      // 開啟時焦點在第一格，向右走到第二格。
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(selected, ['collab'], reason: '方向鍵要能走到第二個快捷動作並以 Enter 啟動');
      expect(find.text('共編'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('host-more-menu')));
      await tester.pumpAndSettle();
      // 從快捷列往下能走到清單項目。
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(selected, ['collab', 'export']);

      await tester.tap(find.byKey(const ValueKey('host-more-menu')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('分享'), findsNothing);
      expect(selected, ['collab', 'export']);
    });

    testWidgets('開啟中快捷動作的權限或內容改變，沿用清單項目的關閉／重開清理契約', (tester) async {
      final semantics = tester.ensureSemantics();
      final controller = TpMoreMenuController();
      final selected = <String>[];
      var revoked = false;
      late StateSetter update;
      const grantedActions = [
        TpActionItem(
          key: ValueKey('quick-collab'),
          value: 'collab',
          label: '共編',
          semanticLabel: '共編設定',
          icon: CupertinoIcons.person_2,
        ),
      ];
      const revokedActions = [
        TpActionItem(
          key: ValueKey('quick-collab'),
          value: 'collab',
          label: '共編',
          semanticLabel: '共編設定，只有擁有者可以管理',
          icon: CupertinoIcons.person_2,
          enabled: false,
          selected: true,
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Scaffold(
                body: Align(
                  alignment: Alignment.topRight,
                  child: TpMoreMenuButton<String>(
                    key: const ValueKey('host-more-menu'),
                    controller: controller,
                    quickActions: revoked ? revokedActions : grantedActions,
                    items: _quickMenuItems,
                    onSelected: selected.add,
                  ),
                ),
              );
            },
          ),
        ),
      );
      controller.open();
      await tester.pumpAndSettle();
      expect(find.text('共編'), findsOneWidget);

      update(() => revoked = true);
      await tester.pumpAndSettle();
      expect(find.text('共編'), findsNothing, reason: '舊權限的面板必須關閉');

      controller.open();
      await tester.pumpAndSettle();
      final flags = tester
          .getSemantics(find.bySemanticsLabel('共編設定，只有擁有者可以管理').first)
          .getSemanticsData()
          .flagsCollection;
      expect(flags.isEnabled, Tristate.isFalse, reason: '停用原因要朗讀出來');
      expect(flags.isSelected, Tristate.isTrue, reason: '選取語意要保留');
      await tester.tap(find.text('共編'));
      await tester.pumpAndSettle();
      expect(selected, isEmpty, reason: '停用的快捷動作不得執行');
      semantics.dispose();
    });

    testWidgets('plain 觸發鈕以鍵盤開啟快捷選單，Esc 關閉後焦點回到觸發鈕', (tester) async {
      final selected = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topRight,
              child: TpMoreMenuButton<String>(
                key: const ValueKey('host-more-menu'),
                plain: true,
                tooltip: '行程選項',
                quickActions: _quickActions,
                items: _quickMenuItems,
                onSelected: selected.add,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const ValueKey('host-more-menu'))),
        const Size(44, 44),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      bool triggerHasFocus() {
        final focusedContext = FocusManager.instance.primaryFocus?.context;
        if (focusedContext == null) return false;
        return find
            .ancestor(
              of: find.byWidget(focusedContext.widget),
              matching: find.byKey(const ValueKey('host-more-menu')),
            )
            .evaluate()
            .isNotEmpty;
      }

      expect(triggerHasFocus(), isTrue, reason: 'Tab 要能停在「⋯」上');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('分享'), findsOneWidget, reason: 'Enter 開啟選單');
      expect(triggerHasFocus(), isFalse, reason: '開啟後焦點進入選單');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('分享'), findsNothing);
      expect(triggerHasFocus(), isTrue, reason: '關閉後焦點回到觸發鈕');
      expect(selected, isEmpty);

      // 選取後同樣回到觸發鈕。
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(selected, ['share']);
      expect(find.text('分享'), findsNothing);
      expect(triggerHasFocus(), isTrue, reason: '選取關閉後焦點回到觸發鈕');
    });

    testWidgets('快捷動作的焦點與按壓底色取自主題前景，深淺色都不是寫死的白', (tester) async {
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          _menuHost(
            items: _quickMenuItems,
            quickActions: _quickActions,
            theme: theme,
            onSelected: (_) {},
          ),
        );
        await tester.tap(find.byKey(const ValueKey('host-more-menu')));
        await tester.pumpAndSettle();
        final onSurface = theme.colorScheme.onSurface;
        (double, double, double) rgb(Color color) =>
            (color.r, color.g, color.b);

        Color tileFill() {
          final box = tester.widget<AnimatedContainer>(
            find.descendant(
              of: find.byKey(const ValueKey('quick-share')),
              matching: find.byType(AnimatedContainer),
            ),
          );
          return (box.decoration! as BoxDecoration).color!;
        }

        expect(tileFill().a, 0, reason: '靜止時沒有底色');
        // 鍵盤焦點：開啟時焦點已在第一格，方向鍵回到它會顯示焦點底。
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        final focused = tileFill();
        expect(rgb(focused), rgb(onSurface), reason: '焦點底色跟隨主題前景');
        expect(focused.a, greaterThan(0));
        expect(focused.a, lessThan(0.3));

        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('quick-share'))),
        );
        await tester.pump();
        final pressed = tileFill();
        expect(rgb(pressed), rgb(onSurface), reason: '按壓底色跟隨主題前景');
        expect(pressed.a, greaterThan(focused.a));
        await gesture.cancel();
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
      }
    });
  });

  testWidgets('工具列玻璃一般模式交由材質呈現，提高對比補明顯實心邊', (tester) async {
    for (final highContrast in [false, true]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: MediaQueryData(highContrast: highContrast),
            child: Scaffold(
              body: Column(
                children: [
                  TpToolbarGlassButton(
                    tooltip: '更多',
                    onPressed: () {},
                    child: const Icon(Icons.more_horiz),
                  ),
                  TpToolbarActionGroup(
                    children: [
                      TpToolbarIconButton(
                        icon: CupertinoIcons.share,
                        tooltip: '分享',
                        onPressed: () {},
                      ),
                      TpToolbarIconButton(
                        icon: CupertinoIcons.add,
                        tooltip: '新增',
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // 一般模式不再校準舊材質的邊線；提高對比仍提供明確邊界。
      final matcher = highContrast ? greaterThan(0.5) : 0;
      final reason = 'highContrast=$highContrast';

      // 圓鈕的描邊是可覆寫的預設值。
      final button = tester.widget<GlassButton>(find.byType(GlassButton).first);
      expect(
        (button.shape as LiquidRoundedSuperellipse).side.color.a,
        matcher,
        reason: '$reason：工具列玻璃圓鈕',
      );

      final edge = find.descendant(
        of: find.byType(TpToolbarActionGroup),
        matching: find.byType(TpGlassEdge),
      );
      final boundary = tester.widget<Container>(
        find.descendant(of: edge, matching: find.byType(Container)).first,
      );
      final decoration = boundary.foregroundDecoration! as ShapeDecoration;
      expect(
        (decoration.shape as LiquidRoundedSuperellipse).side.color.a,
        matcher,
        reason: '$reason：動作群組的無障礙邊界',
      );
    }
  });

  testWidgets('表單主要動作是 prominent，著色在底色而不是字符', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          appBar: TpAppBar(
            role: TpAppBarRole.modalForm,
            title: const Text('編輯行程'),
            onCancel: () {},
            primaryActionLabel: '儲存',
            onPrimaryAction: () {},
          ),
        ),
      ),
    );

    final scheme = AppTheme.light().colorScheme;
    final primary = tester.widget<TextButton>(
      find.descendant(
        of: find.byKey(const ValueKey('tp-app-bar-primary-action')),
        matching: find.byType(TextButton),
      ),
    );
    const resting = <WidgetState>{};
    expect(
      primary.style?.backgroundColor?.resolve(resting),
      scheme.primary,
      reason: '著色在底色',
    );
    expect(
      primary.style?.foregroundColor?.resolve(resting),
      scheme.onPrimary,
      reason: '底色著色後，文字改用 onPrimary 才有對比',
    );

    // 一列只有一個 prominent，且置於尾端。
    final prominentButtons = tester
        .widgetList<TpToolbarTextButton>(find.byType(TpToolbarTextButton))
        .where((button) => button.prominent)
        .toList();
    expect(prominentButtons.length, 1);
    expect(prominentButtons.single.label, '儲存');

    // 取消是次要動作，維持純文字。
    final cancel = tester.widget<TextButton>(
      find.ancestor(of: find.text('取消'), matching: find.byType(TextButton)),
    );
    expect(cancel.style?.backgroundColor?.resolve(resting), isNull);
  });

  testWidgets('群組容器包住更多選單時，header 的動作額度判斷仍成立', (tester) async {
    // 改寫前這裡會 assert：`action is TpMoreMenuButton` 對群組容器不成立。
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          appBar: TpAppBar(
            role: TpAppBarRole.detail,
            title: const Text('行程'),
            actions: [
              TpToolbarIconButton(
                icon: CupertinoIcons.share,
                tooltip: '分享',
                onPressed: () {},
              ),
              TpToolbarActionGroup(
                children: [
                  TpMoreMenuButton<int>(
                    items: const [
                      TpActionItem(value: 1, label: '列印', icon: Icons.print),
                    ],
                    onSelected: (_) {},
                  ),
                  TpToolbarIconButton(
                    icon: CupertinoIcons.add,
                    tooltip: '新增',
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('tp-toolbar-action-group')),
      findsOneWidget,
    );
  });

  testWidgets(
    'TpToolbarGlassButton resolves custom settings for Reduce Transparency',
    (tester) async {
      const customSettings = LiquidGlassSettings(
        glassColor: Color(0x332196F3),
        blur: 24,
        thickness: 20,
        refractiveIndex: 1.2,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: AppAccessibilityScope(
            reduceTransparency: true,
            child: Scaffold(
              body: TpToolbarGlassButton(
                tooltip: '更多',
                onPressed: () {},
                glassSettings: customSettings,
                child: const Icon(Icons.more_horiz),
              ),
            ),
          ),
        ),
      );

      final settings = tester
          .widget<GlassButton>(find.byType(GlassButton))
          .settings!;
      expect(settings.glassColor.a, 1);
      expect(settings.backerColor?.a, 1);
      expect(settings.platformViewFallbackColor?.a, 1);
      expect(settings.blur, 0);
      expect(settings.thickness, 0);
      expect(settings.refractiveIndex, 1);
    },
  );

  testWidgets('standalone app bar never implies a leading action', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          appBar: TpAppBar(role: TpAppBarRole.standalone, title: Text('邀請')),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('tp-app-bar-back')), findsNothing);
    expect(find.byKey(const ValueKey('tp-app-bar-close')), findsNothing);
    expect(find.text('取消'), findsNothing);
  });

  testWidgets('detail 固定 bar 只退一層路由且不再自動附加帳號入口', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            TpAccountActionScope(onOpen: (_) {}, child: child!),
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(
                  appBar: TpAppBar(
                    role: TpAppBarRole.detail,
                    title: Text('外觀'),
                  ),
                ),
              ),
            ),
            child: const Text('開啟'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account-avatar-button')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('tp-app-bar-back')));
    await tester.pumpAndSettle();

    expect(find.text('開啟'), findsOneWidget);
    expect(find.text('外觀'), findsNothing);
  });

  testWidgets('固定 bar 的帳號入口改由呼叫端明文提供', (tester) async {
    var accountOpened = false;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => TpAccountActionScope(
          onOpen: (_) => accountOpened = true,
          child: child!,
        ),
        home: const Scaffold(
          appBar: TpAppBar(
            role: TpAppBarRole.detail,
            title: Text('共編設定'),
            accountEntry: TpAccountAvatarButton(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('account-avatar-button')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('account-avatar-button'))),
      const Size(44, 44),
    );
    await tester.tap(find.byKey(const ValueKey('account-avatar-button')));
    expect(accountOpened, isTrue);
  });

  testWidgets('內容 header 的帳號入口不佔用一般動作額度', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            TpAccountActionScope(onOpen: (_) {}, child: child!),
        home: Scaffold(
          appBar: TpAppBar(
            role: TpAppBarRole.detail,
            title: const Text('共編設定'),
            actions: [
              TpToolbarIconButton(
                icon: CupertinoIcons.arrow_clockwise,
                tooltip: '重新整理',
                onPressed: () {},
              ),
            ],
            accountEntry: const TpAccountAvatarButton(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('account-avatar-button')), findsOneWidget);
    expect(find.byTooltip('重新整理'), findsOneWidget);
    // 帳號入口自成一組，固定排在最右側。
    expect(
      tester.getCenter(find.byKey(const ValueKey('account-avatar-button'))).dx,
      greaterThan(tester.getCenter(find.byTooltip('重新整理')).dx),
    );
  });

  testWidgets('內容 header 兩個一般動作沒有更多選單時仍拒收', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: TpAppBar(
            role: TpAppBarRole.detail,
            title: const Text('共編設定'),
            actions: [
              TpToolbarIconButton(
                icon: CupertinoIcons.arrow_clockwise,
                tooltip: '重新整理',
                onPressed: () {},
              ),
              TpToolbarIconButton(
                icon: CupertinoIcons.share,
                tooltip: '分享',
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isAssertionError);
  });

  testWidgets('帳號入口誤放進 actions 會被擋下', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          appBar: TpAppBar(
            role: TpAppBarRole.detail,
            title: Text('共編設定'),
            actions: [TpAccountAvatarButton()],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isAssertionError);
  });

  testWidgets('modal form exposes Cancel and the explicit submit verb', (
    tester,
  ) async {
    var cancelled = false;
    var saved = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: TpAppBar(
            role: TpAppBarRole.modalForm,
            title: const Text('編輯行程'),
            onCancel: () => cancelled = true,
            primaryActionLabel: '儲存',
            onPrimaryAction: () => saved = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('取消'));
    await tester.tap(find.text('儲存'));

    expect(cancelled, isTrue);
    expect(saved, isTrue);
  });

  testWidgets('modal form keeps the complete Cancel label at large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          appBar: TpAppBar(
            role: TpAppBarRole.modalForm,
            title: const Text('編輯停留點'),
            onCancel: () {},
            primaryActionLabel: '儲存',
            onPrimaryAction: () {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('取消'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('tp-app-bar-cancel'))).width,
      greaterThan(64),
    );
  });

  testWidgets('sheet header centers its title between optional controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TpSheetHeader(
                title: '選擇行程',
                leading: SizedBox.square(
                  dimension: TpSpacing.tapMin,
                  child: Text('取消'),
                ),
                trailing: SizedBox.square(
                  dimension: TpSpacing.tapMin,
                  child: Icon(CupertinoIcons.xmark),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final header = tester.getRect(find.byType(TpSheetHeader));
    final screen = tester.getRect(find.byType(Scaffold));
    final trailing = tester.getRect(find.byIcon(CupertinoIcons.xmark));
    expect(header.width, screen.width);
    expect(trailing.right, closeTo(header.right - TpSpacing.s4, 0.1));
    expect(tester.getSize(find.byType(TpSheetHeader)).height, 56);
    expect(
      tester.getCenter(find.text('選擇行程')).dx,
      closeTo(tester.getCenter(find.byType(TpSheetHeader)).dx, 0.1),
    );
    expect(
      tester.getSize(find.byIcon(CupertinoIcons.xmark)).height,
      lessThanOrEqualTo(TpSpacing.tapMin),
    );
  });

  testWidgets(
    'TpAppBar delegates layout to GlassAppBar and keeps title left aligned',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: TpAppBar(
              role: TpAppBarRole.standalone,
              title: const Text('行程'),
              actions: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.more_horiz),
                ),
                IconButton(onPressed: () {}, icon: const Icon(Icons.person)),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(GlassAppBar), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      final appBar = tester.widget<GlassAppBar>(find.byType(GlassAppBar));
      expect(appBar.centerTitle, isFalse);
      expect(
        tester.getCenter(find.text('行程')).dx,
        lessThan(tester.getCenter(find.byType(GlassAppBar)).dx),
      );
      final actionRects = tester
          .widgetList<IconButton>(find.byType(IconButton))
          .map((widget) => tester.getRect(find.byWidget(widget)))
          .toList();
      expect(actionRects, hasLength(2));
      expect(actionRects.last.left - actionRects.first.right, 8);
    },
  );

  testWidgets('更多選單可選取並重新開啟', (tester) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: TpAppBar(
            role: TpAppBarRole.standalone,
            title: const Text('行程'),
            actions: [
              TpMoreMenuButton<String>(
                key: const ValueKey('more-menu'),
                items: const [
                  TpActionItem(
                    key: ValueKey('open-sheet'),
                    value: 'sheet',
                    label: '開啟視窗',
                    icon: Icons.open_in_new,
                  ),
                ],
                onSelected: (value) => selected = value,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('more-menu')));
    await tester.pumpAndSettle();
    expect(find.text('開啟視窗'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('open-sheet')));
    await tester.pumpAndSettle();
    expect(selected, 'sheet');

    await tester.tap(find.byKey(const ValueKey('more-menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('open-sheet')), findsOneWidget);
  });

  testWidgets('選單觸發鈕與面板都走中性語意層，不再是品牌褐玻璃', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          appBar: TpAppBar(
            role: TpAppBarRole.standalone,
            title: const Text('行程'),
            actions: [
              TpMoreMenuButton<String>(
                key: const ValueKey('primary-more-menu'),
                items: const [
                  TpActionItem(
                    value: 'notes',
                    label: '筆記',
                    icon: Icons.description_outlined,
                    selected: true,
                  ),
                ],
                onSelected: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    final trigger = tester.widget<GlassButton>(
      find.descendant(
        of: find.byKey(const ValueKey('primary-more-menu')),
        matching: find.byType(GlassButton),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('primary-more-menu')));
    await tester.pumpAndSettle();
    final scheme = AppTheme.light().colorScheme;
    (double, double, double) rgb(Color c) => (c.r, c.g, c.b);
    expect(rgb(trigger.settings!.glassColor), isNot(rgb(scheme.primary)));
    final text = tester.widget<Text>(find.text('筆記'));
    expect(text.style?.color, scheme.onSurface);
    expect(find.byIcon(CupertinoIcons.check_mark), findsOneWidget);
  });

  testWidgets('深色選單的項目文字走標籤色', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: TpMoreMenuButton<String>(
            items: const [TpActionItem(value: 'notes', label: '筆記')],
            onSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TpMoreMenuButton<String>));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.text('筆記')).style?.color,
      AppTheme.dark().colorScheme.onSurface,
    );
  });

  testWidgets('停用刪除保留分組與破壞性提示且不執行', (tester) async {
    final semantics = tester.ensureSemantics();
    var calls = 0;
    await tester.pumpWidget(
      _menuHost(
        items: const [
          TpActionItem(value: 'edit', label: '行程資料'),
          TpActionItem(
            value: 'delete',
            label: '刪除行程',
            icon: CupertinoIcons.delete,
            dividerBefore: true,
            role: TpActionRole.destructive,
            enabled: false,
          ),
        ],
        onSelected: (_) => calls++,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('host-more-menu')));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.text('刪除行程')).top,
      greaterThan(tester.getRect(find.text('行程資料')).bottom),
    );
    expect(
      tester.widget<Text>(find.text('刪除行程')).style?.color,
      AppTheme.light().colorScheme.error,
    );
    final flags = tester
        .getSemantics(find.bySemanticsLabel('刪除行程').first)
        .getSemanticsData()
        .flagsCollection;
    expect(flags.isEnabled, Tristate.isFalse);
    await tester.tap(find.text('刪除行程'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('行程資料'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets(
    'expanded option uses shared glass sheet with centered compact header',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => unawaited(
                    showAppScreenSheet<void>(
                      context,
                      builder: (_) => const Scaffold(
                        appBar: TpAppBar(
                          role: TpAppBarRole.standalone,
                          title: Text('隱私權與存取'),
                        ),
                        body: Text('展開內容'),
                      ),
                    ),
                  ),
                  child: const Text('展開'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('展開'));
      await tester.pumpAndSettle();

      expect(find.byType(GlassModalSheetScaffold), findsOneWidget);
      final appBar = tester.widget<GlassAppBar>(find.byType(GlassAppBar));
      expect(appBar.centerTitle, isTrue);

      final screenCenter = tester.getCenter(find.byType(MaterialApp)).dx;
      final titleRect = tester.getRect(find.text('隱私權與存取'));
      expect(titleRect.center.dx, closeTo(screenCenter, 1));
      expect(
        find.byKey(const ValueKey('app-large-sheet-drag-indicator')),
        findsNothing,
      );
      expect(
        tester
            .widget<GlassModalSheetScaffold>(
              find.byType(GlassModalSheetScaffold),
            )
            .showDragIndicator,
        isFalse,
      );
      expect(
        DefaultTextStyle.of(tester.element(find.text('隱私權與存取'))).style.fontSize,
        greaterThanOrEqualTo(20),
      );
    },
  );

  testWidgets('large sheet modal form fits Cancel and its submit action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => unawaited(
                showAppScreenSheet<void>(
                  context,
                  builder: (_) => Scaffold(
                    appBar: TpAppBar(
                      role: TpAppBarRole.modalForm,
                      title: const Text('編輯行程'),
                      onCancel: () {},
                      primaryActionLabel: '儲存',
                      onPrimaryAction: () {},
                    ),
                  ),
                ),
              ),
              child: const Text('展開表單'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('展開表單'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('tp-app-bar-cancel')), findsOneWidget);
    expect(find.text('儲存'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('tp-app-bar-cancel'))).width,
      greaterThan(64),
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('tp-app-bar-primary-action')))
          .width,
      greaterThan(64),
    );
    expect(find.byKey(const ValueKey('app-large-sheet-close')), findsNothing);
  });

  testWidgets('large sheet 的固定 bar 保留分享與關閉操作，標題在非對稱動作間置中', (tester) async {
    var shares = 0;
    var closes = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: TpLargeSheetNavigationScope(
          onClose: () => closes++,
          child: Builder(
            builder: (context) {
              return Scaffold(
                appBar: TpAppBar(
                  role: TpAppBarRole.detail,
                  title: const Text('Sheet'),
                  actions: [
                    TpToolbarIconButton(
                      icon: CupertinoIcons.share,
                      tooltip: '分享',
                      onPressed: () => shares++,
                    ),
                  ],
                ),
                body: const SizedBox(),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    final title = tester.getRect(
      find.byKey(const ValueKey('tp-app-bar-title')),
    );
    final actions = tester.getRect(
      find.byKey(const ValueKey('tp-app-bar-actions')),
    );
    final bar = tester.getRect(find.byType(TpAppBar));
    expect(title.center.dx, closeTo(bar.center.dx, 0.5));
    expect(title.right, lessThanOrEqualTo(actions.left));
    await tester.tap(find.byTooltip('分享'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('app-large-sheet-close')));
    await tester.pumpAndSettle();
    expect(shares, 1);
    expect(closes, 1);
  });
}
