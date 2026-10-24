import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/app/app_feedback.dart';
import 'package:tripline/ui/tp_app_bar.dart';

void main() {
  testWidgets('外層 Scaffold 的橫幅已吃掉狀態列：內層 app bar 不再重複留 safe area', (
    tester,
  ) async {
    late BuildContext outer;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(top: 59),
            viewPadding: const EdgeInsets.only(top: 59),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              outer = context;
              return const AppErrorBannerInset(
                child: Scaffold(
                  appBar: TpAppBar(
                    role: TpAppBarRole.detail,
                    title: Text('探索'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    showAppError(outer, '載入失敗');
    await tester.pumpAndSettle();

    final bannerBottom = tester
        .getBottomLeft(find.byKey(const ValueKey('app-error-banner')))
        .dy;
    final titleTop = tester.getTopLeft(find.text('探索')).dy;
    // 標題置中在 56pt 的 bar 內，距橫幅底緣應小於一個 toolbar 高度。
    expect(titleTop - bannerBottom, lessThan(kToolbarHeight));

    await tester.tap(find.text('關閉'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('探索')).dy,
      greaterThanOrEqualTo(59),
      reason: '橫幅關閉後狀態列留白要回來',
    );
  });

  testWidgets('錯誤使用持續 banner，並可重試或關閉', (tester) async {
    var retryCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () =>
                  showAppError(context, '載入失敗', onRetry: () => retryCount++),
              child: const Text('觸發'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('觸發'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-error-banner')), findsOneWidget);
    expect(find.text('載入失敗'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();
    expect(retryCount, 1);
    expect(find.byKey(const ValueKey('app-error-banner')), findsNothing);
  });

  testWidgets('沒有重試動作時仍可明確關閉錯誤', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showAppError(context, '無法載入'),
              child: const Text('觸發'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('觸發'));
    await tester.pumpAndSettle();

    expect(find.text('重試'), findsNothing);
    await tester.tap(find.text('關閉'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-error-banner')), findsNothing);
  });

  testWidgets('不可關閉的錯誤必須提供重試 recovery', (tester) async {
    late BuildContext scaffoldContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              scaffoldContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(
      () => showAppError(scaffoldContext, '無法恢復', allowDismiss: false),
      throwsAssertionError,
    );
  });
}
