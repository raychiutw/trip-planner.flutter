import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/requests_repository.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/chat/chat_screen.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/models/trip_request.dart';
import 'package:tripline/models/user.dart';
import 'package:tripline/theme/app_theme.dart';

class _MockRequestsRepo extends Mock implements RequestsRepository {}

class _MockTripRepo extends Mock implements TripRepository {}

class _StubAuth extends AuthNotifier {
  @override
  Future<UserInfo?> build() async =>
      const UserInfo(id: '1', email: 'me@x.com', displayName: 'Me');
}

const _trips = [TripSummary(tripId: 'okinawa', name: 'okinawa', title: '沖繩')];

TripRequest _req({
  required int id,
  String message = 'hi',
  String? reply,
  required RequestStatus status,
}) => TripRequest(
  id: id,
  tripId: 'okinawa',
  message: message,
  reply: reply,
  status: status,
);

void main() {
  late _MockRequestsRepo reqRepo;
  late _MockTripRepo tripRepo;

  setUp(() {
    reqRepo = _MockRequestsRepo();
    tripRepo = _MockTripRepo();
    when(tripRepo.watchMyTrips).thenAnswer((_) => Stream.value(_trips));
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

  Widget buildApp() {
    return ProviderScope(
      overrides: [
        requestsRepositoryProvider.overrideWithValue(reqRepo),
        tripRepositoryProvider.overrideWithValue(tripRepo),
        authStateProvider.overrideWith(_StubAuth.new),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: const ChatScreen()),
    );
  }

  testWidgets('行程下拉渲染(預設最近,顯示 trip 標題)', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('chat-trip-dropdown')), findsOneWidget);
    expect(find.text('沖繩'), findsWidgets);
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

    await tester.enterText(find.byKey(const ValueKey('chat-input')), '改午餐');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat-send')));
    await tester.pumpAndSettle();

    verify(
      () => reqRepo.sendRequest(tripId: 'okinawa', message: '改午餐'),
    ).called(1);
    expect(find.text('改午餐'), findsWidgets); // user 氣泡樂觀顯示
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

  testWidgets('my-trips 空 → 「先建立行程」提示', (tester) async {
    when(tripRepo.watchMyTrips).thenAnswer((_) => Stream.value(const []));

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('先建立行程'), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-trip-dropdown')), findsNothing);
  });

  testWidgets('下拉切換行程 → 新行程的工單被載入', (tester) async {
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
    await tester.tap(find.text('京都').last); // 選單項
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
      (_) async =>
          _req(id: 99, message: 'x', status: RequestStatus.processing),
    );
    when(() => reqRepo.fetchRequest(99)).thenAnswer(
      (_) async =>
          _req(id: 99, message: 'x', status: RequestStatus.completed),
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
}
