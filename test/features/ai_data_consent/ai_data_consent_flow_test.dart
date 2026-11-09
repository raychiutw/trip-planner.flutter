import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoAlertDialog;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/ai_data_consent_repository.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/features/ai_data_consent/ai_data_consent_controller.dart';
import 'package:tripline/features/ai_data_consent/ai_data_consent_flow.dart';
import 'package:tripline/features/trips/trips_list_screen.dart'
    show myTripsProvider;
import 'package:tripline/models/trip.dart';
import 'package:tripline/models/ai_data_consent.dart';
import 'package:tripline/models/user.dart';
import 'package:tripline/theme/app_theme.dart';

class _MockConsentRepo extends Mock implements AiDataConsentRepository {}

AiDataConsent _consent(
  AiDataConsentStatus status, {
  bool enforced = true,
  String version = 'ai-data-v1',
  String title = '使用 AI 助理前，請先了解',
}) => AiDataConsent(
  status: status,
  currentVersion: version,
  acceptedVersion: status == AiDataConsentStatus.valid ? version : null,
  acceptedAt: status == AiDataConsentStatus.valid
      ? '2026-10-01T02:03:04.000Z'
      : null,
  enforced: enforced,
  text: AiDataConsentText(
    version: version,
    title: title,
    intro: '以下說明由 server 提供',
    sections: const [
      AiDataConsentSection(heading: '會交給 AI 的資料', items: ['行程內容', '你的訊息']),
    ],
    withdrawal: const ['撤回後新的 AI 請求不再受理'],
  ),
);

const _ownerGate = AiConsentRequiredException(
  party: AiConsentParty.owner,
  requiredVersion: 'ai-data-v1',
);
const _submitterGate = AiConsentRequiredException(
  party: AiConsentParty.submitter,
  requiredVersion: 'ai-data-v1',
  status: AiDataConsentStatus.none,
);

class _StubAuth extends AuthNotifier {
  @override
  Future<UserInfo?> build() async =>
      const UserInfo(id: 'u1', email: 'a@b.c', emailVerified: true);
}

class _SignedOutAuth extends AuthNotifier {
  @override
  Future<UserInfo?> build() async => null;
}

class _Harness extends ConsumerWidget {
  const _Harness({required this.run});

  final Future<void> Function(BuildContext context, WidgetRef ref) run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(myTripsProvider); // 先載入行程清單，流程用 ref.read 取角色
    return _body(context, ref);
  }

  Widget _body(BuildContext context, WidgetRef ref) => Scaffold(
    body: Center(
      child: TextButton(
        key: const ValueKey('go'),
        onPressed: () => unawaited(run(context, ref)),
        child: const Text('go'),
      ),
    ),
  );
}

