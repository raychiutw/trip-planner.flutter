/// 帳號下的一組 passkey（GET /account/passkeys 與註冊 verify 的回應），不含公鑰與簽名計數。
library;

class Passkey {
  const Passkey({
    required this.id,
    required this.name,
    required this.transports,
    required this.backupEligible,
    this.createdAt,
    this.lastUsedAt,
  });

  factory Passkey.fromJson(Map<String, dynamic> json) => Passkey(
    id: json['id'] as String,
    name: json['name'] as String,
    transports: (json['transports'] as List<dynamic>? ?? [])
        .map((t) => t as String)
        .toList(),
    backupEligible:
        json['backupEligible'] == 1 || json['backupEligible'] == true,
    createdAt: json['createdAt'] as String?,
    lastUsedAt: json['lastUsedAt'] as String?,
  );

  /// 憑證 ID（base64url）；改名、撤銷用它。
  final String id;
  final String name;
  final List<String> transports;

  /// 是否為可同步的 passkey。
  final bool backupEligible;

  /// `"YYYY-MM-DD HH:MM:SS"`（UTC）；註冊 verify 理論上一定有，但後端型別允許 null。
  final String? createdAt;

  /// 最後一次用它登入的時間；沒用過為 null。
  final String? lastUsedAt;
}
