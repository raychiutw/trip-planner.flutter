/// 敏感操作的重新驗證（step-up，ADR-0016）：證明存放、發證 repository、收到
/// `REAUTH_REQUIRED` 時「問一次、帶證明、重試一次」的閘門。
///
/// 只有五個敏感操作的 repository 方法會經過 [StepUpGate.run]（變更密碼、刪行程、
/// 撤銷／刪除分享、撤銷 passkey、刪帳號）；其餘請求不受影響，也沒有全域重試。
/// 帶標頭仍走 `ApiClient` 的 `headers` 參數，認證標頭照舊由它統一產生。
library;

import 'api_client.dart';
import 'api_error.dart';

/// 證明的請求標頭名稱（api `STEP_UP_PROOF_HEADER`）。
const kStepUpProofHeader = 'X-Step-Up-Proof';

/// api 發的證明與有效秒數（`expires_in`，目前 300）。
class StepUpProof {
  const StepUpProof({required this.proof, required this.expiresIn});

  final String proof;
  final int expiresIn;
}

/// 證明只放記憶體（與 access token 同等級）；登出、換帳號時由 `AuthNotifier` 清除。
class StepUpProofStore {
  StepUpProofStore({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  String? _proof;
  DateTime? _expiresAt;

  /// 還在效期內的證明，沒有或過期回 null。
  String? get valid {
    final expiresAt = _expiresAt;
    if (_proof == null || expiresAt == null || !_now().isBefore(expiresAt)) {
      return null;
    }
    return _proof;
  }

  void save(StepUpProof proof) {
    _proof = proof.proof;
    _expiresAt = _now().add(Duration(seconds: proof.expiresIn));
  }

  void clear() {
    _proof = null;
    _expiresAt = null;
  }
}

/// 向使用者要重新驗證；取消回 null。實作在 `lib/app/step_up_dialog.dart`（要 UI）。
abstract interface class StepUpPrompter {
  Future<StepUpProof?> prompt();
}

/// 沒有 UI 時的預設：一律視為取消（測試與未接線的環境）。
class NoStepUpPrompter implements StepUpPrompter {
  const NoStepUpPrompter();

  @override
  Future<StepUpProof?> prompt() async => null;
}

/// 使用者放棄重新驗證，原操作沒有執行。
class StepUpCancelledException implements Exception {
  const StepUpCancelledException();

  @override
  String toString() => 'StepUpCancelledException';
}

/// 沒有閘門（單元測試、未接線）時直接執行、不帶標頭。
Future<T> runStepUp<T>(
  StepUpGate? gate,
  Future<T> Function(Map<String, String>? headers) call,
) => gate == null ? call(null) : gate.run(call);

class StepUpGate {
  StepUpGate({
    required StepUpProofStore store,
    required StepUpPrompter prompter,
  }) : _store = store,
       _prompter = prompter;

  final StepUpProofStore _store;
  final StepUpPrompter _prompter;
  Future<StepUpProof?>? _pending;

  /// 執行敏感操作 [call]。效期內有證明就直接帶；沒有就不帶標頭（api 沒開強制時行為不變）。
  /// 收到 403 `REAUTH_REQUIRED` → 清掉舊證明、問使用者、成功後**只重試一次**；
  /// 取消丟 [StepUpCancelledException]，重試後仍被要求就把原錯誤丟出去。
  Future<T> run<T>(
    Future<T> Function(Map<String, String>? headers) call,
  ) async {
    final sent = _store.valid;
    try {
      return await call(_headers(sent));
    } on ApiError catch (error) {
      if (!_isReauthRequired(error)) rethrow;
      // 另一個操作剛好在我們等回應時換到新證明：直接用，不再問第二次。
      final fresh = _store.valid;
      if (fresh != null && fresh != sent) return call(_headers(fresh));
      _store.clear();
      final proof = await _askOnce();
      if (proof == null) throw const StepUpCancelledException();
      _store.save(proof);
      return call(_headers(proof.proof));
    }
  }

  /// 兩個操作同時被要求時共用同一次詢問。
  Future<StepUpProof?> _askOnce() {
    final pending = _pending ??= _prompter.prompt();
    return pending.whenComplete(() => _pending = null);
  }

  static Map<String, String>? _headers(String? proof) =>
      proof == null ? null : {kStepUpProofHeader: proof};

  static bool _isReauthRequired(ApiError error) =>
      error.status == 403 && error.code == 'REAUTH_REQUIRED';
}

/// `/account/reauth/*`：發重新驗證證明。失敗一律 403 `REAUTH_INVALID`（不是 401，
/// 不會被當成登入過期）；沒密碼 409 `REAUTH_NO_PASSWORD`；限流 429 `REAUTH_RATE_LIMITED`。
class StepUpRepository {
  StepUpRepository({required ApiClient client}) : _client = client;

  final ApiClient _client;

  /// POST /account/reauth/options，step-up 專用挑戰；`allowCredentials` 只含本人的 passkey。
  Future<Map<String, dynamic>> options() async {
    final body = await _client.post(
      '/account/reauth/options',
      body: <String, dynamic>{},
    );
    return body as Map<String, dynamic>;
  }

  /// POST /account/reauth/passkey，以平台簽好的 assertion [credential] 換證明。
  Future<StepUpProof> passkey(Map<String, dynamic> credential) async => _proof(
    await _client.post(
      '/account/reauth/passkey',
      body: {'credential': credential},
    ),
  );

  /// POST /account/reauth/password，以目前密碼換證明；密碼只在這個請求的 body，不落地。
  Future<StepUpProof> password(String password) async => _proof(
    await _client.post(
      '/account/reauth/password',
      body: {'password': password},
    ),
  );

  static StepUpProof _proof(Object? body) {
    final map = body as Map<String, dynamic>;
    return StepUpProof(
      proof: map['proof'] as String,
      expiresIn: (map['expires_in'] as num?)?.toInt() ?? 300,
    );
  }
}
