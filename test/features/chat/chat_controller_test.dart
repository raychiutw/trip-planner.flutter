import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/requests_repository.dart';
import 'package:tripline/features/chat/chat_controller.dart';
import 'package:tripline/features/trip_detail/trip_providers.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/trip_request.dart';
import 'package:tripline/models/user.dart';

class _MockRepo extends Mock implements RequestsRepository {}

/// 不打網路的假認證:build 回固定 user。
class _StubAuth extends AuthNotifier {
  _StubAuth(this._user);
  final UserInfo? _user;
  @override
  Future<UserInfo?> build() async => _user;
}

TripRequest _req({
  required int id,
  String message = 'hi',
  String? reply,
  required RequestStatus status,
  String? createdAt,
}) => TripRequest(
  id: id,
  tripId: 't',
  message: message,
  reply: reply,
  status: status,
  createdAt: createdAt ?? '2026-06-0$id',
);

/// 排空 microtask/event queue,讓 unawaited 的 poll 走完（mock 立即回 → 不等 4s）。
Future<void> _flush() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(<TripDay>[]);
  });

  ProviderContainer makeContainer(_MockRepo repo, {void Function()? onDays}) {
    final c = ProviderContainer(
      overrides: [
        requestsRepositoryProvider.overrideWithValue(repo),
        authStateProvider.overrideWith(
          () => _StubAuth(
            const UserInfo(id: '1', email: 'me@x.com', displayName: 'Me'),
          ),
        ),
        if (onDays != null)
          tripDaysProvider.overrideWith((ref, tripId) {
            onDays();
            return Stream.value(<TripDay>[]);
          }),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  ChatController ctrlOf(ProviderContainer c) {
    c.listen(
      chatControllerProvider('t'),
      (_, _) {},
    ); // keep alive (autoDispose)
    return c.read(chatControllerProvider('t').notifier);
  }

  test(
    'loadInitial：desc 2 筆 → requests 反轉成 asc;initialLoading false',
    () async {
      final repo = _MockRepo();
      when(
        () => repo.fetchRequests(
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
              id: 2,
              message: 'b',
              status: RequestStatus.completed,
              reply: 'B',
            ),
            _req(
              id: 1,
              message: 'a',
              status: RequestStatus.completed,
              reply: 'A',
            ),
          ],
          hasMore: false,
        ),
      );

      final c = makeContainer(repo);
      await ctrlOf(c).loadInitial();

      final s = c.read(chatControllerProvider('t'));
      expect(s.initialLoading, isFalse);
      expect(s.requests.map((r) => r.id).toList(), [1, 2]); // asc
    },
  );

  test(
    'send：樂觀 temp → processing → poll completed → reply 可見 + tripDays invalidate',
    () async {
      final repo = _MockRepo();
      when(
        () => repo.fetchRequests(
          tripId: any(named: 'tripId'),
          limit: any(named: 'limit'),
          sort: any(named: 'sort'),
          before: any(named: 'before'),
          beforeId: any(named: 'beforeId'),
        ),
      ).thenAnswer((_) async => (items: <TripRequest>[], hasMore: false));
      when(
        () => repo.sendRequest(
          tripId: any(named: 'tripId'),
          message: any(named: 'message'),
        ),
      ).thenAnswer(
        (_) async =>
            _req(id: 7, message: '改午餐', status: RequestStatus.processing),
      );
      when(() => repo.fetchRequest(7)).thenAnswer(
        (_) async => _req(
          id: 7,
          message: '改午餐',
          status: RequestStatus.completed,
          reply: '改好了',
        ),
      );

      var daysFetches = 0;
      final c = makeContainer(repo, onDays: () => daysFetches++);
      c.listen(tripDaysProvider('t'), (_, _) {}, fireImmediately: true);
      await c.read(tripDaysProvider('t').future); // daysFetches = 1

      final ctrl = ctrlOf(c);
      await ctrl.loadInitial();

      await ctrl.send('改午餐');
      // 樂觀 temp 立即出現
      expect(c.read(chatControllerProvider('t')).requests, hasLength(1));

      await _flush();
      await c.read(tripDaysProvider('t').future); // 確保 invalidate 後重抓被計數

      final s = c.read(chatControllerProvider('t'));
      final row = s.requests.firstWhere((r) => r.id == 7);
      expect(row.status, RequestStatus.completed);
      expect(row.reply, '改好了');
      expect(s.sending, isFalse);
      expect(daysFetches, greaterThanOrEqualTo(2));
    },
  );

  test('poll 401 → authExpired', () async {
    final repo = _MockRepo();
    when(
      () => repo.fetchRequests(
        tripId: any(named: 'tripId'),
        limit: any(named: 'limit'),
        sort: any(named: 'sort'),
        before: any(named: 'before'),
        beforeId: any(named: 'beforeId'),
      ),
    ).thenAnswer((_) async => (items: <TripRequest>[], hasMore: false));
    when(
      () => repo.sendRequest(
        tripId: any(named: 'tripId'),
        message: any(named: 'message'),
      ),
    ).thenAnswer((_) async => _req(id: 8, status: RequestStatus.processing));
    when(() => repo.fetchRequest(8)).thenThrow(
      const ApiError(status: 401, code: 'AUTH_REQUIRED', message: 'login'),
    );

    final c = makeContainer(repo);
    final ctrl = ctrlOf(c);
    await ctrl.loadInitial();
    await ctrl.send('hi');
    await _flush();

    expect(c.read(chatControllerProvider('t')).authExpired, isTrue);
  });

  test('loadOlder：before/beforeId → prepend 更舊', () async {
    final repo = _MockRepo();
    // 初次（before/beforeId 皆 null）→ [3,2] desc，hasMore true
    when(
      () => repo.fetchRequests(
        tripId: any(named: 'tripId'),
        limit: any(named: 'limit'),
        sort: any(named: 'sort'),
        before: null,
        beforeId: null,
      ),
    ).thenAnswer(
      (_) async => (
        items: [
          _req(id: 3, status: RequestStatus.completed),
          _req(id: 2, status: RequestStatus.completed),
        ],
        hasMore: true,
      ),
    );
    // 翻頁（beforeId: 2）→ [1]，hasMore false
    when(
      () => repo.fetchRequests(
        tripId: any(named: 'tripId'),
        limit: any(named: 'limit'),
        sort: any(named: 'sort'),
        before: any(named: 'before'),
        beforeId: 2,
      ),
    ).thenAnswer(
      (_) async => (
        items: [_req(id: 1, status: RequestStatus.completed)],
        hasMore: false,
      ),
    );

    final c = makeContainer(repo);
    final ctrl = ctrlOf(c);
    await ctrl.loadInitial(); // asc [2,3]
    await ctrl.loadOlder(); // prepend [1] → [1,2,3]

    final s = c.read(chatControllerProvider('t'));
    expect(s.requests.map((r) => r.id).toList(), [1, 2, 3]);
    expect(s.hasMore, isFalse);
  });

  test('send：空字串 no-op（不呼叫 sendRequest）', () async {
    final repo = _MockRepo();
    when(
      () => repo.fetchRequests(
        tripId: any(named: 'tripId'),
        limit: any(named: 'limit'),
        sort: any(named: 'sort'),
        before: any(named: 'before'),
        beforeId: any(named: 'beforeId'),
      ),
    ).thenAnswer((_) async => (items: <TripRequest>[], hasMore: false));

    final c = makeContainer(repo);
    final ctrl = ctrlOf(c);
    await ctrl.loadInitial();
    await ctrl.send('   ');

    verifyNever(
      () => repo.sendRequest(
        tripId: any(named: 'tripId'),
        message: any(named: 'message'),
      ),
    );
    expect(c.read(chatControllerProvider('t')).requests, isEmpty);
  });

  test('send：403 → error 提示 + 移除 temp', () async {
    final repo = _MockRepo();
    when(
      () => repo.fetchRequests(
        tripId: any(named: 'tripId'),
        limit: any(named: 'limit'),
        sort: any(named: 'sort'),
        before: any(named: 'before'),
        beforeId: any(named: 'beforeId'),
      ),
    ).thenAnswer((_) async => (items: <TripRequest>[], hasMore: false));
    when(
      () => repo.sendRequest(
        tripId: any(named: 'tripId'),
        message: any(named: 'message'),
      ),
    ).thenThrow(const ApiError(status: 403, code: 'FORBIDDEN', message: 'no'));

    final c = makeContainer(repo);
    final ctrl = ctrlOf(c);
    await ctrl.loadInitial();
    await ctrl.send('hi');

    final s = c.read(chatControllerProvider('t'));
    expect(s.requests, isEmpty); // temp 已移除
    expect(s.error, isNotNull);
    expect(s.sending, isFalse);
  });

  test('messages：completed row 投影成 user + assistant 兩氣泡', () async {
    final repo = _MockRepo();
    when(
      () => repo.fetchRequests(
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
            reply: 'a',
          ),
        ],
        hasMore: false,
      ),
    );

    final c = makeContainer(repo);
    await ctrlOf(c).loadInitial();

    final msgs = c.read(chatControllerProvider('t')).messages;
    expect(msgs, hasLength(2));
  });

  test('送出中行程被 dispose → 不因 state-after-dispose 丟例外', () async {
    final repo = _MockRepo();
    when(
      () => repo.fetchRequests(
        tripId: any(named: 'tripId'),
        limit: any(named: 'limit'),
        sort: any(named: 'sort'),
        before: any(named: 'before'),
        beforeId: any(named: 'beforeId'),
      ),
    ).thenAnswer((_) async => (items: <TripRequest>[], hasMore: false));
    final post = Completer<TripRequest>();
    when(
      () => repo.sendRequest(
        tripId: any(named: 'tripId'),
        message: any(named: 'message'),
      ),
    ).thenAnswer((_) => post.future);

    final c = makeContainer(repo);
    final sub = c.listen(chatControllerProvider('t'), (_, _) {});
    final ctrl = c.read(chatControllerProvider('t').notifier);
    await ctrl.loadInitial();

    final sending = ctrl.send('hi'); // 卡在 post.future
    c.invalidate(chatControllerProvider('t')); // 舊 controller dispose
    post.complete(
      _req(id: 1, status: RequestStatus.completed),
    ); // continuation 寫已死 state

    await expectLater(sending, completes); // 有 _disposed 守門 → 不丟
    sub.close();
  });

  test('reload：失敗後可重試成功', () async {
    final repo = _MockRepo();
    var calls = 0;
    when(
      () => repo.fetchRequests(
        tripId: any(named: 'tripId'),
        limit: any(named: 'limit'),
        sort: any(named: 'sort'),
        before: any(named: 'before'),
        beforeId: any(named: 'beforeId'),
      ),
    ).thenAnswer((_) async {
      calls++;
      if (calls == 1) throw Exception('boom'); // 首次失敗
      return (
        items: [_req(id: 1, status: RequestStatus.completed, reply: 'a')],
        hasMore: false,
      );
    });

    final c = makeContainer(repo);
    final ctrl = ctrlOf(c);
    await ctrl.loadInitial();
    expect(c.read(chatControllerProvider('t')).error, isNotNull);

    await ctrl.reload();
    final s = c.read(chatControllerProvider('t'));
    expect(s.error, isNull);
    expect(s.requests, hasLength(1));
  });
}
