import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoColors;
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/requests_repository.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/features/chat/chat_screen.dart';
import 'package:tripline/features/chat/speech_service.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/models/trip_request.dart';
import 'package:tripline/models/user.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_glass_surface.dart';
import 'package:tripline/ui/tp_root_scaffold.dart';

class _MockRequestsRepo extends Mock implements RequestsRepository {}

class _MockTripRepo extends Mock implements TripRepository {}

class _MockSpeechService extends Mock implements SpeechService {}

class _MockAuthRepo extends Mock implements AuthRepository {}

class _StubAuth extends AuthNotifier {
  _StubAuth(this.user);

  final UserInfo user;

  @override
  Future<UserInfo?> build() async => user;
}

class _ChatQueryHarness extends StatefulWidget {
  const _ChatQueryHarness({super.key});

  @override
  State<_ChatQueryHarness> createState() => _ChatQueryHarnessState();
}

class _ChatQueryHarnessState extends State<_ChatQueryHarness> {
  String _tripId = 'okinawa';
  String? _prefill;

  void showTrip(String tripId, {String? prefill}) {
    setState(() {
      _tripId = tripId;
      _prefill = prefill;
    });
  }

  @override
  Widget build(BuildContext context) =>
      ChatScreen(initialTripId: _tripId, initialPrefill: _prefill);
}

const _trips = [TripSummary(tripId: 'okinawa', name: 'okinawa', title: '沖繩')];

TripRequest _req({
  required int id,
  String message = 'hi',
  String? reply,
  required RequestStatus status,
  String? submittedBy,
  String? submittedByDisplayName,
}) => TripRequest(
  id: id,
  tripId: 'okinawa',
  message: message,
  reply: reply,
  status: status,
  submittedBy: submittedBy,
  submittedByDisplayName: submittedByDisplayName,
);

