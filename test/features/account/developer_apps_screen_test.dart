import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/account/developer_apps_screen.dart';
import 'package:tripline/models/oauth.dart';
import 'package:tripline/theme/app_theme.dart';

class MockTripRepository extends Mock implements TripRepository {}

void main() {
  late MockTripRepository mockTripRepository;

  const developerApp = DeveloperApp(
    clientId: 'tp_dev',
    clientType: 'public',
    appName: 'Dev App',
    homepageUrl: 'https://dev.example.com',
    redirectUris: ['https://dev.example.com/callback'],
    allowedScopes: ['openid', 'profile'],
    status: 'pending_review',
    createdAt: '2026-07-08T10:00:00Z',
    updatedAt: '2026-07-08T10:00:00Z',
  );

  setUp(() {
    mockTripRepository = MockTripRepository();
    when(
      () => mockTripRepository.fetchDeveloperApps(),
    ).thenAnswer((_) async => const [developerApp]);
    when(
      () => mockTripRepository.createDeveloperApp(
        appName: any(named: 'appName'),
        clientType: any(named: 'clientType'),
        redirectUris: any(named: 'redirectUris'),
        allowedScopes: any(named: 'allowedScopes'),
        appDescription: any(named: 'appDescription'),
        homepageUrl: any(named: 'homepageUrl'),
      ),
    ).thenAnswer(
      (_) async => const CreatedDeveloperApp(
        clientId: 'tp_new',
        appName: 'New App',
        clientType: 'public',
        status: 'pending_review',
        redirectUris: ['https://new.example.com/callback'],
        allowedScopes: ['openid', 'email'],
      ),
    );
  });

  Future<void> pumpList(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tripRepositoryProvider.overrideWithValue(mockTripRepository),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const DeveloperAppsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpForm(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tripRepositoryProvider.overrideWithValue(mockTripRepository),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const DeveloperAppNewScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('列出 developer apps 並顯示新增入口', (tester) async {
    await pumpList(tester);

    expect(find.text('開發者應用'), findsOneWidget);
    expect(find.text('Dev App'), findsOneWidget);
    expect(find.text('待審核'), findsOneWidget);
    expect(find.byKey(const Key('developer-apps-new')), findsOneWidget);
  });

  testWidgets('新增 app 表單送出 redirect URI 與 scopes', (tester) async {
    await pumpForm(tester);

    await tester.enterText(
      find.byKey(const Key('developer-app-name')),
      'New App',
    );
    await tester.enterText(
      find.byKey(const Key('developer-app-redirect-uris')),
      'https://new.example.com/callback',
    );
    await tester.tap(find.byKey(const Key('developer-app-scope-email')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('developer-app-create-submit')));
    await tester.pumpAndSettle();

    verify(
      () => mockTripRepository.createDeveloperApp(
        appName: 'New App',
        clientType: 'public',
        redirectUris: const ['https://new.example.com/callback'],
        allowedScopes: const ['openid', 'profile', 'email'],
        appDescription: null,
        homepageUrl: null,
      ),
    ).called(1);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('tp_new'), findsOneWidget);
  });
}
