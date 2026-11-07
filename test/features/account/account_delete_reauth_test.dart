/// 無密碼（Google-only）帳號刪除：確認影響 → Google 重新驗證 → verified 才送刪除。
/// 走公開的 AccountScreen；後端以 mock repository 取代，瀏覽器以假 launcher 取代。
/// 注意：沒有真實 Google 往返，只驗 App 端對契約的處理。
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/api/oauth/oauth_config.dart';
import 'package:tripline/api/oauth/oauth_login_service.dart';
import 'package:tripline/api/oauth/oauth_providers.dart';
import 'package:tripline/api/oauth/oauth_token_store.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/settings_store.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/app/app_version.dart';
import 'package:tripline/features/account/account_screen.dart';
import 'package:tripline/models/user.dart';
import 'package:tripline/theme/app_theme.dart';

import '../../helpers/ai_data_consent_fixtures.dart';
import '../../helpers/fake_oauth.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockTripRepository extends Mock implements TripRepository {}

/// 假的授權視窗：[reply] 決定 callback 帶回什麼（null = 丟 [error]）。
class _FakeLauncher implements AuthorizationLauncher {
  Map<String, String> Function(Uri url)? reply;
  Object? error;
  Future<void>? gate;
  final opened = <Uri>[];
  String? host;
  String? path;

  @override
  Future<Uri> authorize(
    Uri authorizeUrl, {
    required String callbackHost,
    required String callbackPath,
  }) async {
    opened.add(authorizeUrl);
    host = callbackHost;
    path = callbackPath;
    await gate;
    if (error != null) throw error!;
    return Uri.https(callbackHost, callbackPath, reply!(authorizeUrl));
  }
}

