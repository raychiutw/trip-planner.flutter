import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/passkey_repository.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/app/passkey_platform.dart';
import 'package:tripline/features/account/settings/passkeys_screen.dart';
import 'package:tripline/models/passkey.dart';
import 'package:tripline/theme/app_theme.dart';

import '../../../helpers/fake_passkey_platform.dart';

class MockPasskeyRepository extends Mock implements PasskeyRepository {}

void main() {
  late MockPasskeyRepository repo;
  late FakePasskeyPlatform platform;

  const iphone = Passkey(
    id: 'cred-1',
    name: '我的 iPhone',
    transports: ['internal'],
    backupEligible: true,
    createdAt: '2026-11-01 08:00:00',
    lastUsedAt: null,
  );
  const options = <String, dynamic>{'challenge': 'ch'};

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (retryCount, error) => null,
        overrides: [
          passkeyRepositoryProvider.overrideWithValue(repo),
          passkeyPlatformProvider.overrideWithValue(platform),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const PasskeysScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> submitName(WidgetTester tester, [String? text]) async {
    if (text != null) {
      await tester.enterText(
        find.byKey(const ValueKey('passkey-name-field')),
        text,
      );
    }
    await tester.tap(find.byKey(const ValueKey('passkey-name-submit')));
    await tester.pumpAndSettle();
  }

  setUp(() {
    repo = MockPasskeyRepository();
    platform = FakePasskeyPlatform();
    when(() => repo.list()).thenAnswer((_) async => const [iphone]);
    when(() => repo.registerOptions()).thenAnswer((_) async => options);
    when(
      () => repo.registerVerify(
        credential: any(named: 'credential'),
        name: any(named: 'name'),
      ),
    ).thenAnswer(
      (_) async => const Passkey(
        id: 'cred-new',
        name: '新手機',
        transports: [],
        backupEligible: false,
      ),
    );
    when(() => repo.rename(any(), any())).thenAnswer((_) async => iphone);
    when(() => repo.revoke(any())).thenAnswer((_) async {});
  });

  testWidgets('白話說明：passkey 是什麼、存在哪、沒有生物辨識用裝置密碼', (tester) async {
    await pumpScreen(tester);

    expect(find.textContaining('取代密碼'), findsOneWidget);
    expect(find.textContaining('只保存公鑰'), findsOneWidget);
    expect(find.textContaining('裝置密碼'), findsOneWidget);
  });

  testWidgets('列表：名稱、建立時間、尚未使用', (tester) async {
    await pumpScreen(tester);

    expect(find.text('我的 iPhone'), findsOneWidget);
    expect(find.textContaining('建立於'), findsOneWidget);
    expect(find.textContaining('尚未使用'), findsOneWidget);
  });

  testWidgets('列表：有最後使用時間就顯示', (tester) async {
    when(() => repo.list()).thenAnswer(
      (_) async => const [
        Passkey(
          id: 'c',
          name: '公司筆電',
          transports: [],
          backupEligible: false,
          createdAt: '2026-11-01 08:00:00',
          lastUsedAt: '2026-11-10 09:30:00',
        ),
      ],
    );
    await pumpScreen(tester);

    expect(find.textContaining('最後使用'), findsOneWidget);
    expect(find.textContaining('尚未使用'), findsNothing);
  });

  testWidgets('空狀態：沒有 passkey 仍可新增', (tester) async {
    when(() => repo.list()).thenAnswer((_) async => const []);
    await pumpScreen(tester);

    expect(find.text('還沒有 passkey'), findsOneWidget);
    expect(find.byKey(const ValueKey('passkey-add')), findsOneWidget);
  });

  testWidgets('載入失敗有重試入口，重試會重抓', (tester) async {
    var calls = 0;
    when(() => repo.list()).thenAnswer((_) async {
      calls++;
      if (calls == 1) throw ApiError(status: 500, code: 'X', message: 'x');
      return const [iphone];
    });
    await pumpScreen(tester);

    expect(find.byKey(const ValueKey('passkeys-retry')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('passkeys-retry')));
    await tester.pumpAndSettle();

    expect(find.text('我的 iPhone'), findsOneWidget);
  });

  testWidgets('新增成功：options → 平台建立 → verify 帶使用者取的名稱 → 重抓列表', (tester) async {
    platform.outcome = const PasskeyCreated(fakeCredential);
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('passkey-add')));
    await tester.pumpAndSettle();
    await submitName(tester, '新手機');

    expect(platform.createCalls, 1);
    expect(platform.lastOptions, options);
    verify(
      () => repo.registerVerify(credential: fakeCredential, name: '新手機'),
    ).called(1);
    verify(() => repo.list()).called(2);
    expect(find.text('已新增 passkey'), findsOneWidget);
  });

  testWidgets('新增：名稱留空就用預設名稱，不送空字串', (tester) async {
    platform.outcome = const PasskeyCreated(fakeCredential);
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('passkey-add')));
    await tester.pumpAndSettle();
    await submitName(tester, '   ');

    final captured = verify(
      () => repo.registerVerify(
        credential: any(named: 'credential'),
        name: captureAny(named: 'name'),
      ),
    ).captured;
    expect(captured.single, isNotEmpty);
    expect((captured.single as String).trim(), isNotEmpty);
  });

  testWidgets('新增：使用者在系統對話框取消 → 不呼叫 verify、不重抓、有友善提示', (tester) async {
    platform.outcome = const PasskeyCancelled();
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('passkey-add')));
    await tester.pumpAndSettle();
    await submitName(tester, '新手機');

    expect(platform.createCalls, 1);
    verifyNever(
      () => repo.registerVerify(
        credential: any(named: 'credential'),
        name: any(named: 'name'),
      ),
    );
    verify(() => repo.list()).called(1);
    expect(find.text('已取消新增 passkey'), findsOneWidget);
  });

  testWidgets('新增：平台失敗 → 不呼叫 verify、顯示錯誤', (tester) async {
    platform.outcome = const PasskeyCreateFailed();
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('passkey-add')));
    await tester.pumpAndSettle();
    await submitName(tester, '新手機');

    verifyNever(
      () => repo.registerVerify(
        credential: any(named: 'credential'),
        name: any(named: 'name'),
      ),
    );
    expect(find.textContaining('無法建立 passkey'), findsOneWidget);
  });

  testWidgets('新增：裝置已有同帳號 passkey → 不呼叫 verify、說明原因', (tester) async {
    platform.outcome = const PasskeyAlreadyOnDevice();
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('passkey-add')));
    await tester.pumpAndSettle();
    await submitName(tester, '新手機');

    verifyNever(
      () => repo.registerVerify(
        credential: any(named: 'credential'),
        name: any(named: 'name'),
      ),
    );
    expect(find.textContaining('這支裝置已經有'), findsOneWidget);
  });

  testWidgets('新增：api 409 PASSKEY_ALREADY_REGISTERED → 對應訊息、不重抓列表', (
    tester,
  ) async {
    platform.outcome = const PasskeyCreated(fakeCredential);
    when(
      () => repo.registerVerify(
        credential: any(named: 'credential'),
        name: any(named: 'name'),
      ),
    ).thenThrow(
      ApiError(status: 409, code: 'PASSKEY_ALREADY_REGISTERED', message: 'dup'),
    );
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('passkey-add')));
    await tester.pumpAndSettle();
    await submitName(tester, '新手機');

    expect(find.textContaining('已經註冊過'), findsOneWidget);
    verify(() => repo.list()).called(1);
  });

  testWidgets('新增：options 取得失敗（400 逾時）→ 不叫平台', (tester) async {
    when(() => repo.registerOptions()).thenThrow(
      ApiError(status: 400, code: 'PASSKEY_CHALLENGE_INVALID', message: 'x'),
    );
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('passkey-add')));
    await tester.pumpAndSettle();
    await submitName(tester, '新手機');

    expect(platform.createCalls, 0);
    expect(find.textContaining('驗證已逾時'), findsOneWidget);
  });

  testWidgets('改名：送出新名稱並重抓列表', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('passkey-rename-cred-1')));
    await tester.pumpAndSettle();
    await submitName(tester, '公司筆電');

    verify(() => repo.rename('cred-1', '公司筆電')).called(1);
    verify(() => repo.list()).called(2);
  });

  testWidgets('撤銷：確認前不呼叫 api，確認後才呼叫並重抓', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('passkey-revoke-cred-1')));
    await tester.pumpAndSettle();

    expect(find.textContaining('撤銷「我的 iPhone」'), findsOneWidget);
    verifyNever(() => repo.revoke(any()));

    await tester.tap(find.widgetWithText(CupertinoDialogAction, '撤銷'));
    await tester.pumpAndSettle();

    verify(() => repo.revoke('cred-1')).called(1);
    verify(() => repo.list()).called(2);
    expect(find.text('已撤銷 passkey'), findsOneWidget);
  });

  testWidgets('撤銷：按取消不呼叫 api', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('passkey-revoke-cred-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CupertinoDialogAction, '取消'));
    await tester.pumpAndSettle();

    verifyNever(() => repo.revoke(any()));
    expect(find.text('我的 iPhone'), findsOneWidget);
  });
}
