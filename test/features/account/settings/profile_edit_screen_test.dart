import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/account/settings/profile_edit_screen.dart';
import 'package:tripline/models/user.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_app_bar.dart';

class _MockAuthRepo extends Mock implements AuthRepository {}

class _MockTripRepo extends Mock implements TripRepository {}

void main() {
  late _MockAuthRepo authRepo;
  late _MockTripRepo tripRepo;
  late GoRouter router;

  setUp(() {
    authRepo = _MockAuthRepo();
    tripRepo = _MockTripRepo();
    when(() => authRepo.currentUser()).thenAnswer(
      (_) async =>
          const UserInfo(id: '1', email: 'me@x.com', displayName: '舊名字'),
    );
  });

  Widget buildApp({TextScaler textScaler = TextScaler.noScaling}) {
    router = GoRouter(
      initialLocation: '/settings/profile',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: Column(
              children: [
                const Text('帳號首頁'),
                Consumer(
                  builder: (_, ref, _) => Text(
                    ref.watch(authStateProvider).asData?.value?.displayName ??
                        '載入中',
                  ),
                ),
              ],
            ),
          ),
          routes: [
            GoRoute(
              path: 'settings/profile',
              builder: (_, _) => const ProfileEditScreen(),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    return ProviderScope(
      retry: (_, _) => null,
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepo),
        tripRepositoryProvider.overrideWithValue(tripRepo),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
      ),
    );
  }

  testWidgets('帶入目前名稱 + 改名儲存 → updateProfile', (tester) async {
    when(
      () => tripRepo.updateProfile(displayName: any(named: 'displayName')),
    ).thenAnswer(
      (_) async =>
          const UserInfo(id: '1', email: 'me@x.com', displayName: '新名字'),
    );

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    expect(find.text('舊名字'), findsOneWidget); // 帶入初值
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('儲存'), findsOneWidget);
    expect(find.byKey(const ValueKey('tp-app-bar-back')), findsNothing);
    expect(
      tester
          .widget<TpToolbarTextButton>(
            find.byKey(const ValueKey('profile-save')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const ValueKey('profile-display-name')),
              matching: find.byType(EditableText),
            ),
          )
          .focusNode
          .hasFocus,
      isTrue,
    );
    expect(find.text('個人資料'), findsNWidgets(2));

    await tester.enterText(
      find.byKey(const ValueKey('profile-display-name')),
      '新名字',
    );
    await tester.pump();
    expect(
      tester
          .widget<TpToolbarTextButton>(
            find.byKey(const ValueKey('profile-save')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const ValueKey('profile-save')));
    await tester.pumpAndSettle();

    verify(() => tripRepo.updateProfile(displayName: '新名字')).called(1);
  });

  testWidgets('名稱只差空白不需儲存，送出時去除首尾空白', (tester) async {
    when(() => tripRepo.updateProfile(displayName: '新名字')).thenAnswer(
      (_) async =>
          const UserInfo(id: '1', email: 'me@x.com', displayName: '新名字'),
    );
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('profile-display-name'));
    final save = find.byKey(const ValueKey('profile-save'));
    await tester.enterText(field, '  舊名字  ');
    await tester.pump();
    expect(tester.widget<TpToolbarTextButton>(save).onPressed, isNull);
    verifyNever(
      () => tripRepo.updateProfile(displayName: any(named: 'displayName')),
    );
    await tester.enterText(field, '  新名字  ');
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();
    verify(() => tripRepo.updateProfile(displayName: '新名字')).called(1);
    expect(find.byType(ProfileEditScreen), findsNothing);
    expect(find.text('帳號首頁'), findsOneWidget);
  });

  testWidgets('送出 A 後繼續輸入 B，成功只確認 A 並保留 B 的離頁保護', (tester) async {
    final pending = Completer<UserInfo>();
    when(
      () => tripRepo.updateProfile(displayName: any(named: 'displayName')),
    ).thenAnswer((_) => pending.future);
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('profile-display-name'));
    await tester.enterText(field, 'A');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('profile-save')));
    await tester.pump();
    await tester.enterText(field, 'B');
    pending.complete(
      const UserInfo(id: '1', email: 'me@x.com', displayName: 'A'),
    );
    await tester.pumpAndSettle();
    expect(find.text('B'), findsOneWidget);
    expect(find.text('帳號首頁'), findsNothing);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('捨棄未儲存的變更？'), findsOneWidget);
    verify(() => tripRepo.updateProfile(displayName: 'A')).called(1);
  });

  testWidgets('初載錯誤可重試，錯誤對讀屏持續宣告', (tester) async {
    when(() => authRepo.currentUser()).thenThrow(Exception('offline'));
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    expect(find.text('無法載入個人資料'), findsOneWidget);
    expect(
      tester
          .widget<Semantics>(
            find
                .ancestor(
                  of: find.text('無法載入個人資料'),
                  matching: find.byType(Semantics),
                )
                .first,
          )
          .properties
          .liveRegion,
      isTrue,
    );
    when(() => authRepo.currentUser()).thenAnswer(
      (_) async =>
          const UserInfo(id: '1', email: 'me@x.com', displayName: '舊名字'),
    );
    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();
    expect(find.text('舊名字'), findsOneWidget);
  });

  testWidgets('鍵盤與按鈕共用提交，顯示儲存進度，失敗保留草稿並可重試', (tester) async {
    final pending = Completer<UserInfo>();
    when(
      () => tripRepo.updateProfile(displayName: any(named: 'displayName')),
    ).thenAnswer((_) => pending.future);
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('profile-display-name')),
      '新名字',
    );
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.tap(find.byKey(const ValueKey('profile-save')));
    await tester.pump();
    verify(() => tripRepo.updateProfile(displayName: '新名字')).called(1);
    expect(find.text('儲存中…'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pump();
    expect(find.text('捨棄未儲存的變更？'), findsNothing);
    pending.completeError(Exception('offline'));
    await tester.pumpAndSettle();
    expect(find.text('新名字'), findsOneWidget);
    expect(find.text('儲存失敗,請稍後再試'), findsOneWidget);
    expect(
      tester
          .widget<Semantics>(
            find
                .ancestor(
                  of: find.text('儲存失敗,請稍後再試'),
                  matching: find.byType(Semantics),
                )
                .first,
          )
          .properties
          .liveRegion,
      isTrue,
    );
    when(
      () => tripRepo.updateProfile(displayName: any(named: 'displayName')),
    ).thenAnswer(
      (_) async =>
          const UserInfo(id: '1', email: 'me@x.com', displayName: '新名字'),
    );
    await tester.tap(find.byKey(const ValueKey('profile-save')));
    await tester.pumpAndSettle();
    expect(find.text('帳號首頁'), findsOneWidget);
  });

  testWidgets('離頁後成功只刷新帳號資料，不顯示通知或返回其他頁', (tester) async {
    final pending = Completer<UserInfo>();
    when(
      () => tripRepo.updateProfile(displayName: any(named: 'displayName')),
    ).thenAnswer((_) => pending.future);
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('profile-display-name')),
      '新名字',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('profile-save')));
    router.go('/');
    await tester.pumpAndSettle();
    expect(find.text('帳號首頁'), findsOneWidget);
    when(() => authRepo.currentUser()).thenAnswer(
      (_) async =>
          const UserInfo(id: '1', email: 'me@x.com', displayName: '新名字'),
    );
    pending.complete(
      const UserInfo(id: '1', email: 'me@x.com', displayName: '新名字'),
    );
    await tester.pumpAndSettle();
    expect(find.text('新名字'), findsOneWidget);
    expect(find.text('已更新個人資料'), findsNothing);
    expect(find.text('帳號首頁'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('成功後排程返回前的新輸入仍保留，不使用過期關閉許可', (tester) async {
    final pending = Completer<UserInfo>();
    when(
      () => tripRepo.updateProfile(displayName: any(named: 'displayName')),
    ).thenAnswer((_) => pending.future);
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('profile-display-name')),
      'A',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('profile-save')));
    pending.complete(
      const UserInfo(id: '1', email: 'me@x.com', displayName: 'A'),
    );
    await tester.idle();
    tester.testTextInput.updateEditingValue(const TextEditingValue(text: 'B'));
    await tester.idle();
    await tester.pumpAndSettle();
    expect(find.text('B'), findsOneWidget);
    expect(find.text('帳號首頁'), findsNothing);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('捨棄未儲存的變更？'), findsOneWidget);
  });

  testWidgets('儲存後刷新帳號失敗仍保留後續草稿及重試出口', (tester) async {
    final pending = Completer<UserInfo>();
    when(
      () => tripRepo.updateProfile(displayName: any(named: 'displayName')),
    ).thenAnswer((_) => pending.future);
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('profile-display-name'));
    await tester.enterText(field, 'A');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('profile-save')));
    await tester.enterText(field, 'B');
    when(() => authRepo.currentUser()).thenThrow(Exception('offline'));
    pending.complete(
      const UserInfo(id: '1', email: 'me@x.com', displayName: 'A'),
    );
    await tester.pumpAndSettle();
    expect(find.text('B'), findsOneWidget);
    expect(find.text('重試'), findsOneWidget);
    when(() => authRepo.currentUser()).thenAnswer(
      (_) async => const UserInfo(id: '1', email: 'me@x.com', displayName: 'A'),
    );
    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();
    expect(find.text('B'), findsOneWidget);
  });

  for (final succeeds in [true, false]) {
    testWidgets('儲存${succeeds ? '成功' : '失敗'}後保留新草稿的游標與中文組字', (tester) async {
      final pending = Completer<UserInfo>();
      when(
        () => tripRepo.updateProfile(displayName: any(named: 'displayName')),
      ).thenAnswer((_) => pending.future);
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('profile-display-name'));
      await tester.enterText(field, 'A');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('profile-save')));
      await tester.pump();
      const editing = TextEditingValue(
        text: '新名字',
        selection: TextSelection.collapsed(offset: 1),
        composing: TextRange(start: 0, end: 2),
      );
      tester.testTextInput.updateEditingValue(editing);
      await tester.pump();
      if (succeeds) {
        pending.complete(
          const UserInfo(id: '1', email: 'me@x.com', displayName: 'A'),
        );
      } else {
        pending.completeError(Exception('offline'));
      }
      await tester.pumpAndSettle();
      final editable = tester.widget<EditableText>(
        find.descendant(of: field, matching: find.byType(EditableText)),
      );
      expect(editable.controller.value, editing);
      expect(editable.focusNode.hasFocus, isTrue);
    });
  }

  testWidgets('改名後取消會確認捨棄未儲存變更', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('profile-display-name')),
      '新名字',
    );
    await tester.pump();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.text('捨棄未儲存的變更？'), findsOneWidget);
  });

  testWidgets('200% Dynamic Type 下個人資料欄位與儲存動作不裁切', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildApp(textScaler: const TextScaler.linear(2)));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('profile-display-name')), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-save')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
