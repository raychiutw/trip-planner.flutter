import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_app_bar.dart';
import 'package:tripline/ui/tp_root_scaffold.dart';

Widget _app(Widget home, {MediaQueryData? mediaQueryData}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: MediaQuery(
      data: mediaQueryData ?? const MediaQueryData(),
      child: home,
    ),
  );
}

TpRootScaffold _root({int actionCount = 0, Widget? body}) {
  return TpRootScaffold(
    header: TpRootHeaderConfig(
      title: const Text('京都五日行'),
      actions: [
        for (var index = 0; index < actionCount; index++)
          SizedBox.square(key: ValueKey('source-action-$index'), dimension: 44),
      ],
    ),
    body:
        body ??
        const ColoredBox(key: ValueKey('full-bleed-body'), color: Colors.blue),
  );
}

void main() {
  testWidgets('root header is one fixed capsule over full bleed content', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _root(),
        mediaQueryData: const MediaQueryData(
          size: Size(390, 844),
          padding: EdgeInsets.only(top: 44),
        ),
      ),
    );

    final header = find.byKey(const ValueKey('tp-root-glass-header'));
    expect(header, findsOneWidget);
    expect(tester.getRect(header).top, 52);
    expect(tester.getRect(header).left, 16);
    expect(tester.getSize(header).height, 56);
    expect(find.byType(SliverAppBar), findsNothing);
    expect(find.byType(AppBar), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('full-bleed-body'))).dy,
      0,
    );
  });

  testWidgets('root header has one glass surface and supports four actions', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_root(actionCount: 4)));

    final header = find.byKey(const ValueKey('tp-root-glass-header'));
    expect(
      find.descendant(
        of: header,
        matching: find.byKey(const ValueKey('tp-glass-surface')),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('tp-root-header-action-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('tp-root-header-action-3')),
      findsOneWidget,
    );
    await tester.pumpWidget(_app(_root(actionCount: 5)));
    expect(tester.takeException(), isAssertionError);
  });

  testWidgets('root text action keeps the full label and intrinsic width', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        TpRootScaffold(
          header: TpRootHeaderConfig(
            title: const Text('調整順序'),
            actions: [
              TpToolbarTextButton(label: '完成', onPressed: () {}),
              const SizedBox.square(dimension: 44),
            ],
          ),
          body: const SizedBox.expand(),
        ),
        mediaQueryData: const MediaQueryData(
          size: Size(390, 844),
          textScaler: TextScaler.linear(2),
        ),
      ),
    );

    final action = find.byKey(const ValueKey('tp-root-header-action-0'));
    expect(
      find.descendant(of: action, matching: find.text('完成')),
      findsOneWidget,
    );
    expect(tester.getSize(action).height, greaterThanOrEqualTo(44));
    expect(tester.getSize(action).width, greaterThan(44));
    expect(tester.takeException(), isNull);
  });

  testWidgets('scroll content starts clear then passes under fixed header', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        TpRootScaffold(
          showSoftEdge: true,
          header: const TpRootHeaderConfig(title: Text('我的行程')),
          body: TpRootScrollView(
            slivers: [
              SliverList.builder(
                itemCount: 30,
                itemBuilder: (context, index) => SizedBox(
                  height: 56,
                  child: Text(index == 0 ? '第一筆' : '第 ${index + 1} 筆'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final header = find.byKey(const ValueKey('tp-root-glass-header'));
    final headerBefore = tester.getRect(header);
    expect(
      tester.getRect(find.text('第一筆')).top,
      greaterThan(headerBefore.bottom),
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -320));
    await tester.pump();

    expect(tester.getRect(header), headerBefore);
    expect(find.byKey(const ValueKey('tp-root-soft-edge')), findsOneWidget);
  });

  testWidgets('200 percent text keeps HIG action targets and spacing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _root(actionCount: 2),
        mediaQueryData: const MediaQueryData(
          size: Size(390, 844),
          textScaler: TextScaler.linear(2),
        ),
      ),
    );

    final header = tester.getRect(
      find.byKey(const ValueKey('tp-root-glass-header')),
    );
    final first = tester.getRect(
      find.byKey(const ValueKey('tp-root-header-action-0')),
    );
    final second = tester.getRect(
      find.byKey(const ValueKey('tp-root-header-action-1')),
    );
    expect(first.size, const Size(44, 44));
    expect(second.size, const Size(44, 44));
    expect(second.left - first.right, 8);
    expect(header.right - second.right, 16);
    expect(find.text('京都五日行'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
