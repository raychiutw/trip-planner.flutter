import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/account/connected_apps_screen.dart';
import 'package:tripline/models/oauth.dart';
import 'package:tripline/theme/app_theme.dart';

class MockTripRepository extends Mock implements TripRepository {}

void main() {
  late MockTripRepository mockTripRepository;

  const connectedApp = ConnectedApp(
    clientId: 'tp_alpha',
    appName: 'Alpha App',
    appDescription: '行程同步工具',
    homepageUrl: 'https://alpha.example.com',
    status: 'active',
    scopes: ['openid', 'email'],
    grantedAt: 1783500000000,
  );

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tripRepositoryProvider.overrideWithValue(mockTripRepository),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ConnectedAppsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    mockTripRepository = MockTripRepository();
    when(
      () => mockTripRepository.fetchConnectedApps(),
    ).thenAnswer((_) async => const [connectedApp]);
    when(
      () => mockTripRepository.revokeConnectedApp(any()),
    ).thenAnswer((_) async {});
  });

  testWidgets('列出已授權 app、使用者可理解的權限與日期', (tester) async {
    await pumpScreen(tester);

    expect(find.text('已連結的應用程式'), findsOneWidget);
    expect(find.text('Alpha App'), findsOneWidget);
    expect(find.text('行程同步工具'), findsOneWidget);
    expect(find.text('識別您的身分（唯一 ID）'), findsOneWidget);
    expect(find.text('您的電子郵件地址'), findsOneWidget);
    expect(find.text('openid'), findsNothing);
    expect(find.textContaining('1783500000000'), findsNothing);
    expect(find.textContaining('2026/7/8'), findsOneWidget);
  });

  testWidgets('撤銷 app 需確認，確認後呼叫 repository', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('connected-app-revoke-tp_alpha')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('撤銷 Alpha App？'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '撤銷'));
    await tester.pumpAndSettle();

    verify(() => mockTripRepository.revokeConnectedApp('tp_alpha')).called(1);
    expect(find.text('已撤銷 Alpha App'), findsOneWidget);
  });
}
