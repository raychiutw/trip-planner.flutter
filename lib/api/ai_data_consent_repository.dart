import '../models/ai_data_consent.dart';
import 'api_client.dart';
import 'api_error.dart';
import 'cache_read_policy.dart';

/// AI 資料同意的三個動作。三個動作不受 server 旗標影響，永遠可用。
class AiDataConsentRepository {
  AiDataConsentRepository({required ApiClient client}) : _client = client;

  final ApiClient _client;

  /// GET /account/ai-data-consent（不讀不寫本機快取）。回應不是同意狀態回 null。
  Future<AiDataConsent?> fetch() async => AiDataConsent.tryParse(
    await _client.get(
      '/account/ai-data-consent',
      policy: CacheReadPolicy.noStore,
    ),
  );

  /// POST /account/ai-data-consent，帶使用者實際看到的版本。
  ///
  /// 版本已更新回 409 `AI_CONSENT_VERSION_MISMATCH`，保留 [ApiError] 讓呼叫端重讀；
  /// 回應不是同意狀態就丟錯，不假裝已同意。
  Future<AiDataConsent> accept(String version) async => _required(
    await _client.post('/account/ai-data-consent', body: {'version': version}),
  );

  /// DELETE /account/ai-data-consent。冪等；從未同意者回 none。
  Future<AiDataConsent> withdraw() async =>
      _required(await _client.delete('/account/ai-data-consent'));

  AiDataConsent _required(Object? body) =>
      AiDataConsent.tryParse(body) ??
      (throw const FormatException('Unexpected ai-data-consent response'));
}

/// 受管制入口 403 → 型別化結果；其他錯誤回 null。錯誤碼只在這裡比對。
AiConsentRequiredException? aiConsentGateFrom(Object error) {
  if (error is! ApiError || error.status != 403) return null;
  final party = switch (error.code) {
    'AI_CONSENT_REQUIRED' => AiConsentParty.submitter,
    'AI_CONSENT_OWNER_REQUIRED' => AiConsentParty.owner,
    _ => null,
  };
  if (party == null) return null;
  final detail = error.payload?['error'];
  final fields = detail is Map ? detail : const {};
  return AiConsentRequiredException(
    party: party,
    requiredVersion: fields['requiredVersion']?.toString() ?? '',
    status: parseAiDataConsentStatus(fields['status']),
  );
}

/// 包住三個受管制入口的 mutation：被閘門擋下時丟 [AiConsentRequiredException]。
Future<T> translateAiConsentGate<T>(Future<T> Function() mutation) async {
  try {
    return await mutation();
  } on ApiError catch (e) {
    throw aiConsentGateFrom(e) ?? e;
  }
}
