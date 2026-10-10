/// Invitation accept flow state machine.
///
/// This is intentionally UI-free: the `/invite` page owns layout, while this
/// controller owns token loading, account matching, and accept submission.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_error.dart';
import '../../api/collab_repository.dart';
import '../../api/providers.dart';
import '../../models/trip_member.dart';
import '../../models/user.dart';

enum InviteAccountStatus { checking, anonymous, matching, mismatch }

class InviteState {
  const InviteState({
    this.loading = true,
    this.token = '',
    this.invitation,
    this.error,
    this.retryable = false,
    this.accepting = false,
    this.acceptError,
    this.acceptedTripId,
    this.acceptedTripTitle,
  });

  final bool loading;
  final String token;
  final InvitationDetails? invitation;
  final String? error;

  /// 載入失敗是否為暫時性（網路／伺服器），可重試；過期、無效等永久失效為 false。
  final bool retryable;
  final bool accepting;
  final String? acceptError;
  final String? acceptedTripId;
  final String? acceptedTripTitle;

  InviteAccountStatus accountStatusFor(
    UserInfo? user, {
    required bool authLoading,
  }) {
    if (loading || authLoading || invitation == null) {
      return InviteAccountStatus.checking;
    }
    if (user == null) return InviteAccountStatus.anonymous;
    return _sameEmail(user.email, invitation!.invitedEmail)
        ? InviteAccountStatus.matching
        : InviteAccountStatus.mismatch;
  }

  bool canAccept(UserInfo? user, {required bool authLoading}) {
    return accountStatusFor(user, authLoading: authLoading) ==
            InviteAccountStatus.matching &&
        !accepting;
  }

  InviteState copyWith({
    bool? loading,
    String? token,
    Object? invitation = _sentinel,
    Object? error = _sentinel,
    bool? retryable,
    bool? accepting,
    Object? acceptError = _sentinel,
    Object? acceptedTripId = _sentinel,
    Object? acceptedTripTitle = _sentinel,
  }) {
    return InviteState(
      loading: loading ?? this.loading,
      token: token ?? this.token,
      invitation: invitation == _sentinel
          ? this.invitation
          : invitation as InvitationDetails?,
      error: error == _sentinel ? this.error : error as String?,
      retryable: retryable ?? this.retryable,
      accepting: accepting ?? this.accepting,
      acceptError: acceptError == _sentinel
          ? this.acceptError
          : acceptError as String?,
      acceptedTripId: acceptedTripId == _sentinel
          ? this.acceptedTripId
          : acceptedTripId as String?,
      acceptedTripTitle: acceptedTripTitle == _sentinel
          ? this.acceptedTripTitle
          : acceptedTripTitle as String?,
    );
  }

  static const _sentinel = Object();
}

class InviteController extends Notifier<InviteState> {
  InviteController(this.rawToken);

  final String rawToken;
  bool _disposed = false;

  String get _token => rawToken.trim();
  CollabRepository get _repo => ref.read(collabRepositoryProvider);

  @override
  InviteState build() {
    ref.onDispose(() => _disposed = true);
    final token = _token;
    if (token.isEmpty) {
      return const InviteState(loading: false, error: '邀請連結不完整，請向邀請者重新索取連結。');
    }
    unawaited(Future<void>(() => _load(token)));
    return InviteState(loading: true, token: token);
  }

  void retry() {
    if (state.loading || _token.isEmpty) return;
    state = state.copyWith(loading: true, error: null, retryable: false);
    unawaited(_load(_token));
  }

  Future<void> _load(String token) async {
    try {
      final invitation = await _repo.fetchInvitation(token);
      if (_disposed) return;
      state = state.copyWith(
        loading: false,
        invitation: invitation,
        error: null,
      );
    } on ApiError catch (e) {
      if (_disposed) return;
      state = state.copyWith(
        loading: false,
        error: _inviteErrorMessage(e),
        retryable: e.status >= 500 || e.status == 429,
      );
    } on Exception {
      if (_disposed) return;
      state = state.copyWith(
        loading: false,
        error: '無法載入邀請，請稍後再試。',
        retryable: true,
      );
    }
  }

  Future<InvitationAcceptResult?> accept() async {
    if (state.accepting || state.loading || state.invitation == null) {
      return null;
    }
    state = state.copyWith(
      accepting: true,
      acceptError: null,
      acceptedTripId: null,
      acceptedTripTitle: null,
    );
    try {
      final result = await _repo.acceptInvitation(state.token);
      if (_disposed) return result;
      state = state.copyWith(
        accepting: false,
        acceptedTripId: result.tripId,
        acceptedTripTitle: result.tripTitle,
      );
      return result;
    } on ApiError catch (e) {
      if (!_disposed) {
        state = state.copyWith(
          accepting: false,
          acceptError: _inviteErrorMessage(e),
        );
      }
      return null;
    } on Exception {
      if (!_disposed) {
        state = state.copyWith(
          accepting: false,
          acceptError: '接受邀請失敗。你的帳號狀態沒有變更，可以再試一次。',
        );
      }
      return null;
    }
  }
}

final inviteControllerProvider = NotifierProvider.autoDispose
    .family<InviteController, InviteState, String>(InviteController.new);

bool _sameEmail(String a, String b) {
  return a.trim().toLowerCase() == b.trim().toLowerCase();
}

String _inviteErrorMessage(ApiError error) {
  return switch (error.code) {
    'AUTH_REQUIRED' => '請先登入後再接受邀請。',
    'INVITATION_TOKEN_MISSING' => '邀請連結不完整，請向邀請者重新索取連結。',
    'INVITATION_INVALID' => '邀請連結無效，請聯絡邀請者重寄。',
    'INVITATION_ACCEPTED' => '此邀請已被接受，請回到行程清單確認。',
    'INVITATION_EXPIRED' => '邀請已過期，請聯絡邀請者重寄。',
    'INVITATION_EMAIL_MISMATCH' => '此邀請不屬於目前登入帳號。請切換帳號或請邀請者重寄。',
    _ => '邀請處理失敗。你的帳號狀態沒有變更，可以再試一次。',
  };
}