void main() {
  late _MockConsentRepo repo;
  var calls = 0;
  Object? Function() thrower = () => null;
  bool? outcome;
  var current = true;

  Future<void> pumpFlow(
    WidgetTester tester, {
    String? keptMessage,
    bool Function()? isCurrent,
    bool signedIn = true,
    String? tripId,
    String? role,
  }) async {
    calls = 0;
    outcome = null;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            signedIn ? _StubAuth.new : _SignedOutAuth.new,
          ),
          aiDataConsentRepositoryProvider.overrideWithValue(repo),
          myTripsProvider.overrideWith(
            (ref) => Stream.value([
              TripSummary(tripId: 'trip-1', name: '沖繩', role: role),
            ]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: _Harness(
            run: (context, ref) async {
              outcome = await runWithAiDataConsent<bool>(
                context,
                ref,
                keptMessage: keptMessage,
                tripId: tripId,
                isCurrent: isCurrent ?? () => current,
                action: () async {
                  calls++;
                  final error = thrower();
                  if (error != null) throw error;
                  return true;
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> tapGo(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('go')));
    await tester.pumpAndSettle();
  }

  setUp(() {
    repo = _MockConsentRepo();
    thrower = () => null;
    current = true;
  });

  group('旗標關閉或讀不到狀態：行為與沒有這個功能時完全相同', () {
    testWidgets('未登入：完全不介入，不讀同意狀態、不跳 sheet，直接執行一次', (tester) async {
      await pumpFlow(tester, signedIn: false);
      await tapGo(tester);

      verifyNever(repo.fetch);
      expect(
        find.byKey(const ValueKey('ai-data-consent-accept')),
        findsNothing,
      );
      expect(calls, 1);
      expect(outcome, isTrue);
    });

    testWidgets('enforced=false：不跳 sheet、直接執行一次', (tester) async {
      when(repo.fetch).thenAnswer(
        (_) async => _consent(AiDataConsentStatus.none, enforced: false),
      );
      await pumpFlow(tester);
      await tapGo(tester);

      expect(calls, 1);
      expect(outcome, isTrue);
      expect(
        find.byKey(const ValueKey('ai-data-consent-accept')),
        findsNothing,
      );
      verifyNever(() => repo.accept(any()));
    });

    testWidgets('讀不到狀態（null）：不跳 sheet、直接執行一次', (tester) async {
      when(repo.fetch).thenAnswer((_) async => null);
      await pumpFlow(tester);
      await tapGo(tester);

      expect(calls, 1);
      expect(
        find.byKey(const ValueKey('ai-data-consent-accept')),
        findsNothing,
      );
    });

    testWidgets('讀取丟例外：同樣不擋', (tester) async {
      when(repo.fetch).thenThrow(Exception('offline'));
      await pumpFlow(tester);
      await tapGo(tester);

      expect(calls, 1);
    });

    testWidgets('已同意目前版本：直接執行', (tester) async {
      when(repo.fetch)
          .thenAnswer((_) async => _consent(AiDataConsentStatus.valid));
      await pumpFlow(tester);
      await tapGo(tester);

      expect(calls, 1);
      expect(
        find.byKey(const ValueKey('ai-data-consent-accept')),
        findsNothing,
      );
    });
  });

  group('旅伴免同意（本地不攔，由 owner 的同意把關）', () {
    testWidgets('旅伴（role=member）自己沒同意：不跳 sheet、直接執行一次', (tester) async {
      when(repo.fetch)
          .thenAnswer((_) async => _consent(AiDataConsentStatus.none));
      await pumpFlow(tester, tripId: 'trip-1', role: 'member');
      await tapGo(tester);

      expect(calls, 1);
      expect(outcome, isTrue);
      expect(
        find.byKey(const ValueKey('ai-data-consent-accept')),
        findsNothing,
      );
      verifyNever(() => repo.accept(any()));
    });

    testWidgets('擁有者（role=owner）沒同意：照舊先跳 sheet、不執行', (tester) async {
      when(repo.fetch)
          .thenAnswer((_) async => _consent(AiDataConsentStatus.none));
      await pumpFlow(tester, tripId: 'trip-1', role: 'owner');
      await tapGo(tester);

      expect(calls, 0);
      expect(find.text('使用 AI 助理前，請先了解'), findsOneWidget);
    });

    testWidgets('旅伴被 owner 擋下（server 403）：仍顯示 owner 尚未同意、不重送', (tester) async {
      when(repo.fetch)
          .thenAnswer((_) async => _consent(AiDataConsentStatus.none));
      thrower = () => _ownerGate;
      await pumpFlow(tester, tripId: 'trip-1', role: 'member');
      await tapGo(tester);

      expect(calls, 1);
      expect(outcome, isNull);
      expect(
        find.byKey(const ValueKey('ai-data-consent-accept')),
        findsNothing,
      );
    });
  });

  group('送出前本地已知未同意', () {
    for (final status in [
      AiDataConsentStatus.none,
      AiDataConsentStatus.stale,
      AiDataConsentStatus.withdrawn,
    ]) {
      testWidgets('$status：先跳 sheet，在同意之前一律不執行動作', (tester) async {
        when(repo.fetch).thenAnswer((_) async => _consent(status));
        await pumpFlow(tester);
        await tapGo(tester);

        expect(find.text('使用 AI 助理前，請先了解'), findsOneWidget);
        expect(find.text('以下說明由 server 提供'), findsOneWidget);
        expect(find.text('版本 ai-data-v1'), findsOneWidget);
        expect(calls, 0);
        verifyNever(() => repo.accept(any()));
      });
    }

    testWidgets('同意 → 帶看到的版本 POST，成功後只接續執行一次', (tester) async {
      when(repo.fetch)
          .thenAnswer((_) async => _consent(AiDataConsentStatus.none));
      when(() => repo.accept('ai-data-v1'))
          .thenAnswer((_) async => _consent(AiDataConsentStatus.valid));
      await pumpFlow(tester);
      await tapGo(tester);

      await tester.tap(find.byKey(const ValueKey('ai-data-consent-accept')));
      await tester.pumpAndSettle();

      verify(() => repo.accept('ai-data-v1')).called(1);
      expect(calls, 1);
      expect(outcome, isTrue);
      expect(find.text('使用 AI 助理前，請先了解'), findsNothing);
    });

    testWidgets('取消：不呼叫 accept、不執行動作', (tester) async {
      when(repo.fetch)
          .thenAnswer((_) async => _consent(AiDataConsentStatus.none));
      await pumpFlow(tester);
      await tapGo(tester);

      await tester.tap(find.byKey(const ValueKey('ai-data-consent-cancel')));
      await tester.pumpAndSettle();

      expect(calls, 0);
      expect(outcome, isNull);
      verifyNever(() => repo.accept(any()));
    });

    testWidgets('儲存失敗：sheet 留著顯示錯誤、不假裝已同意；重試成功才接續', (tester) async {
      when(repo.fetch)
          .thenAnswer((_) async => _consent(AiDataConsentStatus.none));
      var attempt = 0;
      when(() => repo.accept('ai-data-v1')).thenAnswer((_) async {
        if (attempt++ == 0) throw ApiError.fromResponse(500, null);
        return _consent(AiDataConsentStatus.valid);
      });
      await pumpFlow(tester);
      await tapGo(tester);

      await tester.tap(find.byKey(const ValueKey('ai-data-consent-accept')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('ai-data-consent-error')),
        findsOneWidget,
      );
      expect(calls, 0);

      await tester.tap(find.byKey(const ValueKey('ai-data-consent-accept')));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.byKey(const ValueKey('ai-data-consent-error')), findsNothing);
    });

    testWidgets('版本在 sheet 開著時被更新（409）：重讀後顯示新版說明，不執行動作', (tester) async {
      var reads = 0;
      when(repo.fetch).thenAnswer(
        (_) async => reads++ == 0
            ? _consent(AiDataConsentStatus.none)
            : _consent(
                AiDataConsentStatus.stale,
                version: 'ai-data-v2',
                title: '新版標題',
              ),
      );
      when(() => repo.accept('ai-data-v1')).thenThrow(
        ApiError.fromResponse(409, {
          'error': {
            'code': 'AI_CONSENT_VERSION_MISMATCH',
            'message': 'm',
            'currentVersion': 'ai-data-v2',
          },
        }),
      );
      await pumpFlow(tester);
      await tapGo(tester);

      await tester.tap(find.byKey(const ValueKey('ai-data-consent-accept')));
      await tester.pumpAndSettle();

      expect(find.text('新版標題'), findsOneWidget);
      expect(find.text('版本 ai-data-v2'), findsOneWidget);
      expect(find.text(kAiConsentVersionChangedMessage), findsOneWidget);
      expect(calls, 0);
    });

    testWidgets('有被攔下的輸入時提示「已保留」', (tester) async {
      when(repo.fetch)
          .thenAnswer((_) async => _consent(AiDataConsentStatus.none));
      await pumpFlow(tester, keptMessage: '幫我排第二天');
      await tapGo(tester);

      expect(
        find.byKey(const ValueKey('ai-data-consent-kept')),
        findsOneWidget,
      );
    });

    testWidgets('同意期間行程已換掉（isCurrent=false）：不提交過時的 intent', (tester) async {
      when(repo.fetch)
          .thenAnswer((_) async => _consent(AiDataConsentStatus.none));
      when(() => repo.accept(any()))
          .thenAnswer((_) async => _consent(AiDataConsentStatus.valid));
      await pumpFlow(tester);
      await tapGo(tester);

      current = false;
      await tester.tap(find.byKey(const ValueKey('ai-data-consent-accept')));
      await tester.pumpAndSettle();

      expect(calls, 0);
      expect(outcome, isNull);
    });
  });

  group('server 403 當最終關卡', () {
    testWidgets('送出者被擋：重讀 → 就地同意 → 接續原操作恰好一次', (tester) async {
      var reads = 0;
      when(repo.fetch).thenAnswer(
        (_) async => reads++ == 0
            ? _consent(AiDataConsentStatus.valid, enforced: false)
            : _consent(AiDataConsentStatus.none),
      );
      when(() => repo.accept('ai-data-v1'))
          .thenAnswer((_) async => _consent(AiDataConsentStatus.valid));
      var first = true;
      thrower = () {
        if (!first) return null;
        first = false;
        return _submitterGate;
      };
      await pumpFlow(tester);
      await tapGo(tester);

      expect(calls, 1);
      expect(find.text('使用 AI 助理前，請先了解'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('ai-data-consent-accept')));
      await tester.pumpAndSettle();

      expect(calls, 2, reason: '同意後只重啟一次');
      expect(outcome, isTrue);
    });

    testWidgets('送出者被擋後取消：不重送', (tester) async {
      var reads = 0;
      when(repo.fetch).thenAnswer(
        (_) async => reads++ == 0
            ? _consent(AiDataConsentStatus.valid, enforced: false)
            : _consent(AiDataConsentStatus.none),
      );
      thrower = () => _submitterGate;
      await pumpFlow(tester);
      await tapGo(tester);
      await tester.tap(find.byKey(const ValueKey('ai-data-consent-cancel')));
      await tester.pumpAndSettle();

      expect(calls, 1);
      expect(outcome, isNull);
    });

    testWidgets('旅伴被 owner 擋下：顯示 owner 尚未同意，沒有同意動作、不重送', (tester) async {
      when(repo.fetch)
          .thenAnswer((_) async => _consent(AiDataConsentStatus.valid));
      thrower = () => _ownerGate;
      await pumpFlow(tester, keptMessage: '幫我排第二天');
      await tapGo(tester);

      expect(find.textContaining('行程擁有者尚未同意 AI 資料處理'), findsWidgets);
      expect(
        find.byKey(const ValueKey('ai-data-consent-accept')),
        findsNothing,
      );
      // A27：純告知用 alert，只留一個關閉動作（不再是帶「取消」「知道了」雙鈕的 sheet）。
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.text('知道了'), findsOneWidget);
      expect(find.text('取消'), findsNothing);
      expect(calls, 1);
      expect(outcome, isNull);
      verifyNever(() => repo.accept(any()));
    });

    testWidgets('旅伴被 owner 擋下：「複製這句話」把通知文字交給系統分享選單', (tester) async {
      final shared = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/share'),
            (call) async {
              shared.add((call.arguments as Map)['text'] as String);
              return 'dev.fluttercommunity.plus/share/success';
            },
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('dev.fluttercommunity.plus/share'),
              null,
            ),
      );
      when(repo.fetch)
          .thenAnswer((_) async => _consent(AiDataConsentStatus.valid));
      thrower = () => _ownerGate;
      await pumpFlow(tester, keptMessage: '幫我排第二天');
      await tapGo(tester);

      const notice = '我想用 Tripline 的 AI 排行程，請到 帳號設定 → AI 與資料 同意一下，謝謝！';
      expect(find.text(notice), findsOneWidget);
      expect(find.bySemanticsLabel('複製這句話'), findsOneWidget);
      await tester.tap(find.text('複製這句話'));
      await tester.pumpAndSettle();
      expect(shared, [notice]);

      // 「知道了」仍可關閉。
      await tester.tap(find.text('知道了'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsNothing);
    });

    testWidgets('同意後重送，版本又被更新而再被擋：重新讀取並再詢問一次，接續成功', (tester) async {
      var reads = 0;
      when(repo.fetch).thenAnswer((_) async {
        final n = reads++;
        if (n == 0) return _consent(AiDataConsentStatus.valid, enforced: false);
        return n == 1
            ? _consent(AiDataConsentStatus.none)
            : _consent(AiDataConsentStatus.stale, version: 'ai-data-v2');
      });
      when(() => repo.accept(any())).thenAnswer(
        (inv) async => _consent(
          AiDataConsentStatus.valid,
          version: inv.positionalArguments.first as String,
        ),
      );
      var gates = 2;
      thrower = () => gates-- > 0 ? _submitterGate : null;
      await pumpFlow(tester);
      await tapGo(tester);
      await tester.tap(find.byKey(const ValueKey('ai-data-consent-accept')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('ai-data-consent-accept')),
        findsOneWidget,
        reason: '第二次被擋要重新彈 sheet，不是直接顯示無法確認',
      );
      await tester.tap(find.byKey(const ValueKey('ai-data-consent-accept')));
      await tester.pumpAndSettle();

      verify(() => repo.accept('ai-data-v2')).called(1);
      expect(calls, 3);
      expect(outcome, isTrue);
      expect(find.text(kAiConsentUnavailableMessage), findsNothing);
    });

    testWidgets('一直被擋：再詢問有上限，用完顯示無法確認、不無限迴圈', (tester) async {
      var reads = 0;
      when(repo.fetch).thenAnswer(
        (_) async => reads++ == 0
            ? _consent(AiDataConsentStatus.valid, enforced: false)
            : _consent(AiDataConsentStatus.none),
      );
      when(() => repo.accept('ai-data-v1'))
          .thenAnswer((_) async => _consent(AiDataConsentStatus.valid));
      thrower = () => _submitterGate;
      await pumpFlow(tester);
      await tapGo(tester);
      // 這個情境（事前不知道要同意）sheet 總共出現 2 次、action 共 3 次，之後放棄。
      for (var i = 0; i < 2; i++) {
        expect(
          find.byKey(const ValueKey('ai-data-consent-accept')),
          findsOneWidget,
          reason: '第 ${i + 1} 次 sheet',
        );
        await tester.tap(find.byKey(const ValueKey('ai-data-consent-accept')));
        await tester.pumpAndSettle();
      }

      expect(
        find.byKey(const ValueKey('ai-data-consent-accept')),
        findsNothing,
        reason: '用完上限不再彈第 3 次',
      );
      verify(() => repo.accept('ai-data-v1')).called(2);
      expect(calls, 3);
      expect(outcome, isNull);
      expect(find.text(kAiConsentUnavailableMessage), findsOneWidget);
    });

    testWidgets('重讀不到說明文字：不猜、不繞過閘門，顯示無法確認', (tester) async {
      when(repo.fetch).thenAnswer((_) async => null);
      thrower = () => _submitterGate;
      await pumpFlow(tester);
      await tapGo(tester);

      expect(calls, 1);
      expect(outcome, isNull);
      expect(find.text(kAiConsentUnavailableMessage), findsOneWidget);
    });
  });

  group('補強：409 重新同意、撤回後再被攔、非閘門錯誤', () {
    ApiError mismatch409() => ApiError.fromResponse(409, {
      'error': {
        'code': 'AI_CONSENT_VERSION_MISMATCH',
        'message': 'm',
        'currentVersion': 'ai-data-v2',
      },
    });

    testWidgets('409 後重新同意新版：帶新版本 POST，成功後才接續執行一次', (tester) async {
      var reads = 0;
      when(repo.fetch).thenAnswer(
        (_) async => reads++ == 0
            ? _consent(AiDataConsentStatus.none)
            : _consent(AiDataConsentStatus.stale, version: 'ai-data-v2'),
      );
      when(() => repo.accept('ai-data-v1')).thenThrow(mismatch409());
      when(() => repo.accept('ai-data-v2')).thenAnswer(
        (_) async => _consent(AiDataConsentStatus.valid, version: 'ai-data-v2'),
      );
      await pumpFlow(tester);
      await tapGo(tester);
      await tester.tap(find.byKey(const ValueKey('ai-data-consent-accept')));
      await tester.pumpAndSettle();
      expect(calls, 0, reason: '409 之後、重新同意之前不得執行');

      await tester.tap(find.byKey(const ValueKey('ai-data-consent-accept')));
      await tester.pumpAndSettle();

      verify(() => repo.accept('ai-data-v2')).called(1);
      expect(calls, 1);
      expect(outcome, isTrue);
    });

    testWidgets('409 後取消：不再 POST、不執行、sheet 關閉', (tester) async {
      var reads = 0;
      when(repo.fetch).thenAnswer(
        (_) async => reads++ == 0
            ? _consent(AiDataConsentStatus.none)
            : _consent(AiDataConsentStatus.stale, version: 'ai-data-v2'),
      );
      when(() => repo.accept('ai-data-v1')).thenThrow(mismatch409());
      await pumpFlow(tester);
      await tapGo(tester);
      await tester.tap(find.byKey(const ValueKey('ai-data-consent-accept')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ai-data-consent-cancel')));
      await tester.pumpAndSettle();

      verify(() => repo.accept(any())).called(1);
      expect(calls, 0);
      expect(outcome, isNull);
      expect(
        find.byKey(const ValueKey('ai-data-consent-accept')),
        findsNothing,
      );
    });

    testWidgets('先同意、撤回後再次被攔：真的走 controller.withdraw，下一次動作要重新同意', (
      tester,
    ) async {
      var status = AiDataConsentStatus.valid;
      when(repo.fetch).thenAnswer((_) async => _consent(status));
      when(repo.withdraw).thenAnswer((_) async {
        status = AiDataConsentStatus.withdrawn;
        return _consent(status);
      });
      await pumpFlow(tester);
      await tapGo(tester);
      expect(calls, 1, reason: '已同意：直通');

      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const ValueKey('go'))),
      );
      await container.read(aiDataConsentProvider.notifier).withdraw();
      await tapGo(tester);

      expect(
        find.byKey(const ValueKey('ai-data-consent-accept')),
        findsOneWidget,
      );
      expect(calls, 1, reason: '撤回後同意前不得再執行');
    });

    testWidgets('非閘門錯誤（500）：原樣往外丟，不跳 sheet、不重送', (tester) async {
      when(repo.fetch)
          .thenAnswer((_) async => _consent(AiDataConsentStatus.valid));
      thrower = () => ApiError.fromResponse(500, null);
      await pumpFlow(tester);
      Object? caught;
      await runZonedGuarded(() async {
        await tapGo(tester);
      }, (e, _) => caught = e);

      expect(calls, 1);
      expect(caught, isA<ApiError>());
      expect(
        find.byKey(const ValueKey('ai-data-consent-accept')),
        findsNothing,
      );
    });
  });
}
