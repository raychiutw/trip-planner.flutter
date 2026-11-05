import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/features/ai_consent/ai_data_settings_screen.dart';
import 'package:tripline/models/ai_data_consent.dart';
import 'package:tripline/models/user.dart';
import 'package:tripline/theme/app_theme.dart';

import '../../helpers/ai_data_consent_fixtures.dart';

class _StubAuth extends AuthNotifier {
  @override
  Future<UserInfo?> build() async =>
      const UserInfo(id: 'u1', email: 'a@b.c', emailVerified: true);
}

void main() {
  late MockAiDataConsentRepo repo;

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (retryCount, error) => null,
        overrides: [
          authStateProvider.overrideWith(_StubAuth.new),
          aiDataConsentRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const AiDataSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() => repo = MockAiDataConsentRepo());

  testWidgets('已同意：顯示已同意的版本與時間，以及 server 的說明文字', (tester) async {
    when(
      repo.fetch,
    ).thenAnswer((_) async => aiConsentFixture(AiDataConsentStatus.valid));
    await pump(tester);

    expect(find.text('AI 助理已開啟'), findsOneWidget);
    expect(find.textContaining('版本 ai-data-v1'), findsWidgets);
    expect(find.textContaining('2026-10-01'), findsOneWidget);
    expect(find.text('以下說明由 server 提供'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ai-data-settings-withdraw')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ai-data-settings-consent')),
      findsNothing,
    );
  });

  testWidgets('撤回：先照實告知再確認；確認後呼叫 DELETE 並換成可重新同意', (tester) async {
    when(
      repo.fetch,
    ).thenAnswer((_) async => aiConsentFixture(AiDataConsentStatus.valid));
    when(
      repo.withdraw,
    ).thenAnswer((_) async => aiConsentFixture(AiDataConsentStatus.withdrawn));
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('ai-data-settings-withdraw')));
    await tester.pumpAndSettle();

    // 對話框內逐條顯示 server 的撤回說明，不寫「立即停止」。
    expect(find.textContaining('已經開始的工作不保證能停止'), findsOneWidget);
    expect(find.textContaining('已經交給 AI 處理的資料無法收回'), findsOneWidget);
    expect(find.textContaining('立即停止'), findsNothing);
    verifyNever(repo.withdraw);

    await tester.tap(find.text('撤回同意').last);
    await tester.pumpAndSettle();

    verify(repo.withdraw).called(1);
    expect(find.text('AI 助理已關閉'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ai-data-settings-consent')),
      findsOneWidget,
    );
  });

  testWidgets('撤回取消：不呼叫 DELETE', (tester) async {
    when(
      repo.fetch,
    ).thenAnswer((_) async => aiConsentFixture(AiDataConsentStatus.valid));
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('ai-data-settings-withdraw')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    verifyNever(repo.withdraw);
    expect(find.text('AI 助理已開啟'), findsOneWidget);
  });

  testWidgets('撤回失敗：留在已同意並顯示錯誤，不假裝已撤回', (tester) async {
    when(
      repo.fetch,
    ).thenAnswer((_) async => aiConsentFixture(AiDataConsentStatus.valid));
    when(repo.withdraw).thenThrow(ApiError.fromResponse(500, null));
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('ai-data-settings-withdraw')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('撤回同意').last);
    await tester.pumpAndSettle();

    expect(find.text('AI 助理已開啟'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ai-data-settings-error')),
      findsOneWidget,
    );
  });

  for (final (status, head) in [
    (AiDataConsentStatus.none, 'AI 助理尚未開啟'),
    (AiDataConsentStatus.stale, 'AI 助理已暫停：說明已更新'),
    (AiDataConsentStatus.withdrawn, 'AI 助理已關閉'),
  ]) {
    testWidgets('$status：顯示「$head」與同意入口，同意後轉為已開啟', (tester) async {
      when(repo.fetch).thenAnswer((_) async => aiConsentFixture(status));
      when(
        () => repo.accept('ai-data-v1'),
      ).thenAnswer((_) async => aiConsentFixture(AiDataConsentStatus.valid));
      await pump(tester);

      expect(find.text(head), findsOneWidget);
      expect(
        find.byKey(const ValueKey('ai-data-settings-withdraw')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('ai-data-settings-consent')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ai-data-consent-accept')));
      await tester.pumpAndSettle();

      verify(() => repo.accept('ai-data-v1')).called(1);
      expect(find.text('AI 助理已開啟'), findsOneWidget);
    });
  }

  testWidgets('讀不到狀態：說明無法取得並可重試', (tester) async {
    var reads = 0;
    when(repo.fetch).thenAnswer(
      (_) async =>
          reads++ == 0 ? null : aiConsentFixture(AiDataConsentStatus.valid),
    );
    await pump(tester);

    expect(
      find.byKey(const ValueKey('ai-data-settings-unavailable')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('ai-data-settings-retry')));
    await tester.pumpAndSettle();

    expect(find.text('AI 助理已開啟'), findsOneWidget);
  });
}
