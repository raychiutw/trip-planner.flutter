# OAuth PKCE 實作計畫

> executing-plans 逐 task TDD。分支 `feat/oauth-pkce`。spec：`docs/superpowers/specs/2026-06-12-oauth-pkce-design.md`。
> client 端可立即寫 + 單測;e2e 待 backend owner provision public client。後端不動。

**Tech:** crypto(SHA-256)、url_launcher、flutter_secure_storage、dio。

## Task 1：PKCE
- 新 `lib/api/oauth/pkce.dart`:`String generateCodeVerifier()`(32 bytes `Random.secure` → base64url 無 padding,長度 43)、`String codeChallengeS256(String verifier)`(`base64Url.encode(sha256.convert(ascii).bytes)` 去 `=`)。
- test:RFC 7636 §4 向量 `verifier='dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'` → `challenge='E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM'`;verifier 長度/字元集 `^[A-Za-z0-9\-._~]{43}$`。
- commit `feat: PKCE（code_verifier/S256 challenge）`。

## Task 2：OAuthTokens model
- 新 `lib/models/oauth_tokens.dart`:`accessToken, refreshToken?, tokenType, scope?, expiresAt(DateTime)`。`bool isExpired({Duration skew=60s})`;`factory fromTokenResponse(json, {DateTime now})`(expiresAt=now+expires_in);`toJson()`/`fromJson()`(持久化,expiresAt ISO)。
- test:fromTokenResponse 設 expiresAt;isExpired(skew);json round-trip。
- commit `feat: OAuthTokens model`。

## Task 3：OAuthRepository
- 新 `lib/api/oauth/oauth_repository.dart`:`OAuthRepository({Dio? dio, String origin=kTriplineOrigin})`(自帶 dio,validateStatus 全收)。
  - `Uri buildAuthorizeUrl({clientId, redirectUri, codeChallenge, state, scope='openid profile email offline_access'})` → `<origin>/api/oauth/authorize?...`。
  - `Future<OAuthTokens> exchangeCode({code, codeVerifier, clientId, redirectUri})` → POST `/oauth/token` form-urlencoded `{grant_type:'authorization_code',code,redirect_uri,client_id,code_verifier}`;非 2xx → throw ApiError;→ fromTokenResponse。
  - `Future<OAuthTokens> refresh({refreshToken, clientId})` → POST form `{grant_type:'refresh_token',refresh_token,client_id}`。
  - form-urlencoded:`Options(contentType: Headers.formUrlEncodedContentType)` + data Map。
- test(http_mock_adapter):buildAuthorizeUrl 帶齊 query + S256;exchangeCode 送 form + 解析 token;refresh form;401 → ApiError。
- commit `feat: OAuthRepository（authorize URL / token / refresh）`。

## Task 4：OAuthTokenStore
- 新 `lib/api/oauth/oauth_token_store.dart`:`abstract OAuthTokenStore { read()→Future<OAuthTokens?>; write(t); clear(); }`;`SecureOAuthTokenStore`(flutter_secure_storage key `tripline_oauth_tokens`,存 `jsonEncode(toJson)`);`InMemoryOAuthTokenStore`(測試)。
- test:InMemory write→read round-trip、clear。
- commit `feat: OAuthTokenStore（secure + in-memory）`。

## Task 5：ApiClient Bearer 模式
- `lib/api/api_client.dart`:加 `abstract class BearerTokenSource { Future<String?> accessToken(); Future<bool> refresh(); }`(或獨立檔);ApiClient ctor 加 `BearerTokenSource? bearerSource`。
- `_send`:
  - `final bearer = await _bearerSource?.accessToken();`
  - `if (bearer != null && bearer.isNotEmpty) { headers['Authorization']='Bearer $bearer'; /* 不加 Cookie/Origin */ } else { 現況 cookie+Origin }`。
  - 回應 401 且 `_bearerSource!=null` 且用了 bearer 且 `!isRetryAttempt`:`if (await _bearerSource.refresh()) return _send(...isRetryAttempt:true);`(在 throw 前)。
- test:(a)有 bearerSource 回 token → 送 `Authorization: Bearer`、**無 Origin**;(b)401 → refresh()→retry(用新 token、verify refresh 呼叫 1 次);(c)refresh 回 false → 丟 ApiError(401);(d)bearerSource=null → cookie 模式(沿用既有測試,零破壞)。
- commit `feat: ApiClient Bearer 模式（+ 401 refresh-retry,不送 Origin）`。

## Task 6：OAuthConfig + StoredBearerTokenSource
- 新 `lib/api/oauth/oauth_config.dart`:`clientId=String.fromEnvironment('TRIPLINE_OAUTH_CLIENT_ID')`、`redirectPort=int.fromEnvironment('TRIPLINE_OAUTH_REDIRECT_PORT',defaultValue:8765)`、`redirectUri='http://127.0.0.1:$redirectPort'`、`bool get isConfigured => clientId.isNotEmpty`。
- 新 `lib/api/oauth/stored_bearer_token_source.dart`:`StoredBearerTokenSource implements BearerTokenSource`{store, repo, clientId}。`accessToken()`:讀 store;非空且未過期回 access;過期則嘗試 refresh。`refresh()`:讀 store.refreshToken → repo.refresh → 寫回 store → true;無 refreshToken 或失敗 → clear + false。
- test:accessToken 未過期直回;過期 → refresh 寫回;refresh 失敗 → clear + false。
- commit `feat: OAuthConfig + StoredBearerTokenSource`。

## Task 7：OAuthLoginService（loopback 編排;device 相依,薄）
- 新 `lib/features/auth/oauth_login_service.dart`:`Future<OAuthTokens> login()`:
  1. `verifier=generateCodeVerifier(); challenge=codeChallengeS256(verifier); state=隨機`。
  2. `server = await HttpServer.bind(InternetAddress.loopbackIPv4, OAuthConfig.redirectPort)`。
  3. `launchUrl(repo.buildAuthorizeUrl(...), mode: externalApplication)`。
  4. 等第一個 request → 取 `code`/`state`(驗 state)→ 回 200 HTML「可關閉」→ close server。
  5. `tokens = await repo.exchangeCode(...)`;`store.write(tokens)`;return。
  - 錯誤(state 不符 / error param / timeout)→ throw。逾時 `Future.any` + Timer。
- 不單測(網路/瀏覽器);核心(pkce/exchange)已於 Task 1/3 測。
- commit `feat: OAuthLoginService（loopback PKCE 登入編排）`。

## 收尾
- `flutter analyze` 0 + `flutter test` 全綠。`dart format`。
- README/docs:backend owner provision client 步驟 + `--dart-define` 用法 + 「OAuth 為就緒待註冊,預設仍 cookie」說明。CHANGELOG/TODOS。
- finishing：push + PR(base master)。

## 自審
- 後端不動;client_id/redirect 注入;cookie 模式零破壞(bearerSource 預設 null)。
- 可測核心全測;loopback/browser 薄且隔離。e2e 限制已於 spec/PR 載明。
