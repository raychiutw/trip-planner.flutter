# 第一方 App 的 OAuth scope：標準怎麼說，該豁免還是明確簽發

查核日期：2026-11-03。本文只回答「標準與業界一手文件怎麼處理 first-party client 的 scope 與同意」，不變更任何產品行為，也沒有碰後端 repo 或正式環境。所有 RFC／draft／OIDC 原文都在本次直接抓取並以文字搜尋核對過章節內容；引用一律是轉述，不貼長段。

## 問題與前提

自家原生 App 以 OAuth 2.0 + PKCE 取得 access token 呼叫自家資源伺服器（RS）。兩個選項：

- **A**：RS 依「client 是第一方」旗標，直接豁免 scope 檢查。
- **B**：client 註冊時登記 allowed scopes，App 授權請求明確要求資源 scope（如 `trips:read trips:write`），token 的 scope 由授權伺服器（AS）簽發，RS 檢查 token 的 scope。

已由呼叫端驗證、本文直接當前提（未重查）的事實：

- AS 的 `client_apps` 有 `first_party` 欄位，`tripline-mobile`／`-web` 皆為 1，`allowed_scopes` 只有 `openid profile email offline_access`。
- RS 的 `hasTripScope` 要求 token 帶 `trips:read`／`trips:write`，豁免條件寫死 `client_id=tripline-tp-request`，沒讀 `first_party`。
- 結果：App 登入成功後讀行程全部 403 `PERM_DENIED`。
- Token 同時以 DPoP（RFC 9449）綁金鑰。

## 結論先行

1. **標準沒有「first-party」這個概念**。RFC 6749 的 client 類型只有 confidential／public（§2.1），沒有任何地方定義「第一方可豁免 scope」。因此選項 A 的「第一方旗標」不是標準機制，是實作者自訂。
2. **標準偏向 B 的形狀**：scope 由 AS 簽發進 token、RS 檢查 token 是否涵蓋所請求的資源（OAuth 2.1 draft §5 明文 MUST；RFC 9700 §2.3 SHOULD）。但「scope 值叫什麼、client 註冊時能要哪些、有沒有同意畫面」都留給實作者。
3. **「第一方可省略同意畫面」是被允許的**，且是 AS 端的政策，不等於「token 不必帶 scope」。業界（Auth0、Microsoft Entra）的做法正是：同意可跳過／預先授權，但 token 仍帶 scope，API 仍檢查 scope。
4. **RS 不該以 `client_id` 取代 scope 作為授權依據**：標準沒有這樣的規定，且原生 App 的 `client_id` 是公開值，不能證明呼叫者身分（RFC 8252 §8.6、RFC 6749 §10.2）。

## 一、標準明文規定

