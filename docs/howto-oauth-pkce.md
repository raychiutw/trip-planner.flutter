# 啟用 OAuth PKCE 登入(取代 session cookie + 偽造 Origin)

native app 的 OAuth 2.1 authorization-code + PKCE 用戶端**已實作完成**,但預設**未啟用** —
app 仍走既有的 session cookie 登入。要啟用,需要 backend owner 先 provision 一個 public client
(本 repo 不動後端,只能由你在後端做這一次性設定),再用 `--dart-define` 把 client 設定餵進 build。

## 為什麼預設關閉

`lib/api/providers.dart` 的 `apiClientProvider` 只有在 `OAuthConfig.isConfigured`(即有設
`TRIPLINE_OAUTH_CLIENT_ID`)時才接上 Bearer 來源;否則完全走 cookie。所以沒設定就是現況,零影響。

## 後端一次性設定(backend owner)

後端的 OAuth 引擎已齊備(`/api/oauth/authorize`、`/api/oauth/token`、PKCE-S256、refresh、JWKS),
且 API 接受 `Authorization: Bearer`。缺的是一個可用的 **public client** 與一個 native 能攔截的 redirect:

1. 在 `client_apps` 建立一列(或用 `POST /api/dev/apps` 自助註冊後,由 ops 把 `status` 改成 `active`):
   - `client_type = 'public'`(無 client_secret;強制 PKCE)
   - `redirect_uris = ["http://127.0.0.1:8765"]`(loopback 固定埠;**custom scheme 會被後端拒**)
   - `allowed_scopes` 含 `openid profile email offline_access`
   - `status = 'active'`
2. 記下 `client_id`。

> redirect 採 RFC 8252 loopback(`http://127.0.0.1:<port>`)。port 預設 8765,可用
> `TRIPLINE_OAUTH_REDIRECT_PORT` 覆寫,但**必須與註冊的 redirect_uri 完全一致**(後端 exact-match)。

## build/run 時注入

```bash
flutter run \
  --dart-define=TRIPLINE_OAUTH_CLIENT_ID=<你的 client_id> \
  --dart-define=TRIPLINE_OAUTH_REDIRECT_PORT=8765
```

設定後:
- `apiClientProvider` 會在「有 OAuth token」時自動帶 `Authorization: Bearer`(且**不送 Origin** →
  後端對 no-Origin Bearer 跳過 CSRF,等於擺脫偽造 Origin 的過渡 hack);access token 過期會用
  refresh token 自動換新(`StoredBearerTokenSource`);沒 token 時仍回退 cookie。
- 觸發登入:呼叫 `ref.read(oauthLoginServiceProvider).login()` — 會起 loopback server、開系統瀏覽器
  授權、收 code、換 token、存進 secure storage。(把它接到登入頁的「用 OAuth 登入」按鈕即可。)

## 已知限制 / 待辦

- **e2e 未驗證**:無 active client 前無法跑完整流程;client 端核心(PKCE、token 交換/刷新、Bearer
  ApiClient)皆有單元測試,但瀏覽器/loopback 編排(`OAuthLoginService`)device 相依、未單測。
- **mobile loopback UX**:iOS 上 loopback redirect 後使用者會看到「可關閉此頁」再手動切回 App(不像
  custom scheme 自動返回)。若要更順,需後端放寬 redirect 政策(custom scheme)或設 https App Link
  關聯檔 — 兩者皆後端網域層級,超出本 repo。
- `/oauth/userinfo` 不收 Bearer(後端僅 cookie),身分請改讀 `id_token` claims 或一般 API 端點。
- 登入頁尚未加「用 OAuth 登入」按鈕(就緒待接);預設登入流程不變。
