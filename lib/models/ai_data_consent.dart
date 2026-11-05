/// AI 資料同意（版本化，由 server 持有版本與說明文字）。
///
/// 與「AI 操作授權」（owner 讓 AI 以自己的身分改行程的布林）是兩個獨立概念，
/// 互不取代。契約出處：web spec #1553、api#48／#51。
library;

enum AiDataConsentStatus { none, valid, stale, withdrawn }

/// 未知字串回 null：不是同意狀態的回應一律當「讀不到」，不誤判成已同意或被擋。
AiDataConsentStatus? parseAiDataConsentStatus(Object? value) => switch (value) {
  'none' => AiDataConsentStatus.none,
  'valid' => AiDataConsentStatus.valid,
  'stale' => AiDataConsentStatus.stale,
  'withdrawn' => AiDataConsentStatus.withdrawn,
  _ => null,
};

class AiDataConsentSection {
  const AiDataConsentSection({required this.heading, required this.items});

  final String heading;
  final List<String> items;

  factory AiDataConsentSection.fromJson(Map<String, dynamic> json) =>
      AiDataConsentSection(
        heading: json['heading']?.toString() ?? '',
        items: _strings(json['items']),
      );
}

/// server 提供的說明文字（每個版本不可變）。App 只顯示，不寫死。
class AiDataConsentText {
  const AiDataConsentText({
    required this.version,
    required this.title,
    required this.intro,
    required this.sections,
    required this.withdrawal,
  });

  final String version;
  final String title;
  final String intro;
  final List<AiDataConsentSection> sections;

  /// 撤回方式與效力範圍（已開始的工作不保證能停、已送出的資料收不回來）。
  final List<String> withdrawal;

  factory AiDataConsentText.fromJson(Map<String, dynamic> json) =>
      AiDataConsentText(
        version: json['version']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        intro: json['intro']?.toString() ?? '',
        sections: [
          for (final s in json['sections'] as List<dynamic>? ?? const [])
            if (s is Map) AiDataConsentSection.fromJson(_map(s)),
        ],
        withdrawal: _strings(json['withdrawal']),
      );
}

class AiDataConsent {
  const AiDataConsent({
    required this.status,
    required this.currentVersion,
    required this.text,
    required this.enforced,
    this.acceptedVersion,
    this.acceptedAt,
  });

  final AiDataConsentStatus status;
  final String currentVersion;

  /// valid／stale 才有值；ISO 字串（UTC），顯示層再轉本地時間。
  final String? acceptedVersion;
  final String? acceptedAt;
  final AiDataConsentText text;

  /// server 旗標開且文案已填妥。關閉時所有 AI 入口與沒有這個功能時完全相同。
  final bool enforced;

  /// 受管制入口送出前是否要先就地同意。旗標關一律不擋。
  bool get needsConsent => enforced && status != AiDataConsentStatus.valid;

  /// 不是同意狀態的回應回 null（呼叫端當「不強制」）。
  static AiDataConsent? tryParse(Object? body) {
    if (body is! Map) return null;
    final json = _map(body);
    final status = parseAiDataConsentStatus(json['status']);
    final text = json['text'];
    final version = json['currentVersion'];
    if (status == null || text is! Map || version is! String) return null;
    return AiDataConsent(
      status: status,
      currentVersion: version,
      acceptedVersion: json['acceptedVersion']?.toString(),
      acceptedAt: json['acceptedAt']?.toString(),
      text: AiDataConsentText.fromJson(_map(text)),
      enforced: json['enforced'] == true || json['enforced'] == 1,
    );
  }
}

/// 是誰沒同意：送出者（本人）或行程 owner。
enum AiConsentParty { submitter, owner }

/// 受管制入口被 server 擋下（403 `AI_CONSENT_REQUIRED`／`AI_CONSENT_OWNER_REQUIRED`）。
/// 被擋時 server 不建立 request、不排入佇列。
class AiConsentRequiredException implements Exception {
  const AiConsentRequiredException({
    required this.party,
    required this.requiredVersion,
    this.status,
  });

  final AiConsentParty party;
  final String requiredVersion;

  /// 只有送出者被擋才有；owner 的狀態 server 不揭露。
  final AiDataConsentStatus? status;

  @override
  String toString() =>
      'AiConsentRequiredException($party, requiredVersion: $requiredVersion)';
}

List<String> _strings(Object? value) => [
  for (final v in value as List<dynamic>? ?? const []) v.toString(),
];

Map<String, dynamic> _map(Map<dynamic, dynamic> m) =>
    Map<String, dynamic>.from(m);