| 結論 | 來源（章節） | 轉述 |
| --- | --- | --- |
| scope 由 AS 定義，client 以 `scope` 參數請求，AS 以回應的 `scope` 告知實際簽發範圍 | [RFC 6749 §3.3](https://www.rfc-editor.org/rfc/rfc6749#section-3.3) | scope 字串由 AS 定義；AS 可以全部或部分忽略 client 所請求的 scope；若簽發範圍與請求不同，MUST 在回應帶 `scope`。 |
| client 省略 `scope` 時的行為 | RFC 6749 §3.3 | AS MUST 套用預先定義的預設值，或回 invalid scope；AS SHOULD 文件化其 scope 要求與預設值。 |
| AS 簽發 scope 時應考慮 client 身分 | [RFC 6749 §10.3](https://www.rfc-editor.org/rfc/rfc6749#section-10.3) | client SHOULD 只請求最小必要 scope；AS SHOULD 在決定如何滿足請求的 scope 時考慮 client 身分，且可簽發比請求更少的權限。 |
| RS 必須檢查 token 的 scope 涵蓋所請求的資源 | [OAuth 2.1 draft-ietf-oauth-v2-1-17 §5](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-v2-1-17#section-5)（2026-10 版，Expires 2027-05-04，仍是 draft） | RS MUST 驗證 token 未過期，並確認其 scope 涵蓋所請求的資源。同 draft §1.4.1 說明 scope 機制讓 AS 與 RS 限制特定 client 可存取的資源類型或權限層級，由 RS 負責執行。RFC 6749 本身沒有這句 MUST（它把 RS 驗證方式留在規範外，見 §1.1），所以這是 draft 的收斂，不是 RFC 6749 的既有義務。 |
| token 權限應最小化，並限制在資源與動作 | [RFC 9700 §2.3](https://www.rfc-editor.org/rfc/rfc9700#section-2.3)（BCP 240） | access token 的權限 SHOULD 限制在最小必要；SHOULD 受 audience 限制；也 SHOULD 限制到特定資源與動作，RS 有義務逐請求驗證 token 是否適用該動作，不適用就必須拒絕。這段同時說 client 與 AS MAY 用 `scope` 或 `authorization_details`（RFC 9396）表達。OAuth 2.1 draft §7.1.4 有同型文字。 |
| JWT access token 的 scope 與 aud | [RFC 9068 §2.2.3](https://www.rfc-editor.org/rfc/rfc9068#section-2.2.3)、[§3](https://www.rfc-editor.org/rfc/rfc9068#section-3)、[§4](https://www.rfc-editor.org/rfc/rfc9068#section-4) | 授權請求帶 `scope` 時，簽發的 JWT access token SHOULD 含 `scope` claim；其中每個 scope 字串 MUST 對 `aud` 所指資源有意義。RS MUST 驗證 `aud` 含自己、簽章、`iss`、`exp`、`typ`。 |
| RS 如何用 scope 做授權，標準留白 | RFC 9068 §4 | token 含授權 claim 時，RS SHOULD 結合其他情境資訊決定放行或拒絕；怎麼檢查超出該 profile 範圍。 |
| JWT access token 一定有 `client_id` claim | RFC 9068 §2.2 | `client_id` 是 REQUIRED claim，但同文沒有規定 RS 可拿它取代 scope 檢查。 |
| 原生 App 不得用內嵌 user-agent；即使同一方的 App 亦然 | [RFC 8252 §8.12](https://www.rfc-editor.org/rfc/rfc8252#section-8.12) | 原生 App MUST NOT 以內嵌 user-agent 做授權請求；文中特別說即使是與 AS 同一方的受信任 App，內嵌 user-agent 也違反最小權限原則。這與 first-party 不豁免安全做法一致。 |
| 敏感 token 應 sender-constrain | [RFC 9700 §2.2.1](https://www.rfc-editor.org/rfc/rfc9700#section-2.2.1) | AS 與 RS SHOULD 使用 mTLS 或 DPoP 之類機制限制 token 的持有者，避免被竊 token 遭濫用。 |

## 二、標準留給實作者決定

- **有沒有同意畫面、第一方能否跳過**：
  - RFC 6749 §10.2 要求 AS SHOULD 讓資源擁有者明確認證，並提供 client、scope、有效期資訊供其決定；同節又說 AS SHOULD NOT 在未驗證 client 的情況下自動處理重複請求。
  - [RFC 8252 §8.6](https://www.rfc-editor.org/rfc/rfc8252#section-8.6) 與 [OAuth 2.1 draft §7.3.1](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-v2-1-17#section-7.3.1) 把門檻定在「client 身分能被確保」才可免互動，且以 claimed https redirect 等平台機制可作為身分證明（MAY）；draft 補充這些機制「不等於 client 驗證，也不使 client 變 confidential」。
  - [OIDC Core §3.1.2.4](https://openid.net/specs/openid-connect-core-1_0.html#Consent) 明說 AS MUST 在釋出資訊前取得授權決定，但 MAY 透過「事先的管理性同意」等其他方式建立，不一定要互動對話。
  - OAuth 2.1 draft §2.1 提到 AS 可依對 client 身分的信心決定要不要每次詢問同意，也 SHOULD 考慮信心層級後才允許「略過後續授權的同意提示」。
  - 結論：**同意可由 AS 政策省略，這是標準容許的**；但沒有「第一方」專屬規定。
- **client 能請求哪些 scope（allowed scopes）**：標準沒有「client 註冊 allowed scopes」這個欄位。OAuth 2.1 draft §7.9（Consent Phishing）建議 AS SHOULD 考慮控管 client 註冊，包括限制特定 client 允許請求的 scope，這是 SHOULD，且在 draft 內。
- **scope 值的命名與 scope 與資源的對應**：RFC 6749 §3.3 說由 AS 定義；RFC 9068 §3 說 scope 與預設資源指示符的對應機制「超出本規格範圍」。
- **用 `scope` 還是 `resource`（RFC 8707）表達目標 RS**：RFC 9700 §2.3 兩者皆 MAY；[RFC 8707 §1](https://www.rfc-editor.org/rfc/rfc8707#section-1) 指出 scope 常被過度負擔去表達資源位置，但並不總是可行或適合。
- **RS 與 AS 之間如何傳遞授權資訊**：RFC 6749 §1.1 明說超出規格；可用 JWT（RFC 9068）或 introspection（[RFC 7662 §2.2](https://www.rfc-editor.org/rfc/rfc7662#section-2.2)，回應含 OPTIONAL 的 `scope`、`client_id`，且 AS 可對不同 RS 回不同的 scope 子集）。
- **OIDC 的 scope 行為**：[OIDC Core §3.1.2.1](https://openid.net/specs/openid-connect-core-1_0.html#AuthRequest) 規定請求 MUST 含 `openid`，無法理解的 scope SHOULD 被忽略。這提醒：AS 若不認得 `trips:read` 會直接忽略而不是報錯，請求端要看回應的 `scope` 才知道實際簽到什麼（呼應 RFC 6749 §3.3）。

## 三、DPoP 與 scope 的關係

- RFC 9449 的機制是**持有證明**：RS 要驗證 proof、`ath`（access token hash）、`htm`／`htu` 等（§7、§4.3），把 token 綁在金鑰持有者。我在全文搜尋 `scope` 只看到它在 `WWW-Authenticate` 的 `scope` 參數（§7.1，引用 RFC 6750 §3），**沒有任何一處把 DPoP 當成 scope 檢查的替代**。
- RFC 9449 §11.11 談的是 DPoP 與 client 認證的綁定限制（兩者僅因同一 TLS 通道而共現，沒有密碼學綁定）。以此推論：DPoP 金鑰證明的是「這把金鑰的持有者」，不是「這是哪個 client_id 或這個 client 被授權做什麼」。（推論）
- RFC 9700 §2.2.1 把 sender-constraint 與 §2.3 的權限最小化並列為各自獨立的 SHOULD，可見兩者互補。

## 四、業界慣例（廠商文件，不是標準）

- **Auth0**
  - [First-Party and Third-Party Applications](https://auth0.com/docs/get-started/applications/confidential-and-public-applications/first-party-and-third-party-applications)：比較表列出 user consent「第一方可以跳過（若 API 上開啟），第三方一律需要」。
  - [API Scopes](https://auth0.com/docs/get-started/apis/scopes/api-scopes)：呼叫端是第一方時，預設不要求使用者同意，但可設定要求；並且仍以 scope 限制 token 的存取權限，API 也可再加額外邏輯。
  - 重點：**跳過同意不等於不用 scope**。
- **Microsoft Entra ID**
  - [Expose a web API with scopes](https://learn.microsoft.com/en-us/entra/identity-platform/quickstart-configure-app-expose-web-apis) 說明：可預先授權（pre-authorize）受信任的 client，使使用者不會看到同意提示；呼叫 API 時 token 的 `scp` claim 仍帶註冊的權限，資源在執行期評估 `scp`。同頁提醒只應預先授權你信任的 client。
  - [Permissions and consent overview](https://learn.microsoft.com/en-us/entra/identity-platform/permissions-consent-overview) 也把 preauthorization 描述為「免同意提示」的機制。
  - 重點：同意與 scope 是兩條軸；預授權改的是前者。
- **Okta**
  - [Customize an authorization server](https://developer.okta.com/docs/guides/customize-authz-server/main/)：scope 可設「需要使用者同意」，並註明個別 client 可設定忽略該設定而跳過同意；另可用 access policy rule 限制特定 client、grant type、scope。
  - 重點：同樣把「跳過同意」做成 AS 端、依 client 的設定，scope 仍由 AS 依政策簽發。

三家做法一致：**第一方的特權落在 AS（略過同意、預授權、預設簽發範圍），RS 看的仍是 token 裡的 scope**。這是廠商一致性，不是標準要求。

## 五、對 A 與 B 的評估

下列「推論」標示者為我依上面來源與你的前提所做的判斷，不是來源明文。

| 面向 | A：RS 依第一方旗標豁免 | B：AS 簽發 `trips:*`，RS 檢查 token scope |
| --- | --- | --- |
| 安全 | 授權決定移到 RS，且 RS 要自己知道誰是第一方。標準給 RS 的檢查對象是 token（OAuth 2.1 §5、RFC 9700 §2.3），並無「靠 client 旗標」的依據。`client_id` 在公開 client 是自報值，RFC 8252 §8.6／RFC 6749 §10.2 明確承認冒充問題；RS 若信任 `client_id` 或旗標，攻擊者的另一個 client 只要拿到同帳號的 token 並偽稱或碰到旗標邏輯錯誤，就可能全開。token 洩漏時 A 的爆炸半徑是「第一方可做的一切」，B 則是 token 上的 scope。（推論，依據上述條文） | 符合 RFC 9700 §2.3 的最小權限；token 洩漏影響限於 scope。refresh token 依 RFC 9700 §4.14.2 也綁定同意的 scope。AS 以 `allowed_scopes` 限制各 client 可要的範圍，也符合 OAuth 2.1 §7.9 對 client 註冊的建議。 |
| 可維運 | 規則散在 RS 程式碼，目前甚至寫死單一 `client_id`，新增 client 要改 RS 並部署；已造成這次 403。AS 的 `first_party` 欄位與 RS 邏輯脫節。（來自你的前提） | 規則集中在 AS 設定（`allowed_scopes` 資料列）；新增 client 或調整範圍是資料變更。RS 只認一種規則：token scope。多一個要維護的就是 scope 命名與 AS 簽發設定的一致性。 |
| 客戶端改動成本 | 低：App 不用改，只改 RS（讓 `hasTripScope` 讀旗標，或補豁免）。但若 RS 依賴 AS 的 `first_party`，RS 還需要取得該資訊（introspection 或 token claim），不是零成本。（推論） | 中：App 授權請求要把 `trips:read trips:write` 加進 `scope`；AS 要把這兩個值加進兩個 client 的 `allowed_scopes`（資料變更）；既有已登入的 refresh token 因綁定舊同意範圍，使用者可能需要重新登入才取得新 scope（依 RFC 9700 §4.14.2「refresh token 綁定同意範圍」的推論，實際看 AS 實作）。可用「AS 對第一方 client 預設簽發」降低 App 端改動，見下。 |
| 與 DPoP 關係 | 無關：DPoP 解的是 token 被竊重放，不解授權範圍。A 也不會因 DPoP 而更安全或更不安全，只是少了一層限制。 | 互補：DPoP 管「誰持有」，scope 管「能做什麼」（RFC 9700 §2.2.1 與 §2.3 分列）。兩者不衝突，RS 的檢查順序可為驗 proof／`ath`、再驗 scope。 |
| 與標準一致度 | 低（自訂機制，標準沒有）。 | 高（OAuth 2.1 §5、RFC 9700 §2.3、RFC 9068 §2.2.3）。 |

### 建議

**採 B，並把「第一方」的特權放在 AS、不放在 RS。**（建議本身是推論）

1. AS 在兩個第一方 client 的 `allowed_scopes` 補上 `trips:read`、`trips:write`（資料變更，不改程式）。
2. 「App 要不要改請求」有兩種做法，皆符合 RFC 6749 §3.3：
   - **明確請求**：App 的授權請求帶 `scope=openid profile email offline_access trips:read trips:write`。簡單直接、行為可預期；代價是需發版，且舊版 App 仍會 403。
   - **AS 預設值**：client 省略 scope 時 AS 套預設 scope（§3.3 允許，且 SHOULD 文件化），或依 `first_party` 旗標由 AS 決定簽發範圍（§10.3 明確允許 AS 依 client 身分決定如何滿足 scope）。可不發版修復，但隱含行為較不透明。若採此做法，要在後端文件寫明。
3. RS 維持唯一規則「檢查 token scope」；移除寫死的 `client_id=tripline-tp-request` 豁免，或至少改為資料驅動，而不是新增第二個以 `client_id` 為依據的豁免。
4. 同意畫面：第一方 client 由 AS 政策跳過同意是合理且被容許的（OIDC §3.1.2.4、OAuth 2.1 §2.1、Auth0／Entra／Okta 皆有此功能），但依 RFC 8252 §8.6 與 OAuth 2.1 §7.3.1，免互動的前提是 client 身分可被確保。原生 App 可用 claimed https redirect（本專案已走 Universal Link／App Link）作為身分佐證（MAY），仍要記得這不是 client 認證。
5. 若要在短期內緊急止血而先走 A：只能是暫時措施，且豁免條件應來自 AS 簽進 token 的資訊，不要讓 RS 單憑請求上自報的 `client_id`；同時排定轉 B 的日期。（推論）

### OIDC 與 `offline_access` 的附帶提醒

[OIDC Core §11](https://openid.net/specs/openid-connect-core-1_0.html#OfflineAccess) 規定請求 `offline_access` 時 MUST 使用 `prompt=consent`，除非有其他允許離線存取的處理條件；OP MUST 一律取得同意才回 refresh token，且「先前儲存的同意不一定足夠」。本專案 App 已在 scope 中帶 `offline_access`；若 AS 對第一方跳過同意，需確認其屬於 OIDC 所說的「其他條件」，這是 AS 端的 OIDC 合規問題，我沒有查 AS 實作，結論不確定。

## 六、確定度與限制

- **確定（已逐條核對原文）**：上表標示「標準明文規定」的條文；標準中沒有 first-party 豁免機制這點，是我對 RFC 6749、8252、9700、9068、7662、9449、8707 與 OIDC Core 以關鍵字（`first-party`／`first party`／`trusted`／`consent`）檢索後的結果；RFC 6749、8252、9700、7662、9449、8707、OAuth 2.1 draft -17 與 OIDC Core 全文都搜不到 first-party 一詞；唯一出現處是 RFC 9068 §2.2.2 的附帶說明（第一方 client 呼叫自家後端 API 的常見情境，用來解釋為何 access token 內含身分 claim），沒有訂任何 scope 或同意規則。
- **版本風險**：OAuth 2.1 仍是 draft（本次 datatracker 顯示最新為 -17，2026-10-31；章節編號與措辭仍可能改變），不是 RFC。引用其 MUST 時不能當成現行 RFC 義務。
- **不確定／未查**：
  - 本專案 AS 的實際實作（簽發邏輯、`first_party` 欄位的用途、refresh 時是否重新評估 scope）；
  - `trips:read`／`trips:write` 這種自訂 scope 的 `aud` 對應；
  - 舊 refresh token 在 AS 補上 allowed scopes 後是否自動得到新 scope（依 RFC 9700 §4.14.2 推論需重新授權，但 AS 可自訂）；
  - Okta 頁面僅核對到「個別 client 可忽略需同意設定」這一層，未逐頁追完整設定細節。
- 廠商文件為抓取當日內容，之後可能改版；它們只能說明業界做法，不構成標準依據。

## 參考來源

- [RFC 6749 OAuth 2.0](https://www.rfc-editor.org/rfc/rfc6749)（§1.1、§2.1、§3.3、§10.2、§10.3）
- [RFC 8252 OAuth 2.0 for Native Apps](https://www.rfc-editor.org/rfc/rfc8252)（§8.6、§8.12）
- [RFC 9700 OAuth 2.0 Security BCP](https://www.rfc-editor.org/rfc/rfc9700)（§2.2.1、§2.3、§4.14.2）
- [RFC 9068 JWT Profile for OAuth 2.0 Access Tokens](https://www.rfc-editor.org/rfc/rfc9068)（§2.2、§2.2.3、§3、§4）
- [RFC 7662 Token Introspection](https://www.rfc-editor.org/rfc/rfc7662)（§2.2）
- [RFC 8707 Resource Indicators](https://www.rfc-editor.org/rfc/rfc8707)（§1）
- [RFC 9449 DPoP](https://www.rfc-editor.org/rfc/rfc9449)（§4.3、§7、§7.1、§11.11）
- [OAuth 2.1 draft-ietf-oauth-v2-1-17](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-v2-1-17)（§1.4.1、§2.1、§5、§7.1.4、§7.3.1、§7.9）
- [OpenID Connect Core 1.0](https://openid.net/specs/openid-connect-core-1_0.html)（§3.1.2.1、§3.1.2.4、§11）
- 廠商：[Auth0 first-party／third-party](https://auth0.com/docs/get-started/applications/confidential-and-public-applications/first-party-and-third-party-applications)、[Auth0 API scopes](https://auth0.com/docs/get-started/apis/scopes/api-scopes)、[Microsoft Entra 暴露 Web API／預授權](https://learn.microsoft.com/en-us/entra/identity-platform/quickstart-configure-app-expose-web-apis)、[Microsoft Entra 權限與同意](https://learn.microsoft.com/en-us/entra/identity-platform/permissions-consent-overview)、[Okta authorization server](https://developer.okta.com/docs/guides/customize-authz-server/main/)
