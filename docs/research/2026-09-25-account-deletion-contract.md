# 無密碼帳號刪除能力契約（T47）

日期：2026-09-25。調查 [#380](https://github.com/raychiutw/trip-planner.flutter/issues/380)，供 [#389](https://github.com/raychiutw/trip-planner.flutter/issues/389) 使用。**#389 維持 blocked；#380 的正式環境驗證仍未完成，不關票。**

## 查證範圍與版本

Flutter worktree 由 `origin/master` 建立，fixed point `b9729c171eb1d27a21f7dfc2a98cabf3512824ae`（F）。後端唯讀 checkout `/Users/ray/Projects/trip-planner` 的 master、origin/master 與 GitHub master 當次皆為 `a26590a4cf4a00f6ac991cf783e7b263244aae60`（B）。所有下列原始碼引用均釘在這兩個 SHA，不以檔案最新狀態代替。[F0][B0]

本次未修改 production、未新增後端能力、未輸出秘密、未對任何帳號送出 DELETE／登入／重設密碼／Google OAuth start，也未寄出刪除申請。未執行 Flutter analyze／test 或實機驗證；既有測試只作為 source 證據閱讀。

## 能力矩陣

帳號分類的可靠分界是 `/api/account` 的 `hasPassword`，其判定為該 user 是否有 `provider='local' AND password_hash IS NOT NULL`。不能用登入方式、顯示名稱或是否持有 OAuth token 代替；同一帳號可以同時連結 local 與 Google identity。[B1][B4]

| 種類 | 已核實原始碼能力 | fresh-auth／刪除 | 正式環境證據 |
|---|---|---|---|
| local 密碼帳號 | signup 建 local identity；GET account 回 `hasPassword=true` | DELETE 每次驗目前 password，錯誤／空值在 erase 前拒絕 | Mobile CI 有發布紀錄；正式帳號／endpoint 未驗證 |
| local + Google 連結帳號 | Google callback 可連結同 email 且已驗證的現有 user | 只要仍有 local password，沿用密碼分支；不因 Google 登入改成輸入 DELETE | 正式 Google secrets／啟用及實際帳號集合未知 |
| Google-only／沒有 local password 的帳號 | Google callback 建 identity；hasPassword=false | 後端只要求有效 cookie session + `confirm:'DELETE'`，**沒有 fresh-auth**；Flutter 阻擋 | 正式有無此類帳號未知，不讀取個資資料列 |
| OAuth Bearer 登入的使用者 | 是存取憑證形式，不是另一種 identity 類型 | account GET/DELETE 使用 `requireSessionUser`，只讀 cookie；Bearer-only 不足以通過 handler | 出貨 workflow 未啟用 mobile PKCE；未驗 Bearer 真機 |
| Apple／LINE／其他 | migration 註解列的是可擴充 provider 名稱 | 本次未核實可用 handler／正式設定，不宣稱支援 | 未知 |

來源：[B1–B5][F1–F3]。Google login start 會寫 OAuthState，故沒有用 GET 試探正式啟用狀態。原始碼存在不等於正式服務已開啟。[B4]

## 既有端點與使用者路徑

1. Flutter 帳號頁 → 刪除帳號 → `GET /api/account`。preview 包含 `hasPassword`、`tripsOwned`、`collaboratorsAffected`；Flutter 明確禁用快取與 stale fallback。[F1][F2][B1]
2. 有密碼：顯示永久刪除與共編影響，安全預設焦點是取消；送 `DELETE /api/account` JSON `{password: ...}`。後端再查身份、驗密碼，失敗回 `ACCOUNT_DELETE_CONFIRM_REQUIRED` 或 `ACCOUNT_DELETE_PASSWORD_INVALID`，不進 erasure。[F1][B1]
3. 無密碼：Flutter 顯示「需要重新驗證才能刪除」，不送 DELETE。確認查看說明才開 `https://trip-planner-dby.pages.dev/privacy#delete-account`。repository 雖仍能送 `{confirm:'DELETE'}`，UI 的 guard 與既有 widget test 刻意不讓使用者走此分支，不能把它當成漏接。[F1][F2][F4][F5]
4. Backend DELETE 成功回 200 `{ok:true,tripsDeleted,auditRowsAnonymized,tablesCleared}` 與清 cookie header；Flutter repository 才清本機 session，`accountDeleted()` 再清 OAuth token（有配置時）及快取、auth state 設 null，返回 welcome。[B1][F1][F2][F3]
5. Web 帳號頁仍讓無密碼帳號輸入 DELETE，再送相同端點；成功整頁導向 `/`。這條網頁路徑沒有補足 fresh-auth，不能用「在瀏覽器刪除」宣稱滿足 #389。[B6]

另需注意：backend erasure 是逐表操作，原始碼明示**不是 transaction**，中途失敗可能部分刪除。因此 client 只能保留失敗狀態／提供恢復途徑，不能承諾「失敗時所有資料原封不動」。本次沒有驗證完整 erasure、所有 token 撤銷或重試收斂。[B7]

## fresh-auth 缺口與 #389 外部 blocker

`requireSessionUser` 驗 cookie token 有效性、session revoked 狀態，但不要求最近重新驗證；account DELETE 沒有 reauth proof／challenge／auth_time 檢查。無密碼的 `DELETE` 字串只是意圖確認，不能證明近期身分驗證。[B1][B2]

Google login 只有 `prompt:'consent'`，callback 發一般 session；它沒有將新的驗證綁定目前帳號、刪除用途或一次性期限。不能把重新開 Google consent 畫面當成已建立刪除 fresh-auth 契約。local forgot-password 只查 local identity，reset-password 只更新 local identity，因此不能假設 Google-only 可透過「忘記密碼」補建密碼來繞過缺口。[B4][B5]

#389 可採用的界線：沿用 preview／具名永久刪除確認／成功後清本機認證；**維持無密碼 guard**，直到後端提供且部署下列必要能力。本次列的是外部需求，不是假稱已存在的 API：

- 由後端核實支援的帳號 identity／provider，並提供與當前 user、刪除操作綁定的 fresh-auth；明確期限、單次使用、拒絕／過期／身份不符錯誤契約。
- 刪除端點必須在 erasure 前驗 fresh-auth，不可只在 Flutter 做判斷。須說明 cookie 與 Bearer 呼叫的支援方式，不能混送憑證假裝已解決。
- 用受控測試帳號驗證允許／取消／過期／重播／切換另一帳號／無密碼與混合 identity；外部部署證據與 mobile 可用 callback 需先補齊。
- 確認非交易刪除的失敗狀態與恢復契約，以及所有 session／access／refresh token 的撤銷完成條件，再寫準確的結果文案。

後端阻擋工作已由 [trip-planner #1347](https://github.com/raychiutw/trip-planner/issues/1347) 追蹤。該票於 2026-09-26 仍開啟，明列 challenge、身份綁定、期限、單次使用、錯誤契約及正式部署驗收；目前沒有可供 Flutter 採用的已部署 API。#389 原本依賴 #380 的 edge 應保留。

## 外部說明頁真實動線：source 已核對，live 未證實

F4 實際使用 `url_launcher` externalApplication 開 `/privacy#delete-account`，不開 App 內申請表；其 bool 回傳未作失敗提示。B8 的對應錨點存在，內容提供兩條動線：帳號頁自行刪除，以及無法登入／已移除 App 時，由註冊信箱寄信到公開聯絡地址 `lean.lean@gmail.com`，主旨「刪除帳號申請」。這是 mailto 人工作業，沒有表單送件編號或 fresh-auth API。頁面宣告以來信地址相符核對、7 個工作天完成並回信；**本次沒有驗證郵件送達、人工核身強度或 SLA 實際履行**。[F4][B8]

頁面 source 宣稱「在 app 內即可自行完成」，與 Flutter 無密碼 guard 不完全一致。這是應交給產品／後端處理的跨端落差，不應透過移除 guard 消除。[F1][B8]

2026-09-25 匿名 Python urllib GET `/privacy`、`/api/account` 均回 403；web open `/privacy#delete-account` 亦無法存取。未取得線上頁面內容或 account JSON，不知道是否 edge 規則、網路存取條件或應用層所致；不能把 403 當作不存在，也不能宣稱線上動線已通過。

2026-09-25 後續以 macOS Chrome 實際載入正式 `/privacy` 的 hydrated 正文，並在 390×844 viewport 驗證刪除帳號錨點、`mailto:` 申請與聯絡入口可見；詳見 [Flutter #386 的瀏覽證據](https://github.com/raychiutw/trip-planner.flutter/issues/386#issuecomment-5828100007)。這補足「正式頁面是否有內容」的證據，但桌面窄 viewport 不等於真實行動瀏覽器，亦未核實郵件處理、正式部署 SHA 或 fresh-auth。

## 部署證據

- Flutter [release run 34924340248](https://github.com/raychiutw/trip-planner.flutter/actions/runs/34924340248)，2026-09-15，F SHA：TestFlight／Android internal upload 都 success。工作流無 OAuth client ID dart-define；不是對目前使用者安裝 binary 的稽核。[F6]
- 後端 [Cloudflare check 107967668463](https://api.github.com/repos/raychiutw/trip-planner/check-runs/107967668463)，2026-09-25，B SHA：success，但 output 明示 preview `bbcb059a.trip-planner-dby.pages.dev`、branch preview **uat.trip-planner-dby.pages.dev**。不能因此宣稱正式 `trip-planner-dby.pages.dev` 已部署同一契約。
- GitHub deployments API 最近列出的項目是 github-pages，亦不足以證明正式 Cloudflare alias。正式 deployment SHA、Google 啟用設定、正式帳號種類仍未知。

## 可重現方式與後續驗證 seam

只讀：`git show <SHA>:<下列路徑>`；`gh run view 34924340248 --repo raychiutw/trip-planner.flutter --json headSha,jobs,url`；`gh api repos/raychiutw/trip-planner/commits/a26590a4cf4a00f6ac991cf783e7b263244aae60/check-runs`。公開 GET 可用 `curl --max-time 20 -o /dev/null -w '%{http_code}\n' https://trip-planner-dby.pages.dev/privacy`；不可因重播調查而送 DELETE。

既有 seams：Flutter `test/features/account/account_screen_test.dart` 的「純 OAuth 帳號無 fresh-auth 契約時安全阻擋刪除」、`test/api/auth_repository_test.dart` preview／密碼錯誤保留 session；backend `tests/api/account-delete.test.ts` 的密碼及 confirm 分支。這些是已閱讀的測試來源，本次未執行，#389 接手仍須先按核准新契約寫 failing behavior test。

## 一手來源

以下 F 路徑均在 SHA `b9729c171eb1d27a21f7dfc2a98cabf3512824ae`；B 路徑均在 SHA `a26590a4cf4a00f6ac991cf783e7b263244aae60`。本次以檔案與 graph 對照、釘定 SHA，未把歷史文件當作正式環境現況。

| ID | 路徑 |
|---|---|
| F0 | [Flutter fixed point](https://github.com/raychiutw/trip-planner.flutter/tree/b9729c171eb1d27a21f7dfc2a98cabf3512824ae) |
| F1 | `lib/features/account/account_screen.dart` |
| F2 | `lib/api/auth_repository.dart` |
| F3 | `lib/api/providers.dart`、`lib/api/oauth/oauth_config.dart` |
| F4 | `lib/app/external_links.dart` |
| F5 | `test/features/account/account_screen_test.dart`、`test/api/auth_repository_test.dart` |
| F6 | `.github/workflows/mobile.yml` |
| B0 | [Backend fixed point](https://github.com/raychiutw/trip-planner/tree/a26590a4cf4a00f6ac991cf783e7b263244aae60) |
| B1 | `functions/api/account/index.ts`、`tests/api/account-delete.test.ts` |
| B2 | `functions/api/_session.ts`、`functions/api/_middleware.ts` |
| B3 | `migrations/0032_users_auth_identities.sql`、`functions/api/oauth/signup.ts` |
| B4 | `functions/api/oauth/login/google.ts`、`functions/api/oauth/callback/google.ts` |
| B5 | `functions/api/oauth/forgot-password.ts`、`functions/api/oauth/reset-password.ts` |
| B6 | `src/pages/AccountPage.tsx` |
| B7 | `functions/api/_erasure.ts` |
| B8 | `src/pages/PrivacyPage.tsx` |
