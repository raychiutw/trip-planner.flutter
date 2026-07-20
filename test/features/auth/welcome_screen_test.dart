import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/features/auth/welcome_screen.dart';
import 'package:tripline/theme/app_theme.dart';

void main() {
  Future<void> pumpWelcome(
    WidgetTester tester, {
    required VoidCallback onLogin,
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: WelcomeScreen(onLogin: onLogin),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('直接顯示主訴求、三項功能與登入 CTA', (tester) async {
    var loginCount = 0;
    await pumpWelcome(tester, onLogin: () => loginCount++);

    expect(find.text('行程排壞了，講一句話就好', findRichText: true), findsOneWidget);
    expect(find.text('說一句話就改好'), findsOneWidget);
    expect(find.text('每天的路線一眼看完'), findsOneWidget);
    expect(find.text('出發前先健檢'), findsOneWidget);
    expect(find.text('隱私權政策'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('welcome-login-hero')));
    expect(loginCount, 1);
  });

  testWidgets('頁尾 CTA 可捲到並直接登入', (tester) async {
    var loginCount = 0;
    await pumpWelcome(tester, onLogin: () => loginCount++);

    final bottom = find.byKey(const ValueKey('welcome-login-bottom'));
    await tester.scrollUntilVisible(
      bottom,
      500,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('welcome-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(bottom);
    await tester.pumpAndSettle();
    await tester.tap(bottom);

    expect(loginCount, 1);
  });

  testWidgets('寬畫面與 200% 字級不溢位', (tester) async {
    await pumpWelcome(
      tester,
      onLogin: () {},
      size: const Size(1024, 900),
      textScale: 2,
    );
    await tester.drag(
      find.byKey(const ValueKey('welcome-scroll')),
      const Offset(0, -2000),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
