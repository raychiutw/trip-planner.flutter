/// AI 聊天狀態機:state = `List<TripRequest>`(工單,asc);送訊息走樂觀更新 →
/// POST 換真 row → polling 到 terminal;completed 後 invalidate 行程相關 providers
/// （AI 會直接改行程,畫面要重抓才看得到）。per-trip autoDispose family。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_error.dart';
import '../../api/providers.dart';
import '../../api/requests_repository.dart';
import '../../models/trip_request.dart';
import '../favorites/favorites_providers.dart';
import '../trip_detail/trip_providers.dart';
import 'chat_message.dart';

/// 聊天畫面不可變狀態。
class ChatState {
  const ChatState({
    this.requests = const [],
    this.initialLoading = false,
    this.hasMore = false,
    this.loadingOlder = false,
    this.oldest,
    this.sending = false,
    this.error,
    this.authExpired = false,
  });

  /// 工單清單(由舊到新 asc;對應由上到下時序)。
  final List<TripRequest> requests;
  final bool initialLoading;
  final bool hasMore;
  final bool loadingOlder;

  /// 翻頁 cursor:最舊一筆的 (createdAt, id)。
  final ({String? createdAt, int id})? oldest;
  final bool sending;
  final String? error;

  /// poll/載入遇 401 → 畫面顯示重新登入橫幅。
  final bool authExpired;

  /// 投影成氣泡(1 row → 1~2 個);畫面直接 render 這個。
  List<ChatMessage> get messages =>
      [for (final r in requests) ...rowToMessages(r)];

  ChatState copyWith({
    List<TripRequest>? requests,
    bool? initialLoading,
    bool? hasMore,
    bool? loadingOlder,
    Object? oldest = _sentinel,
    bool? sending,
    Object? error = _sentinel,
    bool? authExpired,
  }) {
    return ChatState(
      requests: requests ?? this.requests,
      initialLoading: initialLoading ?? this.initialLoading,
      hasMore: hasMore ?? this.hasMore,
      loadingOlder: loadingOlder ?? this.loadingOlder,
      oldest: oldest == _sentinel
          ? this.oldest
          : oldest as ({String? createdAt, int id})?,
      sending: sending ?? this.sending,
      error: error == _sentinel ? this.error : error as String?,
      authExpired: authExpired ?? this.authExpired,
    );
  }

  static const _sentinel = Object();
}

class ChatController extends Notifier<ChatState> {
  ChatController(this.tripId);

  /// 由 family arg 經 constructor 注入(riverpod 3.x 慣例)。
  final String tripId;

  static const _pollInterval = Duration(seconds: 4);
  static const _pageSize = 10;

  int _tempId = -1;
  bool _disposed = false;
  bool _initStarted = false;
  final Set<int> _polling = <int>{};

  @override
  ChatState build() {
    ref.onDispose(() => _disposed = true);
    unawaited(Future(loadInitial)); // 進頁自動載入
    return const ChatState(initialLoading: true);
  }

  RequestsRepository get _repo => ref.read(requestsRepositoryProvider);

  String? get _myEmail => switch (ref.read(authStateProvider)) {
        AsyncData(:final value) => value?.email,
        _ => null,
      };
  String? get _myName => switch (ref.read(authStateProvider)) {
        AsyncData(:final value) => value?.displayName,
        _ => null,
      };

  /// 首次載入最新一頁(desc 抓 → 反轉成 asc);idempotent。
  Future<void> loadInitial() async {
    if (_initStarted) return;
    _initStarted = true;
    try {
      final page = await _repo.fetchRequests(
          tripId: tripId, sort: 'desc', limit: _pageSize);
      final rows = page.items.reversed.toList(); // asc
      state = state.copyWith(
        requests: rows,
        initialLoading: false,
        hasMore: page.hasMore,
        oldest: rows.isEmpty
            ? null
            : (createdAt: rows.first.createdAt, id: rows.first.id),
        error: null,
      );
      for (final r in rows) {
        if (!r.status.isTerminal) _startPoll(r.id);
      }
    } on ApiError catch (e) {
      state = e.status == 401
          ? state.copyWith(initialLoading: false, authExpired: true)
          : state.copyWith(initialLoading: false, error: '載入失敗,請稍後再試');
    } on Exception {
      state = state.copyWith(initialLoading: false, error: '載入失敗,請稍後再試');
    }
  }

