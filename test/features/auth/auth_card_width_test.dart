import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/app/adaptive_content.dart';
import 'package:tripline/features/auth/account_flow_screens.dart';
import 'package:tripline/features/auth/login_screen.dart';
import 'package:tripline/theme/app_theme.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  const authCardKey = ValueKey('auth-card');

  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    when(() => mockAuthRepository.currentUser()).thenAnswer((_) async => null);
  });

  /// 把單一認證畫面包進假 GoRouter，量測卡片實際算繪出來的寬度。
  ///
  /// 量「算繪後」而非讀 `BoxConstraints.maxWidth`：宣告了約束不代表約束真的生效
  /// —— 外層若有人再包一層覆寫，讀常數看不出來，量出來的寬度才會露餡。
  Future<double> renderedCardWidth(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: GoRouter(
            routes: [GoRoute(path: '/', builder: (context, state) => screen)],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.getSize(find.byKey(authCardKey)).width;
  }

  testWidgets('login 與 _AuthScaffold 的認證卡片寬度必須一致', (tester) async {
    // 這兩個畫面是同一張視覺卡片的不同內容。先前 login_screen 寫死 400、
    // _AuthScaffold 寫死 420，兩份實作各自漂移 —— 使用者在 login → 忘記密碼
    // 之間切換時卡片會橫向跳動。這個測試守的就是「不再漂移」。
    final loginWidth = await renderedCardWidth(tester, const LoginScreen());
    final forgotWidth = await renderedCardWidth(
      tester,
      const ForgotPasswordScreen(),
    );

    expect(loginWidth, forgotWidth);
    // 兩邊一致但一起壞掉（例如被外層壓成滿版）也要抓得到。
    expect(loginWidth, AppContentWidth.authCard);
  });
}
