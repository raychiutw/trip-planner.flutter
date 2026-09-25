import 'dart:ui' show Tristate;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/features/trips/trip_title_button.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_root_scaffold.dart';

void main() {
  testWidgets('最大字級搜尋無結果可朗讀並可清除後選取行程', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    String? selected;
    try {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(3.2)),
            child: child!,
          ),
          home: Scaffold(
            body: TripTitleButton(
              currentTripId: 'trip-1',
              currentTitle: '東京五日行',
              trips: const [
                TripSummary(tripId: 'trip-1', name: '東京五日行'),
                TripSummary(tripId: 'trip-2', name: '沖繩五日行'),
              ],
              onSelected: (value) => selected = value,
            ),
          ),
        ),
      );
      await tester.tap(find.text('東京五日行'));
      await tester.pumpAndSettle();
      final search = find.byKey(const ValueKey('trip-picker-search'));
      await tester.enterText(search, '不存在的行程');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final empty = find.text('找不到行程');
      expect(empty, findsOneWidget);
      final emptySemantics = tester.getSemantics(empty);
      expect(emptySemantics.label, contains('找不到行程'));
      expect(emptySemantics.flagsCollection.isLiveRegion, isTrue);
      expect(selected, isNull);

      final clearLabel = CupertinoLocalizations.of(
        tester.element(search),
      ).clearButtonLabel;
      await tester.tap(find.bySemanticsLabel(clearLabel));
      await tester.pumpAndSettle();
      expect(find.text('找不到行程'), findsNothing);
      await tester.ensureVisible(find.text('沖繩五日行'));
      await tester.tap(find.text('沖繩五日行'));
      await tester.pumpAndSettle();
      expect(selected, 'trip-2');
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('清除行程搜尋恢復完整清單並保留目前行程', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripTitleButton(
            currentTripId: 'trip-1',
            currentTitle: '東京五日行',
            trips: const [
              TripSummary(tripId: 'trip-1', name: '東京五日行'),
              TripSummary(tripId: 'trip-2', name: '沖繩五日行'),
            ],
            onSelected: (_) => fail('清除搜尋不應切換目前行程'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('東京五日行'));
    await tester.pumpAndSettle();
    final search = find.byKey(const ValueKey('trip-picker-search'));
    final clearLabel = CupertinoLocalizations.of(
      tester.element(search),
    ).clearButtonLabel;
    expect(find.bySemanticsLabel(clearLabel), findsNothing);
    await tester.enterText(search, '沖繩');
    await tester.pumpAndSettle();
    expect(find.text('沖繩五日行'), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-picker-item-trip-1')), findsNothing);
    final clear = find.bySemanticsLabel(clearLabel);
    expect(clear, findsOneWidget);
    final clearSemantics = tester.getSemantics(clear);
    expect(clearSemantics.flagsCollection.isButton, isTrue);
    expect(clearSemantics.rect.width, greaterThanOrEqualTo(44));
    expect(clearSemantics.rect.height, greaterThanOrEqualTo(44));
    await tester.tapAt(tester.getCenter(clear) + const Offset(-20, 0));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(clearLabel), findsNothing);
    expect(find.text('沖繩五日行'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('trip-picker-item-trip-1')))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    expect(tester.testTextInput.editingState?['text'], isEmpty);
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('東京五日行'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('trip picker is a selection sheet', (tester) async {
    final semantics = tester.ensureSemantics();
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripTitleButton(
            currentTripId: 'trip-1',
            currentTitle: '東京五日行',
            trips: const [
              TripSummary(tripId: 'trip-1', name: '東京五日行'),
              TripSummary(tripId: 'trip-2', name: '沖繩五日行'),
            ],
            onSelected: (value) => selected = value,
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byKey(const ValueKey('trip-title-button'))),
      matchesSemantics(
        label: '目前行程',
        value: '東京五日行',
        hint: '點兩下切換行程',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    await tester.tap(find.text('東京五日行'));
    await tester.pumpAndSettle();
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('完成'), findsNothing);
    expect(find.byIcon(CupertinoIcons.check_mark), findsOneWidget);
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('trip-picker-item-trip-1')))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );

    await tester.tap(find.text('沖繩五日行'));
    await tester.pumpAndSettle();
    expect(selected, 'trip-2');
    semantics.dispose();
  });

  testWidgets('只有一個行程時停用 selector 並提供完整語意', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripTitleButton(
            currentTripId: 'trip-1',
            currentTitle: '東京五日行',
            trips: const [TripSummary(tripId: 'trip-1', name: '東京五日行')],
            onSelected: (_) => fail('單一行程不應開啟 selector'),
          ),
        ),
      ),
    );

    final title = find.byKey(const ValueKey('trip-title-button'));
    expect(find.byIcon(CupertinoIcons.chevron_down), findsNothing);
    expect(
      tester.widget<TextButton>(find.byType(TextButton)).onPressed,
      isNull,
    );
    expect(tester.getSize(title).width, greaterThanOrEqualTo(44));
    expect(tester.getSize(title).height, greaterThanOrEqualTo(44));
    expect(
      tester.getSemantics(title),
      matchesSemantics(
        label: '目前行程',
        value: '東京五日行',
        hint: '只有一個行程',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    semantics.dispose();
  });

  testWidgets('非媒體浮動 header 上單一行程的標題仍是完整 onSurface 前景', (tester) async {
    final theme = AppTheme.light();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: TpRootScaffold(
          header: TpRootHeaderConfig(
            title: TripTitleButton(
              currentTripId: 'trip-1',
              currentTitle: '東京五日行',
              trips: const [TripSummary(tripId: 'trip-1', name: '東京五日行')],
              onSelected: (_) => fail('單一行程不應開啟 selector'),
            ),
          ),
          body: const SizedBox.expand(),
        ),
      ),
    );

    // 停用的是切換，不是標題：文字色必須是完整前景，不能跟著按鈕降到 38%。
    expect(
      tester
          .renderObject<RenderParagraph>(find.text('東京五日行'))
          .text
          .style
          ?.color,
      theme.colorScheme.onSurface,
    );
  });
}
