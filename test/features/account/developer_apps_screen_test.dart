import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'dart:async';
import 'dart:ui' show SemanticsAction;
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/account/developer_apps_screen.dart';
import 'package:tripline/models/oauth.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_app_bar.dart';

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
      () => mockTripRepository.fetchDeveloperApp('tp_dev'),
    ).thenAnswer((_) async => developerApp);
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
    when(
      () => mockTripRepository.updateDeveloperApp(
        clientId: any(named: 'clientId'),
        appName: any(named: 'appName'),
        appDescription: any(named: 'appDescription'),
        clearAppDescription: any(named: 'clearAppDescription'),
        homepageUrl: any(named: 'homepageUrl'),
        clearHomepageUrl: any(named: 'clearHomepageUrl'),
        redirectUris: any(named: 'redirectUris'),
        allowedScopes: any(named: 'allowedScopes'),
      ),
    ).thenAnswer((_) async => developerApp);
    when(
      () => mockTripRepository.suspendDeveloperApp(any()),
    ).thenAnswer((_) async => 'tp_dev');
  });

  Future<void> pumpList(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (retryCount, error) => null,
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

  Future<void> pumpForm(
    WidgetTester tester, {
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        retry: (retryCount, error) => null,
        overrides: [
          tripRepositoryProvider.overrideWithValue(mockTripRepository),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          ),
          home: const DeveloperAppNewScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpEditForm(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await pumpList(tester);
    await tester.tap(find.byKey(const Key('developer-app-row-tp_dev')));
    await tester.pumpAndSettle();
  }

  testWidgets('列出 developer apps 並顯示新增入口', (tester) async {
    await pumpList(tester);

    expect(find.text('開發者應用'), findsOneWidget);
    expect(find.text('Dev App'), findsOneWidget);
    expect(find.text('待審核'), findsOneWidget);
    expect(find.byKey(const Key('developer-apps-new')), findsOneWidget);
  });

  testWidgets('點選 developer app 會在同一個 Navigation Stack 開啟編輯表單', (tester) async {
    await pumpList(tester);

    await tester.tap(find.byKey(const Key('developer-app-row-tp_dev')));
    await tester.pumpAndSettle();

    expect(find.byType(DeveloperAppEditScreen), findsOneWidget);
    expect(find.text('編輯 OAuth 應用'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('developer-app-name')))
          .controller
          ?.text,
      'Dev App',
    );
    expect(find.byKey(const Key('developer-app-edit-submit')), findsOneWidget);
  });

  testWidgets('編輯頁 loading/error 保留返回與重試出口', (tester) async {
    final semantics = tester.ensureSemantics();
    final fetchCompleter = Completer<DeveloperApp>();
    when(
      () => mockTripRepository.fetchDeveloperApp('tp_dev'),
    ).thenAnswer((_) => fetchCompleter.future);
    await pumpList(tester);

    await tester.tap(find.byKey(const Key('developer-app-row-tp_dev')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.byKey(const ValueKey('developer-app-edit-loading')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('tp-app-bar-back')), findsOneWidget);

    fetchCompleter.completeError(Exception('offline'));
    await tester.pumpAndSettle();

    expect(find.text('無法載入應用程式'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '重試'), findsOneWidget);
    expect(find.byKey(const ValueKey('tp-app-bar-back')), findsOneWidget);
    expect(
      tester
          .getSemantics(find.byKey(const Key('developer-apps-load-error')))
          .getSemanticsData()
          .flagsCollection
          .isLiveRegion,
      isTrue,
    );
    semantics.dispose();
  });

  testWidgets('編輯 app 成功才返回清單，並只送出一次', (tester) async {
    final semantics = tester.ensureSemantics();
    final updateCompleter = Completer<DeveloperApp>();
    when(
      () => mockTripRepository.updateDeveloperApp(
        clientId: any(named: 'clientId'),
        appName: any(named: 'appName'),
        appDescription: any(named: 'appDescription'),
        clearAppDescription: any(named: 'clearAppDescription'),
        homepageUrl: any(named: 'homepageUrl'),
        clearHomepageUrl: any(named: 'clearHomepageUrl'),
        redirectUris: any(named: 'redirectUris'),
        allowedScopes: any(named: 'allowedScopes'),
      ),
    ).thenAnswer((_) => updateCompleter.future);
    await pumpEditForm(tester);

    await tester.enterText(
      find.byKey(const Key('developer-app-name')),
      'Renamed App',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('developer-app-edit-submit')));
    await tester.tap(find.byKey(const Key('developer-app-edit-submit')));
    await tester.pump();

    expect(
      find.byKey(const Key('developer-app-operation-progress')),
      findsOneWidget,
    );
    final editProgressSemantics = find.bySemanticsLabel('正在儲存應用程式');
    expect(editProgressSemantics, findsOneWidget);
    expect(
      tester
          .getSemantics(editProgressSemantics)
          .getSemanticsData()
          .flagsCollection
          .isLiveRegion,
      isTrue,
    );
    verify(
      () => mockTripRepository.updateDeveloperApp(
        clientId: 'tp_dev',
        appName: 'Renamed App',
        appDescription: null,
        clearAppDescription: true,
        homepageUrl: 'https://dev.example.com',
        clearHomepageUrl: false,
        redirectUris: const ['https://dev.example.com/callback'],
        allowedScopes: const ['openid', 'profile'],
      ),
    ).called(1);
    expect(find.byType(DeveloperAppEditScreen), findsOneWidget);

    updateCompleter.complete(
      const DeveloperApp(
        clientId: 'tp_dev',
        clientType: 'public',
        appName: 'Renamed App',
        homepageUrl: 'https://dev.example.com',
        redirectUris: ['https://dev.example.com/callback'],
        allowedScopes: ['openid', 'profile'],
        status: 'pending_review',
        createdAt: '2026-07-08T10:00:00Z',
        updatedAt: '2026-07-08T11:00:00Z',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DeveloperAppEditScreen), findsNothing);
    semantics.dispose();
  });

  testWidgets('更新後在同一個 ProviderScope 重新開啟會取得最新 detail', (tester) async {
    var detailApp = developerApp;
    when(
      () => mockTripRepository.fetchDeveloperApp('tp_dev'),
    ).thenAnswer((_) async => detailApp);
    when(
      () => mockTripRepository.updateDeveloperApp(
        clientId: any(named: 'clientId'),
        appName: any(named: 'appName'),
        appDescription: any(named: 'appDescription'),
        clearAppDescription: any(named: 'clearAppDescription'),
        homepageUrl: any(named: 'homepageUrl'),
        clearHomepageUrl: any(named: 'clearHomepageUrl'),
        redirectUris: any(named: 'redirectUris'),
        allowedScopes: any(named: 'allowedScopes'),
      ),
    ).thenAnswer((_) async {
      detailApp = const DeveloperApp(
        clientId: 'tp_dev',
        clientType: 'public',
        appName: 'Renamed App',
        homepageUrl: 'https://dev.example.com',
        redirectUris: ['https://dev.example.com/callback'],
        allowedScopes: ['openid', 'profile'],
        status: 'pending_review',
        createdAt: '2026-07-08T10:00:00Z',
        updatedAt: '2026-07-08T11:00:00Z',
      );
      return detailApp;
    });
    await pumpEditForm(tester);

    await tester.enterText(
      find.byKey(const Key('developer-app-name')),
      'Renamed App',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('developer-app-edit-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('developer-app-row-tp_dev')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('developer-app-name')))
          .controller
          ?.text,
      'Renamed App',
    );
    verify(
      () => mockTripRepository.fetchDeveloperApp('tp_dev'),
    ).called(greaterThanOrEqualTo(2));
  });

  testWidgets('編輯 app 失敗會保留輸入與留在原頁重試', (tester) async {
    when(
      () => mockTripRepository.updateDeveloperApp(
        clientId: any(named: 'clientId'),
        appName: any(named: 'appName'),
        appDescription: any(named: 'appDescription'),
        clearAppDescription: any(named: 'clearAppDescription'),
        homepageUrl: any(named: 'homepageUrl'),
        clearHomepageUrl: any(named: 'clearHomepageUrl'),
        redirectUris: any(named: 'redirectUris'),
        allowedScopes: any(named: 'allowedScopes'),
      ),
    ).thenThrow(Exception('offline'));
    await pumpEditForm(tester);

    await tester.enterText(
      find.byKey(const Key('developer-app-name')),
      '保留的名稱',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('developer-app-edit-submit')));
    await tester.pumpAndSettle();

    expect(find.text('儲存應用程式失敗，請稍後再試'), findsOneWidget);
    expect(find.text('保留的名稱'), findsOneWidget);
    expect(find.byType(DeveloperAppEditScreen), findsOneWidget);
  });

  testWidgets('刪除 developer app 需說明影響與不可復原，成功後才返回', (tester) async {
    final semantics = tester.ensureSemantics();
    final deleteCompleter = Completer<String>();
    when(
      () => mockTripRepository.suspendDeveloperApp('tp_dev'),
    ).thenAnswer((_) => deleteCompleter.future);
    await pumpEditForm(tester);

    final deleteButton = find.byKey(const Key('developer-app-delete'));
    await tester.ensureVisible(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(find.text('刪除 Dev App？'), findsOneWidget);
    expect(find.textContaining('無法復原'), findsOneWidget);
    verifyNever(() => mockTripRepository.suspendDeveloperApp(any()));

    await tester.tap(find.widgetWithText(FilledButton, '刪除'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    verify(() => mockTripRepository.suspendDeveloperApp('tp_dev')).called(1);
    expect(
      find.byKey(const Key('developer-app-operation-progress')),
      findsOneWidget,
    );
    final progressRect = tester.getRect(
      find.byKey(const Key('developer-app-operation-progress')),
    );
    final viewportHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(progressRect.top, greaterThanOrEqualTo(0));
    expect(progressRect.bottom, lessThanOrEqualTo(viewportHeight));
    final deleteProgressSemantics = find.bySemanticsLabel('正在刪除應用程式');
    expect(deleteProgressSemantics, findsOneWidget);
    expect(
      tester
          .getSemantics(deleteProgressSemantics)
          .getSemanticsData()
          .flagsCollection
          .isLiveRegion,
      isTrue,
    );
    deleteCompleter.complete('tp_dev');
    await tester.pumpAndSettle();
    expect(find.byType(DeveloperAppEditScreen), findsNothing);
    semantics.dispose();
  });

  testWidgets('刪除後在同一個 ProviderScope 重新開啟不會重現舊 detail', (tester) async {
    var deleted = false;
    when(() => mockTripRepository.fetchDeveloperApp('tp_dev')).thenAnswer((
      _,
    ) async {
      if (deleted) throw Exception('not found');
      return developerApp;
    });
    when(() => mockTripRepository.suspendDeveloperApp('tp_dev')).thenAnswer((
      _,
    ) async {
      deleted = true;
      return 'tp_dev';
    });
    await pumpEditForm(tester);

    await tester.tap(find.byKey(const Key('developer-app-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '刪除'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('developer-app-row-tp_dev')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('developer-app-name')), findsNothing);
    expect(find.text('無法載入應用程式'), findsOneWidget);
    verify(
      () => mockTripRepository.fetchDeveloperApp('tp_dev'),
    ).called(greaterThanOrEqualTo(2));
  });

  testWidgets('刪除 developer app 失敗會保留應用、頁面與重試操作', (tester) async {
    when(
      () => mockTripRepository.suspendDeveloperApp('tp_dev'),
    ).thenThrow(Exception('offline'));
    await pumpEditForm(tester);

    await tester.tap(find.byKey(const Key('developer-app-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '刪除'));
    await tester.pumpAndSettle();

    expect(find.text('刪除應用程式失敗，請稍後再試'), findsOneWidget);
    expect(find.byType(DeveloperAppEditScreen), findsOneWidget);
    expect(find.byKey(const Key('developer-app-delete')), findsOneWidget);
  });

  testWidgets('200% Dynamic Type、語意、鍵盤與表單動作維持 44pt', (tester) async {
    await pumpForm(tester, textScaler: const TextScaler.linear(2));
    final semantics = tester.ensureSemantics();

    final nameFinder = find.byKey(const Key('developer-app-name'));
    final cancelFinder = find.byKey(const ValueKey('tp-app-bar-cancel'));
    expect(tester.getSize(cancelFinder).height, greaterThanOrEqualTo(44));
    expect(tester.getSemantics(nameFinder).label, contains('應用程式名稱'));

    await tester.tap(nameFinder);
    await tester.enterText(nameFinder, 'Accessible App');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.enterText(
      find.byKey(const Key('developer-app-redirect-uris')),
      'https://accessible.example.com/callback',
    );
    await tester.pump();

    final submitFinder = find.byKey(const Key('developer-app-create-submit'));
    expect(tester.getSize(submitFinder).height, greaterThanOrEqualTo(44));
    final submitButton = find.descendant(
      of: submitFinder,
      matching: find.byType(TextButton),
    );
    expect(
      tester
          .getSemantics(submitButton)
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('軟體鍵盤 Next/Done 依表單順序移動焦點', (tester) async {
    await pumpForm(tester);

    EditableText editableText(String key) {
      return tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(Key(key)),
          matching: find.byType(EditableText),
        ),
      );
    }

    final name = editableText('developer-app-name');
    final description = editableText('developer-app-description');
    final homepage = editableText('developer-app-homepage');
    final redirectUris = editableText('developer-app-redirect-uris');

    expect(name.textInputAction, TextInputAction.next);
    expect(description.textInputAction, TextInputAction.next);
    expect(homepage.textInputAction, TextInputAction.next);
    expect(redirectUris.textInputAction, TextInputAction.done);

    await tester.tap(find.byKey(const Key('developer-app-name')));
    await tester.pump();
    expect(name.focusNode.hasFocus, isTrue);

    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(description.focusNode.hasFocus, isTrue);

    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(homepage.focusNode.hasFocus, isTrue);

    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(redirectUris.focusNode.hasFocus, isTrue);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(redirectUris.focusNode.hasFocus, isFalse);
  });

  testWidgets('新增 app pending 顯示可見且可朗讀的進度', (tester) async {
    final semantics = tester.ensureSemantics();
    final createCompleter = Completer<CreatedDeveloperApp>();
    when(
      () => mockTripRepository.createDeveloperApp(
        appName: any(named: 'appName'),
        clientType: any(named: 'clientType'),
        redirectUris: any(named: 'redirectUris'),
        allowedScopes: any(named: 'allowedScopes'),
        appDescription: any(named: 'appDescription'),
        homepageUrl: any(named: 'homepageUrl'),
      ),
    ).thenAnswer((_) => createCompleter.future);
    await pumpForm(tester);

    await tester.enterText(
      find.byKey(const Key('developer-app-name')),
      'New App',
    );
    await tester.enterText(
      find.byKey(const Key('developer-app-redirect-uris')),
      'https://new.example.com/callback',
    );
    await tester.tap(find.byKey(const Key('developer-app-create-submit')));
    await tester.pump();

    expect(
      find.byKey(const Key('developer-app-operation-progress')),
      findsOneWidget,
    );
    final createProgressSemantics = find.bySemanticsLabel('正在建立應用程式');
    expect(createProgressSemantics, findsOneWidget);
    expect(
      tester
          .getSemantics(createProgressSemantics)
          .getSemanticsData()
          .flagsCollection
          .isLiveRegion,
      isTrue,
    );

    createCompleter.complete(
      const CreatedDeveloperApp(
        clientId: 'tp_new',
        appName: 'New App',
        clientType: 'public',
        status: 'pending_review',
        redirectUris: ['https://new.example.com/callback'],
        allowedScopes: ['openid', 'profile'],
      ),
    );
    await tester.pumpAndSettle();
    semantics.dispose();
  });

  testWidgets('新增 app 表單送出 redirect URI 與 scopes', (tester) async {
    await pumpForm(tester);

    expect(find.text('取消'), findsOneWidget);
    expect(find.text('建立'), findsOneWidget);
    expect(find.byKey(const ValueKey('tp-app-bar-back')), findsNothing);

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
    // 自適應對話框:iOS/macOS 為 CupertinoAlertDialog、其餘為 AlertDialog。
    expect(
      find.byWidgetPredicate(
        (w) => w is AlertDialog || w is CupertinoAlertDialog,
      ),
      findsOneWidget,
    );
    expect(find.text('tp_new'), findsOneWidget);
  });

  testWidgets('新增 app 填寫後取消會確認捨棄未儲存變更', (tester) async {
    await pumpForm(tester);

    await tester.enterText(
      find.byKey(const Key('developer-app-name')),
      'New App',
    );
    await tester.pump();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.text('捨棄未儲存的變更？'), findsOneWidget);
  });

  testWidgets('confidential app 成功後顯示一次性 secret 提醒與複製操作', (tester) async {
    String? clipboardText;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (
      methodCall,
    ) async {
      switch (methodCall.method) {
        case 'Clipboard.setData':
          clipboardText =
              (methodCall.arguments as Map<Object?, Object?>)['text']
                  as String?;
          return null;
        case 'Clipboard.getData':
          return <String, Object?>{'text': clipboardText};
        default:
          return null;
      }
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });

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
        clientId: 'tp_secret_client',
        clientSecret: 'secret-once',
        appName: 'Secret App',
        clientType: 'confidential',
        status: 'pending_review',
        redirectUris: ['https://secret.example.com/callback'],
        allowedScopes: ['openid', 'profile'],
      ),
    );
    await pumpForm(tester);

    await tester.enterText(
      find.byKey(const Key('developer-app-name')),
      'Secret App',
    );
    await tester.enterText(
      find.byKey(const Key('developer-app-redirect-uris')),
      'https://secret.example.com/callback',
    );
    await tester.tap(find.text('Confidential'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('developer-app-create-submit')));
    await tester.pumpAndSettle();

    expect(find.text('請立即複製 client_secret'), findsOneWidget);
    expect(find.textContaining('不會再顯示'), findsOneWidget);
    expect(
      find.byKey(const Key('developer-app-copy-client-id')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('developer-app-copy-client-secret')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('developer-app-secret-acknowledge')),
      findsOneWidget,
    );
    expect(find.text('我已複製，繼續'), findsOneWidget);

    await tester.tap(find.byKey(const Key('developer-app-copy-client-secret')));
    final copied = await Clipboard.getData('text/plain');
    expect(copied?.text, 'secret-once');
  });

  testWidgets('sheet 內建立成功後回到 developer apps 清單', (tester) async {
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
          home: TpLargeSheetNavigationScope(
            onClose: () {},
            child: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (routeContext) => Scaffold(
                  body: Center(
                    child: FilledButton(
                      key: const Key('open-developer-app-form'),
                      onPressed: () => Navigator.of(routeContext).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const DeveloperAppNewScreen(),
                        ),
                      ),
                      child: const Text('開啟表單'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-developer-app-form')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('developer-app-name')),
      'New App',
    );
    await tester.enterText(
      find.byKey(const Key('developer-app-redirect-uris')),
      'https://new.example.com/callback',
    );
    await tester.tap(find.byKey(const Key('developer-app-create-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('developer-app-secret-acknowledge')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('open-developer-app-form')), findsOneWidget);
    expect(find.byType(DeveloperAppNewScreen), findsNothing);
    expect(find.text('捨棄未儲存的變更？'), findsNothing);
  });
}
