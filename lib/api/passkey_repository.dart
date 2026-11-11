/// passkey 管理（ADR-0016）：列表、註冊兩步、改名、撤銷。
/// 平台的建立動作不在這裡（見 `lib/app/passkey_platform.dart`），這層只跟 api 講話。
library;

import '../models/passkey.dart';
import 'api_client.dart';
import 'step_up.dart';

class PasskeyRepository {
  PasskeyRepository({required ApiClient client, StepUpGate? stepUp})
    : _client = client,
      _stepUp = stepUp;

  final ApiClient _client;
  final StepUpGate? _stepUp;

  /// GET /account/passkeys，只含本人的，依建立時間舊到新。
  Future<List<Passkey>> list() async {
    final body = await _client.get('/account/passkeys');
    final items =
        (body as Map<String, dynamic>)['passkeys'] as List<dynamic>? ?? [];
    return items
        .map((j) => Passkey.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// POST /account/passkeys/register/options，取得一次性挑戰與 WebAuthn 建立選項（原樣交給平台層）。
  Future<Map<String, dynamic>> registerOptions() async {
    final body = await _client.post(
      '/account/passkeys/register/options',
      body: <String, dynamic>{},
    );
    return body as Map<String, dynamic>;
  }

  /// POST /account/passkeys/register/verify，把平台建立好的 [credential] 交給後端驗證並儲存。
  ///
  /// 沒給 [name] 就不送欄位，由後端用預設名稱。409 `PASSKEY_ALREADY_REGISTERED`
  /// 代表這組憑證已註冊過；其餘錯誤碼都丟 `ApiError`。
  Future<Passkey> registerVerify({
    required Map<String, dynamic> credential,
    String? name,
  }) async {
    final body = await _client.post(
      '/account/passkeys/register/verify',
      body: {'credential': credential, 'name': ?name},
    );
    return Passkey.fromJson(body as Map<String, dynamic>);
  }

  /// PATCH /account/passkeys/:id，改名（後端去前後空白、最多 50 字、不可為空）。
  Future<Passkey> rename(String id, String name) async {
    final body = await _client.patch(
      '/account/passkeys/${Uri.encodeComponent(id)}',
      body: {'name': name},
    );
    return Passkey.fromJson(body as Map<String, dynamic>);
  }

  /// DELETE /account/passkeys/:id，撤銷：不影響任何登入狀態，找不到回 404 `PASSKEY_NOT_FOUND`。
  ///
  /// 敏感操作：收到 `REAUTH_REQUIRED` 會先重新驗證再重試一次（見 `step_up.dart`）。
  Future<void> revoke(String id) => runStepUp(
    _stepUp,
    (headers) => _client.delete(
      '/account/passkeys/${Uri.encodeComponent(id)}',
      headers: headers,
    ),
  );
}
