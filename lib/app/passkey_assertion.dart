/// passkey 登入（assertion）在平台層的結果（ADR-0016）。平台層不丟例外，全部落在這三種。
library;

sealed class PasskeyAssertion {
  const PasskeyAssertion();
}

/// [credential] 是 WebAuthn 的 PublicKeyCredential JSON（id、rawId、type、response），
/// 形狀與 `POST /oauth/passkey/login` 的 `credential` 相同。
class PasskeyAsserted extends PasskeyAssertion {
  const PasskeyAsserted(this.credential);
  final Map<String, dynamic> credential;
}

/// 使用者在系統對話框按了取消。
class PasskeyAssertCancelled extends PasskeyAssertion {
  const PasskeyAssertCancelled();
}

/// 其他失敗：此網域在這支裝置沒有 passkey、網域關聯未通過、裝置不支援、逾時……
class PasskeyAssertFailed extends PasskeyAssertion {
  const PasskeyAssertFailed();
}
