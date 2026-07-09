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

class _MockShareRepo extends Mock implements ShareRepository {}

const _shares = [TripShare(id: 1, label: '給爸媽', viewCount: 2)];

void main() {
  late _MockShareRepo repo;
  setUp(() {
    repo = _MockShareRepo();
    when(() => repo.fetchShares(any())).thenAnswer((_) async => _shares);
  });

  Widget buildApp() => ProviderScope(
    overrides: [shareRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const ShareScreen(tripId: 't'),
    ),
  );

  testWidgets('渲染現有連結', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    expect(find.text('給爸媽'), findsOneWidget);
    expect(find.textContaining('已被檢視 2 次'), findsOneWidget);
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
    await tester.tap(find.text('OK'));
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

  testWidgets('撤銷 → 確認 → 呼叫 revoke', (tester) async {
    when(() => repo.revokeShare(any(), any())).thenAnswer((_) async {});

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('share-revoke-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '撤銷')); // 對話框確認
    await tester.pumpAndSettle();

    verify(() => repo.revokeShare('t', 1)).called(1);
  });

  testWidgets('刪除 → 確認 → 呼叫 delete', (tester) async {
    when(() => repo.deleteShare(any(), any())).thenAnswer((_) async {});

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('share-delete-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '刪除'));
    await tester.pumpAndSettle();

    verify(() => repo.deleteShare('t', 1)).called(1);
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
    await tester.tap(find.byKey(const ValueKey('share-edit-btn-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('share-edit-label')),
      '旅伴',
    );
    await tester.tap(find.widgetWithText(FilledButton, '儲存'));
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
    await tester.tap(find.byKey(const ValueKey('share-edit-btn-1')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('share-edit-section-reservations')),
    );
    await tester.tap(find.byKey(const ValueKey('share-edit-anonymous')));
    await tester.tap(find.widgetWithText(FilledButton, '儲存'));
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
    await tester.tap(find.byKey(const ValueKey('share-edit-btn-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('share-edit-expiry-7d')));
    await tester.tap(find.widgetWithText(FilledButton, '儲存'));
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
}
