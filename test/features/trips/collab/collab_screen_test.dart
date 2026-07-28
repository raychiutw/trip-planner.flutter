import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/collab_repository.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/features/trips/collab/collab_screen.dart';
import 'package:tripline/models/trip_member.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_app_bar.dart';

class _MockCollabRepo extends Mock implements CollabRepository {}

const _members = [
  TripMember(id: 1, email: 'owner@x.com', role: 'owner', userId: 'u1'),
  TripMember(id: 2, email: 'v@x.com', role: 'viewer', userId: 'u2'),
];

void main() {
  late _MockCollabRepo repo;

  setUp(() {
    repo = _MockCollabRepo();
    when(() => repo.fetchMembers(any())).thenAnswer((_) async => _members);
    when(() => repo.fetchInvites(any())).thenAnswer((_) async => const []);
  });

  Widget buildApp() {
    return ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [collabRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const CollabScreen(tripId: 'okinawa'),
      ),
    );
  }

  testWidgets('owner → 顯示成員清單', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    expect(find.text('owner@x.com'), findsOneWidget);
    expect(find.text('v@x.com'), findsOneWidget);
  });

  testWidgets('shell 外的共編設定保留可達的帳號入口', (tester) async {
    var accountOpened = false;
    await tester.pumpWidget(
      ProviderScope(
        retry: (retryCount, error) => null,
        overrides: [collabRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => TpAccountActionScope(
            onOpen: (_) => accountOpened = true,
            child: child!,
          ),
          home: const CollabScreen(tripId: 'okinawa'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final account = find.byKey(const ValueKey('account-avatar-button'));
    expect(account, findsOneWidget);
    await tester.tap(account);
    expect(accountOpened, isTrue);
  });

  testWidgets('regular width 置中限制共編內容寬度', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    final content = tester.getRect(
      find.byKey(const ValueKey('collab-content')),
    );
    expect(content.width, 720);
    expect(content.center.dx, 600);
  });

  testWidgets('新增成員 → 輸入 email + 點新增 → invite', (tester) async {
    when(
      () => repo.invite(
        tripId: any(named: 'tripId'),
        email: any(named: 'email'),
        role: any(named: 'role'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('collab-email')),
      'b@x.com',
    );
    await tester.tap(find.byKey(const ValueKey('collab-add')));
    await tester.pumpAndSettle();

    verify(
      () => repo.invite(tripId: 'okinawa', email: 'b@x.com', role: 'member'),
    ).called(1);
  });

  testWidgets('email 欄位鍵盤 Done 可送出邀請', (tester) async {
    when(
      () => repo.invite(
        tripId: any(named: 'tripId'),
        email: any(named: 'email'),
        role: any(named: 'role'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('collab-email')));
    await tester.enterText(
      find.byKey(const ValueKey('collab-email')),
      'keyboard@x.com',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    verify(
      () => repo.invite(
        tripId: 'okinawa',
        email: 'keyboard@x.com',
        role: 'member',
      ),
    ).called(1);
  });

  testWidgets('邀請中鎖定邀請表單且以 live region 宣告進度', (tester) async {
    final completed = Completer<void>();
    when(
      () => repo.invite(
        tripId: any(named: 'tripId'),
        email: any(named: 'email'),
        role: any(named: 'role'),
      ),
    ).thenAnswer((_) => completed.future);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('collab-email')),
      'pending@x.com',
    );
    await tester.tap(find.widgetWithText(ChoiceChip, '檢視成員'));
    await tester.tap(find.byKey(const ValueKey('collab-add')));
    await tester.pump();

    expect(
      tester
          .widget<AbsorbPointer>(
            find.byKey(const ValueKey('collab-invite-form')),
          )
          .absorbing,
      isTrue,
    );
    final progress = tester.widget<Semantics>(
      find.byKey(const ValueKey('collab-invite-progress')),
    );
    expect(progress.properties.liveRegion, isTrue);
    expect(progress.properties.label, '正在新增共編成員');

    await tester.tap(
      find.widgetWithText(ChoiceChip, '共編成員'),
      warnIfMissed: false,
    );
    await tester.tap(
      find.byKey(const ValueKey('collab-add')),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('collab-email')))
          .controller!
          .text,
      'pending@x.com',
    );
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '檢視成員'))
          .selected,
      isTrue,
    );
    verify(
      () => repo.invite(
        tripId: 'okinawa',
        email: 'pending@x.com',
        role: 'viewer',
      ),
    ).called(1);

    completed.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('新增失敗保留 email 並允許再次送出', (tester) async {
    when(
      () => repo.invite(
        tripId: any(named: 'tripId'),
        email: any(named: 'email'),
        role: any(named: 'role'),
      ),
    ).thenThrow(Exception('offline'));

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('collab-email')),
      'retry@x.com',
    );
    await tester.tap(find.byKey(const ValueKey('collab-add')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('collab-email')))
          .controller!
          .text,
      'retry@x.com',
    );
    expect(find.byKey(const ValueKey('collab-action-error')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('collab-add')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('移除成員使用具名不可復原流程並等待伺服器成功', (tester) async {
    final completed = Completer<void>();
    when(() => repo.removeMember(2)).thenAnswer((_) => completed.future);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('member-actions-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('member-remove-2')));
    await tester.pumpAndSettle();

    expect(find.text('移除「v@x.com」？'), findsOneWidget);
    expect(find.textContaining('無法復原'), findsOneWidget);
    await tester.tap(find.widgetWithText(CupertinoActionSheetAction, '移除'));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('irreversible-action-progress')),
      findsOneWidget,
    );

    completed.complete();
    await tester.pumpAndSettle();
    verify(() => repo.removeMember(2)).called(1);
  });

  testWidgets('從選單移除成員以 action sheet 確認，非選單的撤銷邀請仍是 alert', (tester) async {
    when(() => repo.fetchInvites(any())).thenAnswer(
      (_) async => const [
        TripInvite(id: 'invite-1', invitedEmail: 'guest@x.com'),
      ],
    );
    when(() => repo.removeMember(2)).thenAnswer((_) async {});
    when(
      () => repo.revokeInvite(
        tripId: any(named: 'tripId'),
        email: any(named: 'email'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // 選單來源：破壞性動作要出 action sheet。
    await tester.tap(find.byKey(const ValueKey('member-actions-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('member-remove-2')));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoActionSheet), findsOneWidget);
    expect(find.byType(CupertinoAlertDialog), findsNothing);
    await tester.tap(
      find.widgetWithText(CupertinoActionSheetAction, '取消').last,
    );
    await tester.pumpAndSettle();
    verifyNever(() => repo.removeMember(2));

    // 非選單來源(列上的撤銷按鈕)：alert 仍合規，不順手改。
    await tester.tap(find.widgetWithText(TextButton, '撤銷'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.byType(CupertinoActionSheet), findsNothing);
  });

  testWidgets('撤銷邀請沿用不可復原流程且保留原 API 參數', (tester) async {
    when(() => repo.fetchInvites(any())).thenAnswer(
      (_) async => const [
        TripInvite(id: 'invite-1', invitedEmail: 'guest@x.com'),
      ],
    );
    when(
      () => repo.revokeInvite(
        tripId: any(named: 'tripId'),
        email: any(named: 'email'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '撤銷'));
    await tester.pumpAndSettle();

    expect(find.text('撤銷「guest@x.com」的邀請？'), findsOneWidget);
    await tester.tap(find.widgetWithText(CupertinoDialogAction, '撤銷'));
    await tester.pumpAndSettle();

    verify(
      () => repo.revokeInvite(tripId: 'okinawa', email: 'guest@x.com'),
    ).called(1);
  });

  testWidgets('載入失敗持續顯示並可重試', (tester) async {
    var attempts = 0;
    when(() => repo.fetchMembers(any())).thenAnswer((_) async {
      attempts += 1;
      if (attempts == 1) throw Exception('offline');
      return _members;
    });

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('collab-page-error')), findsOneWidget);
    expect(find.text('重試'), findsOneWidget);
    await tester.tap(find.text('重試'));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('owner@x.com'), findsOneWidget);
  });

  testWidgets('非 owner（403）→ 提示', (tester) async {
    when(() => repo.fetchMembers(any())).thenAnswer(
      (_) async => throw const ApiError(
        status: 403,
        code: 'PERM_ADMIN_ONLY',
        message: 'no',
      ),
    );

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('只有行程擁有者'), findsOneWidget);
    expect(find.byKey(const ValueKey('collab-add')), findsNothing);
  });

  testWidgets('最大 Dynamic Type 下成員動作維持 44pt 且不溢位', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: ProviderScope(
          overrides: [collabRepositoryProvider.overrideWithValue(repo)],
          child: const CollabScreen(tripId: 'okinawa'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const ValueKey('member-actions-2'))),
      const Size(44, 44),
    );
    expect(find.byKey(const ValueKey('member-remove-2')), findsNothing);
  });
}
