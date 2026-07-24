/// 分享連結狀態機:載入清單(write 權限,403→canManage false)+ 建立/編輯/旋轉
/// (回 ShareLink 供畫面顯示 URL)+ 撤銷/刪除;每動作後 reload。
/// 沿用 collab 的 _disposed/重入守門。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api_error.dart';
import '../../../api/providers.dart';
import '../../../api/share_repository.dart';
import '../../../models/trip_share.dart';

/// 分享連結管理畫面的狀態。
class ShareState {
  const ShareState({
    this.loading = true,
    this.canManage = true,
    this.shares = const [],
    this.error,
    this.creating = false,
    this.updatingId,
    this.revokingId,
    this.rotatingId,
    this.deletingId,
    this.lastCreated,
  });

  final bool loading;
  final bool canManage;
  final List<TripShare> shares;
  final String? error;
  final bool creating;
  final int? updatingId;
  final int? revokingId;
  final int? rotatingId;
  final int? deletingId;

  /// 最近一次取得 raw token 的連結(建立或重產生)→ 畫面顯示 + 複製。
  final ShareLink? lastCreated;

  ShareState copyWith({
    bool? loading,
    bool? canManage,
    List<TripShare>? shares,
    Object? error = _sentinel,
    bool? creating,
    Object? updatingId = _sentinel,
    Object? revokingId = _sentinel,
    Object? rotatingId = _sentinel,
    Object? deletingId = _sentinel,
    Object? lastCreated = _sentinel,
  }) {
    return ShareState(
      loading: loading ?? this.loading,
      canManage: canManage ?? this.canManage,
      shares: shares ?? this.shares,
      error: error == _sentinel ? this.error : error as String?,
      creating: creating ?? this.creating,
      updatingId: updatingId == _sentinel
          ? this.updatingId
          : updatingId as int?,
      revokingId: revokingId == _sentinel
          ? this.revokingId
          : revokingId as int?,
      rotatingId: rotatingId == _sentinel
          ? this.rotatingId
          : rotatingId as int?,
      deletingId: deletingId == _sentinel
          ? this.deletingId
          : deletingId as int?,
      lastCreated: lastCreated == _sentinel
          ? this.lastCreated
          : lastCreated as ShareLink?,
    );
  }

  static const _sentinel = Object();
}

/// 管理單一行程的公開分享連結清單與連結異動。
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

  /// 保留目前表單與清單並重新載入頁面資料。
  Future<void> retry() => _load();

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
  Future<bool> create(
    String label, {
    List<String>? visibleSections,
    int? expiresAt,
    bool? anonymous,
  }) async {
    if (state.creating ||
        state.updatingId != null ||
        state.revokingId != null ||
        state.rotatingId != null ||
        state.deletingId != null) {
      return false;
    }
    state = state.copyWith(creating: true, error: null, lastCreated: null);
    try {
      final link = await _repo.createShare(
        tripId,
        label: label.trim(),
        visibleSections: visibleSections,
        expiresAt: expiresAt,
        anonymous: anonymous,
      );
      await _reload();
      if (_disposed) return true;
      state = state.copyWith(creating: false, lastCreated: link);
      return true;
    } on ApiError catch (e) {
      if (_disposed) return false;
      state = state.copyWith(
        creating: false,
        error: e.status == 403 ? '沒有權限建立分享' : '建立失敗,請稍後再試',
      );
      return false;
    } on Exception {
      if (_disposed) return false;
      state = state.copyWith(creating: false, error: '建立失敗,請稍後再試');
      return false;
    }
  }

  /// 撤銷分享連結;成功後保留 row 統計並重新載入清單。
  Future<bool> revoke(int shareId) async {
    if (state.updatingId != null ||
        state.revokingId != null ||
        state.rotatingId != null ||
        state.deletingId != null) {
      return false;
    }
    state = state.copyWith(revokingId: shareId, error: null);
    try {
      await _repo.revokeShare(tripId, shareId);
      await _reload();
      if (_disposed) return true;
      state = state.copyWith(revokingId: null);
      return true;
    } on Exception {
      if (_disposed) return false;
      state = state.copyWith(revokingId: null, error: '撤銷失敗,請稍後再試');
      return false;
    }
  }

  /// 重新產生分享連結 token;成功後 lastCreated 帶新 URL(只顯示一次)。
  Future<void> rotate(int shareId) async {
    if (state.updatingId != null ||
        state.rotatingId != null ||
        state.revokingId != null ||
        state.deletingId != null) {
      return;
    }
    state = state.copyWith(rotatingId: shareId, error: null, lastCreated: null);
    try {
      final rotated = await _repo.rotateShare(tripId, shareId);
      await _reload();
      if (_disposed) return;
      state = state.copyWith(
        rotatingId: null,
        lastCreated: ShareLink(
          id: shareId,
          token: rotated.token,
          url: rotated.url,
        ),
      );
    } on Exception {
      if (_disposed) return;
      state = state.copyWith(rotatingId: null, error: '重新產生失敗,請稍後再試');
    }
  }

  /// 永久刪除分享連結;成功後重新載入清單。
  Future<bool> delete(int shareId) async {
    if (state.updatingId != null ||
        state.deletingId != null ||
        state.revokingId != null ||
        state.rotatingId != null) {
      return false;
    }
    state = state.copyWith(deletingId: shareId, error: null);
    try {
      await _repo.deleteShare(tripId, shareId);
      await _reload();
      if (_disposed) return true;
      state = state.copyWith(deletingId: null);
      return true;
    } on Exception {
      if (_disposed) return false;
      state = state.copyWith(deletingId: null, error: '刪除失敗,請稍後再試');
      return false;
    }
  }

  /// 更新分享連結設定;成功後重新載入清單。
  Future<bool> update(
    int shareId, {
    String? label,
    List<String>? visibleSections,
    int? expiresAt,
    bool clearExpiresAt = false,
    bool? anonymous,
  }) async {
    if (state.updatingId != null ||
        state.deletingId != null ||
        state.revokingId != null ||
        state.rotatingId != null) {
      return false;
    }
    state = state.copyWith(updatingId: shareId, error: null);
    try {
      await _repo.updateShare(
        tripId,
        shareId,
        label: label?.trim(),
        visibleSections: visibleSections,
        expiresAt: expiresAt,
        clearExpiresAt: clearExpiresAt,
        anonymous: anonymous,
      );
      await _reload();
      if (_disposed) return true;
      state = state.copyWith(updatingId: null);
      return true;
    } on Exception {
      if (_disposed) return false;
      state = state.copyWith(updatingId: null, error: '儲存失敗,請稍後再試');
      return false;
    }
  }
}

final shareControllerProvider = NotifierProvider.autoDispose
    .family<ShareController, ShareState, String>(ShareController.new);
