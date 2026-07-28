/// 產品控制在所有平台共用 Apple HIG 行為。
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/app/adaptive.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_action_item.dart';

void main() {
  Widget host(TargetPlatform platform, void Function(BuildContext) onTap) {
    return MaterialApp(
      theme: ThemeData(platform: platform),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => onTap(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
  }

  testWidgets('iOS 日期選擇器沿用 locale 並停用範圍外日期', (tester) async {
    const locale = Locale('zh', 'TW');
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        supportedLocales: const [locale],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => unawaited(
                showAppDatePicker(
                  context,
                  initialDate: DateTime(2026, 4, 24),
                  firstDate: DateTime(2026, 4, 23),
                  lastDate: DateTime(2026, 4, 25),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final picker = tester.widget<CalendarDatePicker>(
      find.byType(CalendarDatePicker),
    );
    expect(picker.initialDate, DateTime(2026, 4, 24));
    expect(picker.firstDate, DateTime(2026, 4, 23));
    expect(picker.lastDate, DateTime(2026, 4, 25));
    expect(
      Localizations.localeOf(tester.element(find.byType(CalendarDatePicker))),
      locale,
    );
  });

  testWidgets('iOS 日期選擇器取消不回寫，完成才回傳選取日期', (tester) async {
    late Future<DateTime?> result;
    await tester.pumpWidget(
      host(TargetPlatform.iOS, (context) {
        result = showAppDatePicker(
          context,
          initialDate: DateTime(2026, 4, 24),
          firstDate: DateTime(2026, 4, 23),
          lastDate: DateTime(2026, 4, 25),
        );
      }),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消').last);
    await tester.pumpAndSettle();
    expect(await result, isNull);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    tester
        .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
        .onDateChanged(DateTime(2026, 4, 25));
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(await result, DateTime(2026, 4, 25));
  });

  testWidgets('Android 日期也使用同一個 calendar sheet', (tester) async {
    await tester.pumpWidget(
      host(TargetPlatform.android, (context) {
        unawaited(
          showAppDatePicker(
            context,
            initialDate: DateTime(2026, 4, 24),
            firstDate: DateTime(2026, 4, 23),
            lastDate: DateTime(2026, 4, 25),
          ),
        );
      }),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(CalendarDatePicker), findsOneWidget);
    expect(find.byType(CupertinoDatePicker), findsNothing);
    expect(find.byType(DatePickerDialog), findsNothing);
  });

  testWidgets('iOS 完成回傳 wheel 顯示的五分鐘值，取消不回寫', (tester) async {
    late Future<TimeOfDay?> result;
    await tester.pumpWidget(
      host(TargetPlatform.iOS, (context) {
        result = showAppTimePicker(
          context,
          initialTime: const TimeOfDay(hour: 10, minute: 7),
        );
      }),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final picker = tester.widget<CupertinoDatePicker>(
      find.byType(CupertinoDatePicker),
    );
    expect(picker.initialDateTime, DateTime(2000, 1, 1, 10, 5));
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(await result, const TimeOfDay(hour: 10, minute: 5));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消').last);
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });

  testWidgets('Android 也使用五分鐘 wheel，完成回傳所見值且取消不回寫', (tester) async {
    late Future<TimeOfDay?> result;
    await tester.pumpWidget(
      host(TargetPlatform.android, (context) {
        result = showAppTimePicker(
          context,
          initialTime: const TimeOfDay(hour: 10, minute: 7),
        );
      }),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final picker = tester.widget<CupertinoDatePicker>(
      find.byType(CupertinoDatePicker),
    );
    expect(picker.minuteInterval, 5);
    expect(picker.initialDateTime, DateTime(2000, 1, 1, 10, 5));
    picker.onDateTimeChanged(DateTime(2000, 1, 1, 10, 10));
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    expect(await result, const TimeOfDay(hour: 10, minute: 10));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消').last);
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });

  testWidgets('iOS → CupertinoAlertDialog + 破壞性 action;確認回傳 true', (
    tester,
  ) async {
    late Future<bool> future;
    await tester.pumpWidget(
      host(TargetPlatform.iOS, (context) {
        future = showAppConfirm(
          context,
          title: '刪除停留點',
          message: '確定要刪除嗎?',
          confirmLabel: '刪除',
          isDestructive: true,
        );
      }),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    final actions = tester
        .widgetList<CupertinoDialogAction>(find.byType(CupertinoDialogAction))
        .toList();
    expect(actions.first.isDefaultAction, isTrue);
    expect(actions.last.isDestructiveAction, isTrue);
    expect(actions.last.isDefaultAction, isFalse);

    await tester.tap(find.widgetWithText(CupertinoDialogAction, '刪除'));
    await tester.pumpAndSettle();
    expect(await future, isTrue);
  });

  testWidgets('Android 破壞性確認也由安全選項取得預設動作', (tester) async {
    await tester.pumpWidget(
      host(TargetPlatform.android, (context) {
        unawaited(
          showAppConfirm(
            context,
            title: '刪除收藏',
            confirmLabel: '刪除',
            isDestructive: true,
          ),
        );
      }),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    final actions = tester
        .widgetList<CupertinoDialogAction>(find.byType(CupertinoDialogAction))
        .toList();
    expect(actions.first.isDefaultAction, isTrue);
    expect(actions.last.isDestructiveAction, isTrue);
  });

  testWidgets('Android → CupertinoAlertDialog;取消回傳 false', (tester) async {
    late Future<bool> future;
    await tester.pumpWidget(
      host(TargetPlatform.android, (context) {
        future = showAppConfirm(context, title: '登出帳號', confirmLabel: '登出');
      }),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(find.widgetWithText(CupertinoDialogAction, '取消'));
    await tester.pumpAndSettle();
    expect(await future, isFalse);
  });

  group('選單來源的破壞性確認', () {
    Widget destructiveHost({
      required TpDestructiveConfirmSource source,
      TextScaler textScaler = TextScaler.noScaling,
      FocusNode? triggerFocus,
      void Function(Future<bool>)? capture,
      ThemeData? theme,
      Brightness platformBrightness = Brightness.light,
      String title = '刪除停留點',
      String message = '刪除「首里城」後，相關交通時間將重新計算。此動作無法復原。',
    }) {
      return MaterialApp(
        theme: theme ?? AppTheme.light(),
        // Dynamic Type 與 appearance 要掛在 Navigator 之上，modal popup 才吃得
        // 到 —— 掛在 `home` 裡面的話 overlay 讀不到，量到的會是未縮放的假結果。
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: textScaler,
            platformBrightness: platformBrightness,
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                focusNode: triggerFocus,
                onPressed: () {
                  final future = showAppDestructiveConfirm(
                    context,
                    source: source,
                    title: title,
                    message: message,
                    confirmLabel: '刪除',
                  );
                  if (capture == null) {
                    unawaited(future);
                  } else {
                    capture(future);
                  }
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
    }

    /// 讀 widget **實際畫出來**的文字顏色。
    ///
    /// 不可改成 resolve 一次 `CupertinoColors.destructiveRed` 再跟 theme token
    /// 互比 —— 那是拿兩個常數對撞，widget 畫成什麼顏色完全不在斷言範圍內。
    Color? paintedColorOf(WidgetTester tester, Finder text) =>
        tester.renderObject<RenderParagraph>(text).text.style?.color;

    Finder confirmActionText() => find.descendant(
      of: find.widgetWithText(CupertinoActionSheetAction, '刪除'),
      matching: find.text('刪除'),
    );

    testWidgets('選單來源出 action sheet 而不是 alert，確認回傳 true', (tester) async {
      late Future<bool> future;
      await tester.pumpWidget(
        destructiveHost(
          source: TpDestructiveConfirmSource.menu,
          capture: (value) => future = value,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoActionSheet), findsOneWidget);
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(find.text('刪除停留點'), findsOneWidget);
      expect(find.textContaining('相關交通時間將重新計算'), findsOneWidget);

      await tester.tap(find.widgetWithText(CupertinoActionSheetAction, '刪除'));
      await tester.pumpAndSettle();
      expect(await future, isTrue);
    });

    testWidgets('取消可辨識且回傳 false', (tester) async {
      late Future<bool> future;
      await tester.pumpWidget(
        destructiveHost(
          source: TpDestructiveConfirmSource.menu,
          capture: (value) => future = value,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final cancel = find.widgetWithText(CupertinoActionSheetAction, '取消');
      expect(cancel, findsOneWidget);
      expect(
        tester.widget<CupertinoActionSheetAction>(cancel).isDestructiveAction,
        isFalse,
      );

      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(await future, isFalse);
    });

    testWidgets('破壞性項目畫出來的就是 Light 的 error 語意色', (tester) async {
      await tester.pumpWidget(
        destructiveHost(source: TpDestructiveConfirmSource.menu),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final confirm = find.widgetWithText(CupertinoActionSheetAction, '刪除');
      expect(
        tester.widget<CupertinoActionSheetAction>(confirm).isDestructiveAction,
        isTrue,
      );

      final painted = paintedColorOf(tester, confirmActionText());
      final expected = Theme.of(tester.element(confirm)).colorScheme.error;
      expect(painted, isSameColorAs(expected));
      // 取消項不得跟著變紅 —— 兩者同色的話上面那條也會恆真。
      final cancel = find.widgetWithText(CupertinoActionSheetAction, '取消');
      final cancelPainted = paintedColorOf(
        tester,
        find.descendant(of: cancel, matching: find.text('取消')),
      );
      expect(cancelPainted, isNot(isSameColorAs(expected)));
    });

    testWidgets('破壞性項目畫出來的就是 Dark 的 error 語意色', (tester) async {
      await tester.pumpWidget(
        destructiveHost(
          source: TpDestructiveConfirmSource.menu,
          theme: AppTheme.dark(),
          platformBrightness: Brightness.dark,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final confirm = find.widgetWithText(CupertinoActionSheetAction, '刪除');
      final painted = paintedColorOf(tester, confirmActionText());
      final expected = Theme.of(tester.element(confirm)).colorScheme.error;
      expect(painted, isSameColorAs(expected));
      // Dark 的 error 與 Light 不同色；不加這條就分不出「真的讀到深色」還是
      // 「深色情境根本沒生效、量到的其實是淺色」。
      expect(painted, isNot(isSameColorAs(AppTheme.light().colorScheme.error)));
    });

    // 真實呼叫端會把使用者可控的內容插進 title（共編的 email、分享的標籤）
    // 或 message（時間軸的停留點名稱），所以量的是那些形狀，不是短字串。
    //
    // 守到的界線（實測，非估算；量法見下方 reason）：
    // 螢幕 375×667（iOS 16 最小支援尺寸 iPhone SE 2/3、iPhone 8）、
    // Dynamic Type 3.2×（iOS 無障礙上限 AX5）時，
    // title ≤ 3 行 + message ≤ 4 行 → sheet 高 563.5pt，不捲動。
    // 這是靠 `showAppActionSheet` 對 title/message 截行換來的：**不截行的話，
    // 同樣內容在同樣條件下實測會捲動**（title 版 maxScrollExtent 215.4、
    // message 版 5.4）。行數上限再放寬到 title 3 + message 6 仍不捲，
    // 但 title 6 行就會捲 —— 也就是說「內容無限長就一定不捲」並不成立，
    // 守住的是「截行之後不捲」。
    const longEmail =
        'wanderlust.itinerary.planner+okinawa2026@long-domain-example.com.tw';
    const longPoi = '沖繩美麗海水族館黑潮之海大水槽與鯨鯊觀賞區（本部町國營沖繩紀念公園內）';
    const longShareLabel =
        '沖繩五天四夜家族旅遊完整行程（含來回班機、飯店訂房代號與租車資訊，給爸媽與弟弟妹妹看的公開唯讀版本，請勿外流）';

    for (final scenario in [
      (
        name: '長 email 進 title（共編移除成員）',
        title: '移除「$longEmail」？',
        message: '這位成員將失去此行程的存取權，且無法復原。',
      ),
      (
        name: '長分享標籤進 title（撤銷分享連結）',
        title: '撤銷「$longShareLabel」？',
        message: '這個分享連結將立即失效，且無法復原。',
      ),
      (
        name: '長停留點名稱進 message（時間軸刪除景點）',
        title: '刪除停留點',
        message: '刪除「$longPoi」後，相關交通時間將重新計算。此動作無法復原。',
      ),
    ]) {
      testWidgets('最小螢幕 + 最大 Dynamic Type 下不捲動：${scenario.name}', (
        tester,
      ) async {
        // iOS 16 起最小的支援尺寸（iPhone SE 2/3、iPhone 8）。
        tester.view.physicalSize = const Size(375, 667);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          destructiveHost(
            source: TpDestructiveConfirmSource.menu,
            // iOS 無障礙級別的最大 Dynamic Type（AX5）。
            textScaler: const TextScaler.linear(3.2),
            title: scenario.title,
            message: scenario.message,
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        // 先確認放大真的傳到了 sheet —— 否則下面的「不捲動」是恆真的假綠燈。
        final sheet = find.byType(CupertinoActionSheet);
        expect(tester.getSize(sheet).height, greaterThan(300));

        final scrollables = find.descendant(
          of: sheet,
          matching: find.byType(Scrollable),
        );
        expect(scrollables, findsWidgets);
        for (final element in scrollables.evaluate()) {
          final state = (element as StatefulElement).state as ScrollableState;
          expect(
            state.position.maxScrollExtent,
            0,
            reason:
                'action sheet 不得捲動（HIG action-sheets：Avoid letting an '
                'action sheet scroll）',
          );
        }
      });
    }

    testWidgets('action sheet 接管焦點，關閉後焦點回到原處', (tester) async {
      final triggerFocus = FocusNode(debugLabel: 'trigger');
      addTearDown(triggerFocus.dispose);

      await tester.pumpWidget(
        destructiveHost(
          source: TpDestructiveConfirmSource.menu,
          triggerFocus: triggerFocus,
        ),
      );
      triggerFocus.requestFocus();
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, triggerFocus);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, isNot(triggerFocus));

      await tester.tap(find.widgetWithText(CupertinoActionSheetAction, '取消'));
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, triggerFocus);
    });

    testWidgets('非選單來源維持 alert', (tester) async {
      late Future<bool> future;
      await tester.pumpWidget(
        destructiveHost(
          source: TpDestructiveConfirmSource.direct,
          capture: (value) => future = value,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.byType(CupertinoActionSheet), findsNothing);

      await tester.tap(find.widgetWithText(CupertinoDialogAction, '刪除'));
      await tester.pumpAndSettle();
      expect(await future, isTrue);
    });

    testWidgets('regular size class 不出貼底的 action sheet', (tester) async {
      // iPad 直向。regular size class 的判定沿用 `showAppContentSheet` 的
      // 同一條規則，不另訂寬度門檻。
      tester.view.physicalSize = const Size(1024, 1366);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late Future<bool> future;
      await tester.pumpWidget(
        destructiveHost(
          source: TpDestructiveConfirmSource.menu,
          capture: (value) => future = value,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoActionSheet), findsNothing);
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);

      await tester.tap(find.widgetWithText(CupertinoDialogAction, '刪除'));
      await tester.pumpAndSettle();
      expect(await future, isTrue);
    });

    testWidgets('compact size class 仍出 action sheet', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        destructiveHost(source: TpDestructiveConfirmSource.menu),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoActionSheet), findsOneWidget);
      expect(find.byType(CupertinoAlertDialog), findsNothing);
    });
  });

  testWidgets('iOS → CupertinoActionSheet;選破壞性動作回傳其值', (tester) async {
    late Future<String?> future;
    await tester.pumpWidget(
      host(TargetPlatform.iOS, (context) {
        future = showAppActionSheet<String>(
          context,
          actions: const [
            TpActionItem(label: '分享', value: 'share', icon: Icons.share),
            TpActionItem(
              label: '刪除',
              value: 'delete',
              icon: CupertinoIcons.delete,
              role: TpActionRole.destructive,
            ),
          ],
        );
      }),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoActionSheet), findsOneWidget);
    await tester.tap(find.widgetWithText(CupertinoActionSheetAction, '刪除'));
    await tester.pumpAndSettle();
    expect(await future, 'delete');
  });

  testWidgets('Android → CupertinoActionSheet;取消回傳 null', (tester) async {
    late Future<String?> future;
    await tester.pumpWidget(
      host(TargetPlatform.android, (context) {
        future = showAppActionSheet<String>(
          context,
          actions: const [
            TpActionItem(label: '分享', value: 'share', icon: Icons.share),
          ],
        );
      }),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoActionSheet), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    await tester.tap(find.widgetWithText(CupertinoActionSheetAction, '取消'));
    await tester.pumpAndSettle();
    expect(await future, isNull);
  });

  testWidgets('Android action sheet 保留 disabled 語意', (tester) async {
    await tester.pumpWidget(
      host(TargetPlatform.android, (context) {
        showAppActionSheet<String>(
          context,
          actions: const [
            TpActionItem(label: '分享', value: 'share', icon: Icons.share),
            TpActionItem(
              label: '刪除',
              value: 'delete',
              icon: CupertinoIcons.delete,
              dividerBefore: true,
              role: TpActionRole.destructive,
              enabled: false,
            ),
          ],
        );
      }),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoActionSheet), findsOneWidget);
    final disabledAction = find.widgetWithText(
      CupertinoActionSheetAction,
      '刪除',
    );
    expect(disabledAction, findsOneWidget);
    expect(
      tester
          .widgetList<Semantics>(
            find.ancestor(of: disabledAction, matching: find.byType(Semantics)),
          )
          .any((widget) => widget.properties.enabled == false),
      isTrue,
    );
  });

  testWidgets('Android Cupertino action sheet 可在短螢幕捲動長清單', (tester) async {
    tester.view.physicalSize = const Size(390, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late Future<String?> future;
    await tester.pumpWidget(
      host(TargetPlatform.android, (context) {
        future = showAppActionSheet<String>(
          context,
          actions: const [
            TpActionItem(label: '分享', value: 'share', icon: Icons.share),
            TpActionItem(label: '共編設定', value: 'collab', icon: Icons.group),
            TpActionItem(
              label: 'AI 健檢',
              value: 'health',
              icon: Icons.health_and_safety,
            ),
            TpActionItem(
              label: '匯出 JSON',
              value: 'export',
              icon: Icons.download,
            ),
            TpActionItem(
              label: '刪除行程',
              value: 'delete',
              icon: CupertinoIcons.delete,
              dividerBefore: true,
              role: TpActionRole.destructive,
            ),
          ],
        );
      }),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('刪除行程'),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('刪除行程'));
    await tester.pumpAndSettle();

    expect(await future, 'delete');
    expect(tester.takeException(), isNull);
  });

  testWidgets('action sheets render the shared selected checkmark', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(TargetPlatform.android, (context) {
        showAppActionSheet<String>(
          context,
          actions: const [
            TpActionItem(
              label: '最近加入',
              value: 'recent',
              icon: CupertinoIcons.clock,
              selected: true,
            ),
          ],
        );
      }),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byIcon(CupertinoIcons.check_mark), findsOneWidget);
  });

  testWidgets('iOS action sheet does not dispatch a disabled action', (
    tester,
  ) async {
    var completed = false;
    await tester.pumpWidget(
      host(TargetPlatform.iOS, (context) {
        showAppActionSheet<String>(
          context,
          actions: const [
            TpActionItem(
              label: '暫不可用',
              value: 'disabled',
              icon: CupertinoIcons.lock,
              enabled: false,
            ),
          ],
        ).then((_) => completed = true);
      }),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('暫不可用'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoActionSheet), findsOneWidget);
    expect(completed, isFalse);
  });

  testWidgets('iOS → 頂部橫幅顯示訊息(非 SnackBar);結束不留 pending timer', (tester) async {
    await tester.pumpWidget(
      host(TargetPlatform.iOS, (context) {
        showAppNotice(context, '已登出該裝置');
      }),
    );
    await tester.tap(find.text('open'));
    await tester.pump(); // 插入 overlay + 排程 post-frame
    await tester.pump(const Duration(milliseconds: 300)); // 滑入動畫

    expect(find.text('已登出該裝置'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(
      tester
          .widgetList<Semantics>(find.byType(Semantics))
          .any(
            (widget) =>
                widget.properties.liveRegion == true &&
                widget.properties.label == '已登出該裝置',
          ),
      isTrue,
    );
    // 不推進到 2.5s;測試結束時 tree 拆除須取消 timer,否則框架報 pending timer。
  });

  testWidgets('Android → 頂部橫幅顯示訊息而非 SnackBar', (tester) async {
    await tester.pumpWidget(
      host(TargetPlatform.android, (context) {
        showAppNotice(context, '已刪除');
      }),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('已刪除'), findsOneWidget);
  });

  testWidgets('頂部橫幅不攔截底下 44pt toolbar 動作', (tester) async {
    var actionCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              SizedBox.square(
                dimension: 44,
                child: IconButton(
                  key: const ValueKey('notice-underlying-action'),
                  onPressed: () => actionCount++,
                  icon: const Icon(CupertinoIcons.ellipsis),
                ),
              ),
            ],
          ),
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAppNotice(context, '已完成'),
              child: const Text('顯示提示'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('顯示提示'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('已完成'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('notice-underlying-action'))),
      const Size(44, 44),
    );
    await tester.tap(find.byKey(const ValueKey('notice-underlying-action')));
    expect(actionCount, 1);
  });

  testWidgets('unsaved guard coalesces concurrent close requests', (
    tester,
  ) async {
    final controller = AppUnsavedChangesController();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: AppUnsavedChangesGuard(
          controller: controller,
          hasChanges: true,
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                unawaited(controller.requestPop());
                unawaited(controller.requestPop());
              },
              child: const Text('close twice'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('close twice'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
  });

  Widget searchHost(TargetPlatform platform, TextEditingController controller) {
    return MaterialApp(
      theme: ThemeData(platform: platform),
      home: Scaffold(
        body: AppSearchField(
          fieldKey: const ValueKey('search'),
          controller: controller,
          placeholder: '搜尋',
        ),
      ),
    );
  }

  testWidgets('AppSearchField iOS → CupertinoSearchTextField;enterText 生效', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(searchHost(TargetPlatform.iOS, controller));

    expect(find.byType(CupertinoSearchTextField), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('search')), '沖繩');
    expect(controller.text, '沖繩');
  });

  testWidgets('AppSearchField Android → CupertinoSearchTextField', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(searchHost(TargetPlatform.android, controller));

    expect(find.byType(CupertinoSearchTextField), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('search')), '釜山');
    expect(controller.text, '釜山');
  });

  testWidgets('AppSearchField debounce 只送出停止輸入後的最新文字', (tester) async {
    final controller = TextEditingController();
    final changes = <String>[];
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppSearchField(
            fieldKey: const ValueKey('search'),
            controller: controller,
            placeholder: '搜尋',
            debounce: const Duration(milliseconds: 300),
            onChanged: changes.add,
          ),
        ),
      ),
    );

    await tester.enterText(find.byKey(const ValueKey('search')), '東');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.byKey(const ValueKey('search')), '東京');
    await tester.pump(const Duration(milliseconds: 299));
    expect(changes, isEmpty);

    await tester.pump(const Duration(milliseconds: 1));
    expect(changes, ['東京']);
  });

  testWidgets('AppSearchField 搜尋送出會取消尚未觸發的 debounce', (tester) async {
    final controller = TextEditingController();
    final changes = <String>[];
    final submissions = <String>[];
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppSearchField(
            fieldKey: const ValueKey('search'),
            controller: controller,
            placeholder: '搜尋',
            debounce: const Duration(milliseconds: 300),
            onChanged: changes.add,
            onSubmitted: submissions.add,
          ),
        ),
      ),
    );

    await tester.enterText(find.byKey(const ValueKey('search')), '東京');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();

    expect(submissions, ['東京']);
    expect(changes, isEmpty);

    await tester.pump(const Duration(milliseconds: 300));
    expect(changes, isEmpty);
  });
}
