import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/features/auth/welcome_screen.dart';
import 'package:tripline/theme/app_theme.dart';

/// 歡迎頁「建立帳號」「忘記這支手機」兩個文字連結的文字左緣，要跟主標題、
/// 主按鈕的內容左緣對齊（Android 實機曾縮進約 30px）。iOS 與 Android、
/// 淺色與深色都必須是同一個位置。
void main() {
  const links = {
    'welcome-signup': '沒有帳號，建立帳號',
    'welcome-forget-phone': '忘記這支手機',
  };

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final brightness in Brightness.values) {
      testWidgets('連結文字左緣與主標題對齊（${platform.name}／${brightness.name}）', (
        tester,
      ) async {
        const size = Size(390, 844);
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final base = brightness == Brightness.light
            ? AppTheme.light()
            : AppTheme.dark();
        await tester.pumpWidget(
          MaterialApp(
            theme: base.copyWith(platform: platform),
            home: MediaQuery(
              data: MediaQueryData(size: size, platformBrightness: brightness),
              child: WelcomeScreen(
                onLogin: () {},
                onSignup: () {},
                keptAccount: '洋蔥',
                onForgetPhone: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final headlineLeft = tester
            .getTopLeft(find.byKey(const ValueKey('welcome-headline')))
            .dx;
        final accountLeft = tester
            .getTopLeft(find.byKey(const ValueKey('welcome-kept-account')))
            .dx;
        expect(accountLeft, closeTo(headlineLeft, 0.5), reason: '帳號列');

        for (final MapEntry(:key, :value) in links.entries) {
          final button = find.byKey(ValueKey(key));
          final textLeft = tester
              .getTopLeft(
                find.descendant(of: button, matching: find.text(value)),
              )
              .dx;
          expect(textLeft, closeTo(headlineLeft, 0.5), reason: value);
          // 去掉內距後，點擊區仍須至少 44pt 高。
          expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
        }
      });
    }
  }
}
