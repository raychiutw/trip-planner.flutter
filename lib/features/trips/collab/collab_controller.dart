/// 共編狀態機:載入成員 + 待接受邀請(owner/admin 限定,403 → canManage false);
/// 邀請/改角色/移除/撤銷;每動作後 reload。無 OCC。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api_error.dart';
import '../../../api/collab_repository.dart';
import '../../../api/providers.dart';
import '../../../models/trip_member.dart';

class CollabState {
  const CollabState({
    this.loading = true,
    this.canManage = true,
    this.members = const [],
    this.invites = const [],
    this.error,
    this.adding = false,
    this.changingId,
    this.removingId,
    this.revokingEmail,
    this.actionError,
  });

  final bool loading;

  /// 非 owner/admin → 列表 403 → 不可管理。
  final bool canManage;
  final List<TripMember> members;
  final List<TripInvite> invites;
  final String? error;

  final bool adding;
  final int? changingId;
  final int? removingId;
  final String? revokingEmail;
  final String? actionError;

  CollabState copyWith({
    bool? loading,
    bool? canManage,
    List<TripMember>? members,
    List<TripInvite>? invites,
    Object? error = _sentinel,
    bool? adding,
    Object? changingId = _sentinel,
    Object? removingId = _sentinel,
    Object? revokingEmail = _sentinel,
    Object? actionError = _sentinel,
  }) {
    return CollabState(
      loading: loading ?? this.loading,
      canManage: canManage ?? this.canManage,
      members: members ?? this.members,
      invites: invites ?? this.invites,
      error: error == _sentinel ? this.error : error as String?,
      adding: adding ?? this.adding,
      changingId: changingId == _sentinel
          ? this.changingId
          : changingId as int?,
      removingId: removingId == _sentinel
          ? this.removingId
          : removingId as int?,
      revokingEmail: revokingEmail == _sentinel
          ? this.revokingEmail
          : revokingEmail as String?,
      actionError: actionError == _sentinel
          ? this.actionError
          : actionError as String?,
    );
  }

  static const _sentinel = Object();
}

class CollabController extends Notifier<CollabState> {
  CollabController(this.tripId);

  final String tripId;
  bool _disposed = false;

  @override
  CollabState build() {
    ref.onDispose(() => _disposed = true);
    unawaited(_load());
    return const CollabState(loading: true);
  }

  CollabRepository get _repo => ref.read(collabRepositoryProvider);

  Future<void> _load() async {
    try {
      final members = await _repo.fetchMembers(tripId);
      if (_disposed) return;
      final invites = await _safeInvites();
      if (_disposed) return;
      state = state.copyWith(
        loading: false,
        canManage: true,
        members: members,
        invites: invites,
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

  /// 保留目前內容並重新載入頁面資料。
  Future<void> retry() => _load();

  /// 邀請列表失敗不阻擋成員顯示(best-effort)。
  Future<List<TripInvite>> _safeInvites() async {
    try {
      return await _repo.fetchInvites(tripId);
    } on Exception {
      return const [];
    }
  }

  Future<void> _reload() async {
    try {
      final members = await _repo.fetchMembers(tripId);
      final invites = await _safeInvites();
      if (_disposed) return;
      state = state.copyWith(members: members, invites: invites);
    } on Exception {
      // 保留現況
    }
  }

  Future<bool> invite(String email, String role) async {
    final e = email.trim();
    if (e.isEmpty || state.adding) return false;
    state = state.copyWith(adding: true, actionError: null);
    try {
      await _repo.invite(tripId: tripId, email: e, role: role);
      await _reload();
      if (_disposed) return true;
      state = state.copyWith(adding: false);
      return true;
    } on ApiError catch (err) {
      if (_disposed) return false;
      state = state.copyWith(
        adding: false,
        actionError: switch (err.status) {
          409 => '此 email 已有權限或待接受邀請',
          403 => '沒有權限管理共編',
          _ => '新增失敗,請稍後再試',
        },
      );
      return false;
    } on Exception {
      if (_disposed) return false;
      state = state.copyWith(adding: false, actionError: '新增失敗,請稍後再試');
      return false;
    }
  }

  Future<void> changeRole(int permissionId, String role) async {
    if (state.changingId != null) return;
    state = state.copyWith(changingId: permissionId, actionError: null);
    try {
      await _repo.changeRole(permissionId, role);
      await _reload();
      if (_disposed) return;
      state = state.copyWith(changingId: null);
    } on Exception {
      if (_disposed) return;
      state = state.copyWith(changingId: null, actionError: '變更失敗,請稍後再試');
    }
  }

  Future<bool> removeMember(int permissionId) async {
    if (state.removingId != null) return false;
    state = state.copyWith(removingId: permissionId, actionError: null);
    try {
      await _repo.removeMember(permissionId);
      await _reload();
      if (_disposed) return true;
      state = state.copyWith(removingId: null);
      return true;
    } on Exception {
      if (_disposed) return false;
      state = state.copyWith(removingId: null, actionError: '移除失敗,請稍後再試');
      return false;
    }
  }

  Future<bool> revokeInvite(String email) async {
    if (state.revokingEmail != null) return false;
    state = state.copyWith(revokingEmail: email, actionError: null);
    try {
      await _repo.revokeInvite(tripId: tripId, email: email);
      await _reload();
      if (_disposed) return true;
      state = state.copyWith(revokingEmail: null);
      return true;
    } on Exception {
      if (_disposed) return false;
      state = state.copyWith(revokingEmail: null, actionError: '撤銷失敗,請稍後再試');
      return false;
    }
  }
}

final collabControllerProvider = NotifierProvider.autoDispose
    .family<CollabController, CollabState, String>(CollabController.new);
