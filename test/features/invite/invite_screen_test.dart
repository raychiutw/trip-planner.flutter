import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/collab_repository.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/features/invite/invite_screen.dart';
import 'package:tripline/models/trip_member.dart';
import 'package:tripline/models/user.dart';
import 'package:tripline/theme/app_theme.dart';

class _MockCollabRepo extends Mock implements CollabRepository {}

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._user);

  final UserInfo? _user;

  @override
  Future<UserInfo?> build() async => _user;

  @override
  Future<void> logout() async {
    state = const AsyncData(null);
  }
}

const _invitation = InvitationDetails(
  tripId: 'trip-1',
  tripTitle: '沖繩家庭旅行',
  invitedEmail: 'traveler@example.com',
  inviterDisplayName: 'Ray',
  inviterEmail: 'ray@example.com',
  expiresAt: '2026-07-16T00:00:00.000Z',
);

const _traveler = UserInfo(
  id: 'u1',
  email: 'traveler@example.com',
  emailVerified: true,
);

const _otherUser = UserInfo(
  id: 'u2',
  email: 'other@example.com',
  emailVerified: true,
);

void main() {
  late _MockCollabRepo repo;

  Future<void> pumpInvite(
    WidgetTester tester, {
    UserInfo? user,
    String token = 'raw-token',
    Locale locale = const Locale('zh', 'TW'),
    Size size = const Size(390, 844),
    double textScale = 1,
    bool settle = true,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      initialLocation: '/invite?token=$token',
      routes: [
        GoRoute(
          path: '/invite',
          builder: (context, state) =>
              InviteScreen(token: state.uri.queryParameters['token'] ?? ''),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => Scaffold(
            body: Text('login ${state.uri.queryParameters['redirect_after']}'),
          ),
        ),
        GoRoute(
          path: '/signup',
          builder: (context, state) => Scaffold(
            body: Text('signup ${state.uri.queryParameters['invitation']}'),
          ),
        ),
        GoRoute(
          path: '/trips/:tripId',
          builder: (context, state) =>
              Scaffold(body: Text('trip ${state.pathParameters['tripId']}')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collabRepositoryProvider.overrideWithValue(repo),
          authStateProvider.overrideWith(() => _FakeAuthNotifier(user)),
        ],
        child: MaterialApp.router(
          locale: locale,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('zh', 'TW'), Locale('en', 'US')],
          theme: AppTheme.light(),
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(size: size, textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  setUp(() {
    repo = _MockCollabRepo();
    when(
      () => repo.fetchInvitation(any()),
    ).thenAnswer((_) async => _invitation);
    when(() => repo.acceptInvitation(any())).thenAnswer(
      (_) async =>
          const InvitationAcceptResult(tripId: 'trip-1', tripTitle: '沖繩家庭旅行'),
    );
  });

  testWidgets('未登入顯示 C 版 checklist 並保留 invite redirect', (tester) async {
    await pumpInvite(tester);

    expect(find.byKey(const ValueKey('invite-page')), findsOneWidget);
    expect(find.text('共編邀請'), findsOneWidget);
    expect(find.text('沖繩家庭旅行'), findsOneWidget);
    expect(find.text('邀請連結有效'), findsOneWidget);
    expect(find.text('帳號待確認'), findsOneWidget);
    expect(find.text('登入 traveler@example.com 後即可加入'), findsOneWidget);
    expect(find.byKey(const ValueKey('invite-signup')), findsOneWidget);
    expect(find.byKey(const ValueKey('invite-login')), findsOneWidget);
    expect(find.byKey(const ValueKey('account-avatar-button')), findsNothing);
    expect(
      tester
          .widget<ListView>(find.byKey(const ValueKey('invite-page')))
          .keyboardDismissBehavior,
      ScrollViewKeyboardDismissBehavior.onDrag,
    );

    await tester.tap(find.byKey(const ValueKey('invite-signup')));
    await tester.pumpAndSettle();

    expect(find.text('signup raw-token'), findsOneWidget);
    verifyNever(() => repo.acceptInvitation(any()));
  });

  testWidgets('邀請載入狀態會向 screen reader 宣告', (tester) async {
    final pending = Completer<InvitationDetails>();
    when(() => repo.fetchInvitation(any())).thenAnswer((_) => pending.future);

    await pumpInvite(tester, settle: false);

    final loading = find.byKey(const ValueKey('invite-loading'));
    expect(loading, findsOneWidget);
    expect(
      tester
          .getSemantics(loading)
          .getSemanticsData()
          .flagsCollection
          .isLiveRegion,
      isTrue,
    );

    pending.complete(_invitation);
    await tester.pumpAndSettle();
  });

  testWidgets('未登入點登入會帶回 invite redirect', (tester) async {
    await pumpInvite(tester);

    await tester.tap(find.byKey(const ValueKey('invite-login')));
    await tester.pumpAndSettle();

    expect(find.text('login /invite?token=raw-token'), findsOneWidget);
    verifyNever(() => repo.acceptInvitation(any()));
  });

  testWidgets('邀請期限依目前 locale 顯示', (tester) async {
    await pumpInvite(tester, locale: const Locale('en', 'US'));

    expect(find.text('有效至 7/16/2026'), findsOneWidget);
  });

  testWidgets('邀請頁在 compact Accessibility Size 可捲動完成流程', (tester) async {
    await pumpInvite(tester, size: const Size(320, 568), textScale: 3.2);

    final login = find.byKey(const ValueKey('invite-login'));
    await tester.ensureVisible(login);
    await tester.pumpAndSettle();

    expect(login, findsOneWidget);
    expect(tester.getSize(login).height, greaterThanOrEqualTo(44));
    expect(tester.takeException(), isNull);
  });

  testWidgets('登入帳號符合時可接受邀請並前往行程', (tester) async {
    await pumpInvite(tester, user: _traveler);

    expect(find.text('帳號已確認'), findsOneWidget);
    expect(find.text('目前登入 traveler@example.com'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('invite-accept')));
    await tester.pumpAndSettle();

    verify(() => repo.acceptInvitation('raw-token')).called(1);
    expect(find.text('trip trip-1'), findsOneWidget);
  });

  testWidgets('登入帳號不符時顯示 C 版 checklist 並提供切換帳號', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpInvite(tester, user: _otherUser);

    expect(find.byKey(const ValueKey('invite-mismatch')), findsOneWidget);
    expect(find.text('使用對應帳號接受邀請'), findsOneWidget);
    expect(find.text('請切換到受邀帳號後再加入此行程。'), findsOneWidget);
    expect(find.byKey(const ValueKey('invite-account-pair')), findsOneWidget);
    expect(find.text('邀請帳號'), findsOneWidget);
    expect(find.text('目前帳號'), findsOneWidget);
    expect(find.text('traveler@example.com'), findsOneWidget);
    expect(find.text('other@example.com'), findsOneWidget);
    expect(find.textContaining('此邀請寄給'), findsNothing);
    expect(find.textContaining('但目前登入的是'), findsNothing);
    expect(find.byKey(const ValueKey('invite-accept')), findsNothing);

    final switchButton = find.byKey(const ValueKey('invite-switch-account'));
    await tester.drag(
      find.byKey(const ValueKey('invite-page')),
      const Offset(0, -160),
    );
    await tester.pumpAndSettle();
    await tester.tap(switchButton);
    await tester.pumpAndSettle();

    expect(find.text('login /invite?token=raw-token'), findsOneWidget);
  });

  testWidgets('邀請無效時顯示持續錯誤狀態', (tester) async {
    when(() => repo.fetchInvitation(any())).thenThrow(
      const ApiError(
        status: 410,
        code: 'INVITATION_EXPIRED',
        message: 'expired',
      ),
    );

    await pumpInvite(tester);

    expect(find.byKey(const ValueKey('invite-error')), findsOneWidget);
    expect(find.text('邀請已過期，請聯絡邀請者重寄。'), findsOneWidget);
    expect(find.text('請聯絡邀請者重寄一份新的邀請連結。'), findsNothing);
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('invite-error')))
          .getSemanticsData()
          .flagsCollection
          .isLiveRegion,
      isTrue,
    );
  });
}
