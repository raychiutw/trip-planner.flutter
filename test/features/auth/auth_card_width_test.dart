import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/app/adaptive_content.dart';
import 'package:tripline/features/auth/account_flow_screens.dart';
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

  testWidgets('_AuthScaffold 的認證卡片寬度符合 AppContentWidth.authCard', (
    tester,
  ) async {
    // 登入頁已併入歡迎頁，認證卡片只剩帳號流程頁共用 _AuthScaffold；
    // 量算繪後寬度，抓得到被外層壓成滿版的情況。
    final forgotWidth = await renderedCardWidth(
      tester,
      const ForgotPasswordScreen(),
    );

    expect(forgotWidth, AppContentWidth.authCard);
  });
}
