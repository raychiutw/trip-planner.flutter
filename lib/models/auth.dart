/// Auth flow response models（signup、password reset、email verification）。
library;

/// Signup 成功時可同步接受共編邀請並回傳加入的行程。
class SignupJoinedTrip {
  const SignupJoinedTrip({required this.id, required this.title});

  /// 已加入的 trip id。
  final String id;

  /// 已加入的 trip title。
  final String title;

  factory SignupJoinedTrip.fromJson(Map<String, dynamic> json) {
    return SignupJoinedTrip(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
    );
  }
}

/// `POST /oauth/signup` 成功回應。
class SignupResult {
  const SignupResult({
    required this.ok,
    required this.userId,
    required this.email,
    this.requiresVerification = false,
    this.joinedTrip,
    this.invitationError,
  });

  /// 後端成功旗標。
  final bool ok;

  /// 新建立的 user id。
  final String userId;

  /// 新帳號 email。
  final String email;

  /// 是否需要 email 驗證。
  final bool requiresVerification;

  /// 若 signup body 帶 invitationToken 且接受成功，這裡會帶行程資訊。
  final SignupJoinedTrip? joinedTrip;

  /// Signup 成功但 invitation 接受失敗時的錯誤碼。
  final String? invitationError;

  factory SignupResult.fromJson(Map<String, dynamic> json) {
    final joinedTripJson = json['joinedTrip'];
    return SignupResult(
      ok: json['ok'] == true || json['ok'] == 1,
      userId: json['userId'] as String,
      email: json['email'] as String,
      requiresVerification:
          json['requiresVerification'] == true ||
          json['requiresVerification'] == 1,
      joinedTrip: joinedTripJson is Map
          ? SignupJoinedTrip.fromJson(Map<String, dynamic>.from(joinedTripJson))
          : null,
      invitationError: json['invitationError'] as String?,
    );
  }
}

/// Auth helper endpoints 的 `{ok, message}` 通用回應。
class AuthMessageResult {
  const AuthMessageResult({required this.ok, required this.message});

  /// 後端成功旗標。
  final bool ok;

  /// 顯示給使用者的人話訊息。
  final String message;

  factory AuthMessageResult.fromJson(Map<String, dynamic> json) {
    return AuthMessageResult(
      ok: json['ok'] == true || json['ok'] == 1,
      message: json['message'] as String? ?? '',
    );
  }
}
