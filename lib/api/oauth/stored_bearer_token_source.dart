/// 把 OAuthTokenStore + OAuthRepository 接成 ApiClient 用的 BearerTokenSource:
/// 提供當前 access token,過期時用 refresh token 換新並寫回。
/// 安全要點:只有「真的失效(token 端 400/401)」才清空登入;暫時性(網路/寫入)
/// 保留 token 稍後再試,避免 rotating refresh token 因一次失敗就鎖死。並發 refresh
/// single-flight,避免同一輪過期觸發多次 refresh 把 rotating token 燒掉。
library;

import 'dart:async';

import '../../models/oauth_tokens.dart';
import '../api_client.dart' show BearerTokenSource, DpopKeyProvider;
import '../api_error.dart';
import '../dpop/proof_key.dart';
import '../dpop/proof_key_store.dart';
import 'oauth_repository.dart';
import 'oauth_token_store.dart';

class StoredBearerTokenSource implements BearerTokenSource, DpopKeyProvider {
  StoredBearerTokenSource({
    required OAuthTokenStore store,
    required OAuthRepository repository,
    required String clientId,
    ProofKeyStore? proofKeys,
  }) : _store = store,
       _repo = repository,
       _clientId = clientId,
       _proofKeys = proofKeys;

  final OAuthTokenStore _store;
  final OAuthRepository _repo;
  final String _clientId;
  final ProofKeyStore? _proofKeys;

  Future<OAuthTokens?>? _inFlight;

  /// access token 只活在記憶體;store 只留 refresh token(ADR-0014)。
  OAuthTokens? _memory;

  final _signedOut = StreamController<void>.broadcast();

  /// refresh token 被後端拒絕(撤銷、過期、重放)而清掉憑證時通知,
  /// 認證狀態據此回到未登入。
  Stream<void> get signedOut => _signedOut.stream;

  /// 登入完成後交給來源:access token 進記憶體,其餘落地。
  Future<void> adopt(OAuthTokens tokens) async {
    _memory = tokens;
    await _store.write(tokens);
  }

  /// 目前的 access token 是綁定金鑰的才回金鑰，ApiClient 據此用 DPoP scheme。
  @override
  Future<ProofKey?> proofKey() async =>
      (_memory?.isDpop ?? false) ? await _proofKeys?.load() : null;

  /// 清掉本機登入憑證、記憶體中的 access token 與 DPoP 金鑰（登出、帳號刪除）。
  Future<void> clear() async {
    _memory = null;
    try {
      await _store.clear();
    } finally {
      await _proofKeys?.delete();
    }
  }

  /// refresh 被拒或金鑰遺失：憑證與金鑰一併清掉，並通知回到未登入。
  Future<void> _invalidate() async {
    await clear();
    _signedOut.add(null);
  }

  @override
  Future<String?> accessToken() async {
    final OAuthTokens? stored;
    try {
      stored = await _store.read();
    } on TokenStoreLockedException {
      // 受保護的憑證還沒解鎖:這時沒有可用的登入憑證,但憑證本身還在。
      return null;
    }
    if (stored == null) {
      // 已登出(store 被清掉):記憶體裡的 access token 也不能再用。
      _memory = null;
      return null;
    }
    final memory = _memory;
    if (memory != null && !memory.isExpired()) return memory.accessToken;
    return (await _refreshShared())?.accessToken;
  }

  @override
  Future<bool> refresh() async => (await _refreshShared()) != null;

  /// single-flight:同一時間只跑一次 refresh,並發呼叫共用同一個 Future。
  Future<OAuthTokens?> _refreshShared() =>
      _inFlight ??= _doRefresh().whenComplete(() => _inFlight = null);

  Future<OAuthTokens?> _doRefresh() async {
    final OAuthTokens? old;
    try {
      old = await _store.read();
    } on TokenStoreLockedException {
      return null;
    }
    final rt = old?.refreshToken;
    if (rt == null || rt.isEmpty) return null;

    // 綁定的 refresh token 必須用原本那把金鑰簽；金鑰沒了就不可能換成功，
    // 不必打網路，直接回登入頁（ADR-0015）。
    final key = old!.isDpop ? await _proofKeys?.load() : null;
    if (old.isDpop && key == null) {
      await _invalidate();
      return null;
    }

    final OAuthTokens fresh;
    try {
      fresh = await _repo.refresh(
        refreshToken: rt,
        clientId: _clientId,
        proofKey: key,
      );
    } on ApiError catch (e) {
      // 400/401 = refresh token 真的失效(撤銷/過期)→ 視為登出。
      if (e.status == 400 || e.status == 401) await _invalidate();
      return null;
    } on Exception {
      // 網路等暫時性錯誤 → 保留 token,稍後再試(不清空)。
      return null;
    }

    // 登出（憑證已被清掉）發生在 refresh 進行中：不能把憑證寫回去讓它復活。
    try {
      if (await _store.read() == null) return null;
    } on TokenStoreLockedException {
      return null;
    }

    // refresh 回應常不含新 id_token → 沿用舊的,身分不丟；
    // 沒有輪替（回應不含新 refresh token）時沿用舊的，否則下次就沒得換了。
    final merged = fresh.copyWith(
      idToken: fresh.idToken ?? old.idToken,
      refreshToken: fresh.refreshToken ?? rt,
    );
    _memory = merged;
    try {
      await _store.write(merged);
    } on Exception {
      // 寫入失敗:仍回傳 merged(本輪可用),不清空(下次再試寫)。
    }
    return merged;
  }
}
