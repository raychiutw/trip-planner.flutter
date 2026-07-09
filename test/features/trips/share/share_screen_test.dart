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
    when(() => repo.createShare(any(), label: any(named: 'label'))).thenAnswer(
      (_) async =>
          const ShareLink(id: 7, token: 'tok', url: '/s/tok', label: 'x'),
    );

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('share-label')), 'x');
    await tester.tap(find.byKey(const ValueKey('share-create')));
    await tester.pumpAndSettle();

    verify(() => repo.createShare('t', label: 'x')).called(1);
    expect(find.textContaining('/s/tok'), findsOneWidget);
    expect(find.byKey(const ValueKey('share-copy')), findsOneWidget);
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
