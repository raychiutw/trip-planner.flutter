/// 分享連結狀態機:載入清單(write 權限,403→canManage false)+ 建立(回 ShareLink
/// 供畫面顯示 URL)+ 撤銷;每動作後 reload。沿用 collab 的 _disposed/重入守門。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api_error.dart';
import '../../../api/providers.dart';
import '../../../api/share_repository.dart';
import '../../../models/trip_share.dart';

class ShareState {
  const ShareState({
    this.loading = true,
    this.canManage = true,
    this.shares = const [],
    this.error,
    this.creating = false,
    this.revokingId,
    this.lastCreated,
  });

  final bool loading;
  final bool canManage;
  final List<TripShare> shares;
  final String? error;
  final bool creating;
  final int? revokingId;

  /// 最近一次建立的連結(raw token 只回一次)→ 畫面顯示 + 複製。
  final ShareLink? lastCreated;

  ShareState copyWith({
    bool? loading,
    bool? canManage,
    List<TripShare>? shares,
    Object? error = _sentinel,
    bool? creating,
    Object? revokingId = _sentinel,
    Object? lastCreated = _sentinel,
  }) {
    return ShareState(
      loading: loading ?? this.loading,
      canManage: canManage ?? this.canManage,
      shares: shares ?? this.shares,
      error: error == _sentinel ? this.error : error as String?,
      creating: creating ?? this.creating,
      revokingId: revokingId == _sentinel
          ? this.revokingId
          : revokingId as int?,
      lastCreated: lastCreated == _sentinel
          ? this.lastCreated
          : lastCreated as ShareLink?,
    );
  }

  static const _sentinel = Object();
}

class ShareController extends Notifier<ShareState> {
  ShareController(this.tripId);

  final String tripId;
  bool _disposed = false;

  @override
  ShareState build() {
    ref.onDispose(() => _disposed = true);
    unawaited(_load());
    return const ShareState(loading: true);
  }

  ShareRepository get _repo => ref.read(shareRepositoryProvider);

  Future<void> _load() async {
    try {
      final shares = await _repo.fetchShares(tripId);
      if (_disposed) return;
      state = state.copyWith(
        loading: false,
        canManage: true,
        shares: shares,
        error: null,
      );
    } on ApiError catch (e) {
      if (_disposed) return;
      state = e.status == 403
          ? state.copyWith(loading: false, canManage: false)
          : state.copyWith(loading: false, error: '載入失敗,請稍後再試');
    } on Exception {
      if (_disposed) return;
      state = state.copyWith(loading: false, error: '載入失敗,請稍後再試');
    }
  }

  Future<void> _reload() async {
    try {
      final shares = await _repo.fetchShares(tripId);
      if (_disposed) return;
      state = state.copyWith(shares: shares);
    } on Exception {
      // 保留現況
    }
  }

  /// 建立分享連結;成功後 lastCreated 帶 ShareLink(供顯示/複製)。
  Future<void> create(String label) async {
    if (state.creating) return;
    state = state.copyWith(creating: true, error: null, lastCreated: null);
    try {
      final link = await _repo.createShare(tripId, label: label.trim());
      await _reload();
      if (_disposed) return;
      state = state.copyWith(creating: false, lastCreated: link);
    } on ApiError catch (e) {
      if (_disposed) return;
      state = state.copyWith(
        creating: false,
        error: e.status == 403 ? '沒有權限建立分享' : '建立失敗,請稍後再試',
      );
    } on Exception {
      if (_disposed) return;
      state = state.copyWith(creating: false, error: '建立失敗,請稍後再試');
    }
  }

  Future<void> revoke(int shareId) async {
    if (state.revokingId != null) return;
    state = state.copyWith(revokingId: shareId, error: null);
    try {
      await _repo.revokeShare(tripId, shareId);
      await _reload();
      if (_disposed) return;
      state = state.copyWith(revokingId: null);
    } on Exception {
      if (_disposed) return;
      state = state.copyWith(revokingId: null, error: '撤銷失敗,請稍後再試');
    }
  }
}

final shareControllerProvider = NotifierProvider.autoDispose
    .family<ShareController, ShareState, String>(ShareController.new);
