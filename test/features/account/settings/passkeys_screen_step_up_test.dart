/// 撤銷 passkey 遇到 api 強制重新驗證（REAUTH_REQUIRED）的整條流程：
/// 真的 ApiClient＋StepUpGate＋對話框，只有 HTTP 與平台通道是假的。
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/app/passkey_reauth_platform.dart';
import 'package:tripline/app/step_up_dialog.dart';
import 'package:tripline/features/account/settings/passkeys_screen.dart';
import 'package:tripline/theme/app_theme.dart';

import '../../../helpers/fake_passkey_reauth_platform.dart';

class _Server implements HttpClientAdapter {
  _Server({required this.hasPasskey});

  final bool hasPasskey;
  final requests = <RequestOptions>[];
  final bodies = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    bodies.add(jsonEncode(options.data));
    final path = options.uri.path;
    final (int, Object?) reply = switch ('${options.method} $path') {
      'GET /api/account/passkeys' => (
        200,
        {
          'passkeys': [
            {
              'id': 'cred-1',
              'name': '我的 iPhone',
              'transports': ['internal'],
              'backupEligible': true,
              'createdAt': '2026-11-01 08:00:00',
              'lastUsedAt': null,
            },
          ],
        },
      ),
      'DELETE /api/account/passkeys/cred-1' =>
        options.headers['X-Step-Up-Proof'] == 'issued-proof'
            ? (204, null)
            : (
                403,
                {
                  'error': {'code': 'REAUTH_REQUIRED', 'message': '需要重新驗證'},
                },
              ),
      'POST /api/account/reauth/options' => (
        200,
        {
          'challenge': 'ch',
          'allowCredentials': hasPasskey
              ? [
                  {'type': 'public-key', 'id': 'cred-1'},
                ]
              : <dynamic>[],
        },
      ),
      'POST /api/account/reauth/password' ||
      'POST /api/account/reauth/passkey' => (
        200,
        {'proof': 'issued-proof', 'expires_in': 300},
      ),
      _ => (
        404,
        {
          'error': {'code': 'NOT_FOUND', 'message': 'x'},
        },
      ),
    };
    return ResponseBody.fromString(
      reply.$2 == null ? '' : jsonEncode(reply.$2),
      reply.$1,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}

  List<RequestOptions> deletes() =>
      requests.where((r) => r.method == 'DELETE').toList();
}

void main() {
  final navKey = GlobalKey<NavigatorState>();
  late FakePasskeyReauthPlatform platform;

  Future<void> pumpFrames(WidgetTester tester) async {
    // 進行中對話框的 spinner 永不停止，不能用 pumpAndSettle。
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpScreen(WidgetTester tester, _Server server) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (retryCount, error) => null,
        overrides: [
          apiClientProvider.overrideWithValue(
            ApiClient(dio: Dio()..httpClientAdapter = server),
          ),
          passkeyReauthPlatformProvider.overrideWithValue(platform),
          stepUpPrompterProvider.overrideWith(
            (ref) => DialogStepUpPrompter(
              repository: ref.read(stepUpRepositoryProvider),
              platform: ref.read(passkeyReauthPlatformProvider),
              contextOf: () => navKey.currentContext,
            ),
          ),
        ],
        child: MaterialApp(
          navigatorKey: navKey,
          theme: AppTheme.light(),
          home: const PasskeysScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> confirmRevoke(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('passkey-revoke-cred-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CupertinoDialogAction, '撤銷'));
    await pumpFrames(tester);
  }

  setUp(() => platform = FakePasskeyReauthPlatform());

  testWidgets('密碼路徑：REAUTH_REQUIRED → 輸入密碼 → 帶證明重試一次 → 撤銷成功', (tester) async {
    final server = _Server(hasPasskey: false);
    await pumpScreen(tester, server);

    await confirmRevoke(tester);
    expect(find.byKey(const ValueKey('step-up-dialog')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('step-up-password-field')),
      'my-current-pw',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('step-up-password-submit')));
    await pumpFrames(tester);
    await tester.pumpAndSettle();

    final deletes = server.deletes();
    expect(deletes, hasLength(2));
    expect(deletes[0].headers.containsKey('X-Step-Up-Proof'), isFalse);
    expect(deletes[1].headers['X-Step-Up-Proof'], 'issued-proof');
    expect(find.text('已撤銷 passkey'), findsOneWidget);
    // 密碼只出現在 reauth/password 那一個請求的 body。
    final withPassword = [
      for (var i = 0; i < server.requests.length; i++)
        if (server.bodies[i].contains('my-current-pw') ||
            '${server.requests[i].headers}'.contains('my-current-pw'))
          server.requests[i].uri.path,
    ];
    expect(withPassword, ['/api/account/reauth/password']);
  });

  testWidgets('passkey 路徑：簽署成功 → 帶證明重試 → 撤銷成功', (tester) async {
    platform.outcome = const PasskeyAsserted(fakeAssertion);
    final server = _Server(hasPasskey: true);
    await pumpScreen(tester, server);

    await confirmRevoke(tester);
    await tester.tap(find.byKey(const ValueKey('step-up-passkey')));
    await pumpFrames(tester);
    await tester.pumpAndSettle();

    expect(platform.authenticateCalls, 1);
    expect(server.deletes(), hasLength(2));
    expect(server.deletes().last.headers['X-Step-Up-Proof'], 'issued-proof');
    expect(find.text('已撤銷 passkey'), findsOneWidget);
  });

  testWidgets('取消重新驗證 → 原操作不再執行（DELETE 只送過一次）、passkey 仍在', (tester) async {
    final server = _Server(hasPasskey: true);
    await pumpScreen(tester, server);

    await confirmRevoke(tester);
    await tester.tap(find.byKey(const ValueKey('step-up-cancel')));
    await pumpFrames(tester);
    await tester.pumpAndSettle();

    expect(server.deletes(), hasLength(1));
    expect(find.text('已撤銷 passkey'), findsNothing);
    expect(find.text('我的 iPhone'), findsOneWidget);
  });
}
