---
status: accepted
---

# 認證雙軌：app 扮演瀏覽器走 cookie，OAuth PKCE 已就緒但以 dart-define 關閉

本 repo 是 trip-planner React SPA 的行動版移植,前提是**後端不動** —— 兩個 client 共用同一套 Cloudflare Pages Functions API。而那套後端的認證是為瀏覽器設計的:`POST /api/oauth/login` 發 `Set-Cookie: tripline_session`,之後靠 cookie 辨識身分;CSRF 防護是對 mutating request 檢查 `Origin` header allowlist。

決定是:**出貨版只走 cookie,app 自己扮演瀏覽器**。登入走 `ApiClient.postForResponse` 讀 response 的 `set-cookie`,以 regex 撈出 `tripline_session`(`lib/api/auth_repository.dart:101`、`:303-310`)存進 flutter_secure_storage;之後由 `ApiClient` 統一帶 `Cookie:`,mutating request 再補一個 `Origin`(`lib/api/api_client.dart:961-965`),值取自 `kTriplineOrigin`(`lib/api/api_client.dart:21`),預設就是正式站網域。少了這個 header,後端會擋成 403 —— 對後端而言,app 跟正式站的網頁長得一模一樣。

同時,OAuth 2.1 authorization-code + PKCE 的 client 端**已完整實作**,production backend 也已 provision public client `tripline-mobile`。但它在出貨版是關的,而且是**編譯期**就關的:`OAuthConfig.clientId` 讀 `String.fromEnvironment('TRIPLINE_OAUTH_CLIENT_ID')` 且**沒有 defaultValue**(`lib/api/oauth/oauth_config.dart:7`),沒帶 `--dart-define` 就是空字串 → `isConfigured` 為 false(`lib/api/oauth/oauth_config.dart:18`)→ `oauthEnabledProvider` 為 false(`lib/api/oauth/oauth_providers.dart:15`)→ 登入頁的 OAuth 按鈕整段不建(`lib/features/auth/login_screen.dart:286`)。而 `.github/workflows/mobile.yml` 全檔沒有任何 `dart-define`,所以 TestFlight 與 Google Play internal 送出去的 build,兩條發布路徑都是 cookie。**PKCE 是備好的第二軌,不是現行出貨路徑。**

## Considered Options

**後端加 mobile 專用 token endpoint** —— 最直覺的解法:請後端開一個吃帳密、回 token 的 mobile endpoint,認證就不必假裝自己是瀏覽器,也不必偽造 `Origin`。拒絕的理由是它直接破壞本專案的前提。本 repo 與 web SPA 共用同一套 Pages Functions,任何為 mobile 新開的認證面同時也是 web 的攻擊面;而且兩個 client 的認證行為會就此分岔 —— 移植版有一半的價值來自「合約與 web 版一樣」,分岔掉的部分之後每個功能都要付一次代價。

**custom scheme redirect(`tripline://`)** —— OAuth 授權完回跳最順的作法,使用者不會看到中間頁。後端的 `redirect_uris` 是 exact-match 比對,`tripline-mobile` 註冊的是 `["http://127.0.0.1:8765"]`,custom scheme 直接被拒(後端 client 的註冊值,一手考證在已歸檔的 PKCE 設定文件)。要讓後端收 `tripline://` 就得改 client 註冊政策 —— 又回到上一條被拒的方案。因此 redirect 改走 RFC 8252 loopback `http://127.0.0.1:<port>`,port 由 `TRIPLINE_OAUTH_REDIRECT_PORT` 決定、預設 8765(`lib/api/oauth/oauth_config.dart:10-15`),且必須與後端註冊值完全一致。

**出貨版直接把 PKCE 設為預設路徑** —— client 端寫完了、後端 client 也是 active,看起來可以直接切過去。沒切有兩個原因:loopback redirect 在 iOS 上的回跳體驗是斷的(見 Consequences);以及 `OAuthLoginService` 的瀏覽器/loopback 編排相依於裝置,目前**沒有自動化的實機 e2e**。PKCE、token 交換與刷新、Bearer 模式的 `ApiClient` 都有單元測試,但「開系統瀏覽器 → 收 code → 跳回 App」這一段只有手動驗證。在這條驗完並自動化之前,把所有使用者的登入押在上面不划算。

**只留 cookie,先不實作 PKCE** —— 反方向的偷懶:既然出貨走 cookie,PKCE 大可等後端放寬 redirect 政策再做。拒絕是因為「關著的 PKCE」幾乎不花成本:compile-time const 讓未設定時的行為與「沒有這段程式碼」一致,零 runtime 影響;而偽造 `Origin` 是明確且已知的技術債 —— Bearer 模式下後端對「有 Bearer 且無 Origin」的 request 跳過 CSRF 檢查(`lib/api/api_client.dart:952-955`),切過去就擺脫了這個 hack。先把 client 端寫好、用單元測試鎖住,剩下的就只是一個 build 參數,而不是一次改版。

## Consequences

- **啟用 PKCE 不是改程式碼,是改 build**:release build 必須同時帶 `TRIPLINE_OAUTH_CLIENT_ID` 與 `TRIPLINE_OAUTH_REDIRECT_PORT`,且 port 要與後端註冊的 redirect_uri 完全一致。漏帶不會建置失敗、也不會 crash,而是**靜默回退 cookie** —— 沒有任何 runtime 訊號會提醒你這件事。
- **loopback 在 iOS 上有 UX 代價**:授權完成後使用者會停在瀏覽器的「可關閉此頁」畫面,要手動切回 App,不像 custom scheme 會自動返回。這正是預設關閉的直接理由。要修得靠後端網域層級的 App Link 關聯檔、或放寬 redirect 政策,兩者都在本 repo 之外。
- **測試的可及範圍不對稱**:`oauthEnabledProvider` 是 provider 而非直接讀 const,測試可以 override 它來驗 OAuth 開啟後的登入頁;但 `OAuthConfig.clientId` 本身是 compile-time const,牽涉到它的路徑只能靠注入替身,無法在測試中改「環境」。
- **只要還走 cookie,`Origin` 就必須由 `ApiClient` 統一補上**。任何繞過 `ApiClient`、用 raw dio 直接打 mutating API 的程式碼都會拿到 403,而且症狀看起來像權限或登入過期問題,不像缺一個 header。