void main() {
  late _MockRequestsRepo reqRepo;
  late _MockTripRepo tripRepo;
  late _MockAuthRepo authRepo;

  setUp(() {
    reqRepo = _MockRequestsRepo();
    tripRepo = _MockTripRepo();
    authRepo = _MockAuthRepo();
    when(tripRepo.watchMyTrips).thenAnswer((_) => Stream.value(_trips));
    when(authRepo.fetchAiAuthorization).thenAnswer((_) async => true);
    when(authRepo.authorizeAi).thenAnswer((_) async => true);
    // 預設聊天串為空(各測試可覆寫)。
    when(
      () => reqRepo.fetchRequests(
        tripId: any(named: 'tripId'),
        limit: any(named: 'limit'),
        sort: any(named: 'sort'),
        before: any(named: 'before'),
        beforeId: any(named: 'beforeId'),
      ),
    ).thenAnswer((_) async => (items: <TripRequest>[], hasMore: false));
  });

  Widget buildApp({
    SpeechService? speech,
    String? initialTripId,
    String? initialPrefill,
    UserInfo currentUser = const UserInfo(
      id: '1',
      email: 'ray@example.com',
      displayName: 'Ray Chiu',
    ),
    ThemeData? theme,
    ValueNotifier<int>? reselects,
    Widget? home,
  }) {
    final screen =
        home ??
        ChatScreen(
          initialTripId: initialTripId,
          initialPrefill: initialPrefill,
        );
    return ProviderScope(
      overrides: [
        requestsRepositoryProvider.overrideWithValue(reqRepo),
        tripRepositoryProvider.overrideWithValue(tripRepo),
        authRepositoryProvider.overrideWithValue(authRepo),
        authStateProvider.overrideWith(() => _StubAuth(currentUser)),
        if (speech != null) speechServiceProvider.overrideWithValue(speech),
      ],
      child: MaterialApp(
        theme: theme ?? AppTheme.light(),
        home: reselects == null
            ? screen
            : TpRootReselectScope(notifier: reselects, child: screen),
      ),
    );
  }

  testWidgets('Root Glass Header 直接顯示目前行程並提供 HIG sheet', (tester) async {
    when(tripRepo.watchMyTrips).thenAnswer(
      (_) => Stream.value(const [
        TripSummary(tripId: 'okinawa', name: 'okinawa', title: '沖繩'),
        TripSummary(tripId: 'kyoto', name: 'kyoto', title: '京都'),
      ]),
    );

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('chat-trip-dropdown')), findsOneWidget);
    expect(find.text('沖繩'), findsWidgets);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(find.byKey(const ValueKey('account-avatar-button')), findsOneWidget);
    expect(find.byType(TpRootScaffold), findsOneWidget);
    expect(find.byKey(const ValueKey('tp-root-glass-header')), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-title-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('tp-app-bar-back')), findsNothing);
    expect(find.byKey(const ValueKey('tp-app-bar-close')), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsNothing);

    await tester.tap(find.byKey(const ValueKey('chat-trip-dropdown')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('trip-picker-sheet')), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-picker-search')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('trip-picker-item-okinawa')),
      findsOneWidget,
    );
    expect(find.text('最近的行程'), findsOneWidget);
  });

  testWidgets('登入過期 banner 不會被 Root Header 遮住', (tester) async {
    when(
      () => reqRepo.fetchRequests(
        tripId: any(named: 'tripId'),
        limit: any(named: 'limit'),
        sort: any(named: 'sort'),
        before: any(named: 'before'),
        beforeId: any(named: 'beforeId'),
      ),
    ).thenThrow(
      const ApiError(status: 401, code: 'UNAUTHORIZED', message: 'expired'),
    );

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    final banner = find.text('登入已過期,請重新登入後再試。');
    expect(banner, findsOneWidget);
    final context = tester.element(find.byType(TpRootScaffold));
    expect(
      tester.getTopLeft(banner).dy,
      greaterThanOrEqualTo(TpRootGeometry.initialContentTop(context)),
    );
  });

  testWidgets('重點聊天 tab 會回到訊息頂端並保留草稿', (tester) async {
    final reselects = ValueNotifier<int>(0);
    addTearDown(reselects.dispose);
    when(
      () => reqRepo.fetchRequests(
        tripId: any(named: 'tripId'),
        limit: any(named: 'limit'),
        sort: any(named: 'sort'),
        before: any(named: 'before'),
        beforeId: any(named: 'beforeId'),
      ),
    ).thenAnswer(
      (_) async => (
        items: [
          for (var index = 0; index < 30; index++)
            _req(
              id: index + 1,
              message: '第 ${index + 1} 則行程討論訊息',
              reply: '這是足以撐高聊天清單的回覆內容。',
              status: RequestStatus.completed,
            ),
        ],
        hasMore: false,
      ),
    );

    await tester.pumpWidget(
      buildApp(initialPrefill: '保留的聊天草稿', reselects: reselects),
    );
    await tester.pumpAndSettle();

    final list = find.byKey(const ValueKey('chat-list'));
    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: list, matching: find.byType(Scrollable)),
    );
    await tester.drag(list, const Offset(0, 360));
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, greaterThan(0));
    expect(
      scrollable.position.pixels,
      lessThan(scrollable.position.maxScrollExtent),
    );

    reselects.value++;
    await tester.pumpAndSettle();

    expect(scrollable.position.pixels, scrollable.position.maxScrollExtent);
    final input = tester.widget<TextField>(
      find.byKey(const ValueKey('chat-input')),
    );
    expect(input.controller!.text, '保留的聊天草稿');
  });

  testWidgets('聊天顯示自己名稱與協作者 email fallback，並使用動態 Indigo', (tester) async {
    when(
      () => reqRepo.fetchRequests(
        tripId: any(named: 'tripId'),
        limit: any(named: 'limit'),
        sort: any(named: 'sort'),
        before: any(named: 'before'),
        beforeId: any(named: 'beforeId'),
      ),
    ).thenAnswer(
      (_) async => (
        items: [
          _req(
            id: 1,
            message: '自己的訊息',
            reply: '收到',
            status: RequestStatus.completed,
            submittedBy: 'ray@example.com',
          ),
          _req(
            id: 2,
            message: '協作者訊息',
            reply: '收到',
            status: RequestStatus.completed,
            submittedBy: 'lean@example.com',
          ),
        ],
        hasMore: false,
      ),
    );

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Ray Chiu'), findsOneWidget);
    expect(find.text('lean'), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(const ValueKey('chat-list'))).dy, 0);

    final collaborator = find.byKey(
      const ValueKey('chat-message-collaborator'),
    );
    final collaboratorContext = tester.element(collaborator);
    final accent = CupertinoColors.systemIndigo.resolveFrom(
      collaboratorContext,
    );
    final label = tester.widget<Text>(
      find.byKey(const ValueKey('chat-message-collaborator-label')),
    );
    expect(label.style?.color, accent);
    final decoration =
        tester.widget<DecoratedBox>(collaborator).decoration as BoxDecoration;
    expect(
      decoration.color,
      Color.alphaBlend(
        accent.withValues(alpha: 0.10),
        Theme.of(collaboratorContext).colorScheme.surfaceContainerHigh,
      ),
    );
  });

  testWidgets('聊天訊息可捲到 composer 後方，並可拖曳或點外側收鍵盤', (tester) async {
    when(
      () => reqRepo.fetchRequests(
        tripId: any(named: 'tripId'),
        limit: any(named: 'limit'),
        sort: any(named: 'sort'),
        before: any(named: 'before'),
        beforeId: any(named: 'beforeId'),
      ),
    ).thenAnswer(
      (_) async => (
        items: [
          _req(
            id: 30,
            message: '可收鍵盤的訊息',
            reply: '收到',
            status: RequestStatus.completed,
            submittedBy: 'ray@example.com',
          ),
        ],
        hasMore: false,
      ),
    );

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    final listFinder = find.byKey(const ValueKey('chat-list'));
    final composerFinder = find.byKey(const ValueKey('chat-composer-glass'));
    final list = tester.widget<ListView>(listFinder);
    expect(
      list.keyboardDismissBehavior,
      ScrollViewKeyboardDismissBehavior.onDrag,
    );
    expect(
      tester.getRect(listFinder).bottom,
      greaterThan(tester.getRect(composerFinder).top),
    );

    final inputFinder = find.byKey(const ValueKey('chat-input'));
    EditableText editable() => tester.widget<EditableText>(
      find.descendant(of: inputFinder, matching: find.byType(EditableText)),
    );
    await tester.tap(inputFinder);
    await tester.pump();
    expect(editable().focusNode.hasFocus, isTrue);

    await tester.tap(find.text('可收鍵盤的訊息'));
    await tester.pump();
    expect(editable().focusNode.hasFocus, isFalse);

    await tester.tap(inputFinder);
    await tester.pump();
    await tester.drag(listFinder, const Offset(0, -80));
    await tester.pump();
    expect(editable().focusNode.hasFocus, isFalse);
  });

  testWidgets('聊天自己名稱缺少時使用 email local part', (tester) async {
    when(
      () => reqRepo.fetchRequests(
        tripId: any(named: 'tripId'),
        limit: any(named: 'limit'),
        sort: any(named: 'sort'),
        before: any(named: 'before'),
        beforeId: any(named: 'beforeId'),
      ),
    ).thenAnswer(
      (_) async => (
        items: [
          _req(
            id: 3,
            message: '自己的訊息',
            reply: '收到',
            status: RequestStatus.completed,
            submittedBy: 'ray@example.com',
          ),
        ],
        hasMore: false,
      ),
    );

    await tester.pumpWidget(
      buildApp(
        currentUser: const UserInfo(id: '1', email: 'ray@example.com'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ray'), findsOneWidget);
  });

  testWidgets('深色協作者氣泡使用較強的動態 Indigo tint', (tester) async {
    when(
      () => reqRepo.fetchRequests(
        tripId: any(named: 'tripId'),
        limit: any(named: 'limit'),
        sort: any(named: 'sort'),
        before: any(named: 'before'),
        beforeId: any(named: 'beforeId'),
      ),
    ).thenAnswer(
      (_) async => (
        items: [
          _req(
            id: 4,
            message: '協作者訊息',
            reply: '收到',
            status: RequestStatus.completed,
            submittedBy: 'lean@example.com',
          ),
        ],
        hasMore: false,
      ),
    );

    await tester.pumpWidget(buildApp(theme: AppTheme.dark()));
    await tester.pumpAndSettle();

    final collaborator = find.byKey(
      const ValueKey('chat-message-collaborator'),
    );
    final collaboratorContext = tester.element(collaborator);
    final accent = CupertinoColors.systemIndigo.resolveFrom(
      collaboratorContext,
    );
    final decoration =
        tester.widget<DecoratedBox>(collaborator).decoration as BoxDecoration;
    expect(
      decoration.color,
      Color.alphaBlend(
        accent.withValues(alpha: 0.18),
        Theme.of(collaboratorContext).colorScheme.surfaceContainerHigh,
      ),
    );
  });

  testWidgets('送訊息:輸入 + 點送出 → 樂觀顯示 + verify sendRequest', (tester) async {
    when(
      () => reqRepo.sendRequest(
        tripId: any(named: 'tripId'),
        message: any(named: 'message'),
      ),
    ).thenAnswer(
      (_) async =>
          _req(id: 7, message: '改午餐', status: RequestStatus.processing),
    );
    when(() => reqRepo.fetchRequest(7)).thenAnswer(
      (_) async => _req(
        id: 7,
        message: '改午餐',
        status: RequestStatus.completed,
        reply: '改好了',
      ),
    );

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('chat-composer-glass')), findsOneWidget);
    expect(find.byType(TpGlassSurface), findsNWidgets(2));

    await tester.enterText(find.byKey(const ValueKey('chat-input')), '改午餐');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat-send')));
    await tester.pumpAndSettle();

    verify(
      () => reqRepo.sendRequest(tripId: 'okinawa', message: '改午餐'),
    ).called(1);
    expect(find.text('改午餐'), findsWidgets); // user 氣泡樂觀顯示
  });

  testWidgets('未授權送出 → 顯示 consent sheet；取消保留草稿且不送出', (tester) async {
    when(authRepo.fetchAiAuthorization).thenAnswer((_) async => false);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('chat-input')), '保留這段話');
    await tester.tap(find.byKey(const ValueKey('chat-send')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ai-consent-title')), findsOneWidget);
    expect(find.text('「保留這段話」'), findsOneWidget);
    verifyNever(
      () => reqRepo.sendRequest(
        tripId: any(named: 'tripId'),
        message: any(named: 'message'),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('ai-consent-cancel')));
    await tester.pumpAndSettle();
    final input = tester.widget<TextField>(
      find.byKey(const ValueKey('chat-input')),
    );
    expect(input.controller!.text, '保留這段話');
  });

  testWidgets('授權狀態載入中不會略過 consent 直接送出', (tester) async {
    final authorization = Completer<bool>();
    when(authRepo.fetchAiAuthorization).thenAnswer((_) => authorization.future);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('chat-input')), '先等授權');
    await tester.tap(find.byKey(const ValueKey('chat-send')));
    await tester.pump();

    verifyNever(
      () => reqRepo.sendRequest(
        tripId: any(named: 'tripId'),
        message: any(named: 'message'),
      ),
    );
    expect(find.byKey(const ValueKey('ai-consent-title')), findsNothing);

    authorization.complete(false);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ai-consent-title')), findsOneWidget);
    expect(find.text('「先等授權」'), findsOneWidget);
  });

  testWidgets('授權狀態載入中快速連點只會開一張 consent sheet', (tester) async {
    final authorization = Completer<bool>();
    when(authRepo.fetchAiAuthorization).thenAnswer((_) => authorization.future);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('chat-input')), '只送一次');
    await tester.tap(find.byKey(const ValueKey('chat-send')));
    await tester.tap(find.byKey(const ValueKey('chat-send')));
    await tester.pump();

    authorization.complete(false);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ai-consent-title')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ai-consent-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ai-consent-title')), findsNothing);
  });

  testWidgets('授權狀態查詢失敗時仍先顯示 consent', (tester) async {
    when(authRepo.fetchAiAuthorization).thenThrow(Exception('offline'));

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('chat-input')), '離線訊息');
    await tester.tap(find.byKey(const ValueKey('chat-send')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ai-consent-title')), findsOneWidget);
    verifyNever(
      () => reqRepo.sendRequest(
        tripId: any(named: 'tripId'),
        message: any(named: 'message'),
      ),
    );
  });

  testWidgets('consent 授權未完成可原地重試後送出', (tester) async {
    var attempts = 0;
    when(authRepo.fetchAiAuthorization).thenAnswer((_) async => false);
    when(authRepo.authorizeAi).thenAnswer((_) async => ++attempts > 1);
    when(
      () => reqRepo.sendRequest(
        tripId: any(named: 'tripId'),
        message: any(named: 'message'),
      ),
    ).thenAnswer(
      (_) async =>
          _req(id: 9, message: '再試一次', status: RequestStatus.processing),
    );
    when(() => reqRepo.fetchRequest(9)).thenAnswer(
      (_) async => _req(
        id: 9,
        message: '再試一次',
        status: RequestStatus.completed,
        reply: '完成',
      ),
    );

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('chat-input')), '再試一次');
    await tester.tap(find.byKey(const ValueKey('chat-send')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ai-consent-authorize')));
    await tester.pumpAndSettle();
    expect(find.text('授權未完成，訊息尚未送出。'), findsOneWidget);
    verifyNever(
      () => reqRepo.sendRequest(
        tripId: any(named: 'tripId'),
        message: any(named: 'message'),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('ai-consent-authorize')));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    verify(
      () => reqRepo.sendRequest(tripId: 'okinawa', message: '再試一次'),
    ).called(1);
  });

  testWidgets('consent 授權成功 → 送出原訊息並清空草稿', (tester) async {
    when(authRepo.fetchAiAuthorization).thenAnswer((_) async => false);
    when(
      () => reqRepo.sendRequest(
        tripId: any(named: 'tripId'),
        message: any(named: 'message'),
      ),
    ).thenAnswer(
      (_) async =>
          _req(id: 8, message: '排晚餐', status: RequestStatus.processing),
    );
    when(() => reqRepo.fetchRequest(8)).thenAnswer(
      (_) async => _req(
        id: 8,
        message: '排晚餐',
        status: RequestStatus.completed,
        reply: '完成',
      ),
    );

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('chat-input')), '排晚餐');
    await tester.tap(find.byKey(const ValueKey('chat-send')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ai-consent-authorize')));
    await tester.pumpAndSettle();

    verify(authRepo.authorizeAi).called(1);
    verify(
      () => reqRepo.sendRequest(tripId: 'okinawa', message: '排晚餐'),
    ).called(1);
    final input = tester.widget<TextField>(
      find.byKey(const ValueKey('chat-input')),
    );
    expect(input.controller!.text, isEmpty);
  });

  testWidgets('未授權時建議 prompt 也先走 consent sheet', (tester) async {
    when(authRepo.fetchAiAuthorization).thenAnswer((_) async => false);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chat-suggestion-0')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ai-consent-title')), findsOneWidget);
    expect(find.text('「幫我規劃 Day 1 的早午餐」'), findsOneWidget);
  });

  testWidgets('completed reply → markdown 渲染', (tester) async {
    when(
      () => reqRepo.fetchRequests(
        tripId: any(named: 'tripId'),
        limit: any(named: 'limit'),
        sort: any(named: 'sort'),
        before: any(named: 'before'),
        beforeId: any(named: 'beforeId'),
      ),
    ).thenAnswer(
      (_) async => (
        items: [
          _req(
            id: 1,
            message: 'q',
            status: RequestStatus.completed,
            reply: '**已完成** [看筆記](/trip/okinawa/notes)',
          ),
        ],
        hasMore: false,
      ),
    );

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    final md = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
    expect(md.data, contains('已完成'));
  });

  testWidgets('思考中態顯示', (tester) async {
    // sendRequest 永不回 → 樂觀 temp(open)維持「思考中…」。
    final pending = Completer<TripRequest>();
    when(
      () => reqRepo.sendRequest(
        tripId: any(named: 'tripId'),
        message: any(named: 'message'),
      ),
    ).thenAnswer((_) => pending.future);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('chat-input')), 'hi');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat-send')));
    await tester.pump(); // 不 settle:spinner 持續動畫

    expect(find.text('思考中…'), findsWidgets);
  });

  testWidgets('my-trips 空 → 「尚無行程」與新增入口', (tester) async {
    when(tripRepo.watchMyTrips).thenAnswer((_) => Stream.value(const []));

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('尚無行程'), findsNWidgets(2));
    expect(find.widgetWithText(FilledButton, '新增行程'), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-trip-dropdown')), findsNothing);
  });

  testWidgets('sheet 切換行程 → 新行程的工單被載入', (tester) async {
    when(tripRepo.watchMyTrips).thenAnswer(
      (_) => Stream.value(const [
        TripSummary(tripId: 'okinawa', name: 'okinawa', title: '沖繩'),
        TripSummary(tripId: 'kyoto', name: 'kyoto', title: '京都'),
      ]),
    );

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('chat-trip-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('trip-picker-item-kyoto')));
    await tester.pumpAndSettle();

    verify(
      () => reqRepo.fetchRequests(
        tripId: 'kyoto',
        limit: any(named: 'limit'),
        sort: any(named: 'sort'),
        before: any(named: 'before'),
        beforeId: any(named: 'beforeId'),
      ),
    ).called(1);
  });

  testWidgets('初始 tripId/prefill 會切到指定行程並填入草稿', (tester) async {
    when(tripRepo.watchMyTrips).thenAnswer(
      (_) => Stream.value(const [
        TripSummary(tripId: 'okinawa', name: 'okinawa', title: '沖繩'),
        TripSummary(tripId: 'kyoto', name: 'kyoto', title: '京都'),
      ]),
    );
    when(
      () => reqRepo.sendRequest(
        tripId: any(named: 'tripId'),
        message: any(named: 'message'),
      ),
    ).thenAnswer(
      (_) async =>
          _req(id: 99, message: '京都晚餐草稿', status: RequestStatus.completed),
    );

    await tester.pumpWidget(
      buildApp(initialTripId: 'kyoto', initialPrefill: '幫我安排晚餐'),
    );
    await tester.pumpAndSettle();

    verify(
      () => reqRepo.fetchRequests(
        tripId: 'kyoto',
        limit: any(named: 'limit'),
        sort: any(named: 'sort'),
        before: any(named: 'before'),
        beforeId: any(named: 'beforeId'),
      ),
    ).called(1);

    final input = tester.widget<TextField>(
      find.byKey(const ValueKey('chat-input')),
    );
    expect(input.controller!.text, '幫我安排晚餐');
    await tester.enterText(find.byKey(const ValueKey('chat-input')), '京都晚餐草稿');

    await tester.tap(find.byKey(const ValueKey('chat-trip-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('trip-picker-item-okinawa')));
    await tester.pumpAndSettle();

    final nextInput = tester.widget<TextField>(
      find.byKey(const ValueKey('chat-input')),
    );
    expect(nextInput.controller!.text, isEmpty);
    await tester.enterText(find.byKey(const ValueKey('chat-input')), '沖繩早餐草稿');

    await tester.tap(find.byKey(const ValueKey('chat-trip-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('trip-picker-item-kyoto')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('chat-input')))
          .controller!
          .text,
      '京都晚餐草稿',
    );

    await tester.tap(find.byKey(const ValueKey('chat-send')));
    await tester.pumpAndSettle();
    verify(
      () => reqRepo.sendRequest(tripId: 'kyoto', message: '京都晚餐草稿'),
    ).called(1);
  });

  testWidgets('query 更新不會重建 ChatScreen 或清除各行程草稿', (tester) async {
    when(tripRepo.watchMyTrips).thenAnswer(
      (_) => Stream.value(const [
        TripSummary(tripId: 'okinawa', name: 'okinawa', title: '沖繩'),
        TripSummary(tripId: 'kyoto', name: 'kyoto', title: '京都'),
      ]),
    );
    final harnessKey = GlobalKey<_ChatQueryHarnessState>();

    await tester.pumpWidget(buildApp(home: _ChatQueryHarness(key: harnessKey)));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('chat-input')),
      '沖繩 query 草稿',
    );

    harnessKey.currentState!.showTrip('kyoto');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('chat-input')))
          .controller!
          .text,
      isEmpty,
    );

    harnessKey.currentState!.showTrip('okinawa');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('chat-input')))
          .controller!
          .text,
      '沖繩 query 草稿',
    );

    harnessKey.currentState!.showTrip('okinawa', prefill: '新的深連結指令');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('chat-input')))
          .controller!
          .text,
      '新的深連結指令',
    );
  });

  testWidgets('初次載入失敗 → 顯示重試 → 重試成功', (tester) async {
    var calls = 0;
    when(
      () => reqRepo.fetchRequests(
        tripId: any(named: 'tripId'),
        limit: any(named: 'limit'),
        sort: any(named: 'sort'),
        before: any(named: 'before'),
        beforeId: any(named: 'beforeId'),
      ),
    ).thenAnswer((_) async {
      calls++;
      if (calls == 1) throw Exception('boom');
      return (
        items: [
          _req(
            id: 1,
            message: 'q',
            status: RequestStatus.completed,
            reply: '好了',
          ),
        ],
        hasMore: false,
      );
    });

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    expect(find.text('載入失敗'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('chat-retry')));
    await tester.pumpAndSettle();

    expect(find.text('載入失敗'), findsNothing);
    expect(find.byType(MarkdownBody), findsWidgets); // reply 顯示
  });

  testWidgets('空對話顯示標題「從一個指令開始」與 4 個建議鈕', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('從一個指令開始'), findsOneWidget);
    // 4 個建議鈕皆可見
    for (var i = 0; i < 4; i++) {
      expect(find.byKey(ValueKey('chat-suggestion-$i')), findsOneWidget);
    }
  });

  testWidgets('點建議鈕呼叫 sendRequest(message 為該 prompt)', (tester) async {
    when(
      () => reqRepo.sendRequest(
        tripId: any(named: 'tripId'),
        message: any(named: 'message'),
      ),
    ).thenAnswer(
      (_) async => _req(id: 99, message: 'x', status: RequestStatus.processing),
    );
    when(() => reqRepo.fetchRequest(99)).thenAnswer(
      (_) async => _req(id: 99, message: 'x', status: RequestStatus.completed),
    );

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // 點第一個建議鈕
    await tester.tap(find.byKey(const ValueKey('chat-suggestion-0')));
    await tester.pumpAndSettle();

    verify(
      () => reqRepo.sendRequest(
        tripId: 'okinawa',
        message: any(named: 'message'),
      ),
    ).called(1);
  });

  group('語音輸入', () {
    testWidgets('進聊天頁不呼叫 init()(lazy,不預先請求權限)', (tester) async {
      final speech = _MockSpeechService();
      when(() => speech.isAvailable).thenReturn(false);
      when(speech.init).thenAnswer((_) async => true);
      when(() => speech.listen(any())).thenAnswer((_) async {});

      await tester.pumpWidget(buildApp(speech: speech));
      await tester.pumpAndSettle();

      // 核心回歸:進頁不得觸發 init()(避免一進頁就跳權限對話框)。
      verifyNever(speech.init);
      // 麥克風鈕預設 enabled(不再依賴進頁預檢)。
      final mic = tester.widget<IconButton>(
        find.byKey(const ValueKey('chat-mic-button')),
      );
      expect(mic.onPressed, isNotNull);
    });

    testWidgets('點麥克風 → 才 init + listen 被呼叫', (tester) async {
      final speech = _MockSpeechService();
      when(() => speech.isAvailable).thenReturn(true);
      when(speech.init).thenAnswer((_) async => true);
      when(() => speech.listen(any())).thenAnswer((_) async {});

      await tester.pumpWidget(buildApp(speech: speech));
      await tester.pumpAndSettle();

      // 點之前未 init。
      verifyNever(speech.init);

      await tester.tap(find.byKey(const ValueKey('chat-mic-button')));
      await tester.pumpAndSettle();

      verify(speech.init).called(1);
      verify(() => speech.listen(any())).called(1);
    });

    testWidgets('onResult 回傳文字 → 輸入框出現該文字', (tester) async {
      final speech = _MockSpeechService();
      when(() => speech.isAvailable).thenReturn(true);
      when(speech.init).thenAnswer((_) async => true);
      // 攔截 onResult callback,稍後手動觸發。
      when(() => speech.listen(any())).thenAnswer((invocation) async {
        final onResult =
            invocation.positionalArguments.first as void Function(String);
        onResult('幫我規劃晚餐');
      });

      await tester.pumpWidget(buildApp(speech: speech));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('chat-mic-button')));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('chat-input')),
      );
      expect(field.controller!.text, '幫我規劃晚餐');
    });

    testWidgets('init() 回 false(權限拒絕)→ SnackBar 提示且不 listen', (tester) async {
      final speech = _MockSpeechService();
      when(() => speech.isAvailable).thenReturn(false);
      when(speech.init).thenAnswer((_) async => false);
      when(() => speech.listen(any())).thenAnswer((_) async {});

      await tester.pumpWidget(buildApp(speech: speech));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('chat-mic-button')));
      await tester.pumpAndSettle();

      verify(speech.init).called(1);
      verifyNever(() => speech.listen(any()));
      expect(find.text('需要麥克風與語音辨識權限才能語音輸入'), findsOneWidget);
    });

    testWidgets('sending 中麥克風 disabled', (tester) async {
      // sendRequest 永不回 → sending=true 維持。
      final pending = Completer<TripRequest>();
      when(
        () => reqRepo.sendRequest(
          tripId: any(named: 'tripId'),
          message: any(named: 'message'),
        ),
      ).thenAnswer((_) => pending.future);

      final speech = _MockSpeechService();
      when(() => speech.isAvailable).thenReturn(true);
      when(speech.init).thenAnswer((_) async => true);
      when(() => speech.listen(any())).thenAnswer((_) async {});

      await tester.pumpWidget(buildApp(speech: speech));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('chat-input')), 'hi');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chat-send')));
      await tester.pump(); // 不 settle:維持 sending 態

      final mic = tester.widget<IconButton>(
        find.byKey(const ValueKey('chat-mic-button')),
      );
      expect(mic.onPressed, isNull);
    });

    testWidgets('hintText 為「輸入訊息或語音指令」', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('輸入訊息或語音指令'), findsOneWidget);
    });
  });
}
