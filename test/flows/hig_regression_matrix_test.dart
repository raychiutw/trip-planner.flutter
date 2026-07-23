import 'dart:ui' show Tristate;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:tripline/features/shell/apple_root_tab_bar.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_app_bar.dart';
import 'package:tripline/ui/tp_horizontal_selector.dart';
import 'package:tripline/ui/tp_root_scaffold.dart';
import 'package:tripline/ui/tp_scope_menu.dart';

const _lastContent = ValueKey('hig-last-content');

class _HigState {
  const _HigState({
    required this.brightness,
    this.textScale = 1,
    this.reduceMotion = false,
    this.reduceTransparency = false,
  });

  final Brightness brightness;
  final double textScale;
  final bool reduceMotion;
  final bool reduceTransparency;

  String get name {
    final appearance = brightness == Brightness.dark ? 'dark' : 'light';
    final text = textScale == 1 ? 'text100' : 'text200';
    final motion = reduceMotion ? 'motion-reduced' : 'motion-full';
    final transparency = reduceTransparency
        ? 'transparency-reduced'
        : 'transparency-glass';
    return 'shared-ios-$appearance-$text-$motion-$transparency';
  }
}

const _states = [
  _HigState(brightness: Brightness.light),
  _HigState(brightness: Brightness.dark),
  _HigState(brightness: Brightness.light, textScale: 2),
  _HigState(brightness: Brightness.dark, textScale: 2),
  _HigState(
    brightness: Brightness.light,
    reduceMotion: true,
    reduceTransparency: true,
  ),
  _HigState(
    brightness: Brightness.dark,
    reduceMotion: true,
    reduceTransparency: true,
  ),
];

void main() {
  for (final state in _states) {
    testWidgets('${state.name} keeps shared HIG geometry and behavior', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_MatrixApp(state: state));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('tp-root-glass-header')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('apple-root-tab-bar')), findsOneWidget);
      expect(find.byKey(const ValueKey('day-1-option')), findsOneWidget);
      expect(tester.takeException(), isNull);

      expect(
        tester.getSize(find.byKey(const ValueKey('tp-root-header-action-0'))),
        const Size(44, 44),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('account-avatar-button'))),
        const Size(44, 44),
      );

      await tester.ensureVisible(find.byKey(const ValueKey('day-2-option')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('day-2-option')));
      await tester.pumpAndSettle();
      final dayTwo = tester.getSemantics(
        find.byKey(const ValueKey('day-2-option')),
      );
      expect(
        dayTwo.getSemanticsData().flagsCollection.isSelected,
        Tristate.isTrue,
      );

      final headerGlass = tester.widget<GlassContainer>(
        find.descendant(
          of: find.byKey(const ValueKey('tp-root-glass-header')),
          matching: find.byType(GlassContainer),
        ),
      );
      final fallbackAlpha = headerGlass.settings!.platformViewFallbackColor!.a;
      expect(
        fallbackAlpha,
        state.reduceTransparency
            ? greaterThanOrEqualTo(0.95)
            : closeTo(state.brightness == Brightness.dark ? 0.48 : 0.40, 0.01),
      );

      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, -1200),
        2500,
      );
      await tester.pumpAndSettle();
      final lastContent = tester.getRect(find.byKey(_lastContent));
      final rootTab = tester.getRect(
        find.byKey(const ValueKey('apple-root-tab-bar')),
      );
      expect(lastContent.bottom, lessThanOrEqualTo(rootTab.top));
      expect(tester.takeException(), isNull);
    });
  }
}

class _MatrixApp extends StatelessWidget {
  const _MatrixApp({required this.state});

  final _HigState state;

  @override
  Widget build(BuildContext context) {
    final theme = state.brightness == Brightness.dark
        ? AppTheme.dark()
        : AppTheme.light();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(390, 844),
          padding: const EdgeInsets.only(top: 47),
          viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
          textScaler: TextScaler.linear(state.textScale),
          disableAnimations: state.reduceMotion,
          highContrast: state.reduceTransparency,
        ),
        child: const _MatrixScene(),
      ),
    );
  }
}

class _MatrixScene extends StatefulWidget {
  const _MatrixScene();

  @override
  State<_MatrixScene> createState() => _MatrixSceneState();
}

class _MatrixSceneState extends State<_MatrixScene> {
  var _day = 1;
  var _rootTab = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: TpRootScaffold(
        showSoftEdge: true,
        header: TpRootHeaderConfig(
          title: const Text('京都五日行'),
          actions: [
            TpToolbarGlassButton(
              tooltip: '筆記',
              onPressed: () {},
              child: const Icon(CupertinoIcons.doc_text, size: 20),
            ),
          ],
        ),
        body: TpRootScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.list(
                children: [
                  TpHorizontalSelector<int>(
                    value: _day,
                    options: const [
                      TpScopeOption(
                        value: 1,
                        label: 'DAY 1',
                        key: ValueKey('day-1-option'),
                      ),
                      TpScopeOption(
                        value: 2,
                        label: 'DAY 2',
                        key: ValueKey('day-2-option'),
                      ),
                      TpScopeOption(value: 3, label: 'DAY 3'),
                    ],
                    onSelected: (value) => setState(() => _day = value),
                  ),
                  const SizedBox(height: 16),
                  for (var index = 0; index < 12; index++)
                    Card(
                      key: index == 11 ? _lastContent : null,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(child: Text('${index + 1}')),
                        title: Text(index == 0 ? '清水寺' : '行程景點 ${index + 1}'),
                        subtitle: const Text('10:00–11:30 · 景點'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppleRootTabBar(
        selectedIndex: _rootTab,
        onSelected: (index) => setState(() => _rootTab = index),
      ),
    );
  }
}