  /// 往更舊翻頁(prepend);用最舊一筆當 cursor。
  Future<void> loadOlder() async {
    final cursor = state.oldest;
    if (!state.hasMore || state.loadingOlder || cursor == null) return;
    state = state.copyWith(loadingOlder: true);
    try {
      final page = await _repo.fetchRequests(
        tripId: tripId,
        sort: 'desc',
        limit: _pageSize,
        before: cursor.createdAt,
        beforeId: cursor.id,
      );
      final older = page.items.reversed.toList(); // asc
      state = state.copyWith(
        requests: [...older, ...state.requests],
        loadingOlder: false,
        hasMore: page.hasMore,
        oldest: older.isEmpty
            ? state.oldest
            : (createdAt: older.first.createdAt, id: older.first.id),
      );
      for (final r in older) {
        if (!r.status.isTerminal) _startPoll(r.id);
      }
    } on Exception {
      state = state.copyWith(loadingOlder: false);
    }
  }

  /// 送訊息:樂觀加 temp row → POST 換真 row → 非終態啟動 poll。
  Future<void> send(String text) async {
    final t = text.trim();
    if (t.isEmpty || state.sending) return;
    final temp = TripRequest(
      id: _tempId--,
      tripId: tripId,
      message: t,
      status: RequestStatus.open,
      submittedBy: _myEmail,
      submittedByDisplayName: _myName,
    );
    state = state.copyWith(
      requests: [...state.requests, temp],
      sending: true,
      error: null,
    );
    try {
      final row = await _repo.sendRequest(tripId: tripId, message: t);
      state = state.copyWith(
        requests: [
          for (final r in state.requests)
            if (r.id != temp.id) r,
          row,
        ],
        sending: false,
      );
      if (row.status.isTerminal) {
        if (row.status == RequestStatus.completed) _invalidate();
      } else {
        _startPoll(row.id);
      }
    } on ApiError catch (e) {
      state = state.copyWith(
        requests: [
          for (final r in state.requests)
            if (r.id != temp.id) r,
        ],
        sending: false,
        error: e.status == 403 ? '沒有權限傳訊息' : '送出失敗,請稍後再試',
      );
    } on Exception {
      state = state.copyWith(
        requests: [
          for (final r in state.requests)
            if (r.id != temp.id) r,
        ],
        sending: false,
        error: '送出失敗,請稍後再試',
      );
    }
  }

  void _startPoll(int id) {
    if (_polling.add(id)) unawaited(_poll(id));
  }

  /// 第一次立即抓(測試友善:不必等 4s);未終態才進 delay 迴圈。
  Future<void> _poll(int id) async {
    try {
      if (await _pollOnce(id)) return;
      while (!_disposed) {
        await Future<void>.delayed(_pollInterval);
        if (_disposed) break;
        if (await _pollOnce(id)) break;
      }
    } finally {
      _polling.remove(id);
    }
  }

  /// 抓一次;回 true = 停止 polling(terminal / 401 / disposed)。
  Future<bool> _pollOnce(int id) async {
    TripRequest row;
    try {
      row = await _repo.fetchRequest(id);
    } on ApiError catch (e) {
      if (e.status == 401) {
        if (!_disposed) state = state.copyWith(authExpired: true);
        return true;
      }
      return false; // 暫時性錯誤,續 poll
    } on Exception {
      return false;
    }
    if (_disposed) return true;
    _replace(row);
    if (row.status.isTerminal) {
      if (row.status == RequestStatus.completed) _invalidate();
      return true;
    }
    return false;
  }

  void _replace(TripRequest row) {
    state = state.copyWith(
      requests: [
        for (final r in state.requests) r.id == row.id ? row : r,
      ],
    );
  }

  /// AI 改完行程 → 讓行程相關 providers 重抓(最關鍵點:畫面才看得到 AI 的修改)。
  void _invalidate() {
    ref.invalidate(tripDetailProvider(tripId));
    ref.invalidate(tripDaysProvider(tripId));
    ref.invalidate(tripNotesProvider(tripId));
    ref.invalidate(tripSegmentsProvider(tripId));
    ref.invalidate(favoritesProvider);
  }
}

final chatControllerProvider =
    NotifierProvider.autoDispose.family<ChatController, ChatState, String>(
  ChatController.new,
);
