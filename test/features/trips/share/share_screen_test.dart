import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/share_repository.dart';
import 'package:tripline/features/trips/share/share_screen.dart';
import 'package:tripline/models/trip_share.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_app_bar.dart';

class _MockShareRepo extends Mock implements ShareRepository {}

const _shares = [TripShare(id: 1, label: '給爸媽', viewCount: 2)];

void main() {
  late _MockShareRepo repo;
  setUp(() {
    repo = _MockShareRepo();
    when(() => repo.fetchShares(any())).thenAnswer((_) async => _shares);
  });

  Widget buildApp({
    Future<void> Function(String url)? shareLink,
    ThemeData? theme,
    TextScaler? textScaler,
  }) => ProviderScope(
    retry: (retryCount, error) => null,
    overrides: [shareRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      theme: theme ?? AppTheme.light(),
      builder: textScaler == null
          ? null
          : (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: child!,
            ),
      home: ShareScreen(tripId: 't', shareLink: shareLink),
    ),
  );

  testWidgets('渲染現有連結', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    expect(find.text('給爸媽'), findsOneWidget);
    expect(find.textContaining('已被檢視 2 次'), findsOneWidget);
  });

  testWidgets('shell 外的分享設定保留可達的帳號入口', (tester) async {
    var accountOpened = false;
    await tester.pumpWidget(
      ProviderScope(
        retry: (retryCount, error) => null,
        overrides: [shareRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => TpAccountActionScope(
            onOpen: (_) => accountOpened = true,
            child: child!,
          ),
          home: const ShareScreen(tripId: 't'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final account = find.byKey(const ValueKey('account-avatar-button'));
    expect(account, findsOneWidget);
    await tester.tap(account);
    expect(accountOpened, isTrue);
  });

  testWidgets('regular width 置中限制分享內容寬度', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    final content = tester.getRect(find.byKey(const ValueKey('share-content')));
    expect(content.width, 720);
    expect(content.center.dx, 600);
  });

  testWidgets('建立失敗保留使用者輸入並提供重試', (tester) async {
    when(
      () => repo.createShare(
        any(),
        label: any(named: 'label'),
        visibleSections: any(named: 'visibleSections'),
        anonymous: any(named: 'anonymous'),
      ),
    ).thenThrow(Exception('offline'));

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('share-label')), '家人');
    await tester.tap(find.byKey(const ValueKey('share-create')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('share-label')))
          .controller!
          .text,
      '家人',
    );
    expect(find.byKey(const ValueKey('share-error')), findsOneWidget);
    expect(find.text('重試'), findsOneWidget);
  });

  testWidgets('建立中鎖定建立表單且以 live region 宣告進度', (tester) async {
    final completed = Completer<ShareLink>();
    when(
      () => repo.createShare(
        any(),
        label: any(named: 'label'),
        visibleSections: any(named: 'visibleSections'),
        anonymous: any(named: 'anonymous'),
      ),
    ).thenAnswer((_) => completed.future);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('share-label')), '處理中');
    await tester.tap(find.byKey(const ValueKey('share-create')));
    await tester.pump();

    expect(
      tester
          .widget<AbsorbPointer>(
            find.byKey(const ValueKey('share-create-form')),
          )
          .absorbing,
      isTrue,
    );
    final progress = tester.widget<Semantics>(
      find.byKey(const ValueKey('share-create-progress')),
    );
    expect(progress.properties.liveRegion, isTrue);
    expect(progress.properties.label, '正在建立分享連結');

    await tester.tap(
      find.byKey(const ValueKey('share-section-reservations')),
      warnIfMissed: false,
    );
    await tester.tap(
      find.byKey(const ValueKey('share-create')),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('share-label')))
          .controller!
          .text,
      '處理中',
    );
    expect(
      tester
          .widget<FilterChip>(
            find.byKey(const ValueKey('share-section-reservations')),
          )
          .selected,
      isFalse,
    );
    verify(
      () => repo.createShare(
        't',
        label: '處理中',
        visibleSections: any(named: 'visibleSections'),
        anonymous: false,
      ),
    ).called(1);

    completed.complete(
      const ShareLink(id: 13, token: 'pending', url: '/s/pending'),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('建立 → 顯示完整 URL + 複製鈕', (tester) async {
    when(
      () => repo.createShare(
        any(),
        label: any(named: 'label'),
        visibleSections: any(named: 'visibleSections'),
        anonymous: any(named: 'anonymous'),
      ),
    ).thenAnswer(
      (_) async =>
          const ShareLink(id: 7, token: 'tok', url: '/s/tok', label: 'x'),
    );

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('share-label')), 'x');
    await tester.tap(find.byKey(const ValueKey('share-create')));
    await tester.pumpAndSettle();

    final captured =
        verify(
              () => repo.createShare(
                't',
                label: 'x',
                visibleSections: captureAny(named: 'visibleSections'),
                anonymous: false,
              ),
            ).captured.single
            as List<String>;
    expect(captured, ['flights', 'lodgings', 'pretrip']);
    expect(find.textContaining('/s/tok'), findsOneWidget);
    expect(find.byKey(const ValueKey('share-copy')), findsOneWidget);
  });

  testWidgets('建立 → 可展開 QR code', (tester) async {
    when(
      () => repo.createShare(
        any(),
        label: any(named: 'label'),
        visibleSections: any(named: 'visibleSections'),
        anonymous: any(named: 'anonymous'),
      ),
    ).thenAnswer(
      (_) async =>
          const ShareLink(id: 11, token: 'tokqr', url: '/s/tokqr', label: 'x'),
    );

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('share-label')), 'x');
    await tester.tap(find.byKey(const ValueKey('share-create')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('share-qr-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('share-qr-code')), findsOneWidget);
  });

  testWidgets('建立 → 可用系統分享完整 URL', (tester) async {
    final sharedUrls = <String>[];
    when(
      () => repo.createShare(
        any(),
        label: any(named: 'label'),
        visibleSections: any(named: 'visibleSections'),
        anonymous: any(named: 'anonymous'),
      ),
    ).thenAnswer(
      (_) async => const ShareLink(
        id: 12,
        token: 'tokshare',
        url: '/s/tokshare',
        label: 'x',
      ),
    );

    await tester.pumpWidget(
      buildApp(shareLink: (url) async => sharedUrls.add(url)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('share-label')), 'x');
    await tester.tap(find.byKey(const ValueKey('share-create')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('share-native')));
    await tester.pumpAndSettle();

    expect(sharedUrls, hasLength(1));
    expect(sharedUrls.single, contains('/s/tokshare'));
  });

  testWidgets('建立選項 → 切換公開區塊與匿名設定', (tester) async {
    when(
      () => repo.createShare(
        any(),
        label: any(named: 'label'),
        visibleSections: any(named: 'visibleSections'),
        anonymous: any(named: 'anonymous'),
      ),
    ).thenAnswer(
      (_) async =>
          const ShareLink(id: 8, token: 'tok2', url: '/s/tok2', label: 'x'),
    );

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('share-label')), 'x');
    await tester.tap(find.byKey(const ValueKey('share-section-reservations')));
    await tester.tap(find.byKey(const ValueKey('share-anonymous')));
    await tester.tap(find.byKey(const ValueKey('share-create')));
    await tester.pumpAndSettle();

    final captured =
        verify(
              () => repo.createShare(
                't',
                label: 'x',
                visibleSections: captureAny(named: 'visibleSections'),
                anonymous: true,
              ),
            ).captured.single
            as List<String>;
    expect(captured, ['flights', 'lodgings', 'reservations', 'pretrip']);
  });

  testWidgets('建立期限 → 7 天 preset 送 expiresAt', (tester) async {
    when(
      () => repo.createShare(
        any(),
        label: any(named: 'label'),
        visibleSections: any(named: 'visibleSections'),
        expiresAt: any(named: 'expiresAt'),
        anonymous: any(named: 'anonymous'),
      ),
    ).thenAnswer(
      (_) async =>
          const ShareLink(id: 9, token: 'tok3', url: '/s/tok3', label: 'x'),
    );

    final before = DateTime.now().millisecondsSinceEpoch;
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('share-label')), 'x');
    await tester.tap(find.text('7 天'));
    await tester.tap(find.byKey(const ValueKey('share-create')));
    await tester.pumpAndSettle();
    final after = DateTime.now().millisecondsSinceEpoch;

    final expiresAt =
        verify(
              () => repo.createShare(
                't',
                label: 'x',
                visibleSections: any(named: 'visibleSections'),
                expiresAt: captureAny(named: 'expiresAt'),
                anonymous: false,
              ),
            ).captured.single
            as int;
    expect(
      expiresAt,
      greaterThanOrEqualTo(
        before + const Duration(days: 7).inMilliseconds - 1000,
      ),
    );
    expect(
      expiresAt,
      lessThanOrEqualTo(after + const Duration(days: 7).inMilliseconds + 1000),
    );
  });

  testWidgets('建立期限 → 自訂日期送當日 23:59:59', (tester) async {
    when(
      () => repo.createShare(
        any(),
        label: any(named: 'label'),
        visibleSections: any(named: 'visibleSections'),
        expiresAt: any(named: 'expiresAt'),
        anonymous: any(named: 'anonymous'),
      ),
    ).thenAnswer(
      (_) async =>
          const ShareLink(id: 10, token: 'tok4', url: '/s/tok4', label: 'x'),
    );

    final selected = DateTime.now();
    final expected = DateTime(
      selected.year,
      selected.month,
      selected.day,
      23,
      59,
      59,
    ).millisecondsSinceEpoch;

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('share-label')), 'x');
    await tester.tap(find.text('自訂'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('share-custom-expiry-date')));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('share-create')));
    await tester.pumpAndSettle();

    final expiresAt =
        verify(
              () => repo.createShare(
                't',
                label: 'x',
                visibleSections: any(named: 'visibleSections'),
                expiresAt: captureAny(named: 'expiresAt'),
                anonymous: false,
              ),
            ).captured.single
            as int;
    expect(expiresAt, expected);
  });

  testWidgets('選單的撤銷與刪除都以 action sheet 確認', (tester) async {
    when(() => repo.revokeShare(any(), any())).thenAnswer((_) async {});
    when(() => repo.deleteShare(any(), any())).thenAnswer((_) async {});

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    for (final action in const ['share-revoke-1', 'share-delete-1']) {
      await tester.tap(find.byKey(const ValueKey('share-actions-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey(action)));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsOneWidget, reason: action);
      expect(find.byType(CupertinoAlertDialog), findsNothing, reason: action);
      await tester.tap(
        find.widgetWithText(CupertinoActionSheetAction, '取消').last,
      );
      await tester.pumpAndSettle();
    }

    verifyNever(() => repo.revokeShare(any(), any()));
    verifyNever(() => repo.deleteShare(any(), any()));
  });

  testWidgets('撤銷 → 確認 → 呼叫 revoke', (tester) async {
    final completed = Completer<void>();
    when(
      () => repo.revokeShare(any(), any()),
    ).thenAnswer((_) => completed.future);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('share-actions-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('share-revoke-1')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CupertinoActionSheetAction, '撤銷'),
    ); // action sheet 確認
    await tester.pump();

    expect(
      find.byKey(const ValueKey('irreversible-action-progress')),
      findsOneWidget,
    );
    completed.complete();
    await tester.pumpAndSettle();

    verify(() => repo.revokeShare('t', 1)).called(1);
  });

  testWidgets('刪除 → 確認 → 呼叫 delete', (tester) async {
    when(() => repo.deleteShare(any(), any())).thenAnswer((_) async {});

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('share-actions-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('share-delete-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CupertinoActionSheetAction, '刪除'));
    await tester.pumpAndSettle();

    verify(() => repo.deleteShare('t', 1)).called(1);
  });

  testWidgets('已關閉連結預設折疊，展開後顯示', (tester) async {
    when(() => repo.fetchShares(any())).thenAnswer(
      (_) async => const [
        TripShare(id: 1, label: '使用中', viewCount: 2),
        TripShare(
          id: 2,
          label: '給同事',
          viewCount: 3,
          revokedAt: '2026-07-01T00:00:00Z',
        ),
      ],
    );

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('使用中的連結（1）'), findsOneWidget);
    expect(find.byKey(const ValueKey('share-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('share-2')), findsNothing);
    expect(find.byKey(const ValueKey('share-revoked-toggle')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('share-revoked-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('share-2')), findsOneWidget);
    expect(find.text('給同事'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('share-actions-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('share-delete-2')), findsOneWidget);
  });

  testWidgets('編輯名稱 → 儲存 → 呼叫 updateShare', (tester) async {
    when(
      () => repo.updateShare(
        any(),
        any(),
        label: any(named: 'label'),
        visibleSections: any(named: 'visibleSections'),
        anonymous: any(named: 'anonymous'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('share-actions-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('share-edit-btn-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('share-edit-label')),
      '旅伴',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('share-edit-submit')));
    await tester.pumpAndSettle();

    final sections =
        verify(
              () => repo.updateShare(
                't',
                1,
                label: '旅伴',
                visibleSections: captureAny(named: 'visibleSections'),
                anonymous: false,
              ),
            ).captured.single
            as List<String>;
    expect(sections, isEmpty);
  });

  testWidgets('編輯後取消會確認捨棄並保留 sheet 草稿', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('share-actions-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('share-edit-btn-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('share-edit-label')),
      '尚未儲存',
    );

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.text('捨棄未儲存的變更？'), findsOneWidget);
    await tester.tap(find.text('取消').last);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '尚未儲存'), findsOneWidget);
  });

  testWidgets('編輯內容改回初始值會恢復 clean 並可直接取消', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('share-actions-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('share-edit-btn-1')));
    await tester.pumpAndSettle();

    final submit = find.byKey(const ValueKey('share-edit-submit'));
    expect(tester.widget<TpToolbarTextButton>(submit).onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('share-edit-label')),
      '暫時名稱',
    );
    await tester.pump();
    expect(tester.widget<TpToolbarTextButton>(submit).onPressed, isNotNull);

    await tester.enterText(
      find.byKey(const ValueKey('share-edit-label')),
      '給爸媽',
    );
    await tester.pump();
    expect(tester.widget<TpToolbarTextButton>(submit).onPressed, isNull);

    await tester.tap(find.widgetWithText(TpToolbarTextButton, '取消'));
    await tester.pumpAndSettle();
    expect(find.text('捨棄未儲存的變更？'), findsNothing);
    expect(find.byKey(const ValueKey('share-edit-label')), findsNothing);
  });

  testWidgets('編輯儲存失敗保留全部輸入並留在 sheet', (tester) async {
    when(
      () => repo.updateShare(
        any(),
        any(),
        label: any(named: 'label'),
        visibleSections: any(named: 'visibleSections'),
        anonymous: any(named: 'anonymous'),
      ),
    ).thenThrow(Exception('offline'));

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('share-actions-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('share-edit-btn-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('share-edit-label')),
      '離線草稿',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('share-edit-submit')));
    await tester.pumpAndSettle();

    expect(find.text('儲存失敗，輸入內容已保留，請重試。'), findsOneWidget);
    expect(find.widgetWithText(TextField, '離線草稿'), findsOneWidget);
    expect(find.byKey(const ValueKey('share-edit-submit')), findsOneWidget);
  });

  testWidgets('編輯設定 → 公開區塊與匿名一起更新', (tester) async {
    when(() => repo.fetchShares(any())).thenAnswer(
      (_) async => const [
        TripShare(
          id: 1,
          label: '給爸媽',
          visibleSections: ['flights', 'lodgings'],
          anonymous: false,
        ),
      ],
    );
    when(
      () => repo.updateShare(
        any(),
        any(),
        label: any(named: 'label'),
        visibleSections: any(named: 'visibleSections'),
        anonymous: any(named: 'anonymous'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('share-actions-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('share-edit-btn-1')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('share-edit-section-reservations')),
    );
    await tester.tap(find.byKey(const ValueKey('share-edit-anonymous')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('share-edit-submit')));
    await tester.pumpAndSettle();

    final sections =
        verify(
              () => repo.updateShare(
                't',
                1,
                label: '給爸媽',
                visibleSections: captureAny(named: 'visibleSections'),
                anonymous: true,
              ),
            ).captured.single
            as List<String>;
    expect(sections, ['flights', 'lodgings', 'reservations']);
  });

  testWidgets('編輯期限 → 7 天 preset 送 expiresAt', (tester) async {
    when(
      () => repo.updateShare(
        any(),
        any(),
        label: any(named: 'label'),
        visibleSections: any(named: 'visibleSections'),
        expiresAt: any(named: 'expiresAt'),
        anonymous: any(named: 'anonymous'),
      ),
    ).thenAnswer((_) async {});

    final before = DateTime.now().millisecondsSinceEpoch;
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('share-actions-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('share-edit-btn-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('share-edit-expiry-7d')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('share-edit-submit')));
    await tester.pumpAndSettle();
    final after = DateTime.now().millisecondsSinceEpoch;

    final expiresAt =
        verify(
              () => repo.updateShare(
                't',
                1,
                label: '給爸媽',
                visibleSections: any(named: 'visibleSections'),
                expiresAt: captureAny(named: 'expiresAt'),
                anonymous: false,
              ),
            ).captured.single
            as int;
    expect(
      expiresAt,
      greaterThanOrEqualTo(
        before + const Duration(days: 7).inMilliseconds - 1000,
      ),
    );
    expect(
      expiresAt,
      lessThanOrEqualTo(after + const Duration(days: 7).inMilliseconds + 1000),
    );
  });

  testWidgets('重新產生連結 → 顯示新的完整 URL', (tester) async {
    when(() => repo.rotateShare(any(), any())).thenAnswer(
      (_) async => const RotatedShareLink(token: 'newtok', url: '/s/newtok'),
    );

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('share-actions-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('share-rotate-1')));
    await tester.pumpAndSettle();

    verify(() => repo.rotateShare('t', 1)).called(1);
    expect(find.textContaining('/s/newtok'), findsOneWidget);
    expect(find.byKey(const ValueKey('share-copy')), findsOneWidget);
  });

  testWidgets('非 write 權限(403)→ 提示', (tester) async {
    when(() => repo.fetchShares(any())).thenAnswer(
      (_) async =>
          throw const ApiError(status: 403, code: 'PERM', message: 'no'),
    );

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    expect(find.textContaining('只有可編輯'), findsOneWidget);
    expect(find.byKey(const ValueKey('share-create')), findsNothing);
  });

  testWidgets('最大 Dynamic Type 下 row 只保留 44pt 動作選單且不溢位', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildApp(theme: AppTheme.dark(), textScaler: const TextScaler.linear(2)),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const ValueKey('share-actions-1'))),
      const Size(44, 44),
    );
    expect(find.byKey(const ValueKey('share-edit-btn-1')), findsNothing);
  });
}