void main() {
  late _MockAuthRepository repo;
  late _FakeLauncher launcher;
  late InMemoryOAuthTokenStore tokenStore;

  final authorizeUrl = Uri.parse(
    'https://api.example/api/oauth/login/google?purpose=account-delete&challenge=ch_1',
  );

  setUp(() {
    repo = _MockAuthRepository();
    launcher = _FakeLauncher();
    tokenStore = signedInTokenStore();
    when(() => repo.currentUser()).thenAnswer(
      (_) async => const UserInfo(
        id: 'user-1',
        email: 'ray@example.com',
        emailVerified: true,
        displayName: 'Ray',
      ),
    );
    when(() => repo.startDeleteReauth()).thenAnswer(
      (_) async => DeleteReauthChallenge(
        challengeId: 'ch_1',
        authorizeUrl: authorizeUrl,
      ),
    );
    when(() => repo.cancelDeleteReauth(any())).thenAnswer((_) async {});
    when(
      () =>
          repo.deleteAccountWithReauth(challengeId: any(named: 'challengeId')),
    ).thenAnswer((_) async {});
  });

  void stubPreview({
    bool hasPassword = false,
    String? reauthProvider = 'google',
  }) {
    when(() => repo.fetchAccountDeletionPreview()).thenAnswer(
      (_) async => AccountDeletionPreview(
        hasPassword: hasPassword,
        reauthProvider: reauthProvider,
        tripsOwned: 2,
        collaboratorsAffected: 1,
      ),
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    TextScaler textScaler = TextScaler.noScaling,
    Size size = const Size(800, 1800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
          ...signedInOverrides(store: tokenStore),
          tripRepositoryProvider.overrideWithValue(_MockTripRepository()),
          settingsStoreProvider.overrideWithValue(InMemorySettingsStore()),
          appVersionProvider.overrideWith(
            (ref) => Future.value(
              const AppVersion(version: '0.9.1', buildNumber: '12'),
            ),
          ),
          aiDataConsentRepositoryProvider.overrideWithValue(
            unenforcedConsentRepo(),
          ),
          authorizationLauncherProvider.overrideWithValue(launcher),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          ),
          home: const AccountScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openDeleteDialog(WidgetTester tester) async {
    final row = find.byKey(const ValueKey('settings-delete-account'));
    // 大字級下列在畫面外且延遲建構：一直往上拖到點得到為止。
    for (var i = 0; i < 40 && row.hitTestable().evaluate().isEmpty; i++) {
      await tester.drag(
        find.byKey(const ValueKey('account-sheet-content')),
        const Offset(0, -150),
      );
      await tester.pump();
    }
    await tester.tap(row);
    await tester.pumpAndSettle();
  }

  Future<void> tapStart(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('delete-reauth-start-button')));
    await tester.pumpAndSettle();
  }

  testWidgets('Google-only：確認影響 → Google 驗證 → verified 才送刪除，成功清除 session', (
    tester,
  ) async {
    stubPreview();
    launcher.reply = (_) => {'challenge_id': 'ch_1', 'status': 'verified'};
    when(
      () => repo.fetchDeleteReauthStatus('ch_1'),
    ).thenAnswer((_) async => 'verified');
    await pump(tester);

    await openDeleteDialog(tester);
    expect(find.textContaining('2 個行程'), findsOneWidget);
    expect(find.textContaining('1 位共編者'), findsOneWidget);
    expect(find.textContaining('無法復原'), findsOneWidget);
    verifyNever(() => repo.startDeleteReauth());

    await tapStart(tester);

    expect(launcher.opened, [authorizeUrl]);
    expect(launcher.host, OAuthConfig.callbackHost);
    expect(launcher.path, OAuthConfig.callbackPath);
    verify(() => repo.fetchDeleteReauthStatus('ch_1')).called(1);
    verify(() => repo.deleteAccountWithReauth(challengeId: 'ch_1')).called(1);
    expect(await tokenStore.read(), isNull);
  });

  void expectNoDeleteSent() {
    verifyNever(
      () =>
          repo.deleteAccountWithReauth(challengeId: any(named: 'challengeId')),
    );
  }

  Future<void> expectFailedButSafe(WidgetTester tester, String message) async {
    expectNoDeleteSent();
    expect(find.textContaining(message), findsOneWidget);
    expect(await tokenStore.read(), isNotNull, reason: '沒成功就不能清 session');
    expect(find.byKey(const ValueKey('delete-reauth-dialog')), findsOneWidget);
    // 重試與取消的出口都在。
    expect(find.text('重試'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
  }

  group('伺服器狀態不是 verified：不送刪除、不誤報成功', () {
    for (final entry in {
      'failed': 'Google 驗證未通過',
      'cancelled': '驗證已取消',
      'expired': '驗證已逾時',
      'used': '這次驗證已使用',
      'pending': '尚未完成',
      'started': '尚未完成',
    }.entries) {
      testWidgets(entry.key, (tester) async {
        stubPreview();
        // callback 自稱 verified 也不算，以伺服器狀態為準。
        launcher.reply = (_) => {'challenge_id': 'ch_1', 'status': 'verified'};
        when(
          () => repo.fetchDeleteReauthStatus('ch_1'),
        ).thenAnswer((_) async => entry.key);
        await pump(tester);
        await openDeleteDialog(tester);
        await tapStart(tester);
        await expectFailedButSafe(tester, entry.value);
      });
    }
  });

  testWidgets('使用者中途關掉瀏覽器：視為取消、通知後端取消 challenge、不送刪除', (tester) async {
    stubPreview();
    launcher.error = OAuthLoginException('x', cancelled: true);
    await pump(tester);
    await openDeleteDialog(tester);
    await tapStart(tester);

    await expectFailedButSafe(tester, '已取消驗證');
    verify(() => repo.cancelDeleteReauth('ch_1')).called(1);
    verifyNever(() => repo.fetchDeleteReauthStatus(any()));
  });

  testWidgets('瀏覽器視窗開不起來：失敗且不送刪除', (tester) async {
    stubPreview();
    launcher.error = OAuthLoginException('boom');
    await pump(tester);
    await openDeleteDialog(tester);
    await tapStart(tester);
    await expectFailedButSafe(tester, '無法開啟 Google 驗證');
  });

  testWidgets('callback 的 challenge_id 與本次不符：不採信、不送刪除', (tester) async {
    stubPreview();
    launcher.reply = (_) => {'challenge_id': 'other', 'status': 'verified'};
    await pump(tester);
    await openDeleteDialog(tester);
    await tapStart(tester);
    await expectFailedButSafe(tester, '驗證結果與這次要求不符');
    verifyNever(() => repo.fetchDeleteReauthStatus(any()));
  });

  testWidgets('建立 challenge 時網路錯誤：失敗可重試，沒有開瀏覽器', (tester) async {
    stubPreview();
    when(() => repo.startDeleteReauth()).thenThrow(Exception('offline'));
    await pump(tester);
    await openDeleteDialog(tester);
    await tapStart(tester);
    await expectFailedButSafe(tester, '網路異常');
    expect(launcher.opened, isEmpty);
  });

  testWidgets('查狀態時網路錯誤：不當成已驗證', (tester) async {
    stubPreview();
    launcher.reply = (_) => {'challenge_id': 'ch_1', 'status': 'verified'};
    when(
      () => repo.fetchDeleteReauthStatus('ch_1'),
    ).thenThrow(Exception('offline'));
    await pump(tester);
    await openDeleteDialog(tester);
    await tapStart(tester);
    await expectFailedButSafe(tester, '網路異常');
  });

  testWidgets('驗證失敗後重試：重新建立 challenge，成功才刪除並清 session', (tester) async {
    stubPreview();
    launcher.reply = (_) => {'challenge_id': 'ch_1', 'status': 'verified'};
    final statuses = ['failed', 'verified'];
    when(
      () => repo.fetchDeleteReauthStatus('ch_1'),
    ).thenAnswer((_) async => statuses.removeAt(0));
    await pump(tester);
    await openDeleteDialog(tester);
    await tapStart(tester);
    expectNoDeleteSent();

    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();

    verify(() => repo.startDeleteReauth()).called(2);
    verify(() => repo.deleteAccountWithReauth(challengeId: 'ch_1')).called(1);
    expect(await tokenStore.read(), isNull);
  });

  testWidgets('verified 後刪除遇網路錯誤：不清 session，重試沿用同一 challenge', (tester) async {
    stubPreview();
    launcher.reply = (_) => {'challenge_id': 'ch_1', 'status': 'verified'};
    when(
      () => repo.fetchDeleteReauthStatus('ch_1'),
    ).thenAnswer((_) async => 'verified');
    var calls = 0;
    when(
      () =>
          repo.deleteAccountWithReauth(challengeId: any(named: 'challengeId')),
    ).thenAnswer((_) async {
      if (calls++ == 0) throw Exception('offline');
    });
    await pump(tester);
    await openDeleteDialog(tester);
    await tapStart(tester);
    expect(find.textContaining('網路異常'), findsOneWidget);
    expect(await tokenStore.read(), isNotNull);

    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();

    expect(launcher.opened, hasLength(1), reason: '不必再開瀏覽器');
    verify(() => repo.deleteAccountWithReauth(challengeId: 'ch_1')).called(2);
    expect(await tokenStore.read(), isNull);
  });

  testWidgets('刪除被後端以 REAUTH_REQUIRED 拒絕：不清 session，重試要重新驗證', (tester) async {
    stubPreview();
    launcher.reply = (_) => {'challenge_id': 'ch_1', 'status': 'verified'};
    when(
      () => repo.fetchDeleteReauthStatus('ch_1'),
    ).thenAnswer((_) async => 'verified');
    when(
      () =>
          repo.deleteAccountWithReauth(challengeId: any(named: 'challengeId')),
    ).thenThrow(
      const ApiError(
        status: 403,
        code: 'ACCOUNT_DELETE_REAUTH_REQUIRED',
        message: 'x',
      ),
    );
    await pump(tester);
    await openDeleteDialog(tester);
    await tapStart(tester);
    expect(find.textContaining('驗證已失效'), findsOneWidget);
    expect(await tokenStore.read(), isNotNull);

    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();
    expect(launcher.opened, hasLength(2), reason: '重新走 Google 驗證');
  });

  testWidgets('確認畫面按取消：什麼都不呼叫', (tester) async {
    stubPreview();
    await pump(tester);
    await openDeleteDialog(tester);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    verifyNever(() => repo.startDeleteReauth());
    expect(launcher.opened, isEmpty);
    expect(await tokenStore.read(), isNotNull);
  });

  testWidgets('驗證進行中（瀏覽器開著／App 在背景）：動作停用、不重複建立，回來後接續完成', (tester) async {
    stubPreview();
    final gate = Completer<void>();
    launcher
      ..gate = gate.future
      ..reply = (_) => {'challenge_id': 'ch_1', 'status': 'verified'};
    when(
      () => repo.fetchDeleteReauthStatus('ch_1'),
    ).thenAnswer((_) async => 'verified');
    await pump(tester);
    await openDeleteDialog(tester);
    await tester.tap(find.byKey(const ValueKey('delete-reauth-start-button')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('delete-reauth-progress')),
      findsOneWidget,
    );
    for (final key in [
      'delete-reauth-start-button',
      'delete-reauth-cancel-button',
    ]) {
      expect(
        tester
            .widget<CupertinoDialogAction>(find.byKey(ValueKey(key)))
            .onPressed,
        isNull,
      );
    }
    expectNoDeleteSent();

    gate.complete();
    await tester.pumpAndSettle();
    verify(() => repo.startDeleteReauth()).called(1);
    verify(() => repo.deleteAccountWithReauth(challengeId: 'ch_1')).called(1);
  });

  group('帳號種類分流', () {
    testWidgets('有密碼（含同時有 Google 身分）：走密碼確認，不碰 Google 重新驗證', (tester) async {
      stubPreview(hasPassword: true, reauthProvider: null);
      await pump(tester);
      await openDeleteDialog(tester);

      expect(
        find.byKey(const ValueKey('delete-account-confirmation-field')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('delete-reauth-dialog')), findsNothing);
      verifyNever(() => repo.startDeleteReauth());
    });

    testWidgets('有密碼且後端也回 google：仍以密碼為準', (tester) async {
      stubPreview(hasPassword: true, reauthProvider: 'google');
      await pump(tester);
      await openDeleteDialog(tester);

      expect(
        find.byKey(const ValueKey('delete-account-confirmation-field')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('delete-reauth-dialog')), findsNothing);
    });

    testWidgets('無密碼也沒有 Google 身分：阻擋，不開驗證也不送刪除', (tester) async {
      stubPreview(reauthProvider: null);
      await pump(tester);
      await openDeleteDialog(tester);

      expect(find.text('需要重新驗證才能刪除'), findsOneWidget);
      verifyNever(() => repo.startDeleteReauth());
      expectNoDeleteSent();
    });

    testWidgets('密碼流程的密碼欄位標 Password AutoFill', (tester) async {
      stubPreview(hasPassword: true, reauthProvider: null);
      await pump(tester);
      await openDeleteDialog(tester);

      expect(
        tester
            .widget<CupertinoTextField>(
              find.byKey(const ValueKey('delete-account-confirmation-field')),
            )
            .autofillHints,
        contains(AutofillHints.password),
      );
    });
  });

  group('安全預設焦點與最大字級', () {
    testWidgets('預設動作是取消，不是破壞性動作', (tester) async {
      stubPreview();
      await pump(tester);
      await openDeleteDialog(tester);

      final cancel = tester.widget<CupertinoDialogAction>(
        find.byKey(const ValueKey('delete-reauth-cancel-button')),
      );
      final start = tester.widget<CupertinoDialogAction>(
        find.byKey(const ValueKey('delete-reauth-start-button')),
      );
      expect(cancel.isDefaultAction, isTrue);
      expect(start.isDefaultAction, isFalse);
      expect(start.isDestructiveAction, isTrue);
    });

    for (final failed in [false, true]) {
      testWidgets('textScaler 3.0、小螢幕：不溢位，主要動作可點${failed ? '（失敗態）' : ''}', (
        tester,
      ) async {
        stubPreview();
        launcher.reply = (_) => {'challenge_id': 'ch_1', 'status': 'verified'};
        when(
          () => repo.fetchDeleteReauthStatus('ch_1'),
        ).thenAnswer((_) async => 'failed');
        await pump(
          tester,
          textScaler: const TextScaler.linear(3),
          size: const Size(320, 568),
        );
        await openDeleteDialog(tester);
        if (failed) {
          await tester.ensureVisible(
            find.byKey(const ValueKey('delete-reauth-start-button')),
          );
          await tapStart(tester);
        }

        expect(tester.takeException(), isNull);
        // 對話框內容與動作區可捲動：捲到可見後都要點得到。
        final button = find.byKey(const ValueKey('delete-reauth-start-button'));
        await tester.ensureVisible(button);
        await tester.pump();
        expect(button.hitTestable(), findsOneWidget);
        final cancel = find.byKey(
          const ValueKey('delete-reauth-cancel-button'),
        );
        await tester.ensureVisible(cancel);
        await tester.pump();
        expect(cancel.hitTestable(), findsOneWidget);
      });
    }
  });
}
